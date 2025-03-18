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

    error Bc__Constructor2hasBeenCalled();
    error Bc__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
    error Bc__NeedsMoreThanZero();

    error LPContract__TransferFailed();
    error LPContract__TokenNotAllowed(address tokenAddress);
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

    struct Account {
        uint256 bcAmount;
        uint256 timestamp;
    }

    mapping(address => Account[]) public bcTokenMinted;

    mapping(address user => mapping(address tokenAddress => uint256 tokenAmount)) public
        s_addressToTotalAmounOfParticularToken;
    mapping(address tokenAddress => address tokenPriceFeedAddress) public s_tokenAddressToPriceFeedAddress;

    Weth weth;
    Usdc usdc;
    WethAggr wethAggr;
    UsdcAggr usdcAggr;

    BcToken public immutable i_bcToken;

    uint256 public totalwethInPool;
    uint256 public totalusdcInPool;
    uint256 public totalBcTokensMinted;

    uint256 InitialTotalValueOfOneAssetInPoolInUsd;
    bool tempVar = true; // a workaround

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address[] memory tokenAddresses,
        address[] memory tokenPriceFeedAddresses,
        address bcTokenAddress,
        uint256 InitialTotalValueOfOneAssetInPoolInUsdInput
    ) {
        // if InitialTotalValueOfOneAssetInPoolInUsd is $10_000, then value of total amount of weth and usdc will be $100_000 each. Total value of pool will be $20_000

        if (tokenPriceFeedAddresses.length != tokenAddresses.length) {
            revert Bc__tokenPriceFeedAddressesAndTokenAddressesLengthNotSame();
        }
        i_bcToken = BcToken(bcTokenAddress);

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

    function constructor2() public {
        if (!tempVar) Bc__Constructor2hasBeenCalled();

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

        // minting BcTokens to address(this) contract

        mintInitialLPToken(amountOfInitialwethInPool, amountOfInitialusdcInPool);

        tempVar = false;
    }

    /*//////////////////////////////////////////////////////////////
                           DEPOSITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositeWethToPool(uint256 wethToDeposite) public cantBeZero(wethToDeposite) {
        // deposited to pool

        weth.transferFromOwner(msg.sender, address(this), wethToDeposite);
        totalwethInPool += wethToDeposite;

        // return bcToken to user

        uint256 s = getBcTokensToMintForWeth(wethToDeposite);
        i_bcToken.mint(msg.sender, s);
        totalBcTokensMinted += s;

        // store timestamp for interest calculation

        bcTokenMinted[msg.sender].push(Account({bcAmount: s, timestamp: block.timestamp}));
    }

    function depositeUsdcToPool(uint256 usdcToDeposite) public cantBeZero(usdcToDeposite) {
        // deposited to pool

        usdc.transferFromOwner(msg.sender, address(this), usdcToDeposite);
        totalusdcInPool += usdcToDeposite;

        // return bcToken to user

        uint256 s = getBcTokensToMintForUsdc(usdcToDeposite);
        i_bcToken.mint(msg.sender, s);
        totalBcTokensMinted += s;

        // store timestamp for interest calculation

        bcTokenMinted[msg.sender].push(Account({bcAmount: s, timestamp: block.timestamp}));
    }

    /*//////////////////////////////////////////////////////////////
                           WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/


    function withDrawWethFromPool(uint256 bcTokenAmount) public cantBeZero(bcTokenAmount) {


        uint256 totalBcTokens = getTotalBcTokens(msg.sender, bcTokenAmount);
        
        i_bcToken.burn(msg.sender, totalBcTokens);
        totalBcTokensMinted -= totalBcTokens;

        uint256 wethToWithdraw = totalBcTokens / (100 * getRateRatio());


        weth.transferFromOwner(address(this), msg.sender, wethToWithdraw);
        totalwethInPool -= wethToWithdraw;
    }

    function withDrawUsdcFromPool(uint256 bcTokenAmount) public cantBeZero(bcTokenAmount) {


        uint256 totalBcTokens = getTotalBcTokens(msg.sender, bcTokenAmount);
        
        i_bcToken.burn(msg.sender, totalBcTokens);
        totalBcTokensMinted -= totalBcTokens;

        uint256 usdcToWithdraw = totalBcTokens / 100 );


        usdc.transferFromOwner(address(this), msg.sender, usdcToWithdraw);
        totalusdcInPool -= usdcToWithdraw;
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

    function getBcTokensToMintForWeth(uint256 amount) internal returns (uint256) {

        return (100 * getRateRatio() * amount);
    }

    function getBcTokensToMintForUsdc(uint256 amount) internal returns (uint256) {
        return 100 * amount;
    }

    function getRateRatio() internal returns (uint256) {
        (, int256 rateweth,,,) = wethAggr.latestRoundData();
        (, int256 rateusdc,,,) = usdcAggr.latestRoundData();

        return (uint256(rateweth) / uint256(rateusdc));
    }



    function getTotalBcTokens(address user, uint256 amountToWithdraw) internal return(uint256) {

        // getting the values

        bool running = true;
        uint256 totalBcAmt = 0;
        uint256 index = 0;
        while (running) {

            totalBcAmt += bcTokenMinted[user][index].bcAmount;

            if (totalBcAmt > amountToWithdraw) {
                running = false;
                totalBcAmt -= bcTokenMinted[user][index].bcAmount;
                continue;
            }
            index += 1;
        }

        // calculating the interest + amount

        uint256 interestPerDay = 8/365;
        uint256 totalInterestWithAmt = 0;        
        
        for (uint256 i = 0; i < index; i++) { // last amt lefts

            uint256 amountBc = bcTokenMinted[user][i].bcAmount;
            uint256 timeStamp = bcTokenMinted[user][i].timestamp;
            uint256 numOfDays = (block.timestamp - timeStamp) / 1 days;

            uint256 interest =  amountBc * numOfDays * interestPerDay / 100;

            totalInterestWithAmt += amountBc + interest;
        }
        // handling the last one
                
            uint256 amountBc = amountToWithdraw - totalBcAmt;
            uint256 amountLeft = bcTokenMinted[user][index].bcAmount - amountBc;
            uint256 timestampOfLastOne = bcTokenMinted[user][index].timestamp;

            uint256 timeStamp = bcTokenMinted[user][index].timestamp;
            uint256 numOfDays = (block.timestamp - timeStamp) / 1 days;

            uint256 interest =  amountBc * numOfDays * interestPerDay / 100;

            totalInterestWithAmt += amountBc + interest;

            // new accounting
            tempAccountArray = bcTokenMinted[user]; 
            bcTokenMinted[user] = new Account[];
            bcTokenMinted[user].push(Account({bcAmount: amountLeft, timestamp: timestampOfLastOne}));

            // pushing the rest of the deposites

            for (uint256 i = index + 1; i < tempAccountArray.length; i++) {
                bcTokenMinted[user].push(tempAccountArray[i]);
            }

            // returning the interest with amount

            return totalInterestWithAmt;



    }



















    //////////////// old //////////////
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
        uint256 s = (tokenGiven * totalBcTokensMinted) / totalAmtOfTokenGiven;
        return s;
    }

    function mintLPToken(address user, uint256 amount) public {
        i_bcToken.mint(user, amount);
    }

    function mintInitialLPToken(uint256 amountOfInitialwethInPool, uint256 amountOfInitialusdcInPool) public {

        uint256 tokensToMintFromWeth = getBcTokensToMintForWeth(amountOfInitialwethInPool);
        uint256 tokensToMintFromUsdc = getBcTokensToMintForUsdc(amountOfInitialusdcInPool);


        totalBcTokensMinted += tokensToMintFromUsdc + tokensToMintFromWeth;
        i_bcToken.mint(address(this), tokensToMint);
    }


    function getAmtAnotherTokenForAToken(uint256 tokenAmount, uint256 tokenTotalAmt, uint256 AnotherTokenTotalAmt)
        public
        returns (uint256)
    {
        uint256 AnotherTokenAmt = (tokenAmount * AnotherTokenTotalAmt) / (tokenTotalAmt + tokenAmount); // reference from the video link in readme
        return AnotherTokenAmt;
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier cantBeZero(uint256 amount) {
        if (amount == 0) revert Bc__NeedsMoreThanZero();
        _;
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
