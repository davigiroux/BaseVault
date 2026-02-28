# BaseVault — Roadmap

Each phase has explicit acceptance criteria. A phase is complete only when all criteria pass. Phases are sized for 2–4 hours/week of focused work.

---

## Phase 1 — Foundations (Weeks 1–2)

**Goal:** Working Foundry environment with a deployable contract skeleton.

### Tasks
- Initialize monorepo with pnpm workspaces
- Set up Foundry project inside `packages/contracts`
- Install OpenZeppelin v5 via forge
- Write `BaseVault.sol` skeleton with state variables, custom errors, and events (no logic yet)
- Write first Foundry test file that compiles and runs

### Acceptance Criteria
- [ ] `forge build` passes with zero warnings
- [ ] `forge test` runs and all tests pass (even if trivial)
- [ ] Contract defines: `owner`, `lockDuration`, `deposits` mapping, `VaultDeposited` event, `VaultWithdrawn` event
- [ ] Custom errors defined: `Vault__ZeroAmount`, `Vault__NotYetUnlocked`, `Vault__NothingToWithdraw`, `Vault__TransferFailed`
- [ ] README documents how to run the project locally

---

## Phase 2 — Core Contract Logic (Weeks 3–5)

**Goal:** Fully functional and tested ETH vault contract.

### Tasks
- Implement `deposit()` — accepts ETH, records amount and timestamp per depositor
- Implement `withdraw()` — enforces lock period, transfers ETH back, follows CEI pattern
- Implement `getDeposit(address)` view function
- Write comprehensive Foundry tests

### Acceptance Criteria
- [ ] `deposit()` correctly stores amount and `block.timestamp` for the depositor
- [ ] `withdraw()` reverts with `Vault__NotYetUnlocked` before lock period ends
- [ ] `withdraw()` reverts with `Vault__NothingToWithdraw` if no deposit exists
- [ ] `withdraw()` correctly transfers ETH and clears the deposit record
- [ ] Reentrancy attack test: contract resists reentrant withdrawal attempt
- [ ] Fuzz test on `deposit()`: any amount > 0 is correctly recorded
- [ ] `forge coverage` shows >90% line coverage on `BaseVault.sol`

---

## Phase 3 — Testnet Deployment (Week 6)

**Goal:** Contract live on Base Sepolia, verified on Basescan.

### Tasks
- Write `Deploy.s.sol` deployment script
- Configure `foundry.toml` with Base Sepolia RPC
- Deploy to Base Sepolia
- Verify contract on Basescan
- Test live contract with `cast` CLI calls

### Acceptance Criteria
- [ ] Contract deployed to Base Sepolia with a public address
- [ ] Contract source verified on Basescan (readable ABI and source)
- [ ] Successful `deposit` transaction visible on Basescan
- [ ] Successful `withdraw` transaction after lock period visible on Basescan
- [ ] Deployment address documented in `ARCHITECTURE.md`

---

## Phase 4 — React Frontend (Weeks 7–10)

**Goal:** Clean, functional UI that connects to the deployed contract.

### Tasks
- Initialize Vite + React + TypeScript project in `packages/web`
- Configure wagmi v2 with Base Sepolia + Base Mainnet
- Build wallet connection flow (RainbowKit or ConnectKit)
- Build `useVault` custom hook wrapping all contract interactions
- Build `DepositForm` component
- Build `VaultStatus` component showing lock time remaining and deposited amount
- Build `WithdrawButton` component with disabled state during lock

### Acceptance Criteria
- [ ] User can connect wallet on Base Sepolia
- [ ] `DepositForm` validates input (no zero, no negative) before submitting
- [ ] Transaction pending state is shown during deposit/withdraw
- [ ] `VaultStatus` displays correct deposited amount (formatted, not raw BigInt)
- [ ] `VaultStatus` displays a countdown or date for when withdrawal unlocks
- [ ] `WithdrawButton` is disabled and shows reason when lock is active
- [ ] All contract errors surface as human-readable messages in the UI
- [ ] App works on mobile viewport

---

## Phase 5 — On-Chain Event Monitor (Weeks 11–13)

**Goal:** A live activity feed of vault events, showcasing the analytics/monitoring skillset.

### Tasks
- Use `viem` public client to watch `VaultDeposited` and `VaultWithdrawn` events
- Build `EventFeed` component displaying recent activity (address, amount, timestamp)
- Optionally: aggregate total TVL from events

### Acceptance Criteria
- [ ] `EventFeed` displays last 20 on-chain events in real time
- [ ] New events appear without page refresh
- [ ] Addresses are truncated and linkable to Basescan
- [ ] Amounts are formatted correctly (ETH, not wei)
- [ ] Component degrades gracefully when RPC is slow or unavailable

---

## Phase 6 — Polish & Launch (Week 14+)

**Goal:** Public-facing project ready to share on GitHub and LinkedIn.

### Tasks
- Write thorough README with architecture diagram, setup instructions, and live demo link
- Deploy frontend to Vercel
- (Optional) Deploy contract to Base Mainnet
- Add GitHub Actions CI: `forge test` + `pnpm typecheck` on every PR

### Acceptance Criteria
- [ ] README is clear enough for another engineer to run the project from scratch
- [ ] Frontend accessible at a public URL
- [ ] CI passes on main branch
- [ ] GitHub repo is public and linked from LinkedIn

---

## Stretch Goals (Post-Launch)

These are not in scope for the initial build but are natural extensions if you want to go deeper:

- **ERC-20 support** — allow depositing any whitelisted token, not just ETH
- **Multiple vaults per user** — support concurrent deposits with different lock periods
- **Yield integration** — deposit idle funds into Aave/Compound while locked
- **Goal-based savings** — user sets a target amount; contract enforces both time and amount locks
