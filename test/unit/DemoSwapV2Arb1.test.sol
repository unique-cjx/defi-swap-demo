// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";

import { IERC20 } from "../../src/interfaces/IERC20.sol";
import { IUniswapV2Factory } from "../../src/interfaces/uniswap-v2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import { DemoSwapV2Arb1 } from "../../src/DemoSwapV2Arb1.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";
import { MockUniswapV2Router } from "../mocks/MockUniswapV2Router.sol";

contract DemoSwapV2Arb1Test is Test, BaseDemoSwapV2Test {
    DemoSwapV2Arb1 private arb;
    MockUniswapV2Router private mockRouter;

    IUniswapV2Factory public factory;
    address flashPair;

    uint256 private constant ADD_LIQUIDITY_AMOUNT_WETH = 1000 ether;
    uint256 private constant ADD_LIQUIDITY_AMOUNT_WETH_DAI = 4_000_000 ether;

    uint256 private constant ADD_LIQUIDITY_AMOUNT_MKR = 1000 ether;
    uint256 private constant ADD_LIQUIDITY_AMOUNT_MKR_DAI = 1_000_000 ether;

    function setUp() public {
        _setUp();
        arb = new DemoSwapV2Arb1();

        factory = IUniswapV2Factory(router.factory());
        flashPair = factory.getPair(MKR, DAI);

        deal(DAI, testUser, 1_000_000_000 ether);
        deal(WETH, testUser, 100_000 ether);
        deal(MKR, testUser, 100_000 ether);

        // 1. Deploy Mock Router
        mockRouter = new MockUniswapV2Router();

        // 2. Fund Mock Router with tokens so it can pay out swaps
        deal(DAI, address(mockRouter), 1_000_000 ether);
        deal(WETH, address(mockRouter), 1000 ether);
        // 3. Configure Price on Mock Router
        // Real Router Price (approx): 1 WETH = 4000 DAI (based on SetupLiquidity defaults)
        // We set Mock Router Price:   1 WETH = 3900 DAI (Higher price for WETH)
        mockRouter.setRate(WETH, DAI, 3900e18);
        // Inverse rate: 1 DAI = 0.00025641 WETH
        mockRouter.setRate(DAI, WETH, 0.00025641e18);

        // Add new amount of WETH to liquidity for tests
        vm.startPrank(testUser);
        (uint256 amountA, uint256 amountB,) = router.addLiquidity(
            WETH, DAI, ADD_LIQUIDITY_AMOUNT_WETH, ADD_LIQUIDITY_AMOUNT_WETH_DAI, 0, 0, testUser, block.timestamp
        );

        console2.log("arb1: added WETH/DAI pair in liquidity: %18e WETH and %18e DAI", amountA, amountB);

        (amountA, amountB,) = router.addLiquidity(
            MKR, DAI, ADD_LIQUIDITY_AMOUNT_MKR, ADD_LIQUIDITY_AMOUNT_MKR_DAI, 0, 0, testUser, block.timestamp
        );

        console2.log("arb1: added MKR/DAI pair in liquidity: %18e MKR and %18e DAI", amountA, amountB);
        vm.stopPrank();
    }

    // Scenario:
    // 1. Start with DAI.
    // 2. Buy WETH on Mock Router (Cheap WETH: 3900 DAI per WETH).
    // 3. Sell WETH on Real Router (Expensive WETH: 4000 DAI per WETH).
    // 4. Profit in DAI.
    function test_Arb1Swap() public {
        deal(DAI, testUser, 1_000_000 ether);
        uint256 amountIn = 40_000 ether; //It's approx 10.25641 WETH on Mock Router.

        vm.startPrank(testUser);

        uint256 daiBefore = IERC20(DAI).balanceOf(testUser);
        console2.log("Starting DAI Balance: %18e", daiBefore);

        IERC20(DAI).approve(address(arb), amountIn);
        DemoSwapV2Arb1.SwapParams memory params = DemoSwapV2Arb1.SwapParams({
            router0: address(mockRouter), // Mock: DAI -> WETH (Buy Cheap)
            router1: address(router), // Real: WETH -> DAI (Sell Expensive)
            tokenIn: DAI,
            tokenOut: WETH,
            amountIn: amountIn,
            minProfit: 1
        });

        // Explanation of arbitrage outcome based on liquidity:
        // 1. Market Setup:
        //    - Mock Router: 1 WETH = 3900 DAI (Fixed rate, no slippage).
        //    - Real Router: 1 WETH = 4000 DAI (AMM, x * y = k).
        //
        // 2. Step 1 (Buy WETH):
        //    - Input: 40,000 DAI.
        //    - Output: ~10.2564 WETH (at 3900 DAI/WETH).
        //
        // 3. Step 2 (Sell WETH on Real Router - 1100 WETH):
        //      - Injecting ~10.25 WETH into a 1100 WETH pool is only ~1% of the pool.
        //      - Slippage is manageable (~1%). ~ 3963 DAI per WETH after slippage.
        //      - The price spread (4000 vs 3900, ~2.5% gap) outweighs the slippage cost.
        //
        // Net Profit: ~525 DAI
        // Theoretical Profit: 1025
        // Costs: ~500 DAI (handing fee: 0.3% - 120 DAI + slippage: 380 DAI)
        // How to calculate slippage: x * y = k, k = 4000 * 1100 = 4,400,000, x = (1100+10.256).
        arb.swap(params);

        uint256 daiAfter = IERC20(DAI).balanceOf(testUser);
        console2.log("DAI Balance After: %18e", daiAfter);
        console2.log("Profit:            %18e", daiAfter - daiBefore);

        assertGt(daiAfter, daiBefore, "Should have made a profit");
        vm.stopPrank();
    }

    // Scenario:
    // 1. Start with DAI.
    // 2. Flash swap DAI from MKR/DAI pair.
    // 3. Buy WETH on Mock Router (Cheap WETH: 3900 DAI per WETH).
    // 4. Sell WETH on Real Router (Expensive WETH: 4000 DAI per WETH).
    // 5. Repay flash swap + profit in DAI.
    function test_Arb1FlashSwap() public {
        // Amount of DAI to convert to MKR for flash swap,
        // it's approx 50 MKR, and aslo it approx equles 12.5 WETH
        uint256 borrowAmount = 50_000 ether;

        address token0 = IUniswapV2Pair(flashPair).token0();
        bool isDAI = token0 == DAI;
        DemoSwapV2Arb1.SwapParams memory params = DemoSwapV2Arb1.SwapParams({
            router0: address(mockRouter),
            router1: address(router),
            tokenIn: DAI,
            tokenOut: WETH,
            amountIn: borrowAmount,
            minProfit: 10 ether
        });
        vm.startPrank(testUser);
        uint256 daiBa1 = _getBalance(DAI);
        console2.log("testUser DAI Balance Before: %18e", daiBa1);

        // Explanation of the ~390 DAI Profit:
        // 1. Borrow: 50,000 DAI via Flash Swap.
        //    - Flash Fee (0.3%): ~151 DAI.
        //    - Total Debt: 50,151 DAI.
        //
        // 2. Step 1 (Buy WETH on Mock Router):
        //    - Input: 50,000 DAI.
        //    - Rate: 3900 DAI/WETH.
        //    - Output: ~12.82 WETH.
        //
        // 3. Step 2 (Sell WETH on Real Router):
        //    - Input: ~12.82 WETH.
        //    - Pool Depth: 1100 WETH : 4,400,000 DAI.
        //    - Slippage: ~1.1% (due to 12.8 WETH trade size relative to 1100 WETH pool).
        //    - Swap Fee: 0.3%.
        //    - Output: ~50,541 DAI.
        //
        // 4. Net Profit:
        //    - 50,541 (Revenue) - 50,151 (Debt) = ~390 DAI.
        //    - The 2.5% price spread (4000 vs 3900) covers the slippage and double fees (0.6%).
        arb.flashSwap(flashPair, isDAI, params);

        uint256 daiBa2 = _getBalance(DAI);
        console2.log("testUser DAI Balance After: %18e", daiBa2);
        vm.stopPrank();

        console2.log("Profit:             %18e", daiBa2 - daiBa1);
        assertGt(daiBa2 - daiBa1, 0, "Should have made a profit");
    }
}
