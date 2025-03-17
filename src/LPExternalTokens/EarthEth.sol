// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20Burnable, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// ERC20 Burnable is both ERC20 and Context

contract EarthEth is ERC20Burnable, Ownable {
    constructor() Ownable(msg.sender) ERC20("EarthEth", "EET") {}

    function mint(address account, uint256 amount) public  {
        super._mint(account, amount);
    }

    function burn(address accountAddresToBurn, uint256 amountToBurn) public  {
        super._burn(accountAddresToBurn, amountToBurn);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function getOwner() public view returns (address) {
        return super.owner();
    }
}
