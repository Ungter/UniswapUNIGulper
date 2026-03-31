// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title FeeCollectorReleaser
/// @notice Collects V3 protocol fees and releases them via Firepit in one atomic transaction
/// @dev Caller must approve UNI tokens before calling collectAndRelease
contract FeeCollectorReleaser {
    using SafeERC20 for IERC20;

    // ============================================
    // Immutable Addresses (Ethereum Mainnet)
    // ============================================

    /// @notice V3 Fee Adapter contract
    IV3FeeAdapter public immutable V3_FEE_ADAPTER;

    /// @notice Firepit releaser contract
    IFirepit public immutable FIREPIT;

    /// @notice TokenJar contract (receives fees from V3FeeAdapter)
    address public immutable TOKEN_JAR;

    /// @notice UNI token
    IERC20 public immutable UNI;

    /// @notice Amount of UNI required per release (4000 UNI)
    uint256 public constant UNI_REQUIRED = 4000 * 1e18;

    // ============================================
    // Events
    // ============================================

    event FeesCollected(uint256 poolCount);
    event TokensReleased(address indexed recipient, uint256 tokenCount);

    // ============================================
    // Errors
    // ============================================

    error InsufficientUNIAllowance();
    error TooManyTokens();
    error CollectionFailed();
    error ReleaseFailed();

    // ============================================
    // Constructor
    // ============================================

    constructor(
        address _v3FeeAdapter,
        address _firepit,
        address _tokenJar,
        address _uni
    ) {
        V3_FEE_ADAPTER = IV3FeeAdapter(_v3FeeAdapter);
        FIREPIT = IFirepit(_firepit);
        TOKEN_JAR = _tokenJar;
        UNI = IERC20(_uni);
    }

    // ============================================
    // Main Function
    // ============================================

    /// @notice Collects fees from V3 pools and releases them to the caller
    /// @param pools Array of pool addresses to collect fees from
    /// @param tokensToRelease Array of token addresses to release (max 20)
    /// @return amounts Array of amounts received for each token
    function collectAndRelease(
        address[] calldata pools,
        address[] calldata tokensToRelease
    ) external returns (uint256[] memory amounts) {
        // Check token limit (Firepit max is 20)
        if (tokensToRelease.length > 20) revert TooManyTokens();

        // 1. Transfer UNI from caller to this contract
        uint256 allowance = UNI.allowance(msg.sender, address(this));
        if (allowance < UNI_REQUIRED) revert InsufficientUNIAllowance();

        UNI.safeTransferFrom(msg.sender, address(this), UNI_REQUIRED);

        // 2. Collect fees from V3 pools (fees go to TokenJar)
        if (pools.length > 0) {
            IV3FeeAdapter.CollectParams[]
                memory collectParams = new IV3FeeAdapter.CollectParams[](
                    pools.length
                );

            for (uint256 i = 0; i < pools.length; i++) {
                collectParams[i] = IV3FeeAdapter.CollectParams({
                    pool: pools[i],
                    amount0Requested: type(uint128).max,
                    amount1Requested: type(uint128).max
                });
            }

            V3_FEE_ADAPTER.collect(collectParams);
            emit FeesCollected(pools.length);
        }

        // 3. Approve UNI to Firepit
        UNI.approve(address(FIREPIT), UNI_REQUIRED);

        // 4. Get current nonce from Firepit
        uint256 nonce = FIREPIT.nonce();

        // 5. Call release - this burns UNI and sends tokens from TokenJar to this contract
        FIREPIT.release(nonce, tokensToRelease, address(this));

        // 6. Transfer all received tokens to caller
        amounts = new uint256[](tokensToRelease.length);

        for (uint256 i = 0; i < tokensToRelease.length; i++) {
            IERC20 token = IERC20(tokensToRelease[i]);
            uint256 balance = token.balanceOf(address(this));

            if (balance > 0) {
                token.safeTransfer(msg.sender, balance);
            }

            amounts[i] = balance;
        }

        emit TokensReleased(msg.sender, tokensToRelease.length);

        return amounts;
    }

    /// @notice Allows contract to receive ETH (for native token releases)
    receive() external payable {}

    /// @notice Withdraw any stuck ETH to caller
    function withdrawETH() external {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = msg.sender.call{value: balance}("");
            require(success, "ETH transfer failed");
        }
    }

    /// @notice Emergency withdraw for any stuck tokens
    function withdrawToken(address token) external {
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (balance > 0) {
            tokenContract.safeTransfer(msg.sender, balance);
        }
    }
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

    struct Collected {
        uint128 amount0Collected;
        uint128 amount1Collected;
    }

    function collect(
        CollectParams[] calldata collectParams
    ) external returns (Collected[] memory amountsCollected);
}

interface IFirepit {
    function nonce() external view returns (uint256);

    function threshold() external view returns (uint256);

    function release(
        uint256 _nonce,
        address[] calldata assets,
        address recipient
    ) external;
}
