# BaseVault — Architecture

## System Overview

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

The system has three layers: a Solidity smart contract on Base that manages vault state and delegates idle funds to Aave, a React frontend that communicates with it via wagmi and viem, and Aave v3 which holds deposited assets and accrues yield while they're locked. There is no backend server — all state lives on-chain.

---

## Smart Contract: `BaseVaultV2.sol`

### Deployment Addresses

| Network       | Address       | Basescan |
|---------------|---------------|----------|
| Base Sepolia  | `0x4f23eaeb65dBe4695180aAeA0A6E38A295CD3489` | [View](https://sepolia.basescan.org/address/0x4f23eaeb65dBe4695180aAeA0A6E38A295CD3489) |
| Base Mainnet  | _TBD_         | —        |

### State Variables

```solidity
struct Vault {
    uint256 id;          // Array index scoped per user
    address asset;       // address(0) = ETH, otherwise ERC-20
    uint256 principal;   // Original deposit amount in wei or token units
    uint256 unlocksAt;   // Unix timestamp when withdrawal is permitted
    bool yielding;       // Whether funds were deployed to Aave
}

mapping(address => Vault[]) public vaults;
mapping(address => bool) public whitelistedAssets;

address public immutable aavePool;
address public immutable wethGateway;
bool public yieldEnabled;

uint256 public constant MIN_LOCK_DURATION = 1 days;
uint256 public constant MAX_LOCK_DURATION = 365 days;
```

### Interface

```solidity
/// @notice Deposit an asset into a new time-locked vault
/// @param asset Token address, or address(0) for ETH (uses msg.value)
/// @param amount Amount for ERC-20 deposits (ignored for ETH)
/// @param lockDuration Seconds until withdrawal is permitted
/// @return vaultId Index of the newly created vault for this user
function deposit(address asset, uint256 amount, uint256 lockDuration)
    external payable returns (uint256 vaultId);

/// @notice Withdraw principal + yield from a vault after lock expires
/// @param vaultId Index of the vault to withdraw
function withdraw(uint256 vaultId) external;

/// @notice Get all vaults for a user
function getVaults(address user) external view returns (Vault[] memory);

/// @notice Get a single vault by user and index
function getVault(address user, uint256 vaultId) external view returns (Vault memory);

/// @notice Returns live accrued yield for a yielding vault
/// @dev Reads aToken balance delta from principal — call off-chain only
function totalYield(address user, uint256 vaultId) external view returns (uint256);

/// @notice Owner: add an asset to the whitelist
function whitelistAsset(address token) external;

/// @notice Owner: remove an asset from the whitelist
function removeAsset(address token) external;

/// @notice Owner: pause or resume yield deployment for new deposits
function setYieldEnabled(bool enabled) external;
```

### Events

```solidity
event VaultDeposited(
    address indexed depositor,
    uint256 indexed vaultId,
    address asset,
    uint256 amount,
    uint256 unlocksAt
);

event VaultWithdrawn(
    address indexed depositor,
    uint256 indexed vaultId,
    address asset,
    uint256 principal,
    uint256 yield
);

event AssetWhitelisted(address indexed asset);
event AssetRemoved(address indexed asset);
event YieldEnabledChanged(bool enabled);
```

### Custom Errors

```solidity
error Vault__ZeroAmount();
error Vault__LockDurationInvalid();
error Vault__AssetNotWhitelisted(address asset);
error Vault__ETHValueMismatch();
error Vault__InvalidVaultId(uint256 vaultId);
error Vault__AlreadyWithdrawn(uint256 vaultId);
error Vault__NotYetUnlocked(uint256 unlocksAt);
error Vault__TransferFailed();
error Vault__AaveSupplyFailed();
error Vault__AaveWithdrawFailed();
```

### Security Properties

- **Reentrancy:** CEI pattern — principal is zeroed before any external call (Aave or ETH transfer). No exceptions.
- **Integer overflow:** Solidity 0.8+ reverts on overflow by default.
- **Access control:** Owner controls whitelist and yield toggle only. No ability to touch user funds.
- **Denial of service:** No loops over unbounded state in write functions. `getVaults()` loops in a view function only.
- **ERC-20 safety:** All token transfers use `SafeERC20`. Broken token implementations (non-returning `transfer`) handled transparently.
- **Composability risk:** Funds deployed to Aave depend on Aave's solvency. Documented as an explicit trust assumption.

---

## Frontend Architecture

### Package Structure

```
packages/web/src/
├── components/
│   ├── ConnectButton.tsx        # Wallet connection
│   ├── DepositForm.tsx          # Asset selector, amount, lock duration, submit
│   ├── TokenSelector.tsx        # ETH + whitelisted ERC-20 dropdown
│   ├── ApproveButton.tsx        # Step 1 of ERC-20 deposit (hidden when not needed)
│   ├── VaultList.tsx            # Maps user vaults to VaultCard[]
│   ├── VaultCard.tsx            # Per-vault: asset, principal, yield, countdown, withdraw
│   ├── WithdrawButton.tsx       # Withdraw CTA with lock state
│   ├── YieldDisplay.tsx         # Live accruing yield counter
│   ├── EventFeed.tsx            # Live on-chain activity
│   └── Layout.tsx               # App shell
├── hooks/
│   ├── useVaults.ts             # getVaults() for connected user
│   ├── useVaultYield.ts         # totalYield() polled every 30s
│   ├── useTokenApproval.ts      # reads allowance, triggers approve()
│   ├── useDeposit.ts            # deposit() — ETH and ERC-20 paths
│   ├── useWithdraw.ts           # withdraw(vaultId)
│   ├── useWhitelistedAssets.ts  # reads token whitelist from contract
│   └── useVaultEvents.ts        # VaultDeposited / VaultWithdrawn watcher
├── lib/
│   ├── contract.ts              # ABI + address constants
│   ├── wagmi.ts                 # wagmi config (chains, transports)
│   └── format.ts                # formatEther, formatCountdown, formatAsset helpers
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

### Core Hook: `useVaults`

```typescript
// hooks/useVaults.ts
export function useVaults(userAddress?: Address) {
  const { data: vaults, isLoading, error } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: 'getVaults',
    args: [userAddress ?? zeroAddress],
    query: { enabled: !!userAddress },
  })

  const activeVaults = vaults?.filter(v => v.principal > 0n) ?? []

  return { vaults: activeVaults, isLoading, error }
}
```

### ERC-20 Approval Hook: `useTokenApproval`

```typescript
// hooks/useTokenApproval.ts
export function useTokenApproval(token: Address | undefined, amount: bigint) {
  const { address } = useAccount()

  const { data: allowance } = useReadContract({
    address: token,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address ?? zeroAddress, VAULT_ADDRESS],
    query: { enabled: !!token && !!address },
  })

  const needsApproval = !!token && allowance !== undefined && allowance < amount

  const { writeContractAsync, isPending } = useWriteContract()

  const approve = async () => {
    if (!token) return
    await writeContractAsync({
      address: token,
      abi: erc20Abi,
      functionName: 'approve',
      args: [VAULT_ADDRESS, amount],
    })
  }

  return { needsApproval, approve, isPending }
}
```

---

## Data Flow

### ETH Deposit Flow

```
User inputs amount + lock duration (asset = ETH)
  → DepositForm validates (amount > 0, duration in range)
  → useDeposit hook calls writeContractAsync with msg.value
  → wagmi sends tx to Base network
  → User confirms in wallet
  → Pending state shown in UI
  → BaseVaultV2: records vault, calls wethGateway.depositETH(), vault.yielding = true
  → Tx confirmed → VaultDeposited event emitted
  → useVaults re-fetches → VaultList updates
  → EventFeed picks up new event
```

### ERC-20 Deposit Flow

```
User selects ERC-20 token + inputs amount + lock duration
  → useTokenApproval detects allowance < amount → shows ApproveButton
  → User clicks Approve → approve() tx sent → confirmed
  → ApproveButton hidden, DepositForm enabled
  → useDeposit hook calls writeContractAsync (no msg.value)
  → BaseVaultV2: safeTransferFrom pulls tokens, calls pool.supply(), vault.yielding = true
  → Tx confirmed → VaultDeposited event emitted
  → useVaults re-fetches → VaultList updates
```

### Withdraw Flow

```
User clicks Withdraw on a VaultCard
  → useWithdraw checks isLocked (button disabled if true)
  → writeContractAsync called with vaultId
  → User confirms in wallet
  → BaseVaultV2 (CEI):
      1. Checks: vault exists, not already withdrawn, lock expired
      2. Effects: principal zeroed
      3. Interactions: Aave withdraw (returns principal + yield) → transfer to user
  → VaultWithdrawn event emitted with yield amount
  → useVaults re-fetches → VaultCard removed or shows withdrawn state
  → EventFeed picks up withdrawal with yield
```

---

## Constraints & Design Decisions

**`vaultId` is an array index scoped per user.** No global counter needed. Simple, gas-efficient, and each user's vault IDs start from 0 independently. Tradeoff: IDs are never reused after withdrawal — a withdrawn vault stays in the array with `principal = 0`.

**`address(0)` represents ETH.** Consistent with how other DeFi protocols distinguish native ETH from ERC-20. Makes the deposit function signature uniform across asset types.

**Yield is optional per vault, not per contract.** `vault.yielding` records whether a specific vault's funds went to Aave. If yield is paused when a user deposits, their vault is still created — it just holds funds directly and returns principal only. Existing yielding vaults are unaffected by the pause.

**No upgradability.** Proxy patterns introduce admin keys and complexity. `BaseVaultV2.sol` is immutable. If a critical bug is found post-mainnet, the response is: pause deposits, communicate publicly, deploy v3 at a new address.

**Aave integration is a trust dependency.** `BaseVaultV2.sol` supplies user funds to Aave v3. If Aave is exploited or paused, user funds could be affected. This is documented explicitly and is an acceptable tradeoff for a portfolio project demonstrating composability.

**One whitelist, owner-controlled.** The owner can add or remove ERC-20 tokens. Removal only blocks new deposits — existing vaults with that asset are unaffected and can still withdraw.
