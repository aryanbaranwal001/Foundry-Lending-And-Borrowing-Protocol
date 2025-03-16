// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployDSCT} from "script/DeployDSCT.s.sol";
import {DSCT} from "src/DSCT.sol";
import {StdCheats} from "lib/forge-std/src/StdCheats.sol";

contract DSCTTEST is Test {
    DSCT dsct;
    uint256 public constant STARTING_BALANCE = 1000 ether;
    address public USER = makeAddr("USER");
    address public immutable i_initial_owner = msg.sender;

    function setUp() public {
        DeployDSCT deployDSCT = new DeployDSCT();
        dsct = deployDSCT.run();
        vm.deal(USER, 100 ether);
    }
}
