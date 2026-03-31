// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title FlashFeeCollector
/// @notice Uses V3 flash loan to collect fees with off-chain computed swap routes
/// @dev Routes are computed off-chain via QuoterV2 to save gas
contract FlashFeeCollector is Ownable {
    using SafeERC20 for IERC20;

    // ============================================
    // Types
    // ============================================

    /// @notice Pre-computed swap route for a token
    /// @param token Token to swap
    /// @param fee Fee tier for direct token→WETH swap (500, 3000, 10000), 0 if via stable
    /// @param viaStable If true, route through USDC or USDT
    /// @param stable USDC or USDT address (only used if viaStable)
    /// @param stableFee1 Fee for token→stable hop
    /// @param stableFee2 Fee for stable→WETH hop
    struct SwapRoute {
        address token;
        uint24 fee;
        bool viaStable;
        address stable;
        uint24 stableFee1;
        uint24 stableFee2;
    }

    /// @notice Pool collection params with selective amounts
    /// @param pool V3 pool address
    /// @param amount0 Amount to collect for token0 (0 to skip, max to collect all)
    /// @param amount1 Amount to collect for token1 (0 to skip, max to collect all)
    struct PoolCollect {
        address pool;
        uint128 amount0;
        uint128 amount1;
    }

    // ============================================
    // Constants & Immutables
    // ============================================

    uint256 public constant UNI_LOAN_AMOUNT = 4000 * 1e18;
    uint256 public constant MIN_PROFIT = 5 * 1e16; // 0.05 UNI

    IV3FeeAdapter public immutable V3_FEE_ADAPTER;
    IFirepit public immutable FIREPIT;
    IERC20 public immutable UNI;
    address public immutable WETH;
    IUniswapV3Pool public immutable FLASH_POOL;
    IUniversalRouter public immutable UNIVERSAL_ROUTER;
    bool public immutable UNI_IS_TOKEN0;

    // Known stablecoins
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // Universal Router command
    uint8 private constant V3_SWAP_EXACT_IN = 0x00;

    // Hardcoded mainnet addresses
    address private constant V3_FEE_ADAPTER_ADDR =
        0x5E74C9f42EEd283bFf3744fBD1889d398d40867d;
    address private constant FIREPIT_ADDR =
        0x0D5Cd355e2aBEB8fb1552F56c965B867346d6721;
    address private constant UNI_ADDR =
        0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address private constant WETH_ADDR =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant FLASH_POOL_ADDR =
        0x3470447f3CecfFAc709D3e783A307790b0208d60;
    address private constant UNIVERSAL_ROUTER_ADDR =
        0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;

    // ============================================
    // Events & Errors
    // ============================================

    event Executed(address indexed caller, uint256 profit);
    event DebugStep(string step, uint256 value);

    error Unauthorized();
    error InsufficientProfit(uint256 profit, uint256 required);
    error FlashLoanFailed(uint256 balance, uint256 required);
    error TooManyTokens(uint256 count, uint256 max);
    error FirepitReleaseFailed();

    // ============================================
    // Constructor
    // ============================================

    constructor(address _owner) Ownable(_owner) {
        V3_FEE_ADAPTER = IV3FeeAdapter(V3_FEE_ADAPTER_ADDR);
        FIREPIT = IFirepit(FIREPIT_ADDR);
        UNI = IERC20(UNI_ADDR);
        WETH = WETH_ADDR;
        FLASH_POOL = IUniswapV3Pool(FLASH_POOL_ADDR);
        UNIVERSAL_ROUTER = IUniversalRouter(UNIVERSAL_ROUTER_ADDR);
        UNI_IS_TOKEN0 = IUniswapV3Pool(FLASH_POOL_ADDR).token0() == UNI_ADDR;
    }

    // ============================================
    // Main Entry Point (Owner Only)
    // ============================================

    /// @notice Execute fee collection with pre-computed routes
    /// @param pools V3 pools to collect fees from with selective amounts
    /// @param tokensToRelease Tokens to release from Firepit
    /// @param routes Pre-computed swap routes for each token
    /// @param wethToUniFee Fee tier for final WETH→UNI swap
    function execute(
        PoolCollect[] calldata pools,
        address[] calldata tokensToRelease,
        SwapRoute[] calldata routes,
        uint24 wethToUniFee
    ) external onlyOwner {
        if (tokensToRelease.length > 20)
            revert TooManyTokens(tokensToRelease.length, 20);

        bytes memory data = abi.encode(
            pools,
            tokensToRelease,
            routes,
            wethToUniFee
        );

        if (UNI_IS_TOKEN0) {
            FLASH_POOL.flash(address(this), UNI_LOAN_AMOUNT, 0, data);
        } else {
            FLASH_POOL.flash(address(this), 0, UNI_LOAN_AMOUNT, data);
        }
    }

    // ============================================
    // Flash Loan Callback
    // ============================================

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        if (msg.sender != address(FLASH_POOL)) revert Unauthorized();

        (
            PoolCollect[] memory pools,
            address[] memory tokensToRelease,
            SwapRoute[] memory routes,
            uint24 wethToUniFee
        ) = abi.decode(data, (PoolCollect[], address[], SwapRoute[], uint24));

        uint256 totalToRepay = UNI_LOAN_AMOUNT + (UNI_IS_TOKEN0 ? fee0 : fee1);

        // 1. Collect fees with selective amounts
        _collectFees(pools);

        // 2. Release tokens from Firepit
        UNI.approve(address(FIREPIT), UNI_LOAN_AMOUNT);
        uint256 nonce = FIREPIT.nonce();

        try FIREPIT.release(nonce, tokensToRelease, address(this)) {} catch {
            revert FirepitReleaseFailed();
        }

        // 3. Swap all tokens → WETH using provided routes
        _swapAllToWETH(tokensToRelease, routes);

        // 4. Swap all WETH → UNI
        uint256 wethBal = IERC20(WETH).balanceOf(address(this));
        if (wethBal > 0) {
            _executeSwap(WETH, address(UNI), wethBal, wethToUniFee);
        }

        // 5. Repay flash loan and send profit
        uint256 uniBal = UNI.balanceOf(address(this));
        emit DebugStep("UNI balance", uniBal);

        if (uniBal < totalToRepay) revert FlashLoanFailed(uniBal, totalToRepay);

        UNI.safeTransfer(address(FLASH_POOL), totalToRepay);

        uint256 profit = UNI.balanceOf(address(this));
        if (profit < MIN_PROFIT) revert InsufficientProfit(profit, MIN_PROFIT);

        UNI.safeTransfer(owner(), profit);
        emit Executed(owner(), profit);
    }

    // ============================================
    // Internal - Fee Collection
    // ============================================

    function _collectFees(PoolCollect[] memory pools) internal {
        if (pools.length == 0) return;

        IV3FeeAdapter.CollectParams[]
            memory params = new IV3FeeAdapter.CollectParams[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            params[i] = IV3FeeAdapter.CollectParams({
                pool: pools[i].pool,
                amount0Requested: pools[i].amount0,
                amount1Requested: pools[i].amount1
            });
        }

        V3_FEE_ADAPTER.collect(params);
    }

    // ============================================
    // Internal - Swap Logic
    // ============================================

    function _swapAllToWETH(
        address[] memory tokens,
        SwapRoute[] memory routes
    ) internal {
        // Build a mapping from token to route
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == address(UNI) || token == WETH) continue;

            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal == 0) continue;

            // Try to handle as LP token first
            if (_tryHandleLP(token, bal, routes)) continue;

            // Find route for this token
            SwapRoute memory route = _findRoute(token, routes);

            if (route.fee == 0 && !route.viaStable) {
                // No route provided, try default 0.3% fee
                _executeSwap(token, WETH, bal, 3000);
            } else if (route.viaStable) {
                // Multi-hop via stablecoin
                _executeSwap(token, route.stable, bal, route.stableFee1);
                uint256 stableBal = IERC20(route.stable).balanceOf(
                    address(this)
                );
                if (stableBal > 0) {
                    _executeSwap(
                        route.stable,
                        WETH,
                        stableBal,
                        route.stableFee2
                    );
                }
            } else {
                // Direct swap
                _executeSwap(token, WETH, bal, route.fee);
            }
        }
    }

    function _findRoute(
        address token,
        SwapRoute[] memory routes
    ) internal pure returns (SwapRoute memory) {
        for (uint256 i = 0; i < routes.length; i++) {
            if (routes[i].token == token) {
                return routes[i];
            }
        }
        return SwapRoute(address(0), 0, false, address(0), 0, 0);
    }

    function _tryHandleLP(
        address token,
        uint256 amount,
        SwapRoute[] memory routes
    ) internal returns (bool) {
        try IUniswapV2Pair(token).token0() returns (address t0) {
            address t1;
            try IUniswapV2Pair(token).token1() returns (address _t1) {
                t1 = _t1;
            } catch {
                return false;
            }

            try this._burnLPExternal(token, amount, t0, t1, routes) {
                return true;
            } catch {
                return false;
            }
        } catch {
            return false;
        }
    }

    function _burnLPExternal(
        address token,
        uint256 amount,
        address t0,
        address t1,
        SwapRoute[] calldata routes
    ) external {
        require(msg.sender == address(this), "Only self");

        bool success = IERC20(token).transfer(token, amount);
        require(success, "LP transfer failed");

        (uint256 a0, uint256 a1) = IUniswapV2Pair(token).burn(address(this));

        if (a0 > 0 && t0 != WETH && t0 != address(UNI)) {
            SwapRoute memory r0 = _findRoute(t0, routes);
            if (r0.fee > 0) {
                _executeSwap(t0, WETH, a0, r0.fee);
            } else {
                _executeSwap(t0, WETH, a0, 3000); // Default
            }
        }
        if (a1 > 0 && t1 != WETH && t1 != address(UNI)) {
            SwapRoute memory r1 = _findRoute(t1, routes);
            if (r1.fee > 0) {
                _executeSwap(t1, WETH, a1, r1.fee);
            } else {
                _executeSwap(t1, WETH, a1, 3000); // Default
            }
        }
    }

    function _executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint24 fee
    ) internal {
        if (amount == 0) return;

        IERC20(tokenIn).safeTransfer(address(UNIVERSAL_ROUTER), amount);

        bytes memory path = abi.encodePacked(tokenIn, fee, tokenOut);
        bytes memory commands = abi.encodePacked(V3_SWAP_EXACT_IN);
        bytes[] memory inputs = new bytes[](1);

        inputs[0] = abi.encode(address(this), amount, 0, path, false);

        try
            UNIVERSAL_ROUTER.execute(commands, inputs, block.timestamp + 120)
        {} catch {}
    }

    // ============================================
    // Owner Functions
    // ============================================

    function withdrawToken(address token, address to) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) IERC20(token).safeTransfer(to, bal);
    }

    function withdrawETH(address to) external onlyOwner {
        uint256 bal = address(this).balance;
        if (bal > 0) {
            (bool ok, ) = to.call{value: bal}("");
            require(ok);
        }
    }

    receive() external payable {}
}

// ============================================
// Interfaces
// ============================================

interface IV3FeeAdapter {
    struct CollectParams {
        address pool;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    function collect(CollectParams[] calldata) external;
}

interface IFirepit {
    function nonce() external view returns (uint256);

    function release(uint256, address[] calldata, address) external;
}

interface IUniswapV3Pool {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function flash(address, uint256, uint256, bytes calldata) external;
}

interface IUniversalRouter {
    function execute(
        bytes calldata,
        bytes[] calldata,
        uint256
    ) external payable;
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function burn(address) external returns (uint256, uint256);
}
