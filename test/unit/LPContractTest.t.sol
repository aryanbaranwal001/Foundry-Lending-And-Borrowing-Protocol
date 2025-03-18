// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {StdCheats} from "lib/forge-std/src/StdCheats.sol";
import {DeployBorrowingContract} from "script/DeployBorrowingContract.s.sol";
import {HelperConfigBorrowingContract} from "script/HelperConfigBorrowingContract.s.sol";
import {Bc} from "src/Bc.sol";

import {BcToken} from "src/BcToken.sol";
import {Weth} from "src/BorrowingTokens/Weth.sol";
import {Usdc} from "src/BorrowingTokens/Usdc.sol";
import {WethAggr} from "src/BorrowingAggregators/WethAggr.sol";
import {UsdcAggr} from "src/BorrowingAggregators/UsdcAggr.sol";


contract BcTest is Test {
    BcToken bcToken;
    Weth weth;
    Usdc usdc;
    WethAggr wethAggr;
    UsdcAggr usdcAggr;

    address public wethAddress;
    address public usdcAddress;
    address public wethAggrAddress;
    address public usdcAggrAddress;
    address public bcTokenAddress;

    uint256 public constant STARTING_BALANCE = 1000 ether;
    address public USER = makeAddr("USER");
    address public immutable i_initial_owner = msg.sender;

    Bc bc;
    HelperConfigBorrowingContract helperConfigBorrowingContract;

    function setUp() public {
        DeployBorrowingContract deployBorrowingContract = new DeployBorrowingContract();
        (bc, helperConfigBorrowingContract) = deployBorrowingContract.run();

        (wethAddress, usdcAddress, wethAggrAddress, usdcAggrAddress, bcTokenAddress) =
            helperConfigBorrowingContract.getNetworkConfigs();

        bcTokenAddress = address(bcToken);
        wethAddress = address(weth);
        usdcAddress = address(usdc);
        wethAggrAddress = address(wethAggr);
        usdcAggrAddress = address(usdcAggr);

        vm.deal(USER, 100 ether);
    }

    // function testCheckInitialVolumeOfSunAndEarthTokens() public {
    //     uint256 sunEthAmt = lPContract.getTotalSunEthInPool();
    //     uint256 earthEthAmt = lPContract.getTotalEarthEthInPool();

    //     assert(sunEthAmt == 2.5e18);
    //     assert(earthEthAmt == 1e19);
    //     assert(sunEth.balanceOf(address(lPContract)) == 2.5e18);
    //     assert(earthEth.balanceOf(address(lPContract)) == 1e19);
    // }

    // function testMintInitialLPTokens() public {
    //     uint256 lpTokenBalanceOfContract = lpToken.balanceOf(address(lPContract));

    //     assert(lpTokenBalanceOfContract == 5e18);
    // }

    // function testConstructorTwoStillCallable() public {
    //     bool tempVar = lPContract.constructor2();
    //     assert(tempVar == true);
    // }

    // function testGetTokenFromPoolUsingLPTokens() public giveTokensToUser {
    //     vm.prank(USER);
    //     lPContract.addToPool(1e16, 4e16);

    //     uint256 lpTokenOfUser = lpToken.balanceOf(USER);

    //     vm.prank(USER);
    //     lPContract.getTokensFromPoolUsingLPTokens(lpTokenOfUser);

    //     // No reverts mean lPtokenContract's owner is LPContract which is
    //     // calling the burn function for USER.
    // }

    // function testExchangeSunEthForEarthEth() public {
    //     // calculated 4e8 by hand using. And checking if this equals to that
    //     uint256 anotherTokenAmt = lPContract.getAmtAnotherTokenForAToken(1e8, 1e20, 4e20);
    //     assert(anotherTokenAmt == 4e8 - 1);
    // }

    // modifier giveTokensToUser() {
    //     sunEth.mint(USER, 1e18);
    //     earthEth.mint(USER, 4e18);
    //     _;
    // }
}
