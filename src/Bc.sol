// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "lib/forge-std/src/Script.sol";

import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {BcToken} from "src/BcToken.sol";
import {Weth} from "src/BorrowingTokens/Weth.sol";
import {Usdc} from "src/BorrowingTokens/Usdc.sol";
import {WethAggr} from "src/BorrowingAggregators/WethAggr.sol";
import {UsdcAggr} from "src/BorrowingAggregators/UsdcAggr.sol";

contract Bc is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LPContract__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
    error LPContract__TransferFailed();
    error LPContract__TokenNotAllowed(address tokenAddress);
    error LPContract__NeedsMoreThanZero();
    error LPContract__OneTokenCannotBeZero(uint256 wethAmount, uint256 usdcAmount);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AddedToPool(address user, uint256 wethAmount, uint256 usdcAmount);
    event BasketChosenChoices(uint256 wethAmount, uint256 usdcAmount);
    event BasketChosenFinals1e1(uint256 wethAmount, uint256 usdcAmount);
    event BasketChosenFinals2e2(uint256 wethAmount, uint256 usdcAmount);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address user => mapping(address tokenAddress => uint256 tokenAmount)) public
        s_addressToTotalAmounOfParticularToken;
    mapping(address tokenAddress => address tokenPriceFeedAddress) public s_tokenAddressToPriceFeedAddress;

    Weth weth;
    Usdc usdc;
    WethAggr wethAggr;
    UsdcAggr usdcAggr;

    BcToken public immutable i_lptoken;

    uint256 public totalwethInPool;
    uint256 public totalusdcInPool;
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
        // if InitialTotalValueOfOneAssetInPoolInUsd is $1_000_000, then value of total amount of weth and usdc will be $1_000_000 each. Total value of pool will be $2_000_000
        if (tokenPriceFeedAddresses.length != tokenAddresses.length) {
            revert LPContract__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
        }
        i_lptoken = BcToken(LPTokenAddress);

        for (uint256 i = 0; i < tokenPriceFeedAddresses.length; i++) {
            s_tokenAddressToPriceFeedAddress[tokenAddresses[i]] = tokenPriceFeedAddresses[i];
        }

        weth = Weth(tokenAddresses[0]);
        usdc = Usdc(tokenAddresses[1]);
        wethAggr = WethAggr(tokenPriceFeedAddresses[0]);
        usdcAggr = UsdcAggr(tokenPriceFeedAddresses[1]);
        InitialTotalValueOfOneAssetInPoolInUsd = InitialTotalValueOfOneAssetInPoolInUsdInput;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR 2
    //////////////////////////////////////////////////////////////*/

    function constructor2() public returns (bool) {
        if (tempVar) {
            (, int256 rateweth,,,) = wethAggr.latestRoundData();
            (, int256 rateusdc,,,) = usdcAggr.latestRoundData();

            // 1e6 * 1e18 = x * rate * 1e10 / 1e18
            // 1e6 is amount in dollars
            // x is amount of ethers in wei
            // rate is rate of token in dollars with 8 decimals (given in helper config)
            // rest number are for solidity math/precision control

            uint256 amountOfInitialwethInPool = (InitialTotalValueOfOneAssetInPoolInUsd * 1e26) / uint256(rateweth);
            uint256 amountOfInitialusdcInPool = (InitialTotalValueOfOneAssetInPoolInUsd * 1e26) / uint256(rateusdc);

            weth.mint(address(this), (amountOfInitialwethInPool));
            usdc.mint(address(this), (amountOfInitialusdcInPool));

            totalwethInPool += amountOfInitialwethInPool;
            totalusdcInPool += amountOfInitialusdcInPool;

            // minting LP tokens to address(this) contract

            mintInitialLPToken(amountOfInitialwethInPool, amountOfInitialusdcInPool);
            tempVar = false;
            return false;
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                          ADD TO POOL FUNCTION
    //////////////////////////////////////////////////////////////*/

    function addToPool(uint256 AmountOfweth, uint256 AmountOfusdc) public {
        if (AmountOfweth == 0 || AmountOfusdc == 0) {
            revert LPContract__OneTokenCannotBeZero(AmountOfweth, AmountOfusdc);
        }
        // This function will select the largest basket of token to be added to pool

        (uint256 wethAmt, uint256 usdcAmt) = getTheMaximumBasket(AmountOfweth, AmountOfusdc);

        weth.transferFromOwner(msg.sender, address(this), (wethAmt));
        usdc.transferFromOwner(msg.sender, address(this), (usdcAmt));

        uint256 s = getLPTokensAmtToMint(wethAmt, totalwethInPool);

        totalwethInPool += wethAmt;
        totalusdcInPool += usdcAmt;

        mintLPToken(msg.sender, s);

        emit AddedToPool(msg.sender, wethAmt, usdcAmt);
    }

    /*//////////////////////////////////////////////////////////////
                         GET FROM POOL FUNCTION
    //////////////////////////////////////////////////////////////*/

    function getTokensFromPoolUsingLPTokens(uint256 amountOfLPTokensToBurn) public {
        i_lptoken.burn(msg.sender, amountOfLPTokensToBurn); // it will revert as only owner can call this function of BcToken

        uint256 s1 = totalwethInPool * amountOfLPTokensToBurn / totalLPTokensMinted;
        uint256 e1 = totalusdcInPool * amountOfLPTokensToBurn / totalLPTokensMinted;

        totalwethInPool -= s1;
        totalusdcInPool -= e1;
        totalLPTokensMinted -= amountOfLPTokensToBurn;

        weth.mint(msg.sender, (s1));
        usdc.mint(msg.sender, (e1));
    }

    /*//////////////////////////////////////////////////////////////
                           EXCHANGE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function exchangewethForusdc(uint256 amountOfweth) public {
        // implementing x y = k
        uint256 usdcAmt = getAmtAnotherTokenForAToken(amountOfweth, totalwethInPool, totalusdcInPool);

        weth.transferFromOwner(msg.sender, address(this), amountOfweth);
        totalwethInPool += amountOfweth;

        usdc.transferFromOwner(address(this), msg.sender, usdcAmt);
        totalusdcInPool -= usdcAmt;
    }

    function exchangeusdcForweth(uint256 amountOfusdc) public {
        // implementing x y = k
        uint256 wethAmt = getAmtAnotherTokenForAToken(amountOfusdc, totalusdcInPool, totalwethInPool);

        usdc.transferFromOwner(msg.sender, address(this), amountOfusdc);
        totalusdcInPool += amountOfusdc;

        weth.transferFromOwner(address(this), msg.sender, wethAmt);
        totalwethInPool -= wethAmt;
    }

    /*//////////////////////////////////////////////////////////////
                     CALCULATE ARBITRAGE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getArbitrageForExchangingwethForusdc(uint256 amountOfweth) public returns (uint256) {
        (, int256 rateweth,,,) = wethAggr.latestRoundData();
        (, int256 rateusdc,,,) = usdcAggr.latestRoundData();

        uint256 usdcAmt = getAmtAnotherTokenForAToken(amountOfweth, totalwethInPool, totalusdcInPool);

        uint256 amountInDollars =
            ((usdcAmt * uint256(rateusdc) * 1e10 - (amountOfweth * uint256(rateweth) * 1e10)) / 1e36);
        return amountInDollars;
    }

    function getArbitrageForExchangingusdcForweth(uint256 amountOfusdc) public returns (uint256) {
        (, int256 rateweth,,,) = wethAggr.latestRoundData();
        (, int256 rateusdc,,,) = usdcAggr.latestRoundData();

        uint256 wethAmt = getAmtAnotherTokenForAToken(amountOfusdc, totalusdcInPool, totalwethInPool);

        uint256 amountInDollars =
            uint256(((wethAmt * uint256(rateweth)) * 1e10 - (amountOfusdc * uint256(rateusdc)) * 1e10) / 1e36);
        return amountInDollars;
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getTheMaximumBasket(uint256 AmountOfweth, uint256 AmountOfusdc) public returns (uint256, uint256) {
        if (AmountOfweth == 0 || AmountOfusdc == 0) {
            revert LPContract__OneTokenCannotBeZero(AmountOfweth, AmountOfusdc);
        }

        (uint256 s1, uint256 e1) = getBasket(AmountOfweth, AmountOfusdc, totalwethInPool, totalusdcInPool);
        (uint256 s2, uint256 e2) = getBasketWithReverse(AmountOfweth, AmountOfusdc, totalwethInPool, totalusdcInPool);

        (, int256 SunRateEth,,,) = wethAggr.latestRoundData();
        (, int256 EarthRateEth,,,) = usdcAggr.latestRoundData();

        emit BasketChosenChoices(s1, e1);
        emit BasketChosenChoices(s2, e2);

        if (
            ((s1 * uint256(SunRateEth) + e1 * uint256(EarthRateEth)) / 1e8)
                > ((s2 * uint256(SunRateEth) + e2 * uint256(EarthRateEth)) / 1e8) // overflow error, or underflow error may happen
        ) {
            emit BasketChosenFinals1e1(s1, e1);
            if (s1 == 0 || e1 == 0) {
                revert LPContract__OneTokenCannotBeZero(s1, e1);
            }
            return (s1, e1);
        } else {
            emit BasketChosenFinals2e2(s2, e2);
            if (s2 == 0 || e2 == 0) {
                revert LPContract__OneTokenCannotBeZero(s2, e2);
            }
            return (s2, e2);
        }
    }

    function getBasket(uint256 s, uint256 e, uint256 ItotalwethInPool, uint256 ItotalusdcInPool)
        public
        nonReentrant
        returns (uint256, uint256)
    {
        int256 x;
        int256 y;
        uint256 sun = ItotalwethInPool;
        uint256 earth = ItotalusdcInPool;
        int256 z;
        // (s-z)/e = sun/earth
        // on solving we get (s*earth - sun*e)/earth = z

        x = int256(s);
        y = int256((sun * e) / earth);

        z = x - y;

        if (z < 0) {
            return (0, 0);
        }

        uint256 s1;

        s1 = (s - uint256(z));
        return (s1, e);
    }

    function getBasketWithReverse(uint256 s, uint256 e, uint256 ItotalwethInPool, uint256 ItotalusdcInPool)
        public
        returns (uint256, uint256)
    {
        (uint256 e1, uint256 s1) = getBasket(e, s, ItotalusdcInPool, ItotalwethInPool);
        return (s1, e1);
    }

    function getLPTokensAmtToMint(uint256 tokenGiven, uint256 totalAmtOfTokenGiven) public returns (uint256) {
        uint256 s = (tokenGiven * totalLPTokensMinted) / totalAmtOfTokenGiven;
        return s;
    }

    function mintLPToken(address user, uint256 amount) public {
        i_lptoken.mint(user, amount);
    }

    function mintInitialLPToken(uint256 amountOfInitialwethInPool, uint256 amountOfInitialusdcInPool) public {
        // assuming Liquidity of pool = sqrt(totalwethInPool * totalusdcInPool)
        // assuming Total LP tokens = Liquidity of pool
        // as they are directly proportional
        // reference video link in readmd

        uint256 tokensToMint = sqrt(amountOfInitialusdcInPool * amountOfInitialwethInPool);
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
        return y;
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

    function getTotalwethInPool() public view returns (uint256) {
        return totalwethInPool;
    }

    function getTotalusdcInPool() public view returns (uint256) {
        return totalusdcInPool;
    }
}
