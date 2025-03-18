// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdCheats} from "lib/forge-std/src/StdCheats.sol";
import {DeployLPContract} from "script/DeployLPContract.s.sol";
import {HelperConfigLPContract} from "script/HelperConfigLPContract.s.sol";
import {LPContract} from "src/LPContract.sol";

import {LPToken} from "src/LPToken.sol";
import {SunEth} from "src/LPExternalTokens/SunEth.sol";
import {EarthEth} from "src/LPExternalTokens/EarthEth.sol";
import {EarthEthAggregator} from "src/LPExternalAggregators/EarthEthAggregator.sol";
import {SunEthAggregator} from "src/LPExternalAggregators/SunEthAggregator.sol";

contract LPContractTest is Test {
    LPToken lpToken;
    SunEth sunEth;
    EarthEth earthEth;
    SunEthAggregator sunEthAggregator;
    EarthEthAggregator earthEthAggregator;

    address SunEthAddress;
    address EarthEthAddress;
    address SunEthPriceFeedAddress;
    address EarthEthPriceFeedAddress;
    address LPTokenAddress;

    uint256 public constant STARTING_BALANCE = 1000 ether;
    address public USER = makeAddr("USER");
    address public immutable i_initial_owner = msg.sender;

    LPContract lPContract;
    HelperConfigLPContract helperConfigLPContract;

    function setUp() public {
        DeployLPContract deployLPContract = new DeployLPContract();
        (lPContract, helperConfigLPContract) = deployLPContract.run();

        (SunEthAddress, EarthEthAddress, SunEthPriceFeedAddress, EarthEthPriceFeedAddress, LPTokenAddress) =
            helperConfigLPContract.getNetworkConfigs();

        lpToken = LPToken(LPTokenAddress);
        sunEth = SunEth(SunEthAddress);
        earthEth = EarthEth(EarthEthAddress);
        sunEthAggregator = SunEthAggregator(SunEthPriceFeedAddress);
        earthEthAggregator = EarthEthAggregator(EarthEthPriceFeedAddress);

        vm.deal(USER, 100 ether);
    }

    // function invariant__testFunctionGetTheMaximumBasketSize() public {
    //     // The amount of token from this function must be in ratio 1:4, as it depends on initial supply,
    //     // which depends on the initial prices of SunEth and EarthEth
    //     uint256 sunEthTokens = bound(uint256(keccak256("sunEthSomething")), 1, 1e18);
    //     uint256 earthEthTokens = bound(uint256(keccak256("earthEthSomething")), 1, 1e18);

    //     console.log("sunEthTokens", sunEthTokens);
    //     console.log("earthEthTokens", earthEthTokens);
    //     (uint256 sun, uint256 earth) = lPContract.getTheMaximumBasket(sunEthTokens, earthEthTokens);
    //     assert(4 == uint256(earth / sun));
    // }
}
