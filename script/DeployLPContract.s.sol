// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {LPContract} from "src/LPContract.sol";

import {HelperConfigLPContract} from "script/HelperConfigLPContract.s.sol";


contract DeployLPContract is Script {
    address[] public tokenAddresses;
    address[] public tokenPriceFeedAddresses;
    address public LPTokenAddress;

    address SunEthAddress;
    address EarthEthAddress;
    address SunEthPriceFeedAddress;
    address EarthEthPriceFeedAddress;

    function deployLPContract() public returns (LPContract, HelperConfigLPContract) {
        HelperConfigLPContract helperConfigLPContract = new HelperConfigLPContract();

        (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, LPTokenAddress) =
            helperConfigLPContract.getNetworkConfigs();

        tokenAddresses = [SunEthAddress, EarthEthAddress];
        tokenPriceFeedAddresses = [SunEthPriceFeedAddress, EarthEthPriceFeedAddress];

        vm.startBroadcast();
        LPContract lpContract = new LPContract(tokenAddresses, tokenPriceFeedAddresses, LPTokenAddress);
        vm.stopBroadcast();
        return (lpContract, helperConfigLPContract);
    }

    function run() public returns (LPContract, HelperConfigLPContract) {
        return (deployLPContract());
    }
}
