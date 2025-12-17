// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "../../src/interfaces/IERC20.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0Out, uint256 amount1Out, bytes calldata data) external;
}

/// @dev Minimal UniswapV2-like pair for tests (constant product + 0.3% fee + flash swap callback).
contract MockUniswapV2Pair {
    error MockUniswapV2Pair_InsufficientOutput();
    error MockUniswapV2Pair_InvalidTo();
    error MockUniswapV2Pair_NoInput();
    error MockUniswapV2Pair_KInvariant();
    error MockUniswapV2Pair_ReserveOverflow();

    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }

    /// @notice Seed initial liquidity (single-shot for this unit test).
    function seed(uint256 amount0, uint256 amount1) external {
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        if (amount0Out == 0 && amount1Out == 0) revert MockUniswapV2Pair_InsufficientOutput();
        if (to == token0 || to == token1) revert MockUniswapV2Pair_InvalidTo();

        uint112 _r0 = reserve0;
        uint112 _r1 = reserve1;

        if (amount0Out > _r0 || amount1Out > _r1) revert MockUniswapV2Pair_InsufficientOutput();

        if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);

        if (data.length > 0) {
            IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        }

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0In = balance0 > (uint256(_r0) - amount0Out) ? balance0 - (uint256(_r0) - amount0Out) : 0;
        uint256 amount1In = balance1 > (uint256(_r1) - amount1Out) ? balance1 - (uint256(_r1) - amount1Out) : 0;
        if (amount0In == 0 && amount1In == 0) revert MockUniswapV2Pair_NoInput();

        // UniswapV2 invariant with 0.3% fee
        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        if (balance0Adjusted * balance1Adjusted < uint256(_r0) * uint256(_r1) * 1_000_000) {
            revert MockUniswapV2Pair_KInvariant();
        }

        _update(balance0, balance1);
    }

    function _update(uint256 balance0, uint256 balance1) internal {
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert MockUniswapV2Pair_ReserveOverflow();
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }
}
