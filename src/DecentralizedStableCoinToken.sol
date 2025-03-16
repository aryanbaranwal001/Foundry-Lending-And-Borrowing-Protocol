// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20Burnable, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// ERC20 Burnable is both ERC20 and Context

contract DecentralizedStableCoinToken is ERC20Burnable, Ownable {
    constructor() Ownable(msg.sender) ERC20("StableCoinToken", "SCT") {}

    function burn(address accountAddresToBurn, uint256 amountToBurn) public onlyOwner {
        super._burn(accountAddresToBurn, amountToBurn);
        super.burn(amountToBurn);
    }
}
