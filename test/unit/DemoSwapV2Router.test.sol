// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

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

    // Liquidity you added in SetupLiquidity:
    // 1. WETH/DAI pair: reserves = 1 WETH and 4000 DAI
    // 2. MKR/DAI pair: reserves = 1 MKR and 1000 DAI
    // 3. Uniswap V2 uses the constant-product formula with a 0.3% fee per swap. For a swap of amountIn the amountOut
    // formula is: amountOut = (amountIn * reserveOut * 997) / (reserveIn * 1000 + amountIn * 997)
    //
    // So compute the hopes:
    // WETH -> DAI (reserveIn = 1 WETH, reserveOut = 4000 DAI, amountIn = 1)
    // amountOut_DAI ≈ (1 * 4000 * 997) / (1 * 1000 + 997) ≈ 1996.995493239859789684
    //
    // DAI -> MKR (reserveIn = 1000 DAI, reserveOut = 1 MKR, amountIn ≈ 1996.995)
    // amountOut_MKR ≈ (1 * 1996.995 * 997) / (1000 * 1000 + 1996.995 * 997) ≈ 0.6656641064
    //
    function test_getAmountsOut() public view {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountIn = 1 ether; // representing 1 WETH
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);

        console2.log("-----AMOUNT_OUT-----");
        console2.log("WETH %18e", amounts[0]);
        console2.log("DAI %18e", amounts[1]);
        console2.log("MKR %18e", amounts[2]);
    }

    // MKR/DAI reserves: 1 MKR, 1000 DAI.
    // Uniswap amountsIn formula (simplified): amountIn ≈ (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) *
    // 997)
    // For amountOut = 0.01 MKR:
    // amountIn_DAI ≈ (1000 * 0.01 * 1000) / ((1 - 0.01) * 997) ≈ 10.131404313951956881 DAI
    //
    // WETH/DAI reserves: 1 WETH, 4000 DAI.
    // To get about 10.1314 DAI:
    // amountIn_WETH ≈ (1 * 10.1314 * 1000) / ((4000 - 10.1314) * 997) ≈ 0.002546923473843468 WETH
    function test_getAmountsIn() public view {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountOut = 1e18;
        uint256[] memory amounts = router.getAmountsIn(amountOut, path);

        console2.log("-----AMOUNT_IN-----");
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
}
