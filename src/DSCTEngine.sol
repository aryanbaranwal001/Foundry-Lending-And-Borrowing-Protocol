// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DSCTEngine {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DSCTEngine__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable i_dsct;
    mapping(address user => mapping(address tokenAddress => uint256 tokenAmount)) public
        addressToTotalAmounOfParticularToken;
    mapping(address tokenAddress => address tokenPriceFeedAddress) public tokenAddressToPriceFeedAddress;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address[] memory tokenAddresses, address[] memory tokenPriceFeedAddresses, address DSCTtokenAddress) {
        if (tokenPriceFeedAddresses.length != tokenAddresses.length) {
            revert DSCTEngine__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
        }
        i_dsct = DSCTtokenAddress;

        for (uint256 i = 0; i < tokenPriceFeedAddresses.length; i++) {
            tokenAddressToPriceFeedAddress[tokenAddresses[i]] = tokenPriceFeedAddresses[i];
        }
    }

    





}
