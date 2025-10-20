// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { IWETH } from "../src/interfaces/IWETH.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import { ERC20Mock } from "../test/mocks/ERC20Mock.sol";
import { HelperConfig } from "./HelperConfig.sol";
import { IUniswapV2Router02 } from "../src/interfaces/uniswap-v2/IUniswapV2Router02.sol";

contract SetupLiquidity is Script {
    function run() external returns (HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        IUniswapV2Router02 router = IUniswapV2Router02(config.uniswapRouter);
        if (config.uniswapRouter.code.length == 0 || config.uniswapFactory.code.length == 0) {
            revert("Uniswap not deployed");
        }

        // Skip on Sepolia, as we don't have the tokens there
        if (block.chainid != 31_337) {
            // TODO: Implement token deployment on Sepolia
            revert("Token deployment not implemented for Sepolia");
        }

        address account0 = vm.addr(helperConfig.DEPLOYER_KEY()); // Account0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

        vm.startPrank(account0);
        IWETH weth = IWETH(payable(config.weth));
        weth.deposit{ value: helperConfig.DEPOSITE_WETH_AMOUNT() }();
        console.log("Uniswap WETH balance: %18e", IERC20(config.weth).balanceOf(account0));

        // Approve all tokens for the router
        IERC20(config.weth).approve(config.uniswapRouter, type(uint256).max);
        IERC20(config.wbtc).approve(config.uniswapRouter, type(uint256).max);
        IERC20(config.dai).approve(config.uniswapRouter, type(uint256).max);
        IERC20(config.mkr).approve(config.uniswapRouter, type(uint256).max);

        // Add liquidity for WETH/DAI pair (1 ETH ≈ 4K DAI based on prices)
        ERC20Mock(config.dai).mint(account0, helperConfig.DEPOSITE_DAI_AMOUNT());
        console.log("Uniswap DAI balance: %18e", IERC20(config.dai).balanceOf(account0));
        router.addLiquidity(config.weth, config.dai, 1 ether, 4000 ether, 0, 0, account0, block.timestamp);

        // Add liquidity for WBTC/WETH pair (1 WBTC ≈ 25 ETH based on prices: 100k USD / 4k USD)
        ERC20Mock(config.wbtc).mint(account0, helperConfig.DEPOSITE_WBTC_AMOUNT());
        console.log("Uniswap WBTC balance: %18e", IERC20(config.wbtc).balanceOf(account0));
        router.addLiquidity(
            config.wbtc,
            config.weth,
            1 ether, // 1 WBTC (assuming 18 decimals for simplicity)
            25 ether, // 25 WETH
            0,
            0,
            account0,
            block.timestamp
        );

        // Add liquidity for MKR/DAI pair (1 MKR ≈ 1000 DAI based on prices)
        ERC20Mock(config.mkr).mint(account0, helperConfig.DEPOSITE_MKR_AMOUNT());
        console.log("MKR balance: %18e", IERC20(config.mkr).balanceOf(account0));
        router.addLiquidity(
            config.mkr,
            config.dai,
            1 ether, // 1 MKR
            1000 ether, // 1000 DAI
            0,
            0,
            account0,
            block.timestamp
        );

        vm.stopPrank();

        return helperConfig;
    }
}
