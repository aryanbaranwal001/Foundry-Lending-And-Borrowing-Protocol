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

    event AddedToPool(address user, uint256 sunEthAmount, uint256 earthEthAmount);

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

    constructor(
        address[] memory tokenAddresses,
        address[] memory tokenPriceFeedAddresses,
        address LPTokenAddress,
        uint256 InitialTotalValueOfOneAssetInPoolInUsd
    ) {
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

        (, int256 rateSunEth,,,) = sunEthAggregator.latestRoundData();
        (, int256 rateEarthEth,,,) = earthEthAggregator.latestRoundData();

        // 1e6 * 1e18 = x * rate * 1e10 / 1e18
        // 1e6 is amount in dollars
        // x is amount of ethers in wei
        // rate is rate of token in dollars with 8 decimals (given in helper config)
        // rest number are for solidity math/precision control

        uint256 amountOfInitialSunEthInPool = (InitialTotalValueOfOneAssetInPoolInUsd * 1e26) / uint256(rateSunEth);
        uint256 amountOfInitialEarthEthInPool = (InitialTotalValueOfOneAssetInPoolInUsd * 1e26) / uint256(rateEarthEth);

        sunEth.mint(address(this), (amountOfInitialSunEthInPool));
        earthEth.mint(address(this), (amountOfInitialEarthEthInPool));

        totalSunEthInPool += amountOfInitialSunEthInPool;
        totalEarthEthInPool += amountOfInitialEarthEthInPool;
    }

    /*//////////////////////////////////////////////////////////////
                  ADD TO OR REMOVE FROM POOL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addToPool(uint256 AmountOfSunEth, uint256 AmountOfEarthEth) public {
        // This function will select the largest basket of token to be added to pool
        (uint256 sunEthAmt, uint256 earthEthAmt) = getTheMaximumBasket(AmountOfSunEth, AmountOfEarthEth);

        sunEth.transfer(address(this), (sunEthAmt));
        earthEth.transfer(address(this), (earthEthAmt));

        totalSunEthInPool += sunEthAmt;
        totalEarthEthInPool += earthEthAmt;

        emit AddedToPool(msg.sender, sunEthAmt, earthEthAmt);

        // totalSunEthInPool += AmountOfSunEth;
        // totalEarthEthInPool += ;
    }

    function getTheMaximumBasket(uint256 AmountOfSunEth, uint256 AmountOfEarthEth)
        public
        view
        returns (uint256, uint256)
    {
        (uint256 s1, uint256 e1) = getBasket(AmountOfSunEth, AmountOfEarthEth, totalSunEthInPool, totalEarthEthInPool);
        (uint256 s2, uint256 e2) =
            getBasketWithReverse(AmountOfSunEth, AmountOfEarthEth, totalSunEthInPool, totalEarthEthInPool);

        (, int256 SunRateEth,,,) = sunEthAggregator.latestRoundData();
        (, int256 EarthRateEth,,,) = earthEthAggregator.latestRoundData();

        if (
            (s1 * uint256(SunRateEth) + e1 * uint256(EarthRateEth))
                > (s2 * uint256(SunRateEth) + e2 * uint256(EarthRateEth))
        ) {
            return (s1, e1);
        } else {
            return (s2, e2);
        }
    }

    // get the price of sunEth and earthEth
    // get the total amount

    function getBasket(uint256 s, uint256 e, uint256 ItotalSunEthInPool, uint256 ItotalEarthEthInPool)
        public
        view
        returns (uint256, uint256)
    {
        int256 x;
        uint256 sun = ItotalSunEthInPool;
        uint256 earth = ItotalEarthEthInPool;
        // (s-x)/e = sun/earth
        // on solving we get (s*earth - sun*e)/earth = x
        x = int256((s * earth - sun * e) / earth);

        if (x < 0) {
            return (0, 0);
        }

        uint256 y = uint256(((s * earth - sun * e) / earth) - 1);

        uint256 s1;

        s1 = (s - y);
        return (s1, e);
    }

    function getBasketWithReverse(uint256 s, uint256 e, uint256 ItotalSunEthInPool, uint256 ItotalEarthEthInPool)
        public
        view
        returns (uint256, uint256)
    {
        (uint256 e1, uint256 s1) = getBasket(e, s, ItotalEarthEthInPool, ItotalSunEthInPool);
        return (s1, e1);
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
