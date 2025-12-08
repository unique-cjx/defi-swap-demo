// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IUniswapV2Pair } from "./interfaces/uniswap-v2/IUniswapV2Pair.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

contract DemoSwapV2FlashSwap {
    error DemoSwapV2FlashSwap_InvalidToken();

    IUniswapV2Pair private immutable pair;
    address private immutable token0;
    address private immutable token1;

    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
    }

    /// @notice Initiates a Uniswap V2 flash swap for the specified token and amount.
    /// @param token The address of the token to borrow.
    /// @param amount The amount of the token to borrow.
    function flashSwap(address token, uint256 amount) external {
        if (token != token0 && token != token1) revert DemoSwapV2FlashSwap_InvalidToken();

        // Determine which token to borrow
        uint256 amount0Out = token == token0 ? amount : 0;
        uint256 amount1Out = token == token1 ? amount : 0;

        // Encode only the token address to minimize calldata size
        bytes memory data = abi.encode(token, msg.sender);

        // Call pair.swap to initiate the flash swap
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    /// @notice Uniswap V2 callback for flash swap settlement.
    /// @param sender The initiator of the swap (should be this contract).
    /// @param amount0 The amount of token0 borrowed.
    /// @param amount1 The amount of token1 borrowed.
    /// @param data Encoded data containing the borrowed token and original caller.
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        // 1. Require msg.sender is pair contract
        if (msg.sender != address(pair)) revert();

        // 2. Require sender is this contract
        if (sender != address(this)) revert();

        // 3. Decode token and caller from data
        (address token, address caller) = abi.decode(data, (address, address));

        // 4. Determine amount borrowed (only one of them is > 0)
        uint256 amount = amount0 > 0 ? amount0 : amount1;

        // 5. Calculate flash swap fee and amount to repay
        // fee = borrowed amount * 3 / 997 + 1 to round up
        uint256 fee = (amount * 3) / 997 + 1;
        uint256 amountToRepay = amount + fee;

        // 6. Get flash swap fee from caller
        IERC20(token).transferFrom(caller, address(this), amountToRepay);

        // 7. Repay Uniswap V2 pair
        IERC20(token).transfer(address(pair), amountToRepay);
    }
}
