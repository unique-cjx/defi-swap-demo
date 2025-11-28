// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";

import { IUniswapV2Factory } from "../../src/interfaces/uniswap-v2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import { IERC20 } from "../../src/interfaces/IERC20.sol";
import { DemoSwapV2TWap } from "../../src/DemoSwapV2TWap.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";

contract DemoSwapV2TWapTest is Test, BaseDemoSwapV2Test {
    uint256 private constant MIN_WAIT = 300;

    IUniswapV2Factory public factory;
    DemoSwapV2TWap private twap;

    address pairAddress;

    function setUp() public {
        _setUp();
        factory = IUniswapV2Factory(router.factory());
        pairAddress = factory.getPair(DAI, WETH);
        twap = new DemoSwapV2TWap(pairAddress);
    }

    function getSpot() internal view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pairAddress).getReserves();
        // DAI / WETH
        return uint256(reserve0) * 1e18 / uint256(reserve1);
    }

    // 
    function test_tWapSamePrice() public {
        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap0 = twap.consult(WETH, 1e18);

        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap1 = twap.consult(WETH, 1e18);

        assertApproxEqAbs(twap0, twap1, 1, "ETH TWAP");
    }

    function test_tWapPriceChange() public {
        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap0 = twap.consult(WETH, 1e18);

        // 1. Manipulate price: Swap WETH for DAI
        // This increases WETH reserves and decreases DAI reserves, lowering WETH price
        uint256 amountIn = 1000 ether;
        deal(WETH, address(this), amountIn);
        IERC20(WETH).approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;

        router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        // 2. Wait and update
        skip(MIN_WAIT + 1);
        twap.update();

        uint256 twap1 = twap.consult(WETH, 1e18);

        // 3. Verify TWAP changed
        // Since we sold WETH, the price of WETH in DAI should go down
        assertFalse(twap0 == twap1, "TWAP should change after swap");
        assertLt(twap1, twap0, "WETH TWAP should decrease after selling WETH");
    }
}
