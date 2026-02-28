# BaseVault — Concept & Coding Guidelines

## What Is BaseVault?

BaseVault is a commitment savings protocol on Base. The core mechanic is simple: you deposit ETH into a vault, set a lock period, and cannot withdraw until that period ends. No yield, no complexity — just a time-enforced savings commitment on-chain.

Think of it as a piggy bank you can't smash early.

## Why Build This?

### Learning Goals
- Understand core Solidity patterns: state management, access control, events, custom errors
- Learn the Checks-Effects-Interactions (CEI) pattern and why it matters (reentrancy)
- Get comfortable with Foundry: writing tests, fuzzing, deployment scripts
- Understand how a frontend connects to a smart contract via wagmi + viem
- Learn to read and interpret on-chain events

### Portfolio Goals
- Demonstrate smart contract fundamentals without overreaching
- Show the full stack: Solidity contract → TypeScript frontend → on-chain event monitoring
- Highlight the connection to existing work (analytics, monitoring, LLM tooling if extended later)
- Ship something real, deployed, and publicly verifiable — not a tutorial clone

## What Makes This Different From a Tutorial

Most Solidity tutorials teach you to copy an existing protocol. BaseVault is a complete original project with:

- A real use case (commitment savings is a proven behavioral finance concept)
- Production-quality code standards from day one
- A monitoring layer that mirrors professional observability work
- A clean, mobile-friendly UI — rare for smart contract portfolio projects
- Full test coverage including fuzz and reentrancy tests

---

## Coding Guidelines

### Smart Contracts

**Always use the Checks-Effects-Interactions (CEI) pattern.**
Every state-changing function must: first check all conditions and revert if invalid, then update all state variables, and only then interact with external contracts or transfer ETH. This prevents reentrancy attacks.

```solidity
// ✅ Correct — CEI
function withdraw() external {
    // Checks
    Deposit memory dep = deposits[msg.sender];
    if (dep.amount == 0) revert Vault__NothingToWithdraw();
    if (block.timestamp < dep.unlocksAt) revert Vault__NotYetUnlocked();

    // Effects
    uint256 amount = dep.amount;
    delete deposits[msg.sender];

    // Interactions
    (bool success, ) = msg.sender.call{value: amount}("");
    if (!success) revert Vault__TransferFailed();
}

// ❌ Wrong — interactions before effects (reentrancy risk)
function withdraw() external {
    uint256 amount = deposits[msg.sender].amount;
    (bool success, ) = msg.sender.call{value: amount}(""); // attacker re-enters here
    delete deposits[msg.sender]; // too late
}
```

**Use custom errors, not revert strings.** They are more gas efficient and easier to handle in the frontend.

```solidity
// ✅
error Vault__NotYetUnlocked();
revert Vault__NotYetUnlocked();

// ❌
require(block.timestamp >= dep.unlocksAt, "Not yet unlocked");
```

**Emit events for every state change.** Events are the audit trail of a contract. They also power the frontend's activity feed.

**Use named constants for any number that appears more than once.** `uint256 public constant MIN_LOCK_DURATION = 1 days;` is better than a raw `86400` anywhere.

**Write NatSpec comments on all public and external functions.** This is how the ABI becomes human-readable on Basescan.

```solidity
/// @notice Deposit ETH into the vault with a time lock
/// @param lockDuration Duration in seconds before withdrawal is permitted
function deposit(uint256 lockDuration) external payable { ... }
```

---

### Frontend (React + TypeScript)

**All contract interactions go through custom hooks.** Never call `useReadContract` or `useWriteContract` directly inside a component. Always wrap them in a hook like `useVault`.

```typescript
// ✅ hooks/useVault.ts
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

**Write at least one fuzz test.** Foundry's fuzzer is one of its best features. Use it.

```solidity
function testFuzz_deposit_recordsAmount(uint96 amount) public {
    vm.assume(amount > 0);
    vm.deal(user, amount);
    vm.prank(user);
    vault.deposit{value: amount}(30 days);
    assertEq(vault.getDeposit(user).amount, amount);
}
```

**Test reentrancy explicitly.** Write a malicious contract that tries to re-enter on withdrawal and assert it fails.

**Use `vm.warp` to test time-dependent logic.** Don't leave time-based tests as unverified assumptions.

```solidity
vm.warp(block.timestamp + 31 days);
vault.withdraw(); // should succeed now
```

---

## Guiding Principles

**Finish over feature.** A deployed, working, minimal product is worth more than an ambitious unfinished one. Resist scope creep — stretch goals are in the roadmap for after v1 ships.

**Readable over clever.** This is a learning project with a public audience. Prefer clarity over optimization unless there's a clear gas reason not to.

**Document decisions.** If you make an architectural choice (why ETH-only first, why a single vault per user, why that lock duration range), leave a comment explaining it. Future you — and interviewers — will appreciate it.

**Ship to testnet early.** There's no substitute for interacting with a real deployed contract. Deploy as soon as Phase 2 is complete.
