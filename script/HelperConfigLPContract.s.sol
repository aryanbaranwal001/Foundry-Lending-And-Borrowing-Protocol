// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {LPToken} from "src/LPToken.sol";
import {SunEth} from "src/LPExternalTokens/SunEth.sol";
import {EarthEth} from "src/LPExternalTokens/EarthEth.sol";
import {EarthEthAggregator} from "src/LPExternalAggregators/EarthEthAggregator.sol";
import {SunEthAggregator} from "src/LPExternalAggregators/SunEthAggregator.sol";

// aggregator = contract

contract HelperConfigLPContract is Script {
    LPToken lpToken;
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
    address public LPTokenAddress;

    function DeployTokensAndAggregators()
        public
        returns (
            address, // SunEthAddress
            address, // EarthEthAddress
            address, // SunEthPriceFeedAddress
            address, // EarthEthPriceFeedAddress
            address // LPTokenAddress
        )
    {
        vm.startBroadcast();
        lpToken = new LPToken();
        sunEth = new SunEth();
        earthEth = new EarthEth();
        sunEthAggregator = new SunEthAggregator(DECIMALS, EARTH_ETH_I_ANSWER);
        earthEthAggregator = new EarthEthAggregator(DECIMALS, SUN_ETH_I_ANSWER);
        vm.stopBroadcast();

        SunEthAddress = address(sunEth);
        EarthEthAddress = address(earthEth);
        SunEthPriceFeedAddress = address(sunEthAggregator);
        EarthEthPriceFeedAddress = address(earthEthAggregator);
        LPTokenAddress = address(lpToken);

        return (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, LPTokenAddress);
    }

    function getNetworkConfigs()
        public
        returns (
            address, // SunEthAddress
            address, // EarthEthAddress
            address, // SunEthPriceFeedAddress
            address, // EarthEthPriceFeedAddress
            address // LPTokenAddress
        )
    {
        if (
            SunEthAddress == address(0) && EarthEthAddress == address(0) && SunEthPriceFeedAddress == address(0)
                && EarthEthPriceFeedAddress == address(0) && LPTokenAddress == address(0)
        ) {
            return DeployTokensAndAggregators();
        }
        return (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, LPTokenAddress);
    }
}
