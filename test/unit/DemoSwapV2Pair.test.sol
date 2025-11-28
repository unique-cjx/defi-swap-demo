// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";

contract DemoSwapV2PairTest is Test, BaseDemoSwapV2Test {
    function setUp() public {
        _setUp();
    }
}
