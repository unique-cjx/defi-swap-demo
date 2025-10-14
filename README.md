# Intro

## Purpose

1. Understanding the mathematical principles behind Uniswap V2.
2. A thorough examination of Uniswap V2 contracts.
3. Building `defi-swap-demo` with Foundry on Uniswap V2 Core fork.

## Uniswap V2 Overview

Uniswap V2 is a foundational protocol in DeFi,
serving as the basis for countless other **AMMs** (Automated Market Makers).

> Decentralized exchange that allows users to buy and sell tokens without
> an order book.

### Operations

- Liquidity provider
  - Deposit tokens
- Trader
  - Swap tokens with liquidity pool
- AMM
  - Execute trades
  - Maintain liquidity pool
  - Give swap fees to liquidity providers

### Pros and Cons

| Pros           | Cons                |
| -------------- | ------------------- |
| Permissionless | Impermanent loss    |
| No order book  | Slippage            |
| Low fees       | Front-running       |
| Decentralized  | Smart contract risk |

### How an AMM Works

```
x * y = k
```

#### Where:

- x: amount of Token A in the pool
- y: amount of Token B in the pool
- k: liquidity constant

#### Example:

If we start with an AMM where x = 1 ETH and y = 4000 USDC, then k = 4000,
after that if one user wants to swap 0.1 x(ETH) for y(USDC). in this case,
the amount of token y(USDC) that the user will receive can be calculated as follows:

```
(x + Δx) * (y - Δy) = k
(1 + 0.1) * (4000 - Δy) = 4000
Δy = 363.64 USDC
```

We can see that 0.1 ETH can be swapped for 363.64 USDC. As more users swap USDC for ETH,
the price of ETH in terms of USDC increases. Eventually, the price of ETH reaches a new balance point.

### Contracts

- Factory
  - Create new pairs
- Pair
  - Lock up the tokens
  - Trade tokens
- Router
  - Interact with the pairs

### Swap Fees

- 0.30% fee on each trade

```solidity
// balance0Adjusted = balance0 * 1000 - amount0In * 3
uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
// balance1Adjusted = balance1 * 1000 - amount1In * 3
uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
// Why need this requirement?
// To ensure that after accounting for fees the invariant x * y >= k still holds true.
require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
```

## How to deploy locally Uniswap V2 Contracts

### 1. Compile Uniswap V2 Contracts

```bash
npx hardhat compile
```

### 2. Run a local Ethereum node through Hardhat

```bash
npx hardhat node
```

### 3. Test setup liquidity script

```bash
forge script script/SetupLiquidity.sol -vvv
```
