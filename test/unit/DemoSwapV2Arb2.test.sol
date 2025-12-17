// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";

import { IERC20 } from "../../src/interfaces/IERC20.sol";
import { DemoSwapV2Arb2 } from "../../src/DemoSwapV2Arb2.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";
import { MockUniswapV2Pair } from "../mocks/MockUniswapV2Pair.sol";

contract DemoSwapV2Arb2Test is Test, BaseDemoSwapV2Test {
    DemoSwapV2Arb2 private arb2;

    MockUniswapV2Pair private pair0; // cheap WETH pool (DAI/WETH)
    MockUniswapV2Pair private pair1; // expensive WETH pool (DAI/WETH)

    uint256 private constant PAIR0_DAI = 3_900_000 ether;
    uint256 private constant PAIR0_WETH = 1000 ether;

    uint256 private constant PAIR1_DAI = 40_000_000 ether;
    uint256 private constant PAIR1_WETH = 10_000 ether;

    function setUp() public {
        _setUp();
        arb2 = new DemoSwapV2Arb2();

        // Provide liquidity tokens to testUser
        deal(DAI, testUser, 900_000_000 ether);
        deal(WETH, testUser, 20_000 ether);

        // Deploy 2 pools with same pair but different reserves => price discrepancy
        pair0 = new MockUniswapV2Pair(DAI, WETH);
        pair1 = new MockUniswapV2Pair(DAI, WETH);

        vm.startPrank(testUser);
        IERC20(DAI).approve(address(pair0), type(uint256).max);
        IERC20(WETH).approve(address(pair0), type(uint256).max);
        IERC20(DAI).approve(address(pair1), type(uint256).max);
        IERC20(WETH).approve(address(pair1), type(uint256).max);

        pair0.seed(PAIR0_DAI, PAIR0_WETH); // ~3900 DAI/WETH (cheap WETH vs pair1)
        pair1.seed(PAIR1_DAI, PAIR1_WETH); // ~4000 DAI/WETH (regular WETH)
        vm.stopPrank();
    }

    function test_Arb2FlashSwap() public {
        // Strategy (single-sided):
        // - Flash borrow WETH from pair0, repay in DAI
        // - Sell WETH into pair1 for more DAI
        // - Repay pair0, keep DAI profit
        deal(DAI, testUser, 0 ether);
        deal(WETH, testUser, 0 ether);

        uint256 amountInRepayDai = 3900 * 10 ether; // repay amount (DAI)
        uint256 minProfit = 100 ether;

        vm.startPrank(testUser);
        uint256 daiBefore = _getBalance(DAI);
        console2.log("arb2: testUser DAI before: %18e", daiBefore);
        console2.log("arb2: testUser WETH before: %18e", _getBalance(WETH));

        arb2.flashSwap(address(pair0), address(pair1), true, amountInRepayDai, minProfit);

        uint256 daiAfter = IERC20(DAI).balanceOf(testUser);
        console2.log("arb2: testUser DAI after:  %18e", daiAfter);

        assertGe(daiAfter - minProfit, daiBefore, "Should have made a profit");
        vm.stopPrank();
    }
}
