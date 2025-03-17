// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {LPContract} from "src/LPContract.sol";
import {LPToken} from "src/LPToken.sol";
import {HelperConfigLPContract} from "script/HelperConfigLPContract.s.sol";

contract DeployLPContract is Script {
    address[] public tokenAddresses;
    address[] public tokenPriceFeedAddresses;
    address public LPTokenAddress;

    address SunEthAddress;
    address EarthEthAddress;
    address SunEthPriceFeedAddress;
    address EarthEthPriceFeedAddress;

    uint256 public constant InitialTotalValueOfOneAssetInPoolInUsd = 1_000_000;

    function deployLPContract() public returns (LPContract, HelperConfigLPContract) {
        HelperConfigLPContract helperConfigLPContract = new HelperConfigLPContract();

        (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, LPTokenAddress) =
            helperConfigLPContract.getNetworkConfigs();

        tokenAddresses = [SunEthAddress, EarthEthAddress];
        tokenPriceFeedAddresses = [SunEthPriceFeedAddress, EarthEthPriceFeedAddress];

        vm.startBroadcast();
        LPContract lpContract = new LPContract(
            tokenAddresses, tokenPriceFeedAddresses, LPTokenAddress, InitialTotalValueOfOneAssetInPoolInUsd
        );

        // transfers the ownership of LPToken to LPContract

        LPToken lpToken = LPToken(LPTokenAddress);
        lpToken.transferOwnership(address(lpContract));
        lpContract.constructor2();

        vm.stopBroadcast();
        return (lpContract, helperConfigLPContract);
    }

    function run() public returns (LPContract, HelperConfigLPContract) {
        return (deployLPContract());
    }
}
