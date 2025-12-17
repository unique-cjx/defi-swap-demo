// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";
import { IUniswapV2Pair } from "../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "../../src/interfaces/uniswap-v2/IUniswapV2Factory.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DemoSwapV2PairTest is Test, BaseDemoSwapV2Test {
    IUniswapV2Pair public pair;

    function setUp() public {
        _setUp();

        // Get WETH/DAI pair from factory
        address factory = router.factory();
        address pairAddress = IUniswapV2Factory(factory).getPair(WETH, DAI);
        pair = IUniswapV2Pair(pairAddress);
    }

    function test_Mint() public {
        vm.startPrank(testUser);

        uint256 amount0 = 1 ether; // WETH
        uint256 amount1 = 4000 ether; // DAI (approx price)

        // 1. Transfer tokens directly to pair
        IERC20(WETH).transfer(address(pair), amount0);
        IERC20(DAI).transfer(address(pair), amount1);
        console2.log(
            "Transferred to pair: WETH %18e, DAI %18e",
            IERC20(WETH).balanceOf(address(pair)),
            IERC20(DAI).balanceOf(address(pair))
        );

        // Liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY
        // Liquidity = sqrt(1 ether * 4000 ether)
        // The code typically subtracts a tiny MINIMUM_LIQUIDITY (1000 wei) to prevent inflation attacks,
        // but this is negligible when displaying values in 1e18 format.
        console2.log("Reserves before mint: ", pair.balanceOf(testUser));
        // 2. Call mint
        // The function mints liquidity tokens to the address specified
        uint256 liquidity = pair.mint(testUser);
        vm.stopPrank();

        console2.log("Liquidity minted: %18e", liquidity);
        assertGt(liquidity, 0);
        assertEq(pair.balanceOf(testUser), liquidity);
    }

    function test_Burn() public {
        vm.startPrank(testUser);

        // 1. Add liquidity first to get LP tokens
        uint256 amountWETH = 1 ether;
        uint256 amountDAI = 4000 ether;
        IERC20(WETH).transfer(address(pair), amountWETH);
        IERC20(DAI).transfer(address(pair), amountDAI);
        uint256 liquidity = pair.mint(testUser);

        // 2. Transfer LP tokens to pair (required before burning)
        pair.transfer(address(pair), liquidity);

        // 3. Burn
        // The function burns liquidity tokens in the pair contract and sends underlying tokens to testUser
        (uint256 amount0Out, uint256 amount1Out) = pair.burn(testUser);

        vm.stopPrank();

        console2.log("Burned LP tokens: %18e", liquidity);
        console2.log("Received Token0: %18e", amount0Out);
        console2.log("Received Token1: %18e", amount1Out);

        // Determine expected outputs based on token sorting
        address token0 = pair.token0();
        uint256 expected0Out;
        uint256 expected1Out;

        if (token0 == WETH) {
            expected0Out = amountWETH;
            expected1Out = amountDAI;
        } else {
            expected0Out = amountDAI;
            expected1Out = amountWETH;
        }

        // Should get back roughly what we put in
        // Note: Using relative approximation because of potential small liquidity lock or fee differences if any
        assertApproxEqRel(amount0Out, expected0Out, 1e16); // 0.01 tolerance
        assertApproxEqRel(amount1Out, expected1Out, 1e16);
    }

    function test_Skim() public {
        vm.startPrank(testUser);

        uint256 amountDonation = 5 ether;
        IERC20(WETH).transfer(address(pair), amountDonation);

        uint256 preBalanceWETH = IERC20(WETH).balanceOf(address(pair));
        console2.log("Pre-skim WETH balance: %18e", preBalanceWETH);

        // Recover excess tokens to testUser
        // The function transfers any tokens above the reserves to the specified address
        pair.skim(testUser);
        vm.stopPrank();

        uint256 skimedBalanceWETH = IERC20(WETH).balanceOf(address(pair));
        console2.log("Post-skim WETH balance: %18e", skimedBalanceWETH);
        console2.log("Skimmed WETH: %18e", preBalanceWETH - skimedBalanceWETH);
        assertEq(preBalanceWETH - skimedBalanceWETH, amountDonation);
    }

    function test_Sync() public {
        vm.startPrank(testUser);

        uint256 amountDonation = 10 ether;
        IERC20(WETH).transfer(address(pair), amountDonation);

        (uint112 reserve0Pre, uint112 reserve1Pre,) = pair.getReserves();

        // Force reserves to match balances
        pair.sync();

        (uint112 reserve0Post, uint112 reserve1Post,) = pair.getReserves();
        vm.stopPrank();

        address token0 = pair.token0();
        uint112 wethReservePre;
        uint112 wethReservePost;

        if (token0 == WETH) {
            assertEq(reserve0Post, reserve0Pre + amountDonation);
            assertEq(reserve1Post, reserve1Pre);
            wethReservePre = reserve0Pre;
            wethReservePost = reserve0Post;
        } else {
            assertEq(reserve0Post, reserve0Pre);
            assertEq(reserve1Post, reserve1Pre + amountDonation);
            wethReservePre = reserve1Pre;
            wethReservePost = reserve1Post;
        }
        console2.log("Pre sync Reserves - WETH: %18e", wethReservePre);
        console2.log("Post sync Reserves - WETH: %18e", wethReservePost);
    }

    function test_BasicSwap() public {
        vm.startPrank(testUser);

        // Determine token order
        address token0 = pair.token0();
        bool isWETHZero = token0 == WETH;

        uint256 amountIn = 1 ether; // WETH

        // 1. Transfer input tokens to pair (Optimistic transfer)
        IERC20(WETH).transfer(address(pair), amountIn);

        // 2. Calculate expected output
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        uint256 reserveIn = isWETHZero ? reserve0 : reserve1;
        uint256 reserveOut = isWETHZero ? reserve1 : reserve0;

        if (isWETHZero) {
            console2.log("Reserves before swap - WETH: %18e", reserve0);
            console2.log("Reserves before swap - DAI: %18e", reserve1);
        } else {
            console2.log("Reserves before swap - WETH: %18e", reserve1);
            console2.log("Reserves before swap - DAI: %18e", reserve0);
        }

        // amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        uint256 amount0Out = isWETHZero ? 0 : amountOut;
        uint256 amount1Out = isWETHZero ? amountOut : 0;
        console2.log("amount0Out calculated: %18e, amount1Out calculated: %18e", amount0Out, amount1Out);

        uint256 preBalanceDAI = IERC20(DAI).balanceOf(testUser);

        // 3. Call swap
        pair.swap(amount0Out, amount1Out, testUser, "");

        vm.stopPrank();

        uint256 postBalanceDAI = IERC20(DAI).balanceOf(testUser);
        console2.log("Swapped 1 WETH for DAI: %18e", amountOut);
        console2.log("DAI balance after swap: %18e", postBalanceDAI);
        assertEq(postBalanceDAI - preBalanceDAI, amountOut);
    }
}
