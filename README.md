# Lending Borrowing Protocol


### This Lending Borrowing Protocol has following features

1. The initial pool has a total of $20_000 value, with $10_000 each of the weth token and usdc token.
2. I have use mockV3aggregator pricefeeds to get the price of each tokens in usd.
3. The depositers will get a bcToken which similar to cETH or aWeth. Over the time exchange rate between (usdc & BcToken) and (weth & BcToken) will increase in a way to account for 3% interest on amount deposited.
4. Borrowers will have to deposite a collateral in order to borrow another token such that the borrowed token is always 150% collaterised. This ensure that borrowed token is sufficiently backed enough. They will have to pay a interest of 8% in the borrowed amount.
5. Depositors will get bcTokens according to the price ratio of both tokens in the market

Ex. 

1 weth = $4000
1 usdc = $1000

so if contract gives 100 bcTokens for a usdc, then it will give 400 bcTokens for a weth. 

bcTokens minted is fixed at 100 bcTokens for a usdc. For weth, it will vary according to prices.

6. When someone borrows one token for another, lets say, token A for token B, for the amount of token B user wants, we take only token A such that its 200% collaterize.
7. When the value of token A drops such that it becomes less than being 150% collaterize, we liquidate his funds.



### Reference Video

The math and concepts implemented in this project are based on the following video

https://www.youtube.com/watch?v=QNPyFs8Wybk&t=2s

