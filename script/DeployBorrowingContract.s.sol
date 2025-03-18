// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {Bc} from "src/Bc.sol";
import {BcToken} from "src/BcToken.sol";
import {HelperConfigBorrowingContract} from "script/HelperConfigBorrowingContract.s.sol";

contract DeployBorrowingContract is Script {
    address[] public tokenAddresses;
    address[] public tokenPriceFeedAddresses;
    address public bcTokenAddress;

    address wethAddress;
    address usdcAddress;
    address wethAggrAddress;
    address usdcAggrAddress;

    uint256 public constant InitialTotalValueOfOneAssetInPoolInUsd = 10_000;

    function deployBorrowingContract() public returns (Bc, HelperConfigBorrowingContract) {
        HelperConfigBorrowingContract helperConfigBorrowingContract = new HelperConfigBorrowingContract();

        (wethAddress, usdcAddress, wethAggrAddress, usdcAggrAddress, bcTokenAddress) =
            helperConfigBorrowingContract.getNetworkConfigs();

        tokenAddresses = [wethAddress, usdcAddress];
        tokenPriceFeedAddresses = [wethAggrAddress, usdcAggrAddress];

        vm.startBroadcast();
        Bc bc = new Bc(tokenAddresses, tokenPriceFeedAddresses, bcTokenAddress, InitialTotalValueOfOneAssetInPoolInUsd);

        // transfers the ownership of BcToken to Bc

        BcToken bcToken = BcToken(bcTokenAddress);
        bcToken.transferOwnership(address(bc));
        bc.constructor2();

        vm.stopBroadcast();

        return (bc, helperConfigBorrowingContract);
    }

    function run() public returns (Bc, HelperConfigBorrowingContract) {
        return (deployBorrowingContract());
    }
}
