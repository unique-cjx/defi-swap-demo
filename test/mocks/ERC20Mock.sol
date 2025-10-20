// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    /// @notice Deploys the mock ERC20 token and mints initial supply to the given account
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param initialAccount The address to receive the initial supply
    /// @param initialBalance The amount of tokens to mint initially
    constructor(
        string memory name,
        string memory symbol,
        address initialAccount,
        uint256 initialBalance
    )
        payable
        ERC20(name, symbol)
    {
        _mint(initialAccount, initialBalance);
    }

    /// @notice Mints tokens to a specified account
    /// @param account The address to receive minted tokens
    /// @param amount The amount of tokens to mint
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    /// @notice Burns tokens from a specified account
    /// @param account The address whose tokens will be burned
    /// @param amount The amount of tokens to burn
    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    /// @notice Transfers tokens internally from one address to another
    /// @param from The address to send tokens from
    /// @param to The address to send tokens to
    /// @param value The amount of tokens to transfer
    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    /// @notice Approves a spender to spend tokens on behalf of an owner internally
    /// @param owner The address which owns the tokens
    /// @param spender The address which will spend the tokens
    /// @param value The amount of tokens to approve
    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }
}
