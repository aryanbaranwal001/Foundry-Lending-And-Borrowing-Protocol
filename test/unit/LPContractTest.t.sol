// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdCheats} from "lib/forge-std/src/StdCheats.sol";
import {DeployLPContract} from "script/DeployLPContract.s.sol";
import {HelperConfigLPContract} from "script/HelperConfigLPContract.s.sol";
import {LPContract} from "src/LPContract.sol";

import {LPToken} from "src/LPToken.sol";
import {SunEth} from "src/LPExternalTokens/SunEth.sol";
import {EarthEth} from "src/LPExternalTokens/EarthEth.sol";
import {EarthEthAggregator} from "src/LPExternalAggregators/EarthEthAggregator.sol";
import {SunEthAggregator} from "src/LPExternalAggregators/SunEthAggregator.sol";

contract LPContractTest is Test {
    LPToken lpToken;
    SunEth sunEth;
    EarthEth earthEth;
    SunEthAggregator sunEthAggregator;
    EarthEthAggregator earthEthAggregator;

    address SunEthAddress;
    address EarthEthAddress;
    address SunEthPriceFeedAddress;
    address EarthEthPriceFeedAddress;
    address LPTokenAddress;

    uint256 public constant STARTING_BALANCE = 1000 ether;
    address public USER = makeAddr("USER");
    address public immutable i_initial_owner = msg.sender;

    LPContract lPContract;
    HelperConfigLPContract helperConfigLPContract;

    function setUp() public {
        DeployLPContract deployLPContract = new DeployLPContract();
        (lPContract, helperConfigLPContract) = deployLPContract.run();

        (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, LPTokenAddress) =
            helperConfigLPContract.getNetworkConfigs();

        lpToken = LPToken(LPTokenAddress);
        sunEth = SunEth(SunEthAddress);
        earthEth = EarthEth(EarthEthAddress);
        sunEthAggregator = SunEthAggregator(SunEthPriceFeedAddress);
        earthEthAggregator = EarthEthAggregator(EarthEthPriceFeedAddress);

        vm.deal(USER, 100 ether);
    }

    function testCheckInitialVolumeOfSunAndEarthTokens() public {
        uint256 sunEthAmt = lPContract.getTotalSunEthInPool();
        uint256 earthEthAmt = lPContract.getTotalEarthEthInPool();

        assert(sunEthAmt == 2.5e18);
        assert(earthEthAmt == 1e19);
        assert(sunEth.balanceOf(address(lPContract)) == 2.5e18);
        assert(earthEth.balanceOf(address(lPContract)) == 1e19);
    }

    function testMintInitialLPTokens() public {
        uint256 lpTokenBalanceOfContract = lpToken.balanceOf(address(lPContract));

        assert(lpTokenBalanceOfContract == 5e18);
    }

    function testConstructorTwoStillCallable() public {
        bool tempVar = lPContract.constructor2();
        assert(tempVar == true);
    }

    function testGetTokenFromPoolUsingLPTokens() public giveTokensToUser {
        vm.prank(USER);
        lPContract.addToPool(1e16, 4e16);

        uint256 lpTokenOfUser = lpToken.balanceOf(USER);

        vm.prank(USER);
        lPContract.getTokensFromPoolUsingLPTokens(lpTokenOfUser);

        // No reverts mean lPtokenContract's owner is LPContract which is
        // calling the burn function for USER.
    }

    function testExchangeSunEthForEarthEth() public {
        // calculated 4e8 by hand using. And checking if this equals to that
        uint256 anotherTokenAmt = lPContract.getAmtAnotherTokenForAToken(1e8, 1e20, 4e20);
        assert(anotherTokenAmt == 4e8 - 1);
    }

    modifier giveTokensToUser() {
        sunEth.mint(USER, 1e18);
        earthEth.mint(USER, 4e18);
        _;
    }
}
