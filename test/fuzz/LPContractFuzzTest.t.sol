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

    function testFunctionGetTheMaximumBasketSize(uint256 sunEthTokens, uint256 earthEthTokens) public {
        // The amount of token from this function must be in ratio 1:4, as it depends on initial supply,
        // which depends on the initial prices of SunEth and EarthEth specified in deployLPContract & HelperConfigLPContract
        sunEthTokens = bound(sunEthTokens, 1e2, 1e18);
        earthEthTokens = bound(earthEthTokens, 1e2, 1e18);

        (uint256 sun, uint256 earth) = lPContract.getTheMaximumBasket(sunEthTokens, earthEthTokens);
        assert(4 == uint256(earth / sun));
    }

    function testAddToPoolIsTransferingFundsCorrectly(uint256 sunInUser, uint256 earthInUser) public {
        // initial balance of use is (0,0)
        sunInUser = bound(sunInUser, 1e2, 1e18);
        earthInUser = bound(earthInUser, 1e2, 1e18);

        sunEth.mint(USER, sunInUser);
        earthEth.mint(USER, earthInUser);

        uint256 userSunInitial = sunEth.balanceOf(USER);
        uint256 userEarthInitial = earthEth.balanceOf(USER);

        uint256 contractSunInitial = sunEth.balanceOf(address(lPContract));
        uint256 contractEarthInitial = earthEth.balanceOf(address(lPContract));

        vm.prank(USER);
        lPContract.addToPool(sunInUser, earthInUser);

        (uint256 sun, uint256 earth) = lPContract.getTheMaximumBasket(sunInUser, earthInUser);

        uint256 userSunFinal = sunEth.balanceOf(USER);
        uint256 userEarthFinal = earthEth.balanceOf(USER);

        uint256 contractSunFinal = sunEth.balanceOf(address(lPContract));
        uint256 contractEarthFinal = earthEth.balanceOf(address(lPContract));

        assert(userSunFinal == userSunInitial - sun);
        assert(userEarthFinal == userEarthInitial - earth);

        assert(contractSunFinal == contractSunInitial + sun);
        assert(contractEarthFinal == contractEarthInitial + earth);
    }

    function testLPTokensAreGettingMintedCorrectly() public {
        
    }

}
