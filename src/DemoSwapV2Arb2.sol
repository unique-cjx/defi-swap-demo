// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { console2 } from "forge-std/Test.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { IUniswapV2Pair } from "./interfaces/uniswap-v2/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "./interfaces/uniswap-v2/IUniswapV2Router02.sol";

contract DemoSwapV2Arb2 {
    error DemoSwapV2Arb2_InsufficientProfit();
    error DemoSwapV2Arb2_InvalidSender();
    error DemoSwapV2Arb2_RepayFailed();
    error DemoSwapV2Arb2_InvalidCaller();
    error DemoSwapV2Arb2_InvalidBorrowedAmount(uint256 expected, uint256 actual);

    struct FlashSwapData {
        // Caller of flashSwap (msg.sender inside flashSwap)
        address caller;
        // Pair to flash swap from
        address pair0;
        // Pair to swap from
        address pair1;
        // True if flash swap is token0 in and token1 out
        bool isZeroForOne;
        // Amount in to repay flash swap
        uint256 amountIn;
        // Amount to borrow from flash swap
        uint256 amountOut;
        // Revert if profit is less than this minimum
        uint256 minProfit;
    }

    /// @notice Flash swap from `pair0`, then swap on `pair1` to repay and keep profit.
    /// @param pair0 Pair contract to flash swap from.
    /// @param pair1 Pair contract to swap on (must contain the borrowed/repay tokens).
    /// @param isZeroForOne True to repay token0 and borrow token1 from `pair0`.
    /// @param amountIn Amount of repay token to return to `pair0`.
    /// @param minProfit Minimum required profit (in repay token).
    function flashSwap(address pair0, address pair1, bool isZeroForOne, uint256 amountIn, uint256 minProfit) external {
        IUniswapV2Pair p0 = IUniswapV2Pair(pair0);
        (uint112 reserve0, uint112 reserve1,) = p0.getReserves();

        uint256 amountOut;
        if (isZeroForOne) {
            // repay token0, borrow token1
            amountOut = getAmountOut(amountIn, uint256(reserve0), uint256(reserve1));
        } else {
            // repay token1, borrow token0
            amountOut = getAmountOut(amountIn, uint256(reserve1), uint256(reserve0));
        }

        FlashSwapData memory fsData = FlashSwapData({
            caller: msg.sender,
            pair0: pair0,
            pair1: pair1,
            isZeroForOne: isZeroForOne,
            amountIn: amountIn,
            amountOut: amountOut,
            minProfit: minProfit
        });

        bytes memory data = abi.encode(fsData);

        uint256 amount0Out = isZeroForOne ? 0 : amountOut;
        uint256 amount1Out = isZeroForOne ? amountOut : 0;

        p0.swap(amount0Out, amount1Out, address(this), data);
    }

    /// @notice UniswapV2 flash swap callback.
    /// @param sender Must be this contract.
    /// @param amount0Out Amount of token0 that was borrowed.
    /// @param amount1Out Amount of token1 that was borrowed.
    /// @param data ABI-encoded FlashSwapData.
    function uniswapV2Call(address sender, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external {
        FlashSwapData memory fsData = abi.decode(data, (FlashSwapData));

        if (msg.sender != fsData.pair0) revert DemoSwapV2Arb2_InvalidCaller();
        if (sender != address(this)) revert DemoSwapV2Arb2_InvalidSender();

        IUniswapV2Pair p0 = IUniswapV2Pair(fsData.pair0);

        address tokenBorrowed = fsData.isZeroForOne ? p0.token1() : p0.token0();
        address tokenRepay = fsData.isZeroForOne ? p0.token0() : p0.token1();

        uint256 borrowed = fsData.isZeroForOne ? amount1Out : amount0Out;
        if (borrowed != fsData.amountOut) revert DemoSwapV2Arb2_InvalidBorrowedAmount(fsData.amountOut, borrowed);

        // Swap borrowed token on pair1 to get repay token
        IUniswapV2Pair p1 = IUniswapV2Pair(fsData.pair1);
        address p1Token0 = p1.token0();
        address p1Token1 = p1.token1();
        (uint112 p1Reserve0, uint112 p1Reserve1,) = p1.getReserves();

        uint256 repayOut;
        if (tokenBorrowed == p1Token0 && tokenRepay == p1Token1) {
            // token0 in -> token1 out
            repayOut = getAmountOut(borrowed, uint256(p1Reserve0), uint256(p1Reserve1));
            IERC20(p1Token0).transfer(fsData.pair1, borrowed);
            p1.swap(0, repayOut, address(this), new bytes(0));
        } else if (tokenBorrowed == p1Token1 && tokenRepay == p1Token0) {
            // token1 in -> token0 out
            repayOut = getAmountOut(borrowed, uint256(p1Reserve1), uint256(p1Reserve0));

            IERC20(p1Token1).transfer(fsData.pair1, borrowed);
            p1.swap(repayOut, 0, address(this), new bytes(0));
        } else {
            revert DemoSwapV2Arb2_RepayFailed();
        }

        // Check profit and repay
        uint256 minOut = fsData.amountIn + fsData.minProfit;
        console2.log("-------------- FLASH SWAP PROGRESS --------------");
        console2.log("1. swap borrowed %18e WETH from pair0 through %18e DAI", fsData.amountOut, fsData.amountIn);
        console2.log("2. swap borrowed %18e DAI from pair1 through %18e WETH", repayOut, borrowed);
        console2.log("3. finally profit: %18e DAI", repayOut - fsData.amountIn);
        console2.log("-------------------- END --------------------");

        if (repayOut < minOut) revert DemoSwapV2Arb2_InsufficientProfit();
        IERC20(tokenRepay).transfer(fsData.pair0, fsData.amountIn);
        IERC20(tokenRepay).transfer(fsData.caller, repayOut - fsData.amountIn);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
