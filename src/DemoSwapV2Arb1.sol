// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "./interfaces/IERC20.sol";
import { IUniswapV2Pair } from "./interfaces/uniswap-v2/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "./interfaces/uniswap-v2/IUniswapV2Router02.sol";

contract DemoSwapV2Arb1 {
    struct SwapParams {
        // Router to execute first swap - tokenIn for tokenOut
        address router0;
        // Router to execute second swap - tokenOut for tokenIn
        address router1;
        // Token in of first swap
        address tokenIn;
        // Token out of first swap
        address tokenOut;
        // Amount in for the first swap
        uint256 amountIn;
        // Revert the arbitrage if profit is less than this minimum
        uint256 minProfit;
    }

    // Exercise 1
    // - Execute an arbitrage between router0 and router1
    // - Pull tokenIn from msg.sender
    // - Send amountIn + profit back to msg.sender
    function swap(SwapParams calldata params) external {
        // Responsible for:
        // 1. Pulling the tokens in from the message sender.
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);

        // 2. Executing the first swap on router0.
        IERC20(params.tokenIn).approve(params.router0, params.amountIn);
        
        address[] memory path = new address[](2);
        path[0] = params.tokenIn;
        path[1] = params.tokenOut;

        uint256[] memory amounts = IUniswapV2Router02(params.router0).swapExactTokensForTokens(
            params.amountIn,
            0, 
            path,
            address(this),
            block.timestamp
        );

        // 3. Executing the second swap on router1.
        uint256 amountOut = amounts[1];
        IERC20(params.tokenOut).approve(params.router1, amountOut);

        path[0] = params.tokenOut;
        path[1] = params.tokenIn;

        amounts = IUniswapV2Router02(params.router1).swapExactTokensForTokens(
            amountOut,
            0, 
            path,
            address(this),
            block.timestamp
        );

        // 4. Sending the remaining tokens (including profit) back to the message sender.
        uint256 amountBack = amounts[1];
        require(amountBack >= params.amountIn + params.minProfit, "Insufficient profit");
        
        IERC20(params.tokenIn).transfer(msg.sender, amountBack);
    }

    // Exercise 2
    // - Execute an arbitrage between router0 and router1 using flash swap
    // - Borrow tokenIn with flash swap from pair
    // - Send profit back to msg.sender
    /**
     * @param pair Address of pair contract to flash swap and borrow tokenIn
     * @param isToken0 True if token to borrow is token0 of pair
     * @param params Swap parameters
     */
    function flashSwap(address pair, bool isToken0, SwapParams calldata params) external {
        // Responsible for:
        // 1. Borrow the tokens needed for the arbitrage from the specified pair contract.
        uint256 amount0Out = isToken0 ? params.amountIn : 0;
        uint256 amount1Out = isToken0 ? 0 : params.amountIn;

        // 2. Call a function called UniswapV2Call to execute the arbitrage.
        // Encode caller and params to pass to callback
        bytes memory data = abi.encode(msg.sender, params);

        // 3. Repay the tokens borrowed from the pair contract. (Handled in callback)
        // 4. Send the remaining tokens to the message sender of the flashSwap function. (Handled in callback)
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    function uniswapV2Call(address sender, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external {
        // Ensure sender is this contract (initiator of the swap on the pair)
        require(sender == address(this), "Sender must be this contract");

        (address caller, SwapParams memory params) = abi.decode(data, (address, SwapParams));

        // 1. Execute arbitrage logic
        // Swap 1: tokenIn -> tokenOut on router0
        IERC20(params.tokenIn).approve(params.router0, params.amountIn);
        
        address[] memory path = new address[](2);
        path[0] = params.tokenIn;
        path[1] = params.tokenOut;

        uint256[] memory amounts = IUniswapV2Router02(params.router0).swapExactTokensForTokens(
            params.amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        // Swap 2: tokenOut -> tokenIn on router1
        uint256 amountOut = amounts[1];
        IERC20(params.tokenOut).approve(params.router1, amountOut);

        path[0] = params.tokenOut;
        path[1] = params.tokenIn;

        amounts = IUniswapV2Router02(params.router1).swapExactTokensForTokens(
            amountOut,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountBack = amounts[1];

        // 2. Calculate repayment
        uint256 amountBorrowed = amount0Out > 0 ? amount0Out : amount1Out;
        // Fee is 0.3% => amount * 3 / 997 + 1
        uint256 fee = (amountBorrowed * 3) / 997 + 1;
        uint256 amountToRepay = amountBorrowed + fee;

        require(amountBack >= amountToRepay, "Insufficient funds to repay");

        // 3. Repay pair
        IERC20(params.tokenIn).transfer(msg.sender, amountToRepay);

        // 4. Send profit to caller
        uint256 profit = amountBack - amountToRepay;
        require(profit >= params.minProfit, "Insufficient profit");

        if (profit > 0) {
            IERC20(params.tokenIn).transfer(caller, profit);
        }
    }
}
