// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {DSCTEngine} from "src/DSCTEngine.sol";
import {HelperConfigDSCTEngine} from "script/DSCTEngine/HelperConfigDSCTEngine.s.sol";

contract DeployDSCTEngine is Script {
    address[] public tokenAddresses;
    address[] public tokenPriceFeedAddresses;
    address public DSCTtokenAddress;

    address SunEthAddress;
    address EarthEthAddress;
    address SunEthAggregator;
    address EarthEthAggregator;
    address DSCTAddress;


    function deployDSCTEngine() public returns (DSCTEngine) {
        HelperConfigDSCTEngine helperConfigDSCTEngine = new HelperConfigDSCTEngine();

        (SunEthAddress, EarthEthAggregator, SunEthAggregator, EarthEthAggregator, DSCTAddress) =
            helperConfigDSCTEngine.getNetworkConfigs();

        tokenAddresses = [SunEthAddress, EarthEthAggregator];
        tokenPriceFeedAddresses = [SunEthAggregator, EarthEthAggregator];

        vm.startBroadcast();
        DSCTEngine dsctEngine = new DSCTEngine(tokenAddresses, tokenPriceFeedAddresses, DSCTtokenAddress);
        vm.stopBroadcast();
        return dsctEngine;
    }

    function run() public returns (DSCTEngine) {
        return deployDSCTEngine();
    }
}
