# BaseVault

Yield-bearing commitment savings on Base. Deposit ETH or whitelisted ERC-20 tokens into time-locked vaults — withdrawals only permitted after the lock expires. While locked, funds earn yield via Aave v3.

**[Live Demo](https://web-alpha-five-o7k6218i8f.vercel.app)** · **[Contract on Base Sepolia](https://sepolia.basescan.org/address/0x4f23eaeb65dBe4695180aAeA0A6E38A295CD3489)**

## How It Works

1. Connect wallet on Base Sepolia
2. Choose an asset (ETH, USDC, WETH) and lock duration (1–365 days)
3. Deposit — funds are supplied to Aave v3 to earn yield while locked
4. Withdraw after lock expires — principal + accrued yield returned in one transaction

Multiple concurrent vaults per address. No fees, no upgradability.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        React Frontend                             │
│  VaultList │ DepositForm │ VaultCard │ WithdrawButton │ EventFeed │
└──────────────────────────┬───────────────────────────────────────┘
                           │ wagmi v2 + viem v2
┌──────────────────────────▼───────────────────────────────────────┐
│                      Base Network (L2)                            │
│                      BaseVaultV2.sol                              │
│              (multi-vault, ERC-20, yield-bearing)                 │
└──────────────────────────┬───────────────────────────────────────┘
                           │ IPool + IWETHGateway
┌──────────────────────────▼───────────────────────────────────────┐
│                    Aave v3 on Base                                 │
│            (supply / withdraw on behalf of vault)                 │
└──────────────────────────────────────────────────────────────────┘
```

No backend server — all state lives on-chain. See [ARCHITECTURE.md](ARCHITECTURE.md) for full details.

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
├── contracts/              # Foundry — Solidity smart contracts
│   ├── src/
│   │   ├── BaseVault.sol       # v1 (deployed, immutable)
│   │   └── BaseVaultV2.sol     # v2 (active — multi-vault, ERC-20, Aave yield)
│   ├── test/
│   │   ├── BaseVault.t.sol     # v1 unit tests
│   │   ├── BaseVaultV2.t.sol   # v2 unit tests
│   │   └── BaseVaultV2Fork.t.sol  # v2 Aave fork tests
│   └── script/
│       ├── Deploy.s.sol        # v1 deploy
│       └── DeployV2.s.sol      # v2 deploy
└── web/                    # React frontend
    ├── src/
    │   ├── components/     # VaultList, VaultCard, DepositForm, TokenSelector, etc.
    │   ├── hooks/          # useVaults, useDeposit, useWithdraw, useTokenApproval, etc.
    │   └── lib/            # ABI, wagmi config, formatters, error parsing, tokens
    └── scripts/copy-abi.mjs
```

## Smart Contract

**BaseVaultV2.sol** — multi-asset, yield-bearing vault with time-locked deposits and owner-controlled token whitelist.

| Network      | Address | Explorer |
|-------------|---------|----------|
| Base Sepolia | `0x4f23eaeb65dBe4695180aAeA0A6E38A295CD3489` | [Basescan](https://sepolia.basescan.org/address/0x4f23eaeb65dBe4695180aAeA0A6E38A295CD3489) |

### Interface

```solidity
function deposit(address asset, uint256 amount, uint256 lockDuration) external payable returns (uint256 vaultId);
function withdraw(uint256 vaultId) external;
function getVaults(address user) external view returns (Vault[] memory);
function totalYield(address user, uint256 vaultId) external view returns (uint256);
function whitelistAsset(address token) external;    // owner only
function setYieldEnabled(bool enabled) external;    // owner only
```

### Security

- Checks-Effects-Interactions (CEI) pattern on all state-changing functions
- OpenZeppelin `SafeERC20` for all token transfers
- Custom errors (gas-efficient, no revert strings)
- Solidity 0.8.20 built-in overflow protection
- Aave v3 integration tested against live Base Sepolia fork
- `address(0)` = ETH throughout

### Contract Commands

```bash
cd packages/contracts
forge build                                          # compile
forge test -vvv                                      # unit tests
forge test --fork-url $BASE_SEPOLIA_RPC_URL -vvv     # fork tests (Aave integration)
forge coverage                                       # coverage report
```

## Frontend

React app with multi-vault dashboard, ERC-20 approval flow, live yield display, and countdown timers.

### Stack

- React 18 + TypeScript (strict)
- Vite + Tailwind CSS v4
- wagmi v2 + viem v2 + RainbowKit
- TanStack Query v5

### Environment Variables

```bash
# packages/web/.env.local
VITE_ALCHEMY_API_KEY=                    # Alchemy API key (not full URL)
VITE_WALLETCONNECT_PROJECT_ID=           # From cloud.reown.com
VITE_VAULT_V2_ADDRESS_SEPOLIA=0x4f23eaeb65dBe4695180aAeA0A6E38A295CD3489
```

### Frontend Commands

```bash
cd packages/web
pnpm dev          # start dev server
pnpm build        # production build
pnpm typecheck    # type check
pnpm test         # run tests
```

## License

MIT
