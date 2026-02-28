# BaseVault

Commitment savings protocol on Base. Deposit ETH with a time lock, withdraw only after it expires.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- [Node.js](https://nodejs.org/) v18+
- [pnpm](https://pnpm.io/) v9+

## Quick Start

```bash
# Clone and enter the repo
git clone <repo-url> && cd basevault

# Build contracts
cd packages/contracts
forge build

# Run tests
forge test -vvv
```

## Project Structure

```
packages/
├── contracts/   # Foundry — Solidity smart contracts
└── web/         # React frontend (coming in Phase 4)
```

## Contracts

The core contract is `BaseVault.sol` — a permissionless ETH vault with time-locked deposits.

```bash
cd packages/contracts

forge build          # Compile
forge test -vvv      # Run tests with traces
forge coverage       # Coverage report
```

## License

MIT
