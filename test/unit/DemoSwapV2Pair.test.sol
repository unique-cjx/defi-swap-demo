// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ERC20Mock } from "../../test/mocks/ERC20Mock.sol";
import { IUniswapV2Router02 } from "../../src/interfaces/uniswap-v2/IUniswapV2Router02.sol";
import { SetupLiquidity } from "../../script/SetupLiquidity.sol";
import { HelperConfig } from "../../script/HelperConfig.sol";
import { IWETH } from "../../src/interfaces/IWETH.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";

contract DemoSwapV2PairTest is Test, BaseDemoSwapV2Test {
    function setUp() public {
        _setUp();
    }
}
