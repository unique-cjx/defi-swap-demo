// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { IUniswapV2Factory } from "../../src/interfaces/uniswap-v2/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import { IERC20 } from "../../src/interfaces/IERC20.sol";
import { DemoSwapV2TWap } from "../../src/DemoSwapV2TWap.sol";
import { BaseDemoSwapV2Test } from "./BaseDemoSwapV2Test.sol";

contract DemoSwapV2TWapTest is Test, BaseDemoSwapV2Test {
    uint256 private constant MIN_WAIT_SEC = 300;

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
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        require(reserve0 > 0 && reserve1 > 0, "No reserves");

        if (pair.token0() == WETH) {
            return (uint256(reserve1) * 1e18) / uint256(reserve0); // DAI per WETH
        } else {
            return (uint256(reserve0) * 1e18) / uint256(reserve1); // DAI per WETH
        }
    }

    function test_tWapSamePrice() public {
        skip(MIN_WAIT_SEC + 1); // Wait for minimum TWAP update interval
        twap.update();

        uint256 twap0 = twap.consult(WETH, 1e18);
        console2.log("Initial TWAP price of 1 WETH in DAI: %18e", twap0);

        skip(MIN_WAIT_SEC + 1);
        twap.update();
        uint256 twap1 = twap.consult(WETH, 1e18);
        console2.log("Second TWAP price of 1 WETH in DAI: %18e", twap1);

        assertApproxEqAbs(twap0, twap1, 1, "WETH TWAP");
    }

    function test_tWapPriceChange() public {
        skip(MIN_WAIT_SEC + 1);
        twap.update();

        uint256 twap0 = getSpot();
        console2.log("Initial spot price of 1 WETH in DAI: %18e", twap0);

        // 1. Manipulate price: Swap WETH for DAI
        // This increases WETH reserves and decreases DAI reserves, lowering WETH price
        uint256 amountIn = 10 ether;
        deal(WETH, address(this), amountIn);
        IERC20(WETH).approve(address(router), amountIn);
        console2.log("WETH balance before swap: %18e", IERC20(WETH).balanceOf(address(this)));

        // Initial State
        // WETH reserve: 100 ETH
        // DAI reserve: 400,000 DAI
        // Price: 1 WETH = 4,000 DAI
        //
        // 1. Deduct 0.3% Fee
        // 10 * 0.997 = 9.97 WETH
        //
        // 2. Calculate DAI Output Amount
        // DAI_OUT = (DAI_RESERVE * WETH_IN) / (WETH_RESERVE + WETH_IN)
        // DAI_OUT = (400,000 * 9.97) / (100 + 9.97) = 36,036.26 DAI
        //
        // 3. Update Reserves After Swap
        // New WETH Reserve = 100 + 10 = 110 WETH
        // New DAI Reserve = 400,000 - 36,036.26 = 363,963.74 DAI
        // Final Resulting Price:
        // New Price = 363,963.74 / 110 = 3,308.76 DAI per WETH
        //
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;
        router.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);

        // 2. Wait and update
        skip(MIN_WAIT_SEC + 1);
        twap.update();

        uint256 twap1 = getSpot();
        console2.log("Spot price of 1 WETH in DAI after swap: %18e", twap1);

        // 3. Verify TWAP changed
        // Since we sold WETH, the price of WETH in DAI should go down
        assertFalse(twap0 == twap1, "TWAP should change after swap");
        assertLt(twap1, twap0, "WETH TWAP should decrease after selling WETH");
    }
}
