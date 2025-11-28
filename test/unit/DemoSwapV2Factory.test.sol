// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IUniswapV2Factory } from "../../src/interfaces/uniswap-v2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import { SetupLiquidity } from "../../script/SetupLiquidity.sol";
import { HelperConfig } from "../../script/HelperConfig.sol";
import { ERC20Mock } from "../../test/mocks/ERC20Mock.sol";

contract DemoSwapV2FactoryTest is Test {
    IUniswapV2Factory public factory;
    address public WETH;

    function setUp() public {
        SetupLiquidity setupLiquid = new SetupLiquidity();
        HelperConfig helperConfig = setupLiquid.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        factory = IUniswapV2Factory(config.uniswapFactory);
        WETH = config.weth;
    }

    function test_CreatePair() public {
        ERC20Mock ROSE = new ERC20Mock("Rose Token", "ROSE", msg.sender, 1 ether);
        address pair = factory.createPair(WETH, address(ROSE));
        console2.log("Pair created: %s", pair);

        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        console2.log("Token0 is WETH: %s", token0);
        console2.log("Token1 is ROSE: %s", token1);

        if (address(ROSE) < WETH) {
            assertEq(token0, address(ROSE), "ROSE");
            assertEq(token1, WETH, "WETH");
        } else {
            assertEq(token0, WETH, "WETH");
            assertEq(token1, address(ROSE), "ROSE");
        }
    }
}
