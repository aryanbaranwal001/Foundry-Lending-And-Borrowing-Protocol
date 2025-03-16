// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {DSCT} from "src/DSCT.sol";

contract DeployDSCT is Script {
    function deployDSCT() public returns (DSCT) {
        vm.startBroadcast();
        DSCT dsct = new DSCT();
        vm.stopBroadcast();
        return dsct;
    }

    function run() public returns (DSCT) {
        return deployDSCT();
    }
}
