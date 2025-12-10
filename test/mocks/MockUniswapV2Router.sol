// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "../../src/interfaces/IERC20.sol";

/// @notice A simple mock router to simulate different prices
contract MockUniswapV2Router {
    error MockUniswapV2Router_InvalidPath();
    error MockUniswapV2Router_InvalidRate();
    error MockUniswapV2Router_InsufficientOutputAmount();

    // Exchange rates: tokenIn -> tokenOut -> rate (1e18 scale)
    mapping(address => mapping(address => uint256)) public rates;

    function setRate(address tokenIn, address tokenOut, uint256 rate) external {
        rates[tokenIn][tokenOut] = rate;
    }

    /// @dev Mimics UniswapV2Router02.swapExactTokensForTokens
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 /* deadline */
    )
        external
        returns (uint256[] memory amounts)
    {
        if (path.length < 2) {
            revert MockUniswapV2Router_InvalidPath();
        }
        address tokenIn = path[0];
        address tokenOut = path[path.length - 1];

        // 1. Transfer input tokens from sender to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // 2. Calculate output amount based on configured rate
        uint256 rate = rates[tokenIn][tokenOut];
        if (rate == 0) {
            revert MockUniswapV2Router_InvalidRate();
        }

        // rate is scaled by 1e18 (e.g., 1 WETH = 3900 DAI -> rate = 3900e18)
        uint256 amountOut = (amountIn * rate) / 1e18;
        if (amountOut < amountOutMin) {
            revert MockUniswapV2Router_InsufficientOutputAmount();
        }

        // 3. Transfer output tokens to recipient
        IERC20(tokenOut).transfer(to, amountOut);

        // 4. Return amounts array
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        amounts[path.length - 1] = amountOut;
    }
}
