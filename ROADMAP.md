# BaseVault — Roadmap

Each phase has explicit acceptance criteria. A phase is complete only when all criteria pass. Phases are sized for 2–4 hours/week of focused work.

---

## Phase 1 — Storage Redesign & Multi-Vault (Weeks 1–3)

**Goal:** Deploy `BaseVaultV2.sol` with a new storage model that supports multiple concurrent ETH vaults per user.

### Tasks
- Create `BaseVaultV2.sol` as a new file (keep `BaseVault.sol` intact — v1 stays deployed)
- Redesign storage: `mapping(address => Vault[])` replacing `mapping(address => Deposit)`
- Implement `deposit(uint256 lockDuration) external payable returns (uint256 vaultId)`
- Implement `withdraw(uint256 vaultId) external` — CEI pattern, indexed by vault ID
- Implement `getVaults(address user)` and `getVault(address user, uint256 vaultId)` view functions
- Update events to include `vaultId` and `asset` fields
- Add new custom errors: `Vault__InvalidVaultId`, `Vault__AlreadyWithdrawn`
- Write full test suite for multi-vault behavior

### Acceptance Criteria
- [ ] `forge build` passes with zero warnings on both `BaseVault.sol` and `BaseVaultV2.sol`
- [ ] User can create 3 concurrent ETH vaults with different lock durations
- [ ] Each vault tracks its own amount and unlock timestamp independently
- [ ] `withdraw(0)` withdraws vault 0 without affecting vault 1
- [ ] Withdrawing a vault marks it as withdrawn — second withdrawal reverts with `Vault__AlreadyWithdrawn`
- [ ] `getVaults()` returns the correct array for any address
- [ ] Fuzz test: create N vaults (N = 1–10), withdraw each in random order, assert correct amounts
- [ ] Reentrancy test: malicious contract attempts re-entry during ETH withdrawal, fails
- [ ] 100% line/branch/function coverage on `BaseVaultV2.sol`
- [ ] All existing `BaseVault.sol` tests still pass

---

## Phase 2 — ERC-20 Support (Weeks 4–6)

**Goal:** Extend `deposit()` to accept any whitelisted ERC-20 token in addition to ETH. Introduce an owner-controlled token whitelist.

### Tasks
- Add `Ownable` from OpenZeppelin, set owner in constructor
- Add `mapping(address => bool) public whitelistedAssets` with `whitelistAsset(address)` and `removeAsset(address)` owner functions
- Update `deposit()` signature to `deposit(address asset, uint256 amount, uint256 lockDuration) external payable`
- Implement ETH path: `asset == address(0)`, use `msg.value`
- Implement ERC-20 path: validate `msg.value == 0`, use `SafeERC20.safeTransferFrom`
- Update `withdraw()` to return correct asset (ETH via `call`, ERC-20 via `SafeERC20.safeTransfer`)
- Add new custom errors: `Vault__AssetNotWhitelisted`, `Vault__ETHValueMismatch`
- Write tests using OpenZeppelin's `ERC20Mock`

### Acceptance Criteria
- [ ] ETH deposits work identically to Phase 1 behavior
- [ ] ERC-20 deposit pulls tokens from user via `safeTransferFrom` after user approval
- [ ] ERC-20 withdrawal returns correct token amount via `safeTransfer`
- [ ] Depositing a non-whitelisted token reverts with `Vault__AssetNotWhitelisted`
- [ ] Depositing ETH while specifying an ERC-20 address reverts with `Vault__ETHValueMismatch`
- [ ] Only owner can whitelist/remove tokens — non-owner call reverts
- [ ] Fuzz test: random ERC-20 amounts deposit and withdraw correctly
- [ ] Multi-vault test: user holds one ETH vault and one ERC-20 vault simultaneously
- [ ] 100% coverage maintained

---

## Phase 3 — Aave Yield Integration (Weeks 7–11)

**Goal:** Deploy idle vault funds into Aave v3 on Base while locked. Yield accrues to the depositor and is returned alongside principal on withdrawal.

### Tasks
- Add `IPool` and `IWETHGateway` Aave v3 interfaces (copy from Aave's GitHub)
- Add Aave Pool address and WETH Gateway address as immutable constructor parameters
- Update `deposit()`: after recording state, supply to Aave (`pool.supply()` for ERC-20, `wethGateway.depositETH()` for ETH), set `vault.yielding = true`
- Update `withdraw()`: if `vault.yielding == true`, call Aave withdraw, calculate yield = returned amount − principal, return both to user
- Add `totalYield(address user, uint256 vaultId) external view` — returns live accrued yield via aToken balance delta
- Add owner-controlled `yieldEnabled` flag — pauses new yield deployments without affecting existing vaults or withdrawals
- Write fork tests against Base Sepolia using Foundry's `vm.createFork`

### Acceptance Criteria
- [ ] ETH deposit supplies to Aave via WETH Gateway on Base Sepolia fork
- [ ] ERC-20 deposit (USDC) supplies to Aave Pool on Base Sepolia fork
- [ ] After `vm.warp(+30 days)`, aToken balance exceeds principal — yield has accrued
- [ ] `withdraw()` returns principal + yield to user in a single transaction
- [ ] `totalYield()` returns correct accrued yield at any point during the lock period
- [ ] `vault.yielding == false` for any vault created while yield is paused
- [ ] Owner can disable/re-enable yield deployment — existing vault withdrawals unaffected
- [ ] Fork tests pass against live Base Sepolia Aave v3 deployment
- [ ] All non-fork unit tests maintain 100% coverage

---

## Phase 4 — React Frontend v2 (Weeks 12–15)

**Goal:** Rebuild the UI around multi-vault architecture. Add token selector, vault list view, ERC-20 approval flow, and live yield display.

### Tasks
- Replace single `VaultStatus` with `VaultList` + `VaultCard` per-vault components
- Build `TokenSelector` — ETH and all whitelisted ERC-20s from contract
- Build `ApproveButton` — step 1 of ERC-20 deposit flow, hidden when allowance is sufficient
- Build `useTokenApproval` hook — reads current allowance, triggers `approve()`
- Build `useVaults` hook — `getVaults()` for connected user
- Build `useVaultYield` hook — polls `totalYield()` every 30 seconds
- Update `EventFeed` to handle `vaultId` in events
- Update all error messages for new custom errors

### Acceptance Criteria
- [ ] Deposit form shows token selector (ETH + all whitelisted ERC-20s)
- [ ] ERC-20 deposit shows two-step flow: Approve → Deposit, in that order
- [ ] Approve button is hidden when allowance is already sufficient
- [ ] `VaultList` shows all active vaults for connected wallet
- [ ] Each `VaultCard` displays: asset, principal, live yield, unlock countdown, withdraw button
- [ ] `WithdrawButton` is disabled with reason when lock is active
- [ ] Yield display updates every 30 seconds without full page reload
- [ ] Empty state shown when user has no vaults
- [ ] All contract errors surface as human-readable messages in the UI
- [ ] App works on mobile viewport
- [ ] All v1 frontend tests still pass; new components have test coverage

---

## Phase 5 — Redeploy & Document (Week 16)

**Goal:** `BaseVaultV2.sol` live on Base Sepolia, all documentation updated, CI running fork tests.

### Tasks
- Deploy `BaseVaultV2.sol` with Aave Pool and WETH Gateway addresses as constructor args
- Verify contract source on Basescan
- Whitelist USDC and WETH on Base Sepolia via `cast send`
- Update `ARCHITECTURE.md` with v2 contract interface and Aave integration diagram
- Update `CLAUDE.md` with new contract address and v2 environment variables
- Update README with v2 feature overview and setup instructions
- Add fork test job to GitHub Actions CI (requires `BASE_SEPOLIA_RPC_URL` in repo secrets)
- Deploy frontend v2 to Vercel

### Acceptance Criteria
- [ ] `BaseVaultV2.sol` deployed and source-verified on Base Sepolia
- [ ] Multi-asset vault creation works on live testnet
- [ ] Yield display visible in UI after time elapses on testnet
- [ ] All docs reflect v2 state — no v1-only references remain
- [ ] CI passes including fork test job
- [ ] Frontend v2 live at updated Vercel URL
- [ ] GitHub repo README links to live demo and contract on Basescan
