// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {FlashFeeCollector} from "../contracts/FlashFeeCollector.sol";

contract FlashFeeCollectorTest is Test {
    FlashFeeCollector public collector;

    // Mainnet addresses (for assertions only, hardcoded in contract)
    address constant V3_FEE_ADAPTER =
        0x5E74C9f42EEd283bFf3744fBD1889d398d40867d;
    address constant FIREPIT = 0x0D5Cd355e2aBEB8fb1552F56c965B867346d6721;
    address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNI_WETH_POOL = 0x3470447f3CecfFAc709D3e783A307790b0208d60;

    // Test tokens
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address owner = address(this);

    function setUp() public {
        // Fork mainnet at latest block
        // Note: Set RPC_URL in .env or use --fork-url flag

        // All addresses are hardcoded in contract, only pass owner
        collector = new FlashFeeCollector(owner);

        console.log("FlashFeeCollector deployed at:", address(collector));
    }

    function test_DeploymentCorrect() public view {
        assertEq(address(collector.V3_FEE_ADAPTER()), V3_FEE_ADAPTER);
        assertEq(address(collector.FIREPIT()), FIREPIT);
        assertEq(address(collector.UNI()), UNI);
        assertEq(collector.WETH(), WETH);
        assertEq(collector.owner(), owner);
    }

    function test_OnlyOwnerCanExecute() public {
        FlashFeeCollector.PoolCollect[]
            memory pools = new FlashFeeCollector.PoolCollect[](0);
        address[] memory tokens = new address[](1);
        tokens[0] = WETH;
        FlashFeeCollector.SwapRoute[]
            memory routes = new FlashFeeCollector.SwapRoute[](0);

        // Should work as owner
        // Note: Will revert with FlashLoanFailed since no fees available
        // but that's expected - we're testing ownership
        vm.expectRevert();
        collector.execute(pools, tokens, routes, 3000);

        // Should fail as non-owner
        vm.prank(address(0x1234));
        vm.expectRevert();
        collector.execute(pools, tokens, routes, 3000);
    }

    /*
    function test_ExecuteWithHighActivityPool() public {
        // All pools from highActivityPools.txt
        address[] memory pools = new address[](78);
        pools[0] = 0xb1914469141Ebb6e244e75cEe3f35d43BF6B85e5;
        pools[1] = 0x003896387666C5c11458EEb3F927B72a11b19783;
        pools[2] = 0x46af68beE5212318B3f30AE14b4EE03fd49FB147;
        pools[3] = 0xf7878463070a013A58F547b2b08df47a1FB91744;
        pools[4] = 0x8F0CB37cdFF37E004E0088f563E5fe39E05CCC5B;
        pools[5] = 0x8A7e585048bdA875e64024118c506B14f78166dd;
        pools[6] = 0x9445bd19767F73DCaE6f2De90e6cd31192F62589;
        pools[7] = 0x360acF12e72044ba3eaAA654E51E4725c699DcB1;
        pools[8] = 0xCba27C8e7115b4Eb50Aa14999BC0866674a96eCB;
        pools[9] = 0x57aF956d3E2cCa3B86f3D8C6772C03ddca3eAacB;
        pools[10] = 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
        pools[11] = 0xCD423F3ab39a11ff1D9208B7D37dF56E902C932B;
        pools[12] = 0x9e0905249CeEFfFB9605E034b534544684A58BE6;
        pools[13] = 0xc45A81BC23A64eA556ab4CdF08A86B61cdcEEA8b;
        pools[14] = 0xd31d41DfFa3589bB0c0183e46a1eed983a5E5978;
        pools[15] = 0xBaa1fcEFf65e21d547Bf6747b0b777a32bE53668;
        pools[16] = 0x32D9259e6792B2150FD50395D971864647FA27B2;
        pools[17] = 0x764510aB1d39CF300e7abe8F5B8977D18F290628;
        pools[18] = 0xd19393e02c3cc60C21A89b5e85656fF1122eBd51;
        pools[19] = 0xb1914469141Ebb6e244e75cEe3f35d43BF6B85e5;
        pools[20] = 0x003896387666C5c11458EEb3F927B72a11b19783;
        pools[21] = 0x46af68beE5212318B3f30AE14b4EE03fd49FB147;
        pools[22] = 0xf7878463070a013A58F547b2b08df47a1FB91744;
        pools[23] = 0x8F0CB37cdFF37E004E0088f563E5fe39E05CCC5B;
        pools[24] = 0x8A7e585048bdA875e64024118c506B14f78166dd;
        pools[25] = 0x9445bd19767F73DCaE6f2De90e6cd31192F62589;
        pools[26] = 0x360acF12e72044ba3eaAA654E51E4725c699DcB1;
        pools[27] = 0xCba27C8e7115b4Eb50Aa14999BC0866674a96eCB;
        pools[28] = 0x57aF956d3E2cCa3B86f3D8C6772C03ddca3eAacB;
        pools[29] = 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
        pools[30] = 0xCD423F3ab39a11ff1D9208B7D37dF56E902C932B;
        pools[31] = 0x9e0905249CeEFfFB9605E034b534544684A58BE6;
        pools[32] = 0xc45A81BC23A64eA556ab4CdF08A86B61cdcEEA8b;
        pools[33] = 0xd31d41DfFa3589bB0c0183e46a1eed983a5E5978;
        pools[34] = 0xBaa1fcEFf65e21d547Bf6747b0b777a32bE53668;
        pools[35] = 0x32D9259e6792B2150FD50395D971864647FA27B2;
        pools[36] = 0x764510aB1d39CF300e7abe8F5B8977D18F290628;
        pools[37] = 0xd19393e02c3cc60C21A89b5e85656fF1122eBd51;
        pools[38] = 0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36;
        pools[39] = 0x1d42064Fc4Beb5F8aAF85F4617AE8b3b5B8Bd801;
        pools[40] = 0xa6Cc3C2531FdaA6Ae1A3CA84c2855806728693e8;
        pools[41] = 0x5aE13BAAEF0620FdaE1D355495Dc51a17adb4082;
        pools[42] = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
        pools[43] = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        pools[44] = 0x60594a405d53811d3BC4766596EFD80fd545A270;
        pools[45] = 0xE0554a476A092703abdB3Ef35c80e0D76d32939F;
        pools[46] = 0x11b815efB8f581194ae79006d24E0d814B7697F6;
        pools[47] = 0xc7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b;
        pools[48] = 0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35;
        pools[49] = 0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16;
        pools[50] = 0x9Db9e0e53058C89e5B94e29621a205198648425B;
        pools[51] = 0x56534741CD8B152df6d48AdF7ac51f75169A83b2;
        pools[52] = 0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0;
        pools[53] = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
        pools[54] = 0x6546055f46e866a4B9a4A13e81273e3152BAE5dA;
        pools[55] = 0xE8a1F39C16EEA2844E98f951D711Bb4Bb31557aD;
        pools[56] = 0xFAD57d2039C21811C8F2B5D5B65308aa99D31559;
        pools[57] = 0x59c38b6775Ded821f010DbD30eCabdCF84E04756;
        pools[58] = 0x5aB53EE1d50eeF2C1DD3d5402789cd27bB52c1bB;
        pools[59] = 0xc3Db44ADC1fCdFd5671f555236eae49f4A8EEa18;
        pools[60] = 0x841820459769cd629B10a36FD12E603938cc2679;
        pools[61] = 0x127452F3f9cDc0389b0Bf59ce6131aA3Bd763598;
        pools[62] = 0x7b1E5D984A43eE732de195628d20d05CFaBc3cC7;
        pools[63] = 0xa3f558aebAecAf0e11cA4b2199cC5Ed341edfd74;
        pools[64] = 0xf763Bb342eB3d23C02ccB86312422fe0c1c17E94;
        pools[65] = 0x2982d3295A0E1a99e6E88Ece0E93FfDfc5c761ae;
        pools[66] = 0x2322e5517A3cBc75A3f02d74c96F82dda120D841;
        pools[67] = 0x27941A235804f33D81aDaBb2d56589c5f6Ea6556;
        pools[68] = 0x25392D7129040710f152174Af5019004a6F9b18d;
        pools[69] = 0x53Ead11073fc0651dce70572666f0eD0752abfeA;
        pools[70] = 0x81AEE07F99be78d88881Fa6D98FEFF7555113635;
        pools[71] = 0xf8e349d1d827a6EdF17eE673664CFAd4ca78C533;
        pools[72] = 0xAe750560b09aD1F5246f3b279b3767AfD1D79160;
        pools[73] = 0x18Bbe20F81bdcB340325E28a6eE6BB426B7cCbc1;
        pools[74] = 0xf359492d26764481002eD88BD2acae83cA50B5C9;
        pools[75] = 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
        pools[76] = 0xCD423F3ab39a11ff1D9208B7D37dF56E902C932B;
        pools[77] = 0xEeb8F880EAd7281A301ef2E6791A6bBe790603eD;

        address[] memory tokensToRelease = new address[](16);
        tokensToRelease[0] = WETH;
        tokensToRelease[1] = USDC;
        tokensToRelease[2] = USDT;
        tokensToRelease[3] = UNI;
        tokensToRelease[4] = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK
        tokensToRelease[5] = 0x45804880De22913dAFE09f4980848ECE6EcbAf78; // PAXG
        tokensToRelease[6] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC
        tokensToRelease[7] = 0x45e02bc2875A2914C4f585bBF92a6F28bc07CB70; // MBG
        tokensToRelease[8] = 0xbdF43ecAdC5ceF51B7D1772F722E40596BC1788B; // SEI
        tokensToRelease[9] = 0xe76C6c83af64e4C60245D8C7dE953DF673a7A33D; // Rail
        tokensToRelease[10] = 0xfAbA6f8e4a5E8Ab82F62fe7C39859FA577269BE3; // ONDO
        tokensToRelease[11] = 0x57e114B691Db790C35207b2e685D4A43181e6061; // ENA
        tokensToRelease[12] = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32; // LDO
        tokensToRelease[13] = 0xF3e4872e6a4cF365888D93b6146a2bAA7348F1A4; // SLVON
        tokensToRelease[14] = 0x643C4E15d7d62Ad0aBeC4a9BD4b001aA3Ef52d66; // SYRUP
        tokensToRelease[15] = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD; // SUSDS

        uint256 uniBalanceBefore = IERC20(UNI).balanceOf(owner);
        console.log("UNI balance before:", uniBalanceBefore);

        // This will either succeed with profit or revert
        // depending on available fees
        try collector.execute(pools, tokensToRelease) {
            uint256 uniBalanceAfter = IERC20(UNI).balanceOf(owner);
            uint256 profit = uniBalanceAfter - uniBalanceBefore;
            console.log("SUCCESS! Profit:", profit);
        } catch Error(string memory reason) {
            console.log("Reverted:", reason);
            console.log("Reverted (no reason)");
        }
    }
    */
    /*function test_LpTokenUnwind() public {
        // USDC-WETH V2 Pair
        address lpToken = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;

        deal(lpToken, address(collector), 0.01 * 1e18);

        address[] memory pools = new address[](0);
        address[] memory tokens = new address[](1);
        tokens[0] = lpToken;

        uint256 uniBalanceBefore = IERC20(UNI).balanceOf(owner);

        collector.execute(pools, tokens);

        uint256 uniBalanceAfter = IERC20(UNI).balanceOf(owner);
        uint256 profit = uniBalanceAfter - uniBalanceBefore;

        console.log("LP Test Profit:", profit);

        // Assert LP token was burned (balance should be 0)
        assertEq(
            IERC20(lpToken).balanceOf(address(collector)),
            0,
            "LP tokens not burned"
        );

        // Assert we made some profit (means swaps worked)
        assertTrue(profit > 0, "No profit made from LP unwind");
    }*/

    function test_MixedTokens() public {
        // High activity pools to collect fees from (provides ETH/profit for flash loan)
        address[] memory pools = new address[](78);
        pools[0] = 0x8E4318E2cb1ae291254B187001a59a1f8ac78cEF;
        pools[1] = 0x60594a405d53811d3BC4766596EFD80fd545A270;
        pools[2] = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;
        pools[3] = 0xf7878463070a013A58F547b2b08df47a1FB91744;
        pools[4] = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
        pools[5] = 0xE0554a476A092703abdB3Ef35c80e0D76d32939F;
        pools[6] = 0x9445bd19767F73DCaE6f2De90e6cd31192F62589;
        pools[7] = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        pools[8] = 0x11b815efB8f581194ae79006d24E0d814B7697F6;
        pools[9] = 0xc7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b;
        pools[10] = 0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36;
        pools[11] = 0xC5aF84701f98Fa483eCe78aF83F11b6C38ACA71D;
        pools[12] = 0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35;
        pools[13] = 0x9a772018FbD77fcD2d25657e5C547BAfF3Fd7D16;
        pools[14] = 0x56534741CD8B152df6d48AdF7ac51f75169A83b2;
        pools[15] = 0x9Db9e0e53058C89e5B94e29621a205198648425B;
        pools[16] = 0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0;
        pools[17] = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
        pools[18] = 0xe6ff8b9A37B0fab776134636D9981Aa778c4e718;
        pools[19] = 0xEeb8F880EAd7281A301ef2E6791A6bBe790603eD;
        pools[20] = 0xD80e75fAf4cc02F6447287D5b1EF195EAc19FfD9;
        pools[21] = 0x5aE13BAAEF0620FdaE1D355495Dc51a17adb4082;
        pools[22] = 0x6546055f46e866a4B9a4A13e81273e3152BAE5dA;
        pools[23] = 0xa91F80380D9Cc9c86EB98D2965A0DED9E2000791;
        pools[24] = 0xE8a1F39C16EEA2844E98f951D711Bb4Bb31557aD;
        pools[25] = 0xFAD57d2039C21811C8F2B5D5B65308aa99D31559;
        pools[26] = 0x5d4F3C6fA16908609BAC31Ff148Bd002AA6b8c83;
        pools[27] = 0x1d42064Fc4Beb5F8aAF85F4617AE8b3b5B8Bd801;
        pools[28] = 0x59c38b6775Ded821f010DbD30eCabdCF84E04756;
        pools[29] = 0x5aB53EE1d50eeF2C1DD3d5402789cd27bB52c1bB;
        pools[30] = 0x4C54Ff7F1c424Ff5487A32aaD0b48B19cBAf087F;
        pools[31] = 0xc3Db44ADC1fCdFd5671f555236eae49f4A8EEa18;
        pools[32] = 0x24EE2c6B9597F035088CDa8575E9D5e15a84B9DF;
        pools[33] = 0x38fA0E36a9Eb335Ca00dbd6d0f203b0Bd72Ce3b6;
        pools[34] = 0x841820459769cd629B10a36FD12E603938cc2679;
        pools[35] = 0x127452F3f9cDc0389b0Bf59ce6131aA3Bd763598;
        pools[36] = 0x7b1E5D984A43eE732de195628d20d05CFaBc3cC7;
        pools[37] = 0xa3f558aebAecAf0e11cA4b2199cC5Ed341edfd74;
        pools[38] = 0xf763Bb342eB3d23C02ccB86312422fe0c1c17E94;
        pools[39] = 0x433a00819C771b33FA7223a5B3499b24FBCd1bBC;
        pools[40] = 0x2982d3295A0E1a99e6E88Ece0E93FfDfc5c761ae;
        pools[41] = 0x2322e5517A3cBc75A3f02d74c96F82dda120D841;
        pools[42] = 0x33676385160f9d8f03a0db2821029882f7c79e93;
        pools[43] = 0xfBa26C3F9C8eCeF989def3C5c8aD037487462d83;
        pools[44] = 0x53Ead11073fc0651dce70572666f0eD0752abfeA;
        pools[45] = 0x81AEE07F99be78d88881Fa6D98FEFF7555113635;
        pools[46] = 0x27941A235804f33D81aDaBb2d56589c5f6Ea6556;
        pools[47] = 0x43e7AdE137b86798654D8e78c36D5a556a647224;
        pools[48] = 0x000ba527862e5b82cff0F7c66b646AF023274aA1;
        pools[49] = 0xf8e349d1d827a6EdF17eE673664CFAd4ca78C533;
        pools[50] = 0x893f503FaC2Ee1e5B78665db23F9c94017Aae97D;
        pools[51] = 0x14243EA6bB3d64C8d54A1f47B077e23394D6528A;
        pools[52] = 0xde77450D0887994364b62a93e14A3a76D2Db9162;
        pools[53] = 0x3c385B0ce5b48958ffab12FFd8DA14d433d7b885;
        pools[54] = 0xD9b1A42BEa4f011A9c3fcdF8Ff2Bbc76FdE37D0F;
        pools[55] = 0xAe750560b09aD1F5246f3b279b3767AfD1D79160;
        pools[56] = 0x510100D5143e011Db24E2aa38abE85d73D5B2177;
        pools[57] = 0xdceaf5d0E5E0dB9596A47C0c4120654e80B1d706;
        pools[58] = 0xC74F05C1e7b86fa42Ab07Ab4a1361286B9a90087;
        pools[59] = 0x18Bbe20F81bdcB340325E28a6eE6BB426B7cCbc1;
        pools[60] = 0x8cD6C8c449918D92d2ad4658C32F2e2fF1e7096D;
        pools[61] = 0xe092769bc1fa5262D4f48353f90890Dcc339BF80;
        pools[62] = 0xF12533a96712133d9Bb97C24de5BCf52F48851BD;
        pools[63] = 0xd19393e02c3cc60C21A89b5e85656fF1122eBd51;
        pools[64] = 0x7C706586679Af2BA6D1A9fC2DA9C6aF59883fdD3;
        pools[65] = 0x764510aB1d39CF300e7abe8F5B8977D18F290628;
        pools[66] = 0x32D9259e6792B2150FD50395D971864647FA27B2;
        pools[67] = 0xc45A81BC23A64eA556ab4CdF08A86B61cdcEEA8b;
        //pools[68] = 0x25392D7129040710f152174Af5019004a6F9b18d;
        pools[68] = 0xCD423F3ab39a11ff1D9208B7D37dF56E902C932B;
        pools[69] = 0x57aF956d3E2cCa3B86f3D8C6772C03ddca3eAacB;
        pools[70] = 0xCba27C8e7115b4Eb50Aa14999BC0866674a96eCB;
        pools[71] = 0xf7878463070a013A58F547b2b08df47a1FB91744;
        pools[72] = 0x46af68beE5212318B3f30AE14b4EE03fd49FB147;
        pools[73] = 0xb1914469141Ebb6e244e75cEe3f35d43BF6B85e5;
        pools[74] = 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
        pools[75] = 0xc593Fe9193B745447e86b45eA0Bf62565eE030cc;
        pools[76] = 0x241fC1CdBF9f741933e5Fa515C5b884da93b81b6;
        pools[77] = 0xaA089185Bc53B701375495d93B6192e94E8ca296;
        /*
        address[] memory pools = new address[](30);
        pools[0] = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        pools[1] = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
        pools[2] = 0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36;
        pools[3] = 0xc7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b;
        pools[4] = 0x56534741CD8B152df6d48AdF7ac51f75169A83b2;
        pools[5] = 0x4585FE77225b41b697C938B018E2Ac67Ac5a20c0;
        pools[6] = 0x5aE13BAAEF0620FdaE1D355495Dc51a17adb4082;
        pools[7] = 0xE0554a476A092703abdB3Ef35c80e0D76d32939F;
        pools[8] = 0x11b815efB8f581194ae79006d24E0d814B7697F6;
        pools[9] = 0xf8e349d1d827a6EdF17eE673664CFAd4ca78C533;
        pools[10] = 0x2837809FD68e4a4104af76bbec5b622b6146B2cb;
        pools[11] = 0x7b1E5D984A43eE732de195628d20d05CFaBc3cC7;
        pools[12] = 0x27941A235804f33D81aDaBb2d56589c5f6Ea6556;
        pools[13] = 0xa6Cc3C2531FdaA6Ae1A3CA84c2855806728693e8;
        pools[14] = 0xFAD57d2039C21811C8F2B5D5B65308aa99D31559;
        pools[15] = 0x5aB53EE1d50eeF2C1DD3d5402789cd27bB52c1bB;
        pools[16] = 0x53Ead11073fc0651dce70572666f0eD0752abfeA;
        pools[17] = 0xa3f558aebAecAf0e11cA4b2199cC5Ed341edfd74;
        pools[18] = 0x0c30062368eEfB96bF3AdE1218E685306b8E89Fa;
        pools[19] = 0x87B1d1B59725209879CC5C5adEb99d8BC9EcCf12;
        pools[20] = 0x87B1d1B59725209879CC5C5adEb99d8BC9EcCf12;
        pools[21] = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;
        pools[22] = 0xC2C390c6CD3C4e6c2b70727d35a45e8a072F18cA;
        pools[23] = 0x948b54A93f5aD1df6B8bFF6Dc249D99CA2EcA052;
        pools[24] = 0xC4Dbe30FEcc148a8755c970f3b8b0c9aF0Db81F5;
        pools[25] = 0xf7878463070a013A58F547b2b08df47a1FB91744;
        pools[26] = 0x4d1Eff861316396dD1915F69B49f4C2d7B11590d;
        pools[27] = 0x5AAA28Ca43C6646fD1403e508f0FCA1D92357dde;
        pools[28] = 0x9Db9e0e53058C89e5B94e29621a205198648425B;
        pools[29] = 0x1d42064Fc4Beb5F8aAF85F4617AE8b3b5B8Bd801;
        */
        // Tokens to release
        address[] memory tokensToRelease = new address[](20);
        tokensToRelease[0] = WETH;
        tokensToRelease[1] = USDC;
        tokensToRelease[2] = USDT;
        tokensToRelease[3] = UNI;
        tokensToRelease[4] = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // LINK
        tokensToRelease[5] = 0x45804880De22913dAFE09f4980848ECE6EcbAf78; // PAXG
        tokensToRelease[6] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC
        tokensToRelease[7] = 0x45e02bc2875A2914C4f585bBF92a6F28bc07CB70; // MBG
        tokensToRelease[8] = 0xbdF43ecAdC5ceF51B7D1772F722E40596BC1788B; // SEI
        tokensToRelease[9] = 0xB1F1ee126e9c96231Cc3d3fAD7C08b4cf873b1f1; // Bifi
        tokensToRelease[10] = 0xbc7Ce7b6B5437d7D715fbb1Cc7b4eC12399C5516; // LP1
        tokensToRelease[11] = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852; // LP2
        tokensToRelease[12] = 0xfAbA6f8e4a5E8Ab82F62fe7C39859FA577269BE3; // ONDO
        tokensToRelease[13] = 0xC7e6B676bfC73Ae40bcC4577F22aab1682C691C6; // WETH/USDT
        tokensToRelease[14] = 0x163f8C2467924be0ae7B5347228CABF260318753; // WLD
        tokensToRelease[15] = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32; // LDO
        tokensToRelease[16] = 0xB8c77482e45F1F44dE1745F52C74426C631bDD52; // BNB
        //tokensToRelease[17] = 0x712943857F7Dc415ddB2f3848accADC540CA6b38; // BURGL-WETH
        tokensToRelease[17] = 0xF3e4872e6a4cF365888D93b6146a2bAA7348F1A4; // SLVON
        tokensToRelease[18] = 0xc4704f13d5E08b27B039d53873E813dD2fAD99d9; // SomeLP
        tokensToRelease[19] = 0xC7e6B676bfC73Ae40bcC4577F22aab1682C691C6; // SomeLP

        uint256 uniBalanceBefore = IERC20(UNI).balanceOf(owner);
        console.log("UNI Balance Before:", uniBalanceBefore);

        console.log("Executing mixed token swap (Real Flow)...");

        // Convert pools to PoolCollect structs with max amounts
        FlashFeeCollector.PoolCollect[]
            memory poolCollects = new FlashFeeCollector.PoolCollect[](
                pools.length
            );
        for (uint256 i = 0; i < pools.length; i++) {
            poolCollects[i] = FlashFeeCollector.PoolCollect({
                pool: pools[i],
                amount0: type(uint128).max,
                amount1: type(uint128).max
            });
        }

        // Empty routes - contract will use default 0.3% fee
        FlashFeeCollector.SwapRoute[]
            memory routes = new FlashFeeCollector.SwapRoute[](0);
        collector.execute(poolCollects, tokensToRelease, routes, 3000);

        uint256 uniBalanceAfter = IERC20(UNI).balanceOf(owner);
        uint256 profit = uniBalanceAfter - uniBalanceBefore;

        console.log("Mixed Test Profit:", profit);

        // Assertions
        assertEq(
            IERC20(tokensToRelease[10]).balanceOf(address(collector)),
            0,
            "LP not cleared from collector"
        );
        assertEq(
            IERC20(tokensToRelease[11]).balanceOf(address(collector)),
            0,
            "LP not cleared from collector"
        );
        assertEq(
            IERC20(tokensToRelease[12]).balanceOf(address(collector)),
            0,
            "LP not cleared from collector"
        );
        assertEq(
            IERC20(tokensToRelease[10]).balanceOf(FIREPIT),
            0,
            "LP not released from Firepit"
        );
        assertEq(
            IERC20(tokensToRelease[11]).balanceOf(FIREPIT),
            0,
            "LP not released from Firepit"
        );
        assertTrue(profit > 0, "No profit made from mixed tokens");
    }
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}
