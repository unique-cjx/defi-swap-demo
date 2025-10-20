// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IUniswapV2Router02 } from "../../src/interfaces/uniswap-v2/IUniswapV2Router02.sol";
import { SetupLiquidity } from "../../script/SetupLiquidity.sol";
import { HelperConfig } from "../../script/HelperConfig.sol";
import { IWETH } from "../../src/interfaces/IWETH.sol";

contract DemoSwapV2Test is Test {
    IUniswapV2Router02 public router;
    address public WETH;
    address public DAI;
    address public MKR;

    address public testUser = makeAddr("user");

    function setUp() public {
        SetupLiquidity setupLiquid = new SetupLiquidity();
        HelperConfig helperConfig = setupLiquid.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        router = IUniswapV2Router02(config.uniswapRouter);
        WETH = config.weth;
        MKR = config.mkr;
        DAI = config.dai;

        IWETH Iweth = IWETH(payable(config.weth));
        deal(testUser, 10 ether); // ensure testUser has enough ETH
        vm.startPrank(testUser);
        Iweth.deposit{ value: 10 ether }();
        Iweth.approve(address(router), type(uint256).max);
        console2.log("testUser WETH balance is: %18e", Iweth.balanceOf(testUser));
        vm.stopPrank();
    }

    function test_SwapExactETHForTokens() public {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountIn = 1e18;
        uint256 amountOutMin = 1;

        vm.prank(testUser);
        // amountIn: This is the amount of tokens the user will be sending in
        // amountOutMin: This is the minimum amount of output tokens the user expects
        // path: This is an array of addresses which define the token path for the swap
        uint256[] memory amounts =
            router.swapExactTokensForTokens(amountIn, amountOutMin, path, testUser, block.timestamp);
        console2.log("WETH: %18e", amounts[0]);
        console2.log("DAI: %18e", amounts[1]);
        console2.log("MKR: %18e", amounts[2]);

        uint256 MKRBalance = IERC20(MKR).balanceOf(testUser);
        assertGe(MKRBalance, amountOutMin, "MKR balance of user");
    }

    function test_SwapTokensForExactTokens() public {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountOut = 0.5 * 1e18;
        uint256 amountInMax = 1e18; // What is the maximum WETH the user is willing to spend buy the amount of MKR

        vm.prank(testUser);
        // The MKR/DAI pool starts at 1 MKR costing 2000 DAI.
        // Buying 0.5 MKR therefore requires about 1000 DAI.
        // The WETH/DAI pool price is 1 WETH for 4000 DAI.
        // After the trade, the pool holds 4000 DAI + 1000 DAI in liquidity,
        // So the new price is 1 WETH for 5000 DAI,
        // meaning the user needs to spend about 0.25 WETH to get 1000 DAI.
        // As a result, the user spends roughly 0.25 WETH to receive 0.5 MKR
        uint256[] memory amounts =
            router.swapTokensForExactTokens(amountOut, amountInMax, path, testUser, block.timestamp);
        console2.log("WETH: %18e", amounts[0]);
        console2.log("DAI: %18e", amounts[1]);
        console2.log("MKR: %18e", amounts[2]);

        uint256 MKRBalance = IERC20(MKR).balanceOf(testUser);
        assertEq(MKRBalance, amountOut, "MKR balance of user");
    }
}
