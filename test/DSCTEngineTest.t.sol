// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdCheats} from "lib/forge-std/src/StdCheats.sol";
import {DeployDSCTEngine} from "script/DSCTEngine/DeployDSCTEngine.s.sol";
import {HelperConfigDSCTEngine} from "script/DSCTEngine/HelperConfigDSCTEngine.s.sol";
import {DSCTEngine} from "src/DSCTEngine.sol";

import {DSCT} from "src/DSCT.sol";
import {SunEth} from "src/DSCTEngineTokens/SunEth.sol";
import {EarthEth} from "src/DSCTEngineTokens/EarthEth.sol";
import {EarthEthAggregator} from "src/DSCTEngineTokenAggregator/EarthEthAggregator.sol";
import {SunEthAggregator} from "src/DSCTEngineTokenAggregator/SunEthAggregator.sol";

contract DSCTTEST is Test {
    DSCT dsct;
    SunEth sunEth;
    EarthEth earthEth;
    SunEthAggregator sunEthAggregator;
    EarthEthAggregator earthEthAggregator;

    address SunEthAddress;
    address EarthEthAddress;
    address SunEthPriceFeedAddress;
    address EarthEthPriceFeedAddress;
    address DSCTAddress;

    uint256 public constant STARTING_BALANCE = 1000 ether;
    address public USER = makeAddr("USER");
    address public immutable i_initial_owner = msg.sender;

    DSCTEngine dsctEngine;
    HelperConfigDSCTEngine helperConfigDSCTEngine;

    function setUp() public {
        DeployDSCTEngine deployDSCTEngine = new DeployDSCTEngine();
        (dsctEngine, helperConfigDSCTEngine) = deployDSCTEngine.run();

        (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, DSCTAddress) =
            helperConfigDSCTEngine.getNetworkConfigs();

        dsct = DSCT(DSCTAddress);
        sunEth = SunEth(SunEthAddress);
        earthEth = EarthEth(EarthEthAddress);
        sunEthAggregator = SunEthAggregator(SunEthPriceFeedAddress);
        earthEthAggregator = EarthEthAggregator(EarthEthPriceFeedAddress);

        vm.deal(USER, 100 ether);
    }

    function testCheckingDepositeCollateral() public {
        console.log("--------------------");
        console.log("SunEthAddress: ", SunEthAddress);
        console.log("EarthEthAddress: ", EarthEthAddress);
        console.log("SunEthPriceFeedAddress: ", SunEthPriceFeedAddress);
        console.log("EarthEthPriceFeedAddress: ", EarthEthPriceFeedAddress);
        console.log("DSCTAddress: ", DSCTAddress);
        console.log("--------------------");

        // console.log(dsctEngine.getPriceFeedAddressForTokenAddress(SunEthAddress));
            // dsctEngine.depositCollateral(SunEthAddress, 100 ether);
    }
}
