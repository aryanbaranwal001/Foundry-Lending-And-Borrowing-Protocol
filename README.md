# Automated Market Maker Implementation


### This Automated market maker has following features

1. The initial pool has a total of $2_000_000 value, with $1_000_000 each of the SunEth token and EarthEth Token. Hence, contract starts with a good enough liquidity to minimize arbitrage as much as possible. 
2. I have use mockV3aggregator pricefeeds to get this project as close as possible to how AMMs actually work
3. I have arbitrage checker functions which would show how much of a profit or loss a user is getting for exchanging one kind of token for another in USD.
4. Liquidity pool providers will get another token called LPToken which they can use to get both token in ratio such that it doesn't affect the price of one token in terms of other ,i.e., opportunity for arbitrage is same as before. 
5. LPToken serve as a share of pool.
6. Have to implement my own transfer function in ERC20, as transferFrom does something with approval thingy which I don't want and transfer function doesn't take (address from) as a input.





### Reference Video

The math and concepts implemented in this project are based on the following video

https://www.youtube.com/watch?v=QNPyFs8Wybk&t=2s

