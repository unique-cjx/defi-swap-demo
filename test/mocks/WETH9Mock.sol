// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @notice Minimal WETH9-like mock for local testing
contract WETH9Mock is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") { }

    /// @notice Deposit ETH and receive WETH
    receive() external payable {
        deposit();
    }

    /// @notice Deposit ETH and mint WETH to sender
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    /// @notice Burn WETH and send ETH back to sender
    /// @param wad amount in wei to withdraw
    function withdraw(uint256 wad) external {
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
}
