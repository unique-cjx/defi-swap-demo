// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";

import { IERC20 } from "../src/interfaces/IERC20.sol";
import { IWETH } from "../src/interfaces/IWETH.sol";
import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.sol";
import { ERC20Mock } from "../test/mocks/ERC20Mock.sol";
import { WETH9Mock } from "../test/mocks/WETH9Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;

    int256 public constant ETH_USD_PRICE = 4000e8;
    int256 public constant BTC_USD_PRICE = 100_000e8;
    int256 public constant DAI_USD_PRICE = 1e8;
    int256 public constant MKR_USD_PRICE = 1000e8;

    struct NetworkConfig {
        address weth;
        address wethUsdPriceFeed;
        address wbtc;
        address wbtcUsdPriceFeed;
        address dai;
        address daiUsdPriceFeed;
        address mkr;
        address mkrUsdPriceFeed;
        address uniswapFactory;
        address uniswapRouter;
    }

    uint256 public constant DEPOSITE_WBTC_AMOUNT = 10 ether;
    uint256 public constant DEPOSITE_WETH_AMOUNT = 1000 ether;

    uint256 public constant DEPOSITE_MKR_AMOUNT = 100 ether;
    uint256 public constant DEPOSITE_DAI_AMOUNT = 100_000_000 ether;

    uint256 public immutable DEPLOYER_KEY;

    constructor() {
        uint256 deployKey;
        if (block.chainid == 11_155_111) {
            deployKey = vm.envUint("PRIVATE_KEY");
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            deployKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
        DEPLOYER_KEY = deployKey;
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        // Ref https://docs.chain.link/docs/ethereum-addresses
        // ...
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        // Fetch deployed Uniswap addresses from environment variables
        address uniswapFactory = vm.envAddress("UNISWAP_FACTORY_ADDRESS");
        if (uniswapFactory == address(0) || uniswapFactory.code.length == 0) {
            revert("Uniswap factory not deployed");
        }
        address uniswapRouter = vm.envAddress("UNISWAP_ROUTER_ADDRESS");
        if (uniswapRouter == address(0) || uniswapRouter.code.length == 0) {
            revert("Uniswap router not deployed");
        }

        address wethAddr = vm.envAddress("WETH_ADDRESS");
        if (wethAddr == address(0) || wethAddr.code.length == 0) {
            WETH9Mock wethMock = new WETH9Mock();
            wethAddr = address(wethMock);
        }

        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1 ether);

        MockV3Aggregator daiUsdPriceFeed = new MockV3Aggregator(DECIMALS, DAI_USD_PRICE);
        ERC20Mock daiMock = new ERC20Mock("DAI", "DAI", msg.sender, 1 ether);

        MockV3Aggregator mkrUsdPriceFeed = new MockV3Aggregator(DECIMALS, MKR_USD_PRICE);
        ERC20Mock mkrMock = new ERC20Mock("MKR", "MKR", msg.sender, 1 ether);

        anvilNetworkConfig = NetworkConfig({
            weth: address(wethAddr),
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtc: address(wbtcMock),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            dai: address(daiMock),
            daiUsdPriceFeed: address(daiUsdPriceFeed),
            mkr: address(mkrMock),
            mkrUsdPriceFeed: address(mkrUsdPriceFeed),
            uniswapFactory: uniswapFactory,
            uniswapRouter: uniswapRouter
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory networkConfig) {
        return activeNetworkConfig;
    }
}
