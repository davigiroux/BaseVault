# BaseVault — Claude Code Setup

## Project Overview

BaseVault is a commitment savings protocol deployed on Base (Coinbase's L2). Users deposit ETH or whitelisted ERC-20 tokens into time-locked vaults. Withdrawals are only permitted after the lock expires. While funds are locked, they are deployed to Aave v3 to earn yield, which is returned alongside principal on withdrawal. Each user can hold multiple independent vaults concurrently.

This is a solo project by a senior full-stack engineer learning smart contract development. Code quality standards are high — treat everything as if it will be reviewed by a protocol security auditor.

## Tech Stack

**Smart Contracts**
- Solidity ^0.8.20
- Foundry (forge, cast, anvil)
- OpenZeppelin Contracts v5 (`SafeERC20`, `Ownable`)
- Aave v3 on Base (`IPool`, `IWETHGateway`)
- Base Sepolia (testnet) → Base Mainnet

**Frontend**
- React 18 + TypeScript (strict)
- Vite
- wagmi v2 + viem v2
- TanStack Query v5
- RainbowKit
- Tailwind CSS

**Tooling**
- pnpm workspaces (monorepo: `packages/contracts`, `packages/web`)
- GitHub Actions for CI (unit tests + fork tests)
- Basescan verification

## Repository Structure

```
basevault/
├── packages/
│   ├── contracts/
│   │   ├── src/
│   │   │   ├── BaseVault.sol        # v1 — do not modify
│   │   │   └── BaseVaultV2.sol      # v2 — active development
│   │   ├── test/
│   │   │   ├── BaseVault.t.sol      # v1 tests — must stay green
│   │   │   └── BaseVaultV2.t.sol    # v2 tests
│   │   ├── script/
│   │   │   ├── Deploy.s.sol         # v1 deploy
│   │   │   └── DeployV2.s.sol       # v2 deploy
│   │   └── foundry.toml
│   └── web/
│       ├── src/
│       │   ├── components/
│       │   ├── hooks/
│       │   ├── lib/
│       │   └── App.tsx
│       └── vite.config.ts
├── CLAUDE.md
├── CONCEPT.md
├── ROADMAP.md
├── ARCHITECTURE.md
├── STUDY_GUIDE.md
└── package.json
```

## Coding Conventions

### Solidity
- CEI pattern on every state-changing function — no exceptions, especially now that `withdraw()` calls into Aave
- Use custom errors, never revert strings (`error Vault__NotYetUnlocked()`)
- Use `SafeERC20` for all ERC-20 transfers — never call `transfer` or `transferFrom` directly
- Emit events for every state change
- NatSpec comments on all public/external functions
- No magic numbers — use named constants
- `address(0)` is the canonical representation of ETH throughout

### TypeScript / React
- Strict TypeScript — no `any`, no `as` casts unless unavoidable
- One component per file, named exports only
- Custom hooks in `hooks/` for all contract interactions — never call wagmi hooks directly in components
- ERC-20 deposits always go through `useTokenApproval` before `useDeposit`
- Handle all three states explicitly: loading, error, success
- Format all on-chain values with `viem`'s `formatUnits` / `parseUnits` — never raw BigInt in UI

### General
- Every function does one thing
- No commented-out code in commits
- Prefer explicit over implicit
- If something is a workaround, leave a comment explaining why

## Key Constraints Claude Should Respect

1. **CEI is absolute** — every state-changing function must zero state before any external call, including Aave interactions
2. **Never modify `BaseVault.sol`** — v1 is deployed and must stay unchanged; all new work goes in `BaseVaultV2.sol`
3. **SafeERC20 everywhere** — no direct ERC-20 transfer calls
4. **No shortcuts on error handling** — every contract call in the frontend must handle pending, error, and success states
5. **Fork tests for Aave** — Aave integration must be tested against live Base Sepolia state, not mocked
6. **Test before ship** — no contract function should exist without a corresponding Foundry test

## Environment Variables

```
# packages/web/.env.local
VITE_ALCHEMY_API_KEY=
VITE_VAULT_V1_ADDRESS_SEPOLIA=0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408
VITE_VAULT_V2_ADDRESS_SEPOLIA=
VITE_VAULT_V2_ADDRESS_MAINNET=
VITE_WALLETCONNECT_PROJECT_ID=

# packages/contracts/.env
BASE_SEPOLIA_RPC_URL=
BASE_MAINNET_RPC_URL=
PRIVATE_KEY=
BASESCAN_API_KEY=
```

## Aave v3 Addresses on Base

```
# Base Sepolia
AAVE_POOL=0x07eA79F68B2B3df564D0A34F8e19791234D9031

# Base Mainnet
AAVE_POOL=0xA238Dd80C259a72e81d7e4664a9801593F98d1c5
WETH_GATEWAY=0x8be473dCfA93132658821E67CbEB684ec8Ea2E74
```

## Useful Commands

```bash
# Contracts
cd packages/contracts
forge build
forge test -vvv
forge test --fork-url $BASE_SEPOLIA_RPC_URL -vvv   # fork tests
forge coverage
forge script script/DeployV2.s.sol --rpc-url base_sepolia --broadcast --verify

# Frontend
cd packages/web
pnpm dev
pnpm build
pnpm typecheck
pnpm test
```

## Current Phase

Check `ROADMAP.md` for the current active phase and its acceptance criteria before starting any work session.
