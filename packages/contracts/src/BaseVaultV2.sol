// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BaseVaultV2
/// @notice Multi-vault commitment savings — deposit ETH into independent time-locked vaults
contract BaseVaultV2 is ReentrancyGuard {
    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    struct Vault {
        uint256 id; // Array index scoped per user
        address asset; // address(0) = ETH, ERC-20 address in Phase 2
        uint256 principal; // Original deposit amount (0 = withdrawn)
        uint256 unlocksAt; // Unix timestamp when withdrawal is permitted
        bool yielding; // Whether funds are deployed to Aave (Phase 3)
    }

    // ──────────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────────

    uint256 public constant MIN_LOCK_DURATION = 1 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice Per-user array of vaults (supports multiple concurrent vaults)
    mapping(address => Vault[]) private s_vaults;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

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
        uint256 yield_
    );

    // ──────────────────────────────────────────────
    //  Custom Errors
    // ──────────────────────────────────────────────

    error Vault__ZeroAmount();
    error Vault__LockDurationInvalid();
    error Vault__InvalidVaultId(uint256 vaultId);
    error Vault__AlreadyWithdrawn(uint256 vaultId);
    error Vault__NotYetUnlocked(uint256 unlocksAt);
    error Vault__TransferFailed();

    // ──────────────────────────────────────────────
    //  External Functions
    // ──────────────────────────────────────────────

    /// @notice Deposit ETH into a new time-locked vault
    /// @param lockDuration Duration in seconds before withdrawal is permitted
    /// @return vaultId Index of the newly created vault for this user
    function deposit(uint256 lockDuration) external payable returns (uint256 vaultId) {
        // Checks
        if (msg.value == 0) revert Vault__ZeroAmount();
        if (lockDuration < MIN_LOCK_DURATION || lockDuration > MAX_LOCK_DURATION) {
            revert Vault__LockDurationInvalid();
        }

        // Effects
        uint256 unlocksAt = block.timestamp + lockDuration;
        vaultId = s_vaults[msg.sender].length;

        s_vaults[msg.sender].push(
            Vault({
                id: vaultId,
                asset: address(0),
                principal: msg.value,
                unlocksAt: unlocksAt,
                yielding: false
            })
        );

        emit VaultDeposited(msg.sender, vaultId, address(0), msg.value, unlocksAt);
    }

    /// @notice Withdraw principal from a vault after its lock period has passed
    /// @param vaultId Index of the vault to withdraw
    function withdraw(uint256 vaultId) external nonReentrant {
        // Checks
        if (vaultId >= s_vaults[msg.sender].length) {
            revert Vault__InvalidVaultId(vaultId);
        }

        Vault storage vault = s_vaults[msg.sender][vaultId];

        if (vault.principal == 0) revert Vault__AlreadyWithdrawn(vaultId);
        if (block.timestamp < vault.unlocksAt) {
            revert Vault__NotYetUnlocked(vault.unlocksAt);
        }

        // Effects — zero principal before external call (CEI)
        uint256 amount = vault.principal;
        vault.principal = 0;

        emit VaultWithdrawn(msg.sender, vaultId, address(0), amount, 0);

        // Interactions
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert Vault__TransferFailed();
    }

    // ──────────────────────────────────────────────
    //  View Functions
    // ──────────────────────────────────────────────

    /// @notice Get all vaults for a user
    /// @param user Address to query
    /// @return Array of all vaults (including withdrawn ones with principal = 0)
    function getVaults(address user) external view returns (Vault[] memory) {
        return s_vaults[user];
    }

    /// @notice Get a single vault by user and index
    /// @param user Address to query
    /// @param vaultId Index of the vault
    /// @return The vault at the given index
    function getVault(address user, uint256 vaultId) external view returns (Vault memory) {
        if (vaultId >= s_vaults[user].length) {
            revert Vault__InvalidVaultId(vaultId);
        }
        return s_vaults[user][vaultId];
    }
}
