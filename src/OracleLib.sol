// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__LatestRoundDataIsStale();

    uint256 internal constant TIMEOUT = 3 hours;

    function checkOracleStaleAndLatestRoundData(address priceFeedAddress)
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);

        (roundId, answer, startedAt, updatedAt, answeredInRound) = priceFeed.latestRoundData();

        if (block.timestamp >= updatedAt + TIMEOUT) revert OracleLib__LatestRoundDataIsStale();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function getTimeout() public pure returns (uint256) {
        return TIMEOUT;
    }
}
