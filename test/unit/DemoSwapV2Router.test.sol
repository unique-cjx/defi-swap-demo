// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";

import { IWETH } from "../../src/interfaces/IWETH.sol";
import { IERC20 } from "../../src/interfaces/IERC20.sol";
import { IUniswapV2Router02 } from "../../src/interfaces/uniswap-v2/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "../../src/interfaces/uniswap-v2/IUniswapV2Factory.sol";
import { SetupLiquidity } from "../../script/SetupLiquidity.sol";
import { HelperConfig } from "../../script/HelperConfig.sol";
import { ERC20Mock } from "../../test/mocks/ERC20Mock.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";

contract DemoSwapV2RouterTest is Test, BaseDemoSwapV2Test {
    function setUp() public {
        _setUp();
    }

    // Liquidity added in SetupLiquidity:
    // 1. WETH/DAI pair: reserves = 100 WETH and 400,000 DAI
    // 2. MKR/DAI pair: reserves = 50 MKR and 50,000 DAI
    //
    // Uniswap V2 constant-product formula with 0.3% fee:
    // amountOut = (amountIn * reserveOut * 997) / (reserveIn * 1000 + amountIn * 997)
    //
    // Step 1: WETH -> DAI
    // reserveIn = 100 WETH, reserveOut = 400,000 DAI, amountIn = 1 WETH
    // amountOut_DAI = (1 * 400,000 * 997) / (100 * 1000 + 1 * 997)
    //               = 398,800,000 / 100,997
    //               ≈ 3948.632137588245195401 DAI
    //
    // Step 2: DAI -> MKR
    // reserveIn = 50,000 DAI, reserveOut = 50 MKR, amountIn ≈ 3948.632 DAI
    // amountOut_MKR = (3948.632... * 50 * 997) / (50,000 * 1000 + 3948.632... * 997)
    //               ≈ 196,839,312 / (50,000,000 + 3,936,786)
    //               ≈ 196,839,312 / 53,936,786
    //               ≈ 3.64944457718740367 MKR
    function test_getAmountsOut() public view {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountIn = 1 ether; // representing 1 WETH
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);

        console2.log("WETH %18e", amounts[0]);
        console2.log("DAI %18e", amounts[1]);
        console2.log("MKR %18e", amounts[2]);
    }

    // Liquidity added in SetupLiquidity:
    // 1. WETH/DAI pair: reserves = 100 WETH and 400,000 DAI
    // 2. MKR/DAI pair: reserves = 50 MKR and 50,000 DAI
    //
    // Uniswap amountsIn formula: amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1
    //
    // Step 1: DAI -> MKR (Last hop)
    // We want output = 1 MKR
    // reserveIn = 50,000 DAI, reserveOut = 50 MKR
    // amountIn_DAI = (50,000 * 1 * 1000) / ((50 - 1) * 997) + 1
    //              = 50,000,000 / 48,853 + 1
    //              ≈ 1023.478599062493603259 DAI
    //
    // Step 2: WETH -> DAI (First hop)
    // We want output = 1023.478599... DAI
    // reserveIn = 100 WETH, reserveOut = 400,000 DAI
    // amountIn_WETH = (100 * 1023.478599... * 1000) / ((400,000 - 1023.478599...) * 997) + 1
    //               = 102,347,859.9... / (398,976.521... * 997) + 1
    //               = 102,347,859.9... / 397,779,591.8... + 1
    //               ≈ 0.257297915746912384 WETH
    function test_getAmountsIn() public view {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountOut = 1e18;
        uint256[] memory amounts = router.getAmountsIn(amountOut, path);

        console2.log("WETH %18e", amounts[0]);
        console2.log("DAI %18e", amounts[1]);
        console2.log("MKR %18e", amounts[2]);
    }

    function test_RemoveLiquidity() public {
        ERC20Mock SOL = new ERC20Mock("SOL", "SOL", msg.sender, 1 ether);
        vm.startPrank(testUser);

        SOL.mint(testUser, 100 ether);
        SOL.approve(address(router), type(uint256).max);

        // Add liquidity for SOL/DAI(1 SOL ≈ 200 DAI)
        uint256 solAmount = 10 ether;
        (,, uint256 liquidity) =
            router.addLiquidity(address(SOL), DAI, solAmount, 2000 ether, 1, 1, testUser, block.timestamp);
        console2.log("Liquidity tokens minted: %18e", liquidity);

        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        address pair = factory.getPair(address(SOL), DAI);
        uint256 mintedSolAmount = SOL.balanceOf(pair);
        assertEq(solAmount, mintedSolAmount);

        // Remove liquidity from SOL/DAI
        IERC20(pair).approve(address(router), liquidity);
        (uint256 removedSolAmount, uint256 removedDaiAmount) =
            router.removeLiquidity(address(SOL), DAI, liquidity, 1, 1, testUser, block.timestamp);
        vm.stopPrank();

        console2.log("Removed SOL amount: %18e", removedSolAmount);
        console2.log("Removed DAI amount: %18e", removedDaiAmount);
        assertEq(IERC20(pair).balanceOf(testUser), 0);
    }

    function test_AddLiquidityETH() public {
        ERC20Mock SOL = new ERC20Mock("SOL", "SOL", msg.sender, 1 ether);
        vm.startPrank(testUser);

        SOL.mint(testUser, 100 ether);
        SOL.approve(address(router), type(uint256).max);

        uint256 ethToAdd = 1 ether;
        (uint256 solAmount, uint256 wethAmount, uint256 liquidity) =
            router.addLiquidityETH{ value: ethToAdd }(address(SOL), 20 ether, 1, 1, testUser, block.timestamp);
        vm.stopPrank();

        assertEq(solAmount, 20 ether);
        assertEq(wethAmount, ethToAdd);

        console2.log("Added SOL amount: %18e", solAmount);
        console2.log("Added WETH amount: %18e", wethAmount);
        // The amount of LP tokens minted to the to address, representing their share of the pool
        console2.log("Liquidity tokens minted: %18e", liquidity);
    }

    function test_SwapExactTokensForTokens() public {
        address[] memory path = new address[](3);
        path[0] = MKR;
        path[1] = DAI;
        path[2] = WETH;

        uint256 MKRAmountIn = 5e18;
        uint256 WETHAmountOutMin = 1e18; // Minimum amount of WETH to receive

        vm.prank(testUser);
        // amountIn: This is the amount of tokens the user will be sending in
        // amountOutMin: This is the minimum amount of output tokens the user expects
        // path: This is an array of addresses which define the token path for the swap
        uint256[] memory amounts =
            router.swapExactTokensForTokens(MKRAmountIn, WETHAmountOutMin, path, testUser, block.timestamp);
        console2.log("MKR: %18e", amounts[0]);
        console2.log("DAI: %18e", amounts[1]);
        console2.log("WETH: %18e", amounts[2]);

        uint256 swappedWETHBalance = _getBalance(WETH);
        uint256 swappedMKRBalance = _getBalance(MKR);
        console2.log("swapped WETH balance: %18e", swappedWETHBalance);
        console2.log("swapped MKR balance: %18e", swappedMKRBalance);
        assertGe(swappedWETHBalance, WETHBalance + WETHAmountOutMin);
    }

    function test_SwapTokensForExactTokens() public {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 MKRAmountOut = 1e18;
        uint256 WETHAmountInMax = 0.3e18; // What is the maximum WETH the user is willing to spend buy the amount of MKR

        vm.prank(testUser);
        uint256[] memory amounts =
            router.swapTokensForExactTokens(MKRAmountOut, WETHAmountInMax, path, testUser, block.timestamp);
        console2.log("WETH: %18e", amounts[0]);
        console2.log("DAI: %18e", amounts[1]);
        console2.log("MKR: %18e", amounts[2]);

        uint256 swappedMKRBalance = _getBalance(MKR);
        uint256 swappedWETHBalance = _getBalance(WETH);
        console2.log("swapped MKR balance: %18e", swappedMKRBalance);
        console2.log("swapped WETH balance: %18e", swappedWETHBalance);
        assertEq(swappedMKRBalance, MKRAmountOut + MKRBalance);
    }

    function test_SwapTokensForExactETH() public {
        address[] memory path = new address[](3);
        path[0] = MKR;
        path[1] = DAI;
        path[2] = WETH;

        uint256 WETHAmountOut = 1e17; // 0.1 WETH
        uint256 MKRAmountInMax = 1e18; // What is the maximum MKR the user is willing to spend buy 0.1 WETH

        vm.prank(testUser);
        // Calculation explanation:
        //
        // 1) Uniswap router computes required input amounts backwards through the path.
        //    Formula: amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1
        //
        // 2) Last hop (DAI -> WETH):
        //    - Liquidity deep: reserveIn = 400,000 DAI, reserveOut = 100 WETH
        //    - amountOut = 0.1 WETH
        //    - amountIn_DAI = (400,000 * 0.1 * 1000) / ((100 - 0.1) * 997)
        //                   ≈ 40,000,000 / 99,600.3 ≈ 401 DAI
        //
        // 3) First hop (MKR -> DAI):
        //    - Liquidity deep: reserveIn = 50 MKR, reserveOut = 50,000 DAI
        //    - amountOut = 401 DAI (from step 2)
        //    - amountIn_MKR = (50 * 401 * 1000) / ((50,000 - 401) * 997)
        //                   ≈ 20,050,000 / 49,450,203 ≈ 0.40 MKR
        //
        // 4) Summary (Expected values):
        //    - amounts[0] (MKR In)  ≈ 0.40e18
        //    - amounts[1] (DAI In)  ≈ 401e18
        //    - amounts[2] (WETH Out) = 0.1e18
        uint256[] memory amounts =
            router.swapTokensForExactETH(WETHAmountOut, MKRAmountInMax, path, testUser, block.timestamp);
        console2.log("MKR: %18e", amounts[0]);
        console2.log("DAI: %18e", amounts[1]);
        console2.log("WETH: %18e", amounts[2]);

        console2.log("user's the leatest ETH balance: %18e", testUser.balance);
        assertEq(testUser.balance, amounts[2] + WETHBalance);
    }
}
