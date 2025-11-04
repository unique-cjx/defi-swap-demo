// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "../../src/interfaces/uniswap-v2/IUniswapV2Router02.sol";
import { SetupLiquidity } from "../../script/SetupLiquidity.sol";
import { HelperConfig } from "../../script/HelperConfig.sol";
import { IWETH } from "../../src/interfaces/IWETH.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

/// @notice Base contract for Uniswap V2 swap tests
/// @dev Provides common setup and utility functions to reduce code duplication
abstract contract BaseDemoSwapV2Test is Test {
    /// Uniswap V2
    IUniswapV2Router02 public router;

    /// Test Tokens
    address public WETH;
    address public DAI;
    address public MKR;

    /// Token Balances
    address public testUser = makeAddr("user");

    uint256 public WETHBalance;
    uint256 public DAIBalance;
    uint256 public MKRBalance;

    /// @notice Sets up router, tokens, balances, and approvals for the test user
    function _setUp() public {
        SetupLiquidity setupLiquid = new SetupLiquidity();
        HelperConfig helperConfig = setupLiquid.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        router = IUniswapV2Router02(config.uniswapRouter);

        WETH = config.weth;
        MKR = config.mkr;
        DAI = config.dai;

        IWETH iweth = IWETH(payable(WETH));

        // Mint and deposit tokens to test user
        deal(testUser, 10 ether);
        ERC20Mock(DAI).mint(testUser, 10_000 ether);
        ERC20Mock(MKR).mint(testUser, 100 ether);

        vm.startPrank(testUser);
        // approve router to spend tokens
        iweth.deposit{ value: 10 ether }();
        iweth.approve(address(router), type(uint256).max);
        IERC20(DAI).approve(address(router), type(uint256).max);
        IERC20(MKR).approve(address(router), type(uint256).max);

        // list initial balances
        WETHBalance = iweth.balanceOf(testUser);
        DAIBalance = IERC20(DAI).balanceOf(testUser);
        MKRBalance = IERC20(MKR).balanceOf(testUser);
        console2.log("testUser WETH balance is: %18e", WETHBalance);
        console2.log("testUser DAI balance is: %18e", DAIBalance);
        console2.log("testUser MKR balance is: %18e", MKRBalance);
        vm.stopPrank();
    }

    function _listTokens() internal view returns (address[] memory path) {
        path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;
    }

    function _getBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(testUser);
    }
}
