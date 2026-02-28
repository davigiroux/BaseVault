# BaseVault — Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                     React Frontend                       │
│  DepositForm │ VaultStatus │ WithdrawButton │ EventFeed  │
└──────────────────────┬──────────────────────────────────┘
                       │ wagmi v2 + viem v2
┌──────────────────────▼──────────────────────────────────┐
│                   Base Network (L2)                      │
│                   BaseVault.sol                          │
└─────────────────────────────────────────────────────────┘
```

The system has two layers: a Solidity smart contract deployed on Base, and a React frontend that communicates with it via wagmi and viem. There is no backend server — all state lives on-chain.

---

## Smart Contract: `BaseVault.sol`

### Deployment Addresses

| Network       | Address       | Basescan |
|---------------|---------------|----------|
| Base Sepolia  | 0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408 | [View](https://sepolia.basescan.org/address/0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408) |
| Base Mainnet  | —             | —        |

### State Variables

```solidity
struct Deposit {
    uint256 amount;      // ETH deposited in wei
    uint256 unlocksAt;   // Unix timestamp when withdrawal is permitted
}

mapping(address => Deposit) public deposits;

uint256 public constant MIN_LOCK_DURATION = 1 days;
uint256 public constant MAX_LOCK_DURATION = 365 days;
```

### Interface

```solidity
/// @notice Deposit ETH with a time lock
/// @param lockDuration Seconds until withdrawal is permitted (min: 1 day, max: 365 days)
function deposit(uint256 lockDuration) external payable;

/// @notice Withdraw all deposited ETH if lock period has passed
function withdraw() external;

/// @notice View deposit details for any address
/// @return Deposit struct with amount and unlocksAt timestamp
function getDeposit(address depositor) external view returns (Deposit memory);
```

### Events

```solidity
event VaultDeposited(
    address indexed depositor,
    uint256 amount,
    uint256 unlocksAt
);

event VaultWithdrawn(
    address indexed depositor,
    uint256 amount
);
```

### Custom Errors

```solidity
error Vault__ZeroAmount();           // msg.value == 0 on deposit
error Vault__LockDurationInvalid();  // lockDuration out of allowed range
error Vault__AlreadyDeposited();     // depositor already has an active deposit
error Vault__NothingToWithdraw();    // no deposit found for caller
error Vault__NotYetUnlocked();       // lock period has not passed
error Vault__TransferFailed();       // ETH transfer failed
```

### Security Properties

- **Reentrancy:** CEI pattern ensures state is cleared before ETH transfer. No `ReentrancyGuard` needed given CEI, but may be added as a belt-and-suspenders measure.
- **Integer overflow:** Solidity 0.8+ reverts on overflow by default.
- **Access control:** No admin functions in v1. Contract is fully permissionless.
- **Denial of service:** No loops over user state. Each user's deposit is independent.

---

## Frontend Architecture

### Package Structure

```
packages/web/src/
├── components/
│   ├── ConnectButton.tsx       # Wallet connection
│   ├── DepositForm.tsx         # Amount + lock duration input, submit
│   ├── VaultStatus.tsx         # Current deposit, countdown timer
│   ├── WithdrawButton.tsx      # Withdraw CTA with lock state
│   ├── EventFeed.tsx           # Live on-chain activity
│   └── Layout.tsx              # App shell
├── hooks/
│   ├── useVault.ts             # Aggregated vault state (read)
│   ├── useDeposit.ts           # deposit() write interaction
│   ├── useWithdraw.ts          # withdraw() write interaction
│   └── useVaultEvents.ts       # VaultDeposited / VaultWithdrawn event watcher
├── lib/
│   ├── contract.ts             # ABI + address constants
│   ├── wagmi.ts                # wagmi config (chains, transports)
│   └── format.ts               # formatEther, formatCountdown helpers
└── App.tsx
```

### wagmi Configuration

```typescript
// lib/wagmi.ts
import { createConfig, http } from 'wagmi'
import { base, baseSepolia } from 'wagmi/chains'

export const config = createConfig({
  chains: [baseSepolia, base],
  transports: {
    [baseSepolia.id]: http(`https://base-sepolia.g.alchemy.com/v2/${ALCHEMY_KEY}`),
    [base.id]: http(`https://base-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}`),
  },
})
```

### Core Hook: `useVault`

```typescript
// hooks/useVault.ts
export function useVault(depositorAddress?: Address) {
  const { data: deposit } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: 'getDeposit',
    args: [depositorAddress ?? zeroAddress],
    query: { enabled: !!depositorAddress },
  })

  const isLocked = deposit
    ? BigInt(Date.now()) / 1000n < deposit.unlocksAt
    : false

  const secondsRemaining = deposit
    ? Math.max(0, Number(deposit.unlocksAt) - Math.floor(Date.now() / 1000))
    : 0

  return {
    deposit,
    isLocked,
    secondsRemaining,
    hasDeposit: !!deposit && deposit.amount > 0n,
  }
}
```

### Event Watching: `useVaultEvents`

```typescript
// hooks/useVaultEvents.ts
export function useVaultEvents() {
  const [events, setEvents] = useState<VaultEvent[]>([])
  const publicClient = usePublicClient()

  useEffect(() => {
    if (!publicClient) return

    const unwatch = publicClient.watchContractEvent({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      onLogs: (logs) => {
        setEvents(prev => [...logs.map(parseLog), ...prev].slice(0, 20))
      },
    })

    return unwatch
  }, [publicClient])

  return events
}
```

---

## Data Flow

### Deposit Flow

```
User inputs amount + lock duration
  → DepositForm validates (amount > 0, duration in range)
  → useDeposit hook calls writeContractAsync
  → wagmi sends tx to Base network
  → User confirms in wallet
  → Pending state shown in UI
  → Tx confirmed → VaultDeposited event emitted
  → useVault re-fetches deposit state
  → VaultStatus updates with new amount + countdown
  → EventFeed picks up new event
```

### Withdraw Flow

```
User clicks Withdraw
  → WithdrawButton checks isLocked (disabled if true)
  → useWithdraw hook calls writeContractAsync
  → wagmi sends tx
  → User confirms in wallet
  → Pending state shown
  → Tx confirmed → VaultWithdrawn event emitted
  → useVault re-fetches (deposit cleared)
  → VaultStatus resets
  → EventFeed picks up withdrawal event
```

---

## Constraints & Design Decisions

**One deposit per address at a time.** Simplifies the contract significantly. Multiple concurrent vaults are a stretch goal.

**ETH only in v1.** ERC-20 support adds meaningful complexity (SafeERC20, approvals, token whitelist). Scoped out for v1 to keep the learning surface focused.

**No admin/owner functions.** The contract is fully immutable and permissionless. This is intentional — simplicity is a security property.

**Lock duration is set at deposit time.** This means the same address could have a different lock duration on each new deposit (after withdrawing the previous one).

**No upgradability.** Proxy patterns are complex and introduce their own risks. For a learning project, immutable contracts are the right default.
