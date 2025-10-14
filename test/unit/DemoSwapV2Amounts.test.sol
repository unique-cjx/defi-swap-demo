// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test, console2 } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IUniswapV2Router02 } from "../../src/interfaces/uniswap-v2/IUniswapV2Router02.sol";
import { SetupLiquidity } from "../../script/SetupLiquidity.sol";
import { HelperConfig } from "../../script/HelperConfig.sol";

contract DemoSwapV2AmountTest is Test {
    IUniswapV2Router02 public router;
    address public WETH;
    address public DAI;
    address public MKR;

    function setUp() public {
        SetupLiquidity setupLiquid = new SetupLiquidity();
        HelperConfig helperConfig = setupLiquid.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        router = IUniswapV2Router02(config.uniswapRouter);
        WETH = config.weth;
        DAI = config.dai;
        MKR = config.mkr;
    }

    // Liquidity you added in SetupLiquidity:
    // 1. WETH/DAI pair: reserves = 1 WETH and 4000 DAI
    // 2. MKR/DAI pair: reserves = 1 MKR and 1000 DAI
    // 3. Uniswap V2 uses the constant-product formula with a 0.3% fee per swap. For a swap of amountIn the amountOut
    // formula is: amountOut = (amountIn * reserveOut * 997) / (reserveIn * 1000 + amountIn * 997)
    //
    // So compute the hopes:
    // WETH -> DAI (reserveIn = 1 WETH, reserveOut = 4000 DAI, amountIn = 1)
    // amountOut_DAI ≈ (1 * 4000 * 997) / (1 * 1000 + 997) ≈ 1996.995493239859789684
    //
    // DAI -> MKR (reserveIn = 1000 DAI, reserveOut = 1 MKR, amountIn ≈ 1996.995)
    // amountOut_MKR ≈ (1 * 1996.995 * 997) / (1000 * 1000 + 1996.995 * 997) ≈ 0.6656641064
    //
    function test_getAmountsOut() public {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountIn = 1 ether; // representing 1 WETH
        uint256[] memory amounts = router.getAmountsOut(amountIn, path);

        console2.log("-----AMOUNT_OUT-----");
        console2.log("WETH %18e", amounts[0]);
        console2.log("DAI %18e", amounts[1]);
        console2.log("MKR %18e", amounts[2]);

        assertEq(Math.ceilDiv(amounts[0], 1 ether), 1); // WETH
        assertEq(Math.ceilDiv(amounts[1], 1 ether), 1997); // DAI
        assertEq(Math.ceilDiv(amounts[2], 1 ether), 1); // MKR
    }

    // MKR/DAI reserves: 1 MKR, 1000 DAI.
    // Uniswap amountsIn formula (simplified): amountIn ≈ (reserveIn * amountOut * 1000) / ((reserveOut - amountOut) *
    // 997)
    // For amountOut = 0.01 MKR:
    // amountIn_DAI ≈ (1000 * 0.01 * 1000) / ((1 - 0.01) * 997) ≈ 10.131404313951956881 DAI
    //
    // WETH/DAI reserves: 1 WETH, 4000 DAI.
    // To get about 10.1314 DAI:
    // amountIn_WETH ≈ (1 * 10.1314 * 1000) / ((4000 - 10.1314) * 997) ≈ 0.002546923473843468 WETH
    function test_getAmountsIn() public {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountOut = 1e16; // 1e18 will cause an error: `[Revert] ds-math-sub-underflow`
        uint256[] memory amounts = router.getAmountsIn(amountOut, path);

        console2.log("-----AMOUNT_IN-----");
        console2.log("WETH %18e", amounts[0]);
        console2.log("DAI %18e", amounts[1]);
        console2.log("MKR %18e", amounts[2]);
    }
}
