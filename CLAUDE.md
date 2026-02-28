# BaseVault — Claude Code Setup

## Project Overview

BaseVault is a commitment savings protocol deployed on Base (Coinbase's L2). Users deposit ETH or ERC-20 tokens into a vault with a defined lock period. Withdrawals are only permitted after the lock expires. The project is simultaneously a learning vehicle for Solidity/Foundry and a production-quality portfolio piece.

This is a solo project by a senior full-stack engineer learning smart contract development. Code quality standards are high — treat everything as if it will be reviewed by a protocol security auditor.

## Tech Stack

**Smart Contracts**
- Solidity ^0.8.20
- Foundry (forge, cast, anvil)
- OpenZeppelin Contracts v5
- Base Sepolia (testnet) → Base Mainnet

**Frontend**
- React 18 + TypeScript
- Vite
- wagmi v2 + viem v2
- TanStack Query v5
- Tailwind CSS

**Tooling**
- pnpm workspaces (monorepo: `packages/contracts`, `packages/web`)
- GitHub Actions for CI
- Etherscan/Basescan verification

## Repository Structure

```
basevault/
├── packages/
│   ├── contracts/          # Foundry project
│   │   ├── src/
│   │   │   └── BaseVault.sol
│   │   ├── test/
│   │   │   └── BaseVault.t.sol
│   │   ├── script/
│   │   │   └── Deploy.s.sol
│   │   └── foundry.toml
│   └── web/                # React frontend
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
└── package.json
```

## Coding Conventions

### Solidity
- Follow the Checks-Effects-Interactions (CEI) pattern on every state-changing function
- Use custom errors instead of revert strings (`error Vault__NotYetUnlocked()`)
- Emit events for every state change
- Use `SafeERC20` from OpenZeppelin for all token transfers
- NatSpec comments on all public/external functions
- No magic numbers — use named constants

### TypeScript / React
- Strict TypeScript — no `any`, no `as` casts unless unavoidable
- One component per file, named exports only
- Custom hooks in `hooks/` for all contract interactions (never call wagmi hooks directly in components)
- Handle all three states explicitly: loading, error, success
- Format all on-chain values with `viem`'s `formatUnits` / `parseUnits` — never raw BigInt in UI

### General
- Every function does one thing
- No commented-out code in commits
- Prefer explicit over implicit
- If something is a workaround, leave a comment explaining why

## Key Constraints Claude Should Respect

1. **Security first on contracts** — always use CEI pattern, always check for reentrancy risks
2. **No shortcuts on error handling** — every contract call in the frontend must handle pending, error, and success states
3. **Test before ship** — no contract function should exist without a corresponding Foundry test
4. **Keep it scoped** — this is a focused learning project; do not add features not in the roadmap without flagging it

## Environment Variables

```
# packages/web/.env.local
VITE_ALCHEMY_API_KEY=
VITE_VAULT_ADDRESS_SEPOLIA=
VITE_VAULT_ADDRESS_MAINNET=
VITE_WALLETCONNECT_PROJECT_ID=
```

## Useful Commands

```bash
# Contracts
cd packages/contracts
forge build
forge test -vvv
forge coverage
forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify

# Frontend
cd packages/web
pnpm dev
pnpm build
pnpm typecheck
```

## Current Phase

Check `ROADMAP.md` for the current active phase and its acceptance criteria before starting any work session.
