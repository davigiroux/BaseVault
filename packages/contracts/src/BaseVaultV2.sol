// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title BaseVaultV2
/// @notice Multi-vault commitment savings — deposit ETH or whitelisted ERC-20 tokens into time-locked vaults
contract BaseVaultV2 is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    struct Vault {
        uint256 id; // Array index scoped per user
        address asset; // address(0) = ETH, otherwise ERC-20
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

    /// @notice Owner-controlled whitelist of accepted ERC-20 tokens
    mapping(address => bool) public whitelistedAssets;

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

    event AssetWhitelisted(address indexed asset);
    event AssetRemoved(address indexed asset);

    // ──────────────────────────────────────────────
    //  Custom Errors
    // ──────────────────────────────────────────────

    error Vault__ZeroAmount();
    error Vault__LockDurationInvalid();
    error Vault__AssetNotWhitelisted(address asset);
    error Vault__ETHValueMismatch();
    error Vault__InvalidVaultId(uint256 vaultId);
    error Vault__AlreadyWithdrawn(uint256 vaultId);
    error Vault__NotYetUnlocked(uint256 unlocksAt);
    error Vault__TransferFailed();

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    constructor() Ownable(msg.sender) {}

    // ──────────────────────────────────────────────
    //  External Functions
    // ──────────────────────────────────────────────

    /// @notice Deposit an asset into a new time-locked vault
    /// @param asset Token address, or address(0) for ETH (uses msg.value)
    /// @param amount Amount for ERC-20 deposits (ignored for ETH)
    /// @param lockDuration Duration in seconds before withdrawal is permitted
    /// @return vaultId Index of the newly created vault for this user
    function deposit(address asset, uint256 amount, uint256 lockDuration)
        external
        payable
        returns (uint256 vaultId)
    {
        // Checks — lock duration
        if (lockDuration < MIN_LOCK_DURATION || lockDuration > MAX_LOCK_DURATION) {
            revert Vault__LockDurationInvalid();
        }

        uint256 depositAmount;

        if (asset == address(0)) {
            // ETH path
            if (msg.value == 0) revert Vault__ZeroAmount();
            depositAmount = msg.value;
        } else {
            // ERC-20 path
            if (!whitelistedAssets[asset]) revert Vault__AssetNotWhitelisted(asset);
            if (msg.value != 0) revert Vault__ETHValueMismatch();
            if (amount == 0) revert Vault__ZeroAmount();
            depositAmount = amount;

            // Interactions — pull tokens (safe because state isn't written yet)
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        }

        // Effects
        uint256 unlocksAt = block.timestamp + lockDuration;
        vaultId = s_vaults[msg.sender].length;

        s_vaults[msg.sender].push(
            Vault({
                id: vaultId,
                asset: asset,
                principal: depositAmount,
                unlocksAt: unlocksAt,
                yielding: false
            })
        );

        emit VaultDeposited(msg.sender, vaultId, asset, depositAmount, unlocksAt);
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
        address asset = vault.asset;
        vault.principal = 0;

        emit VaultWithdrawn(msg.sender, vaultId, asset, amount, 0);

        // Interactions
        if (asset == address(0)) {
            (bool success,) = msg.sender.call{value: amount}("");
            if (!success) revert Vault__TransferFailed();
        } else {
            IERC20(asset).safeTransfer(msg.sender, amount);
        }
    }

    // ──────────────────────────────────────────────
    //  Owner Functions
    // ──────────────────────────────────────────────

    /// @notice Add an ERC-20 token to the whitelist
    /// @param token Address of the ERC-20 token to whitelist
    function whitelistAsset(address token) external onlyOwner {
        whitelistedAssets[token] = true;
        emit AssetWhitelisted(token);
    }

    /// @notice Remove an ERC-20 token from the whitelist (existing vaults unaffected)
    /// @param token Address of the ERC-20 token to remove
    function removeAsset(address token) external onlyOwner {
        whitelistedAssets[token] = false;
        emit AssetRemoved(token);
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
