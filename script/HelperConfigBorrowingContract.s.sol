// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {BcToken} from "src/BcToken.sol";
import {Weth} from "src/BorrowingTokens/Weth.sol";
import {Usdc} from "src/BorrowingTokens/Usdc.sol";
import {WethAggr} from "src/BorrowingAggregators/WethAggr.sol";
import {UsdcAggr} from "src/BorrowingAggregators/UsdcAggr.sol";

contract HelperConfigBorrowingContract is Script {
    BcToken bcToken;
    Weth weth;
    Usdc usdc;
    WethAggr wethAggr;
    UsdcAggr usdcAggr;

    uint8 public constant DECIMALS = 8;
    int256 public constant WETH_I_ANSWER = 4000e8; // $4000 for 1 WETH
    int256 public constant USDC_I_ANSWER = 1000e8; // $1000 for 1 USDC

    address public wethAddress;
    address public usdcAddress;
    address public wethAggrAddress;
    address public usdcAggrAddress;
    address public bcTokenAddress;

    function DeployTokensAndAggregators()
        public
        returns (
            address, // wethAddress
            address, // usdcAddress
            address, // wethAggrAddress
            address, // usdcAggrAddress
            address // bcTokenAddress
        )
    {
        vm.startBroadcast();
        bcToken = new BcToken();
        weth = new Weth();
        usdc = new Usdc();
        wethAggr = new WethAggr(DECIMALS, WETH_I_ANSWER);
        usdcAggr = new UsdcAggr(DECIMALS, USDC_I_ANSWER);
        vm.stopBroadcast();

        wethAddress = address(weth);
        usdcAddress = address(usdc);
        wethAggrAddress = address(wethAggr);
        usdcAggrAddress = address(usdcAggr);
        bcTokenAddress = address(bcToken);

        return (wethAddress, usdcAddress, wethAggrAddress, usdcAggrAddress, bcTokenAddress);
    }

    function getNetworkConfigs()
        public
        returns (
            address, // wethAddress
            address, // usdcAddress
            address, // wethAggrAddress
            address, // usdcAggrAddress
            address // bcTokenAddress
        )
    {
        if (
            wethAddress == address(0) && usdcAddress == address(0) && wethAggrAddress == address(0)
                && usdcAggrAddress == address(0) && bcTokenAddress == address(0)
        ) {
            return DeployTokensAndAggregators();
        }
        return (wethAddress, usdcAddress, wethAggrAddress, usdcAggrAddress, bcTokenAddress);
    }
}
