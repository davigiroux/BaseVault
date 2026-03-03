# BaseVault — Concept & Coding Guidelines

## What Is BaseVault?

BaseVault is a commitment savings protocol on Base. Users deposit ETH or ERC-20 tokens into time-locked vaults — withdrawals are blocked until the lock period expires. While funds are locked, they are deployed to Aave v3 to earn yield, which is returned to the depositor on withdrawal alongside their principal.

Each user can hold multiple independent vaults simultaneously, each with its own asset, amount, and lock duration.

Think of it as a piggy bank you can't smash early — that earns interest while you wait.

## Why Build This?

### Learning Goals
- Understand core Solidity patterns: state management, access control, events, custom errors
- Learn the Checks-Effects-Interactions (CEI) pattern and why it matters (reentrancy)
- Get comfortable with Foundry: writing tests, fuzzing, fork testing, deployment scripts
- Master ERC-20 mechanics: SafeERC20, the approve/transferFrom flow, multi-asset accounting
- Understand protocol composability by integrating with Aave v3 (supply, aTokens, withdrawal)
- Understand how a frontend connects to a smart contract via wagmi + viem

### Portfolio Goals
- Demonstrate smart contract fundamentals and protocol-level thinking
- Show the full stack: Solidity contract → TypeScript frontend → on-chain event monitoring
- Signal DeFi protocol competency through Aave integration, not just basic Solidity
- Ship something real, deployed, and publicly verifiable — not a tutorial clone

## What Makes This Different From a Tutorial

Most Solidity tutorials teach you to copy an existing protocol. BaseVault is a complete original project with:

- A real use case (commitment savings is a proven behavioral finance concept)
- Live Aave v3 integration — funds earn real yield on Base
- Production-quality code standards from day one
- Fork tests against live protocol state, not just mocked unit tests
- A clean, mobile-friendly UI with ERC-20 approval flow — rare for smart contract portfolio projects
- Full test coverage including fuzz, reentrancy, and fork tests

---

## Coding Guidelines

### Smart Contracts

**Always use the Checks-Effects-Interactions (CEI) pattern.**
Every state-changing function must: first check all conditions and revert if invalid, then update all state variables, and only then interact with external contracts or transfer ETH. This prevents reentrancy attacks. This is especially critical now that `withdraw()` calls into Aave before returning funds.

```solidity
// ✅ Correct — CEI, even with Aave interaction
function withdraw(uint256 vaultId) external {
    // Checks
    Vault memory v = _getValidVault(msg.sender, vaultId);
    if (block.timestamp < v.unlocksAt) revert Vault__NotYetUnlocked();

    // Effects
    uint256 principal = v.principal;
    vaults[msg.sender][vaultId].principal = 0; // mark withdrawn before interactions

    // Interactions — Aave first, then return to user
    uint256 returned = v.yielding ? _withdrawFromAave(v) : principal;
    uint256 yield = returned - principal;
    _returnFunds(msg.sender, v.asset, returned);

    emit VaultWithdrawn(msg.sender, vaultId, v.asset, principal, yield);
}
```

**Use custom errors, not revert strings.** They are more gas efficient and easier to handle in the frontend.

```solidity
// ✅
error Vault__NotYetUnlocked();
revert Vault__NotYetUnlocked();

// ❌
require(block.timestamp >= v.unlocksAt, "Not yet unlocked");
```

**Emit events for every state change.** Events are the audit trail of a contract. They also power the frontend's activity feed.

**Use `SafeERC20` for all token transfers without exception.** Some ERC-20 tokens (USDT, others) don't correctly return `bool` on transfer. `SafeERC20` handles these silently broken tokens.

```solidity
// ✅
using SafeERC20 for IERC20;
IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

// ❌
IERC20(asset).transferFrom(msg.sender, address(this), amount);
```

**Use named constants for any number that appears more than once.**

```solidity
uint256 public constant MIN_LOCK_DURATION = 1 days;
uint256 public constant MAX_LOCK_DURATION = 365 days;
```

**Write NatSpec comments on all public and external functions.** This is how the ABI becomes human-readable on Basescan.

```solidity
/// @notice Deposit an asset into a new time-locked vault
/// @param asset Token address, or address(0) for ETH
/// @param amount Amount to deposit (ignored for ETH — use msg.value)
/// @param lockDuration Seconds until withdrawal is permitted
/// @return vaultId Index of the newly created vault for this user
function deposit(address asset, uint256 amount, uint256 lockDuration)
    external payable returns (uint256 vaultId) { ... }
```

---

### Frontend (React + TypeScript)

**All contract interactions go through custom hooks.** Never call `useReadContract` or `useWriteContract` directly inside a component. Always wrap them in a purpose-built hook.

```typescript
// ✅ hooks/useDeposit.ts
export function useDeposit() {
  const { writeContractAsync, isPending } = useWriteContract()
  // ...
  return { deposit, isPending, error }
}

// ❌ directly in component
function DepositForm() {
  const { writeContract } = useWriteContract() // don't do this
}
```

**ERC-20 deposits require two transactions — model this explicitly.** The UI must check the current allowance before showing a deposit button. If allowance is insufficient, show Approve first.

```typescript
// ✅ hooks/useTokenApproval.ts
export function useTokenApproval(token: Address, amount: bigint) {
  const { data: allowance } = useReadContract({ functionName: 'allowance', ... })
  const needsApproval = allowance !== undefined && allowance < amount
  return { needsApproval, approve }
}
```

**Always handle three states: loading, error, success.** A component that ignores loading and error states is incomplete.

**Never render raw BigInt values.** Always use `viem`'s `formatEther` or `formatUnits` before displaying numbers.

```typescript
// ✅
import { formatEther } from 'viem'
<span>{formatEther(depositAmount)} ETH</span>

// ❌
<span>{depositAmount.toString()} ETH</span> // shows wei
```

**Contract errors should surface as readable messages.** Map known custom error selectors to human-readable strings. Don't let raw error objects reach the user.

**TypeScript strict mode is non-negotiable.** No `any`. If you're fighting the type system, that's usually a signal the data model needs work.

---

### Testing (Foundry)

**Every public/external function needs at least one happy path and one revert test.**

**Write at least one fuzz test per function with numeric inputs.** Foundry's fuzzer finds edge cases you'd never think to test manually.

```solidity
function testFuzz_deposit_recordsAmount(uint96 amount) public {
    vm.assume(amount > 0);
    vm.deal(user, amount);
    vm.prank(user);
    uint256 vaultId = vault.deposit{value: amount}(address(0), 0, 30 days);
    assertEq(vault.getVault(user, vaultId).principal, amount);
}
```

**Test reentrancy explicitly.** Write a malicious contract that tries to re-enter on withdrawal and assert it fails.

**Use `vm.warp` to test time-dependent logic.** Don't leave time-based tests as unverified assumptions.

```solidity
vm.warp(block.timestamp + 31 days);
vault.withdraw(vaultId); // should succeed now
```

**Use fork tests for Aave integration.** Unit mocks cannot accurately reproduce Aave's yield accrual math. Pin real Base Sepolia state with `vm.createFork` and test against the live protocol.

```solidity
function setUp() public {
    vm.createSelectFork(vm.envString("BASE_SEPOLIA_RPC_URL"));
    // deploy BaseVaultV2 against real Aave addresses
}
```

---

## Guiding Principles

**Finish over feature.** A deployed, working product is worth more than an ambitious unfinished one. Complete each phase fully before moving to the next.

**Readable over clever.** This is a learning project with a public audience. Prefer clarity over optimization unless there is a clear gas reason not to.

**Document decisions.** If you make an architectural choice — why `vaultId` is an array index rather than a global counter, why `address(0)` represents ETH, why yield can be paused independently of deposits — leave a comment explaining it. Future you, and interviewers, will appreciate it.

**Composability comes with risk.** Integrating with Aave means your contract's funds depend on Aave's security. Document this explicitly as a trust assumption. Permissionless doesn't mean risk-free.

**Ship to testnet early.** There's no substitute for interacting with a real deployed contract. Deploy at the end of Phase 1 and keep the testnet address updated throughout.
