## 🧠 Development Guidelines

### Solidity
- Solidity version: `^0.8.20`
- Use **SPDX-License-Identifier** at the top of every file
- Prefer **`pragma solidity ^0.8.20;`** over fixed versions
- Avoid using deprecated constructs (e.g. `var`, `suicide`, `tx.origin` for auth)

### Code Style
- Follow the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Use **camelCase** for variables and functions
- Use **PascalCase** for contract and struct names
- Always include **NatSpec comments** (`/// @notice`, `@param`, `@return`) for public functions
- Order contract members as:
  1. State variables  
  2. Events  
  3. Errors  
  4. Modifiers  
  5. Constructor  
  6. External/Public functions  
  7. Internal/Private functions  

### Security Practices
- Use **`unchecked {}`** only for verified gas optimizations
- Validate all external inputs
- Avoid reentrancy — use `ReentrancyGuard` or check-effects-interactions pattern
- Use **custom errors** instead of `require` strings for gas efficiency
- Avoid magic numbers and hardcoded addresses
- Avoid storage writes in loops when possible

### Gas Optimization Tips
- Use `constant` and `immutable` for fixed values
- Use `uint256` instead of smaller uint types unless packed
- Cache storage variables in memory when repeatedly accessed
- Short-circuit conditionals to save gas

---

## 🧪 Testing & Scripts

### Testing
- Use **Forge tests** written in Solidity (no external JS testing)
- Place tests in the `test/` directory
- Test file naming convention: `{ContractName}.t.sol`
- Use `vm` cheatcodes (e.g. `vm.prank`, `vm.expectRevert`) appropriately
- Prefer `assertEq`, `assertApproxEqAbs`, and `expectRevert` utilities
- Aim for >90% test coverage

### Scripts
- Deployment scripts live in `script/` directory
- Use `forge script` for dry-run deployment and simulation
- Keep scripts deterministic when possible (avoid random addresses)

---

## 🧩 Libraries & Imports
- Use **OpenZeppelin Contracts v5.x**
- For safe math and ERC20/ERC721 implementations, import from `lib/openzeppelin-contracts`
- Avoid inline assembly unless necessary for optimization

---

## 🚫 Do NOT
- Do not use floating-point numbers
- Do not perform external calls inside constructors
- Do not use low-level `call` without proper checks
- Do not commit private keys, `.env`, or build artifacts to Git
- Do not bypass the Forge test suite before deployment

---

## ✅ Example Copilot Prompts
You can ask Copilot to:
- “Create a new ERC20 token contract using OpenZeppelin and Foundry test template.”
- “Generate a Forge test for the `StakingVault` contract covering deposit and withdraw scenarios.”
- “Add custom error handling to prevent unauthorized calls in `setOwner`.”
- “Optimize this loop for gas efficiency under Solidity ^0.8.20.”

---

## 🧩 Project-Specific Notes (Optional)
- Network defaults: `anvil` (local), `sepolia` (testnet), `mainnet`
- Deployment uses private key from environment variable: `PRIVATE_KEY`
- Contract verification via `forge verify-contract`
