# BaseVault

Commitment savings protocol on Base. Deposit ETH with a time lock — withdrawals only permitted after the lock expires. Fully permissionless, no admin functions.

**[Live on Base Sepolia](https://sepolia.basescan.org/address/0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408)**

## How It Works

1. Connect wallet on Base Sepolia
2. Deposit ETH with a lock duration (1–365 days)
3. Wait for the lock to expire (live countdown in UI)
4. Withdraw — ETH is returned in full

One active deposit per address. No fees, no admin, no upgradability.

## Architecture

```
┌───────────────────────────────────────────────┐
│              React Frontend                    │
│  DepositForm · VaultStatus · WithdrawButton    │
└───────────────────┬───────────────────────────┘
                    │ wagmi v2 + viem v2
┌───────────────────▼───────────────────────────┐
│             Base Network (L2)                  │
│             BaseVault.sol                      │
└───────────────────────────────────────────────┘
```

No backend server — all state lives on-chain.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- [Node.js](https://nodejs.org/) v18+
- [pnpm](https://pnpm.io/) v9+

## Quick Start

```bash
git clone <repo-url> && cd BaseVault
pnpm install

# Build & test contracts
cd packages/contracts
forge build
forge test -vvv

# Run frontend
cd ../web
cp .env.example .env.local   # fill in API keys
pnpm dev
```

## Project Structure

```
packages/
├── contracts/          # Foundry — Solidity smart contracts
│   ├── src/BaseVault.sol
│   ├── test/BaseVault.t.sol
│   └── script/Deploy.s.sol
└── web/                # React frontend
    ├── src/
    │   ├── components/   # Layout, DepositForm, VaultStatus, WithdrawButton
    │   ├── hooks/        # useVault, useDeposit, useWithdraw
    │   └── lib/          # ABI, wagmi config, formatters, error parsing
    └── scripts/copy-abi.mjs
```

## Smart Contract

**BaseVault.sol** — permissionless ETH vault with time-locked deposits.

| Network      | Address | Explorer |
|-------------|---------|----------|
| Base Sepolia | `0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408` | [Basescan](https://sepolia.basescan.org/address/0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408) |

### Interface

```solidity
function deposit(uint256 lockDuration) external payable;  // 1 day – 365 days
function withdraw() external;                              // only after lock expires
function getDeposit(address) external view returns (Deposit memory);
```

### Security

- Checks-Effects-Interactions (CEI) pattern on all state-changing functions
- OpenZeppelin `ReentrancyGuard` as belt-and-suspenders
- Custom errors instead of revert strings (gas-efficient)
- Solidity 0.8.20 built-in overflow protection
- 100% test coverage (lines, statements, branches, functions)
- 21 tests including fuzz tests and reentrancy attack simulation

### Contract Commands

```bash
cd packages/contracts
forge build             # compile
forge test -vvv         # run tests with traces
forge coverage          # coverage report
```

## Frontend

React app with wallet connection, deposit form, live countdown, and withdraw flow.

### Stack

- React 18 + TypeScript (strict)
- Vite + Tailwind CSS v4
- wagmi v2 + viem v2 + RainbowKit
- TanStack Query v5

### Environment Variables

```bash
# packages/web/.env.local
VITE_ALCHEMY_API_KEY=         # Alchemy API key (not full URL)
VITE_WALLETCONNECT_PROJECT_ID= # From cloud.reown.com
```

### Frontend Commands

```bash
cd packages/web
pnpm dev          # start dev server (auto-copies ABI from Foundry output)
pnpm build        # production build
pnpm typecheck    # type check
```

## License

MIT
