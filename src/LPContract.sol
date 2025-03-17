// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "lib/forge-std/src/Script.sol";

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
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AddedToPool(address user, uint256 sunEthAmount, uint256 earthEthAmount);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address user => mapping(address tokenAddress => uint256 tokenAmount)) public
        s_addressToTotalAmounOfParticularToken;
    mapping(address tokenAddress => address tokenPriceFeedAddress) public s_tokenAddressToPriceFeedAddress;

    SunEth sunEth;
    EarthEth earthEth;
    SunEthAggregator sunEthAggregator;
    EarthEthAggregator earthEthAggregator;
    LPToken public immutable i_lptoken;

    uint256 public totalSunEthInPool;
    uint256 public totalEarthEthInPool;
    uint256 public totalLPTokensMinted;

    uint256 InitialTotalValueOfOneAssetInPoolInUsd;
    bool tempVar = true; // a workaround

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address[] memory tokenAddresses,
        address[] memory tokenPriceFeedAddresses,
        address LPTokenAddress,
        uint256 InitialTotalValueOfOneAssetInPoolInUsdInput
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
        InitialTotalValueOfOneAssetInPoolInUsd = InitialTotalValueOfOneAssetInPoolInUsdInput;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR 2
    //////////////////////////////////////////////////////////////*/

    function constructor2() public {
        if (tempVar) {
            (, int256 rateSunEth,,,) = sunEthAggregator.latestRoundData();
            (, int256 rateEarthEth,,,) = earthEthAggregator.latestRoundData();

            // 1e6 * 1e18 = x * rate * 1e10 / 1e18
            // 1e6 is amount in dollars
            // x is amount of ethers in wei
            // rate is rate of token in dollars with 8 decimals (given in helper config)
            // rest number are for solidity math/precision control

            uint256 amountOfInitialSunEthInPool = (InitialTotalValueOfOneAssetInPoolInUsd * 1e26) / uint256(rateSunEth);
            uint256 amountOfInitialEarthEthInPool =
                (InitialTotalValueOfOneAssetInPoolInUsd * 1e26) / uint256(rateEarthEth);

            sunEth.mint(address(this), (amountOfInitialSunEthInPool));
            earthEth.mint(address(this), (amountOfInitialEarthEthInPool));

            totalSunEthInPool += amountOfInitialSunEthInPool;
            totalEarthEthInPool += amountOfInitialEarthEthInPool;

            // minting LP tokens to address(this) contract

            mintInitialLPToken(amountOfInitialSunEthInPool, amountOfInitialEarthEthInPool);
            tempVar = false;
        }
    }

    /*//////////////////////////////////////////////////////////////
                          ADD TO POOL FUNCTION
    //////////////////////////////////////////////////////////////*/

    function addToPool(uint256 AmountOfSunEth, uint256 AmountOfEarthEth) public {
        // This function will select the largest basket of token to be added to pool
        (uint256 sunEthAmt, uint256 earthEthAmt) = getTheMaximumBasket(AmountOfSunEth, AmountOfEarthEth);

        sunEth.transfer(address(this), (sunEthAmt));
        earthEth.transfer(address(this), (earthEthAmt));

        uint256 s = getLPTokensAmtToMint(sunEthAmt, totalSunEthInPool);

        totalSunEthInPool += sunEthAmt;
        totalEarthEthInPool += earthEthAmt;

        mintLPToken(msg.sender, s);

        emit AddedToPool(msg.sender, sunEthAmt, earthEthAmt);
    }

    /*//////////////////////////////////////////////////////////////
                         GET FROM POOL FUNCTION
    //////////////////////////////////////////////////////////////*/

    function getTokensFromPoolUsingLPTokens(uint256 amountOfLPTokensToBurn) public {
        i_lptoken.burn(msg.sender, amountOfLPTokensToBurn); // it will revert as only owner can call this function of LPToken

        uint256 s1 = totalSunEthInPool * amountOfLPTokensToBurn / totalLPTokensMinted;
        uint256 e1 = totalEarthEthInPool * amountOfLPTokensToBurn / totalLPTokensMinted;

        totalSunEthInPool -= s1;
        totalEarthEthInPool -= e1;
        totalLPTokensMinted -= amountOfLPTokensToBurn;

        sunEth.mint(msg.sender, (s1));
        earthEth.mint(msg.sender, (e1));
    }

    /*//////////////////////////////////////////////////////////////
                           EXCHANGE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function exchangeSunEthForEarthEth(uint256 amountOfSunEth) public {
        // implementing x y = k
        uint256 earthEthAmt = getAmtAnotherTokenForAToken(amountOfSunEth, totalSunEthInPool, totalEarthEthInPool);

        sunEth.transfer(address(this), amountOfSunEth);
        totalSunEthInPool += amountOfSunEth;

        earthEth.transfer(msg.sender, earthEthAmt);
        totalEarthEthInPool -= earthEthAmt;
    }

    function exchangeEarthEthForSunEth(uint256 amountOfEarthEth) public {
        // implementing x y = k
        uint256 sunEthAmt = getAmtAnotherTokenForAToken(amountOfEarthEth, totalEarthEthInPool, totalSunEthInPool);

        earthEth.transfer(address(this), amountOfEarthEth);
        totalEarthEthInPool += amountOfEarthEth;

        sunEth.transfer(msg.sender, sunEthAmt);
        totalSunEthInPool -= sunEthAmt;
    }

    /*//////////////////////////////////////////////////////////////
                     CALCULATE ARBITRAGE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getArbitrageForExchangingSunEthForEarthEth(uint256 amountOfSunEth) public returns (uint256) {
        (, int256 rateSunEth,,,) = sunEthAggregator.latestRoundData();
        (, int256 rateEarthEth,,,) = earthEthAggregator.latestRoundData();

        uint256 earthEthAmt = getAmtAnotherTokenForAToken(amountOfSunEth, totalSunEthInPool, totalEarthEthInPool);

        uint256 amountInDollars =
            ((earthEthAmt * uint256(rateEarthEth) * 1e10 - (amountOfSunEth * uint256(rateSunEth) * 1e10)) / 1e36);
        return amountInDollars;
    }

    function getArbitrageForExchangingEarthEthForSunEth(uint256 amountOfEarthEth) public returns (uint256) {
        (, int256 rateSunEth,,,) = sunEthAggregator.latestRoundData();
        (, int256 rateEarthEth,,,) = earthEthAggregator.latestRoundData();

        uint256 sunEthAmt = getAmtAnotherTokenForAToken(amountOfEarthEth, totalEarthEthInPool, totalSunEthInPool);

        uint256 amountInDollars = uint256(
            ((sunEthAmt * uint256(rateSunEth)) * 1e10 - (amountOfEarthEth * uint256(rateEarthEth)) * 1e10) / 1e36
        );
        return amountInDollars;
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function getLPTokensAmtToMint(uint256 tokenGiven, uint256 totalAmtOfTokenGiven) public returns (uint256) {
        uint256 s = (tokenGiven * totalLPTokensMinted) / totalAmtOfTokenGiven;
        return s;
    }

    function mintLPToken(address user, uint256 amount) public {
        i_lptoken.mint(user, amount);
    }

    function mintInitialLPToken(uint256 amountOfInitialSunEthInPool, uint256 amountOfInitialEarthEthInPool) public {
        // assuming Liquidity of pool = sqrt(totalSunEthInPool * totalEarthEthInPool)
        // assuming Total LP tokens = Liquidity of pool
        // as they are directly proportional
        // reference video link in readmd

        uint256 tokensToMint = sqrt(amountOfInitialEarthEthInPool * amountOfInitialSunEthInPool);
        totalLPTokensMinted += tokensToMint;
        i_lptoken.mint(address(this), tokensToMint);
    }

    function sqrt(uint256 x) public pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y * 1e10;
    }

    function getAmtAnotherTokenForAToken(uint256 tokenAmount, uint256 tokenTotalAmt, uint256 AnotherTokenTotalAmt)
        public
        returns (uint256)
    {
        uint256 AnotherTokenAmt = (tokenAmount * AnotherTokenTotalAmt) / (tokenTotalAmt + tokenAmount); // reference from the video link in readme
        return AnotherTokenAmt;
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPriceFeedAddressForTokenAddress(address tokenAddress) public view returns (address) {
        return s_tokenAddressToPriceFeedAddress[tokenAddress];
    }

    function getTotalSunEthInPool() public view returns (uint256) {
        return totalSunEthInPool;
    }

    function getTotalEarthEthInPool() public view returns (uint256) {
        return totalEarthEthInPool;
    }
}
