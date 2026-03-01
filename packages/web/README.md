# BaseVault — Frontend

React frontend for the BaseVault commitment savings protocol.

## Setup

```bash
pnpm install
cp .env.example .env.local
```

Fill in `.env.local`:

| Variable | Source |
|----------|--------|
| `VITE_ALCHEMY_API_KEY` | [alchemy.com/dashboard](https://dashboard.alchemy.com/) — API key only, not full URL |
| `VITE_WALLETCONNECT_PROJECT_ID` | [cloud.reown.com](https://cloud.reown.com/) (formerly WalletConnect Cloud) |

## Development

```bash
pnpm dev          # starts Vite dev server (predev copies ABI from Foundry output)
pnpm build        # production build
pnpm typecheck    # TypeScript strict check
```

## ABI Sync

The ABI is auto-generated from Foundry build output. `scripts/copy-abi.mjs` runs as a `predev`/`prebuild` hook, reading `packages/contracts/out/BaseVault.sol/BaseVault.json` and writing `src/lib/abi.ts` with `as const` for full wagmi type inference.

If you change the contract, rebuild it (`forge build` in `packages/contracts`) and restart the dev server.

## Architecture

```
src/
├── components/
│   ├── Layout.tsx          # App shell, header with ConnectButton
│   ├── ConnectButton.tsx   # RainbowKit wrapper
│   ├── VaultStatus.tsx     # Deposit amount, unlock date, live countdown
│   ├── DepositForm.tsx     # Amount + duration (slider + number input)
│   └── WithdrawButton.tsx  # Withdraw with lock-state awareness
├── hooks/
│   ├── useVault.ts         # Reads deposit, computes isLocked/secondsRemaining (1s interval)
│   ├── useDeposit.ts       # deposit() write + tx receipt tracking
│   └── useWithdraw.ts      # withdraw() write + tx receipt tracking
├── lib/
│   ├── abi.ts              # Auto-generated ABI (do not edit)
│   ├── contract.ts         # ABI + address constants
│   ├── wagmi.ts            # RainbowKit config (baseSepolia + base chains)
│   ├── format.ts           # formatEthAmount, formatCountdown, formatUnlockDate
│   └── errors.ts           # parseVaultError → user-facing strings
├── App.tsx                 # Provider stack + main layout
├── main.tsx                # Entry point
└── index.css               # Tailwind v4 + custom theme
```

### Patterns

- **No wagmi hooks in components** — all contract interactions go through custom hooks in `hooks/`
- **Three-state handling** — every contract call handles pending, error, and success
- **Two-phase pending** — `isPending` (wallet confirmation) + `isConfirming` (on-chain confirmation)
- **Format all on-chain values** — never raw BigInt in UI, always through `formatEthAmount`/`formatCountdown`
