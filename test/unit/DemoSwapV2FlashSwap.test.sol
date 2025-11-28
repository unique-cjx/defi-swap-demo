// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";

import { IERC20 } from "../../src/interfaces/IERC20.sol";
import { IUniswapV2Factory } from "../../src/interfaces/uniswap-v2/IUniswapV2Factory.sol";
import { DemoSwapV2FlashSwap } from "../../src/DemoSwapV2FlashSwap.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";

contract DemoSwapV2FlashSwapTest is Test, BaseDemoSwapV2Test {
    DemoSwapV2FlashSwap public flashSwap;
    IUniswapV2Factory public factory;
    address pairAddress;

    uint256 private constant BORROW_AMOUNT = 4000e18;
    uint256 private constant SWAP_FEE_NUMERATOR = 3;
    uint256 private constant SWAP_FEE_DENOMINATOR = 997;

    function setUp() public {
        _setUp();
        factory = IUniswapV2Factory(router.factory());
        pairAddress = factory.getPair(DAI, WETH);
        flashSwap = new DemoSwapV2FlashSwap(pairAddress);
    }

    function test_flashSwapRevertsWithoutCallerData() public {
        vm.prank(testUser);
        vm.expectRevert();
        flashSwap.flashSwap(DAI, BORROW_AMOUNT);
        vm.stopPrank();
    }

    function test_flashSwapRevertsWithInvalidToken() public {
        address invalidToken = MKR; // MKR is not part of the DAI-WETH pair
        vm.prank(testUser);
        vm.expectRevert(DemoSwapV2FlashSwap.DemoSwapV2FlashSwap_InvalidToken.selector);
        flashSwap.flashSwap(invalidToken, BORROW_AMOUNT);
        vm.stopPrank();
    }

    function test_flashswapV2flashswap() public {
        uint256 fee = (BORROW_AMOUNT * SWAP_FEE_NUMERATOR) / SWAP_FEE_DENOMINATOR + 1;
        uint256 amountToRepay = BORROW_AMOUNT + fee;

        vm.startPrank(testUser);
        IERC20(DAI).approve(address(flashSwap), amountToRepay);
        flashSwap.flashSwap(DAI, BORROW_AMOUNT);
        uint256 daiBalanceAfter = _getBalance(DAI);
        vm.stopPrank();
        assertEq(daiBalanceAfter, DAIBalance - amountToRepay);
        console2.log("After flash swap, user DAI balance is: %18e", daiBalanceAfter);
    }

    function test_flashswapV2CallRepaysBorrowedAmount() public {
        uint256 borrowAmount = BORROW_AMOUNT;
        uint256 fee = (borrowAmount * SWAP_FEE_NUMERATOR) / SWAP_FEE_DENOMINATOR + 1;
        console2.log("Calculated the borrowing fee is %18e", fee);
        uint256 amountToRepay = borrowAmount + fee;

        uint256 pairBalanceBefore = IERC20(DAI).balanceOf(pairAddress);
        assertGt(pairBalanceBefore, borrowAmount);

        console2.log("1.before flash swap, pair DAI balance: %18e", pairBalanceBefore);
        deal(DAI, pairAddress, pairBalanceBefore - borrowAmount);
        deal(DAI, testUser, amountToRepay);
        console2.log("2.after deal, pair DAI balance: %18e", IERC20(DAI).balanceOf(pairAddress));
        console2.log("3.after deal, user DAI balance: %18e", _getBalance(DAI));

        vm.prank(testUser);
        IERC20(DAI).approve(address(flashSwap), amountToRepay);

        vm.prank(pairAddress);
        flashSwap.uniswapV2Call(address(flashSwap), borrowAmount, 0, abi.encode(DAI, testUser));

        uint256 pairBalanceAfter = IERC20(DAI).balanceOf(pairAddress);
        assertEq(pairBalanceAfter, pairBalanceBefore - borrowAmount + amountToRepay);

        uint256 userBalanceAfter = _getBalance(DAI);
        assertEq(userBalanceAfter, 0);
    }
}
