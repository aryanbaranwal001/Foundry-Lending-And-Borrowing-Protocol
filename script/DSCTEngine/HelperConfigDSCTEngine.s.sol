// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {DSCT} from "src/DSCT.sol";
import {SunEth} from "src/DSCTEngineTokens/SunEth.sol";
import {EarthEth} from "src/DSCTEngineTokens/EarthEth.sol";
import {EarthEthAggregator} from "src/DSCTEngineTokenAggregator/EarthEthAggregator.sol";
import {SunEthAggregator} from "src/DSCTEngineTokenAggregator/SunEthAggregator.sol";

// aggregator = contract

contract HelperConfigDSCTEngine is Script {
    DSCT dsct;
    SunEth sunEth;
    EarthEth earthEth;
    SunEthAggregator sunEthAggregator;
    EarthEthAggregator earthEthAggregator;

    uint8 public constant DECIMALS = 8;
    int256 public constant SUN_ETH_I_ANSWER = 4000e8;
    int256 public constant EARTH_ETH_I_ANSWER = 1000e8;

    address public SunEthAddress;
    address public EarthEthAddress;
    address public SunEthPriceFeedAddress;
    address public EarthEthPriceFeedAddress;
    address public DSCTAddress;

    function DeployTokensAndAggregators()
        public
        returns (
            address, // SunEthAddress
            address, // EarthEthAddress
            address, // SunEthPriceFeedAddress
            address, // EarthEthPriceFeedAddress
            address // DSCTAddress
        )
    {
        vm.startBroadcast();
        dsct = new DSCT();
        sunEth = new SunEth();
        earthEth = new EarthEth();
        sunEthAggregator = new SunEthAggregator(DECIMALS, EARTH_ETH_I_ANSWER);
        earthEthAggregator = new EarthEthAggregator(DECIMALS, SUN_ETH_I_ANSWER);
        vm.stopBroadcast();

        SunEthAddress = address(sunEth);
        EarthEthAddress = address(earthEth);
        SunEthPriceFeedAddress = address(sunEthAggregator);
        EarthEthPriceFeedAddress = address(earthEthAggregator);
        DSCTAddress = address(dsct);

        return (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, DSCTAddress);
    }

    function getNetworkConfigs()
        public
        returns (
            address, // SunEthAddress
            address, // EarthEthAddress
            address, // SunEthPriceFeedAddress
            address, // EarthEthPriceFeedAddress
            address // DSCTAddress
        )
    {
        if (
            SunEthAddress == address(0) && EarthEthAddress == address(0) && SunEthPriceFeedAddress == address(0)
                && EarthEthPriceFeedAddress == address(0) && DSCTAddress == address(0)
        ) {
            return DeployTokensAndAggregators();
        }
        return (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, DSCTAddress);
    }
}
