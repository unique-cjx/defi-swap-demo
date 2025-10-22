## GetAmountsOut function

### The getAmountsOut function takes three inputs:

- amountIn: The amount of the initial token we're starting with.
- path: The list of tokens involved in the swap. In our example, this is [WETH, DAI, MKR].
- factory: The Uniswap factory contract. This contract is used to create and manage the liquidity pools for the different tokens on Uniswap.

```solidity
    // performs chained getAmountOut calculations on any number of pairs
    // NOTE: amounts[0] = amountIn
    //       amounts[n - 1] = final amount out
    //       amounts[i] = intermediate amounts out
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
​
        // NOTE: Example
        // --- Inputs ---
        // amountIn = 1e18
        // path = [WETH, DAI, MKR]
        // --- Outputs ---
        // WETH    1000000000000000000 (1 * 1e18)
        // DAI  2500339748620145970214 (2500.3397... * 1e18)
        // MKR     1242766501542703043 (1.2427... * 1e18)
​
        // --- Execution ---
        // amounts = [0, 0, 0]
        // amounts = [1000000000000000000, 0, 0]
​
        // For loop
        // i = 0
        // path[i] = WETH, path[i + 1] = DAI
        // amounts[i] = 1000000000000000000
        // amounts[i + 1] = 2500339748620145970214
        // amounts = [1000000000000000000, 2500339748620145970214, 0]
​
        // i = 1
        // path[i] = DAI, path[i + 1] = MKR
        // amounts[i] = 2500339748620145970214
        // amounts[i + 1] = 1242766501542703043
        // amounts = [1000000000000000000, 2500339748620145970214, 1242766501542703043]
​
        // NOTE:
        //   i | path[i]   | path[i + 1]
        //   0 | path[0]   | path[1]
        //   1 | path[1]   | path[2]
        //   2 | path[2]   | path[3]
        // n-2 | path[n-2] | path[n-1]
        for (uint i; i < path.length - 1; i++) {
            // NOTE: reserves = internal balance of tokens inside pair contract
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            // NOTE: use the previous output for input
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
```

## GetAmountsIn function

```solidity
    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
​
        // --- Inputs ---
        // amountOut = 1e18
        // path = [WETH, DAI, MKR]
        // --- Outputs ---
        // WETH     804555560756014274 (0.8045... * 1e18)
        // DAI  2011892163724115442026 (2011.892... * 1e18)
        // MKR     1000000000000000000 (1 * 1e18)
​
        // --- Execution ---
        // amounts = [0, 0, 0]
        // amounts = [0, 0, 1000000000000000000]
​
        // For loop
        // i = 2
        // path[i - 1] = DAI, path[i] = MKR
        // amounts[i] = 1000000000000000000
        // amounts[i - 1] = 2011892163724115442026
        // amounts = [0, 2011892163724115442026, 1000000000000000000]
​
        // i = 1
        // path[i - 1] = WETH, path[i] = DAI
        // amounts[i] = 2011892163724115442026
        // amounts[i - 1] = 804555560756014274
        // amounts = [804555560756014274, 2011892163724115442026, 1000000000000000000]
​
        // NOTE:
        // i     | output amount  | input amount
        // n - 1 | amounts[n - 1] | amounts[n - 2]
        // n - 2 | amounts[n - 2] | amounts[n - 3]
        // ...
        // 2     | amounts[2]     | amounts[1]
        // 1     | amounts[1]     | amounts[0]
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
​
```

## SwapTokensForExactTokens function

```solidity
    // NOTE: swap min input for specified output
    // max in = 3000 DAI
    // out =  1 WETH
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        // NOTE: calculates amounts based on the desired amountOut
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        // NOTE: checks if the amounts is less than or equal to the user's max input
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        // NOTE: transfers the user's input token to the first pair contract for trading
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        // NOTE: performs the swap in the loop, traversing through all pairs in the path
        _swap(amounts, path, to);
    }
```