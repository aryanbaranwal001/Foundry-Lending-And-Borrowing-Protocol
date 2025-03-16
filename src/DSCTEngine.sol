// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";

contract DSCTEngine {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DSCTEngine__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
    error DSCTEngine__TransferFailed();
    error DSCTEngine__TokenNotAllowed(address tokenAddress);
    error DSCTEngine__NeedsMoreThanZero();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable i_dsct;
    mapping(address user => mapping(address tokenAddress => uint256 tokenAmount)) public
        s_addressToTotalAmounOfParticularToken;
    mapping(address tokenAddress => address tokenPriceFeedAddress) public s_tokenAddressToPriceFeedAddress;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address[] memory tokenAddresses, address[] memory tokenPriceFeedAddresses, address DSCTtokenAddress) {
        if (tokenPriceFeedAddresses.length != tokenAddresses.length) {
            revert DSCTEngine__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
        }
        i_dsct = DSCTtokenAddress;

        for (uint256 i = 0; i < tokenPriceFeedAddresses.length; i++) {
            s_tokenAddressToPriceFeedAddress[tokenAddresses[i]] = tokenPriceFeedAddresses[i];
        }
    }

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        // nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        s_addressToTotalAmounOfParticularToken[msg.sender][tokenCollateralAddress] += amountCollateral;
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCTEngine__TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCTEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_tokenAddressToPriceFeedAddress[token] == address(0)) {
            revert DSCTEngine__TokenNotAllowed(token);
        }
        _;
    }
}
