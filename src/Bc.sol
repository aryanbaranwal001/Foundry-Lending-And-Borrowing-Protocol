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

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    struct Account {
        uint256 bcAmount;
        uint256 timestamp;
    }

    struct BorrowWethForUsdc {
        uint256 collateralUsdc;
        uint256 borrowedWeth;
    }

    struct BorrowUsdcForWeth {
        uint256 collateralWeth;
        uint256 borrowedUsdc;
    }

    mapping(address => Account[]) public bcTokenMinted;

    mapping(address => BorrowWethForUsdc) public s_borrowWethForUsdc;

    mapping(address => BorrowUsdcForWeth) public s_borrowUsdcForWeth;

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

        mintInitialbcToken(amountOfInitialwethInPool, amountOfInitialusdcInPool);

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

        uint256 usdcToWithdraw = totalBcTokens / 100;

        usdc.transferFromOwner(address(this), msg.sender, usdcToWithdraw);
        totalusdcInPool -= usdcToWithdraw;
    }

    /*//////////////////////////////////////////////////////////////
                            BORROW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function borrowWethForUsdc(uint256 amountUsdc) public {
        (, int256 rateweth,,,) = wethAggr.latestRoundData();
        (, int256 rateusdc,,,) = usdcAggr.latestRoundData();

        // TotalValueOfUsdc/TotalValueOfWeth * 100 = 200
        // 200 % over collaterized

        uint256 amountWethToBorrow = ((amountUsdc * rateusdc) / (rateweth * 2));

        usdc.transferFromOwner(msg.sender, address(this), amountUsdc);
        weth.transferFromOwner(address(this), msg.sender, amountWethToBorrow);

        totalusdcInPool += amountUsdc;
        totalwethInPool -= amountWethToBorrow;
        uint256 UsdcCollateralFromUser = s_borrowWethForUsdc[msg.sender].collateralUsdc;
        uint256 WethBorrowedToUser = s_borrowWethForUsdc[msg.sender].borrowedWeth;

        UsdcCollateralFromUser += amountUsdc;
        WethBorrowedToUser += amountWethToBorrow;

        s_borrowWethForUsdc[msg.sender] =
            BorrowWethForUsdc({collateralUsdc: UsdcCollateralFromUser, borrowedWeth: WethBorrowedToUser});
    }

    function borrowUsdcForWeth(uint256 amoundWeth) public {
        (, int256 rateweth,,,) = wethAggr.latestRoundData();
        (, int256 rateusdc,,,) = usdcAggr.latestRoundData();

        // TotalValueOfWeth/TotalValueOfUsdc * 100 = 200
        // 200 % over collaterized

        uint256 amountOfUsdcToBorrow = ((amoundWeth * rateweth) / (rateusdc * 2));

        weth.transferFromOwner(msg.sender, address(this), amoundWeth);
        usdc.transferFromOwner(address(this), msg.sender, amountOfUsdcToBorrow);

        totalwethInPool += amoundWeth;
        totalusdcInPool -= amountOfUsdcToBorrow;

        uint256 WethCollateralFromUser = s_borrowUsdcForWeth[msg.sender].collateralWeth;
        uint256 UsdcBorrowedToUser = s_borrowUsdcForWeth[msg.sender].borrowedUsdc;

        WethCollateralFromUser += amoundWeth;
        UsdcBorrowedToUser += amountOfUsdcToBorrow;

        s_borrowUsdcForWeth[msg.sender] =
            BorrowUsdcForWeth({collateralWeth: WethCollateralFromUser, borrowedUsdc: UsdcBorrowedToUser});
    }

    /*//////////////////////////////////////////////////////////////
                    REPAY BORROWED AMOUNT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // If we don't take the interest out, then if we repay all collateral into the contract,
    // then we can get all the borrowed amount back. Hence, at the time of withdrawing, the ratio
    // of amount of tokens in his account (one struct) will we same.

    function repayUsdcForWeth(uint256 amountUsdc) public {
        uint256 borrowedUsdcFromUser = s_borrowUsdcForWeth[msg.sender].borrowedUsdc;
        uint256 collateralWethOfUser = s_borrowUsdcForWeth[msg.sender].collateralWeth;

        uint256 amountOfWethToGetBack = collateralWethOfUser * (amountUsdc / borrowedUsdcFromUser);

        // therefore

        borrowedUsdcFromUser -= amountUsdc;
        collateralWethOfUser -= amountOfWethToPayBack;

        s_borrowUsdcForWeth[msg.sender] =
            BorrowUsdcForWeth({collateralWeth: collateralWethOfUser, borrowedUsdc: borrowedUsdcFromUser});

        usdc.transferFromOwner(msg.sender, address(this), amountUsdc);
        weth.transferFromOwner(address(this), msg.sender, amountOfWethToGetBack * 92 / 100); // 8% interest

        totalusdcInPool += amountUsdc;
        totalwethInPool -= amountOfWethToGetBack * 92 / 100;
    }

    function repayWethForUsdc(uint256 amountWeth) public {
        uint256 borrowedWethFromUser = s_borrowWethForUsdc[msg.sender].borrowedWeth;
        uint256 collateralUsdcOfUser = s_borrowWethForUsdc[msg.sender].collateralUsdc;

        uint256 amountOfUsdcToGetBack = collateralUsdcOfUser * (amountWeth / borrowedWethFromUser);

        // therefore

        borrowedWethFromUser -= amountWeth;
        collateralUsdcOfUser -= amountOfUsdcToPayBack;

        s_borrowWethForUsdc[msg.sender] =
            BorrowWethForUsdc({collateralUsdc: collateralUsdcOfUser, borrowedWeth: borrowedWethFromUser});

        weth.transferFromOwner(msg.sender, address(this), amountWeth);
        usdc.transferFromOwner(address(this), msg.sender, amountOfUsdcToGetBack * 92 / 100); // 8% interest

        totalwethInPool += amountWeth;
        totalusdcInPool -= amountOfUsdcToGetBack * 92 / 100;
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

    function getTotalBcTokens(address user, uint256 amountToWithdraw) internal returns (uint256) {
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

        uint256 interestPerDay = 3 / 365;
        uint256 totalInterestWithAmt = 0;

        for (uint256 i = 0; i < index; i++) {
            // last amt lefts
            uint256 amountBc = bcTokenMinted[user][i].bcAmount;
            uint256 timeStamp = bcTokenMinted[user][i].timestamp;
            uint256 numOfDays = (block.timestamp - timeStamp) / 1 days;

            uint256 interest = amountBc * numOfDays * interestPerDay / 100;

            totalInterestWithAmt += amountBc + interest;
        }
        // handling the last one

        uint256 amountBc = amountToWithdraw - totalBcAmt;
        uint256 amountLeft = bcTokenMinted[user][index].bcAmount - amountBc;
        uint256 timestampOfLastOne = bcTokenMinted[user][index].timestamp;

        uint256 timeStamp = bcTokenMinted[user][index].timestamp;
        uint256 numOfDays = (block.timestamp - timeStamp) / 1 days;

        uint256 interest = amountBc * numOfDays * interestPerDay / 100;

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

    function mintInitialbcToken(uint256 amountOfInitialwethInPool, uint256 amountOfInitialusdcInPool) public {
        uint256 tokensToMintFromWeth = getBcTokensToMintForWeth(amountOfInitialwethInPool);
        uint256 tokensToMintFromUsdc = getBcTokensToMintForUsdc(amountOfInitialusdcInPool);

        totalBcTokensMinted += tokensToMintFromUsdc + tokensToMintFromWeth;
        i_bcToken.mint(address(this), tokensToMint);
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
