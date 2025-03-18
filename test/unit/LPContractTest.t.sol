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

    // function testFunctionGetTheMaximumBasketSize() public {
    //     // The amount of token

    //     uint256 tempVar = lPContract.getTheMaximumBasketSize();
    //     assert(tempVar == 1000);
    // }

    function testAddToPoolIsTransferingFundsCorrectly() public {
        // initial balance of use is (0,0)

        sunEth.mint(USER, 3e8);
        earthEth.mint(USER, 10e8);

        // sunEth address in contract and here is same

        uint256 s1 = sunEth.balanceOf(USER);
        uint256 e1 = earthEth.balanceOf(USER);
        console.log(" after minting Balance of User", s1, e1);

        uint256 s3 = sunEth.balanceOf(address(lPContract));
        uint256 e3 = earthEth.balanceOf(address(lPContract));
        console.log(" before add to pool balance of contract", s3, e3);

        vm.prank(USER);
        lPContract.addToPool(3e8, 10e8);

        uint256 s4 = sunEth.balanceOf(address(lPContract));
        uint256 e4 = earthEth.balanceOf(address(lPContract));
        console.log(" after add to pool balance of contract", s4, e4);

        vm.startPrank(USER);

        // uint256 s1 = sunEth.balanceOf(USER);
        // uint256 e1 = earthEth.balanceOf(USER);
        // uint256 s3 = sunEth.balanceOf(address(lPContract));
        // uint256 e3 = earthEth.balanceOf(address(lPContract));
        // console.log(s3, e3);
        vm.stopPrank();
    }
}
