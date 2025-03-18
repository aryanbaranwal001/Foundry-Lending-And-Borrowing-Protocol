// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdCheats} from "lib/forge-std/src/StdCheats.sol";
import {DeployBorrowingContract} from "script/DeployBorrowingContract.s.sol";
import {HelperConfigBorrowingContract} from "script/HelperConfigBorrowingContract.s.sol";
import {Bc} from "src/Bc.sol";

import {BcToken} from "src/BcToken.sol";
import {Weth} from "src/BorrowingTokens/Weth.sol";
import {Usdc} from "src/BorrowingTokens/Usdc.sol";
import {WethAggr} from "src/BorrowingAggregators/WethAggr.sol";
import {UsdcAggr} from "src/BorrowingAggregators/UsdcAggr.sol";


contract BcTest is Test {
    BcToken bcToken;
    Weth weth;
    Usdc usdc;
    WethAggr wethAggr;
    UsdcAggr usdcAggr;

    address public wethAddress;
    address public usdcAddress;
    address public wethAggrAddress;
    address public usdcAggrAddress;
    address public bcTokenAddress;

    uint256 public constant STARTING_BALANCE = 1000 ether;
    address public USER = makeAddr("USER");
    address public immutable i_initial_owner = msg.sender;

    Bc bc;
    HelperConfigBorrowingContract helperConfigBorrowingContract;

    function setUp() public {
        DeployBorrowingContract deployBorrowingContract = new DeployBorrowingContract();
        (bc, helperConfigBorrowingContract) = deployBorrowingContract.run();

        (wethAddress, usdcAddress, wethAggrAddress, usdcAggrAddress, bcTokenAddress) =
            helperConfigBorrowingContract.getNetworkConfigs();

        bcTokenAddress = address(bcToken);
        wethAddress = address(weth);
        usdcAddress = address(usdc);
        wethAggrAddress = address(wethAggr);
        usdcAggrAddress = address(usdcAggr);

        vm.deal(USER, 100 ether);
    }


}
