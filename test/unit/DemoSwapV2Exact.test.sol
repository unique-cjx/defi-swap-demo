// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ERC20Mock } from "../../test/mocks/ERC20Mock.sol";
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

    uint256 public WETHBalance;
    uint256 public DAIBalance;
    uint256 public MKRBalance;

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
        ERC20Mock(DAI).mint(testUser, 10_000 ether);
        ERC20Mock(MKR).mint(testUser, 100 ether);

        vm.startPrank(testUser);
        Iweth.deposit{ value: 10 ether }();
        Iweth.approve(address(router), type(uint256).max);
        IERC20(DAI).approve(address(router), type(uint256).max);
        IERC20(MKR).approve(address(router), type(uint256).max);

        WETHBalance = Iweth.balanceOf(testUser);
        DAIBalance = IERC20(DAI).balanceOf(testUser);
        MKRBalance = IERC20(MKR).balanceOf(testUser);
        console2.log("testUser WETH balance is: %18e", WETHBalance);
        console2.log("testUser DAI balance is: %18e", DAIBalance);
        console2.log("testUser MKR balance is: %18e", MKRBalance);
        vm.stopPrank();
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

        uint256 swappedWETHBalance = IERC20(WETH).balanceOf(testUser);
        console2.log("swapped WETH balance: %18e", swappedWETHBalance);
        assertGe(swappedWETHBalance, WETHBalance + WETHAmountOutMin);
    }

    function test_SwapTokensForExactETH() public {
        address[] memory path = new address[](3);
        path[0] = MKR;
        path[1] = DAI;
        path[2] = WETH;

        uint256 WETHAmountOut = 1e17; // 0.1 WETH
        uint256 MKRAmountInMax = 1e18; // What is the maximum MKR the user is willing to spend buy 0.1 WETH

        vm.prank(testUser);
        // Calculation explanation (English):
        // 1) Uniswap router computes required input amounts backwards through the path.
        //    It uses getAmountIn which implements the constant-product formula with a 0.3% fee:
        //      amountIn = (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) * 997) + 1
        //
        // 2) For the last hop (WETH <- DAI):
        //    - reserveIn = DAI reserve, reserveOut = WETH reserve.
        //    - Given desired WETH output (amountOut = 0.1 WETH), the router computes how much DAI is required
        //      from the WETH/DAI pool using the formula above.
        //    - This yields DAI ≈ 445.781789813886102753 (logged as amounts[1]).
        //
        // 3) For the previous hop (DAI <- MKR):
        //    - reserveIn = MKR reserve, reserveOut = DAI reserve.
        //    - To obtain the DAI amount computed in step 2, the router computes how much MKR is required
        //      from the MKR/DAI pool using the same getAmountIn formula.
        //    - This yields MKR ≈ 0.806763745892816193 (logged as amounts[0]).
        //
        // 4) Summary:
        //    - amounts[0] = MKR input required (≈ 0.8067637459)
        //    - amounts[1] = DAI intermediate required (≈ 445.7817898139)
        //    - amounts[2] = WETH output (requested 0.1)
        //
        // These values come directly from Uniswap's getAmountIn math (constant product + 0.3% fee).
        uint256[] memory amounts =
            router.swapTokensForExactETH(WETHAmountOut, MKRAmountInMax, path, testUser, block.timestamp);
        console2.log("MKR: %18e", amounts[0]);
        console2.log("DAI: %18e", amounts[1]);
        console2.log("WETH: %18e", amounts[2]);

        uint256 swappedWETHBalance = IERC20(WETH).balanceOf(testUser);
        console2.log("user WETH balance: %18e", swappedWETHBalance);

        assertEq(WETHAmountOut, amounts[2]);
    }

    function test_SwapTokensForExactTokens() public {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 MKRAmountOut = 1e18;
        uint256 WETHAmountInMax = 0.5e18; // What is the maximum WETH the user is willing to spend buy the amount of MKR

        vm.prank(testUser);

        // The MKR/DAI pool starts at 1 MKR costing 2000 DAI.
        // Buying 0.5 MKR therefore requires about 1000 DAI.
        // The WETH/DAI pool price is 1 WETH for 4000 DAI.
        // After the trade, the pool holds 4000 DAI + 1000 DAI in liquidity,
        // So the new price is 1 WETH for 5000 DAI,
        // meaning the user needs to spend about 0.25 WETH to get 1000 DAI.
        // As a result, the user spends roughly 0.25 WETH to receive 0.5 MKR
        uint256[] memory amounts =
            router.swapTokensForExactTokens(MKRAmountOut, WETHAmountInMax, path, testUser, block.timestamp);
        console2.log("WETH: %18e", amounts[0]);
        console2.log("DAI: %18e", amounts[1]);
        console2.log("MKR: %18e", amounts[2]);

        uint256 swappedMKRBalance = IERC20(MKR).balanceOf(testUser);
        console2.log("swapped MKR balance: %18e", swappedMKRBalance);
        assertEq(swappedMKRBalance, MKRAmountOut + MKRBalance);
    }
}
