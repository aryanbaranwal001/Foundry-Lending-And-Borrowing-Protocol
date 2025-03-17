// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {LPToken} from "src/LPToken.sol";

import {SunEth} from "src/LPExternalTokens/SunEth.sol";
import {EarthEth} from "src/LPExternalTokens/EarthEth.sol";
import {SunEthAggregator} from "src/LPExternalAggregators/SunEthAggregator.sol";
import {EarthEthAggregator} from "src/LPExternalAggregators/EarthEthAggregator.sol";


contract LPContract {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LPContract__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
    error LPContract__TransferFailed();
    error LPContract__TokenNotAllowed(address tokenAddress);
    error LPContract__NeedsMoreThanZero();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address user => mapping(address tokenAddress => uint256 tokenAmount)) public
        s_addressToTotalAmounOfParticularToken;

    LPToken public immutable i_lptoken;
    mapping(address tokenAddress => address tokenPriceFeedAddress) public s_tokenAddressToPriceFeedAddress;
    SunEth sunEth;
    EarthEth earthEth;
    SunEthAggregator sunEthAggregator;
    EarthEthAggregator earthEthAggregator;

    uint256 public totalSunEthInPool;
    uint256 public totalEarthEthInPool;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address[] memory tokenAddresses, address[] memory tokenPriceFeedAddresses, address LPTokenAddress, uint256 InitialTotalValueOfOneAssetInPoolInUsd) { 
        // if InitialTotalValueOfOneAssetInPoolInUsd is $1_000_000, then value of total amount of SunEth and EarthEth will be $1_000_000 each. Total value of pool will be $2_000_000
        if (tokenPriceFeedAddresses.length != tokenAddresses.length) {
            revert LPContract__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
        }
        i_lptoken = LPToken(LPTokenAddress);

        for (uint256 i = 0; i < tokenPriceFeedAddresses.length; i++) {
            s_tokenAddressToPriceFeedAddress[tokenAddresses[i]] = tokenPriceFeedAddresses[i];
        }

        sunEth = SunEth(tokenAddresses[0]);
        earthEth = EarthEth(tokenAddresses[1]);
        sunEthAggregator = SunEthAggregator(tokenPriceFeedAddresses[0]);
        earthEthAggregator = EarthEthAggregator(tokenPriceFeedAddresses[1]);

        (,int256 rateSunEth,,,) = sunEthAggregator.latestRoundData();
        (,int256 rateEarthEth,,,) = earthEthAggregator.latestRoundData();

        // 1e6 * 1e18 = x * rate * 1e10 / 1e18
        // 1e6 is amount in dollars
        // x is amount of ethers in wei
        // rate is rate of token in dollars with 8 decimals (given in helper config)
        // rest number are for solidity math/precision control

        int256 amountOfInitialSunEthInPool = int256(InitialTotalValueOfOneAssetInPoolInUsd * 1e26) / rateSunEth;
        int256 amountOfInitialEarthEthInPool = int256(InitialTotalValueOfOneAssetInPoolInUsd * 1e26) / rateEarthEth; 


        sunEth.mint(address(this), amountOfInitialSunEthInPool);
        earthEth.mint(address(this), amountOfInitialEarthEthInPool);

        totalSunEthInPool += amountOfInitialSunEthInPool;
        totalEarthEthInPool += amountOfInitialEarthEthInPool;
    }

    /*//////////////////////////////////////////////////////////////
                  ADD TO OR REMOVE FROM POOL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addToPool(uint256 AmountOfSunEth, uint256 AmountOfEarthEth) public { // This function will select the largest basket of token to be added to pool
        sunEth.transfer(address(this), AmountOfSunEth);
        earthEth.transfer(address(this), AmountOfEarthEth);



    // totalSunEthInPool += AmountOfSunEth;
    // totalEarthEthInPool += ;

    }

    function giveTheBasket(uint256 AmountOfSunEth, uint256 AmountOfEarthEth) public {
        // assumes that user is adding

    }


    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPriceFeedAddressForTokenAddress(address tokenAddress) public view returns (address) {
        return s_tokenAddressToPriceFeedAddress[tokenAddress];
    }
}
