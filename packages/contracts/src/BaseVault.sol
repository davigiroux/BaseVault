// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BaseVault
/// @notice Commitment savings vault — deposit ETH with a time lock, withdraw only after it expires
contract BaseVault is ReentrancyGuard {
    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    struct Deposit {
        uint256 amount; // ETH deposited in wei
        uint256 unlocksAt; // Unix timestamp when withdrawal is permitted
    }

    // ──────────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────────

    uint256 public constant MIN_LOCK_DURATION = 1 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice Address that deployed the contract (informational only — no admin privileges)
    address public immutable owner;

    /// @notice Per-address deposit records (one active deposit per address)
    mapping(address => Deposit) public deposits;

    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    event VaultDeposited(
        address indexed depositor,
        uint256 amount,
        uint256 unlocksAt
    );
    event VaultWithdrawn(address indexed depositor, uint256 amount);

    // ──────────────────────────────────────────────
    //  Custom Errors
    // ──────────────────────────────────────────────

    error Vault__ZeroAmount();
    error Vault__LockDurationInvalid();
    error Vault__AlreadyDeposited();
    error Vault__NothingToWithdraw();
    error Vault__NotYetUnlocked();
    error Vault__TransferFailed();

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ──────────────────────────────────────────────
    //  External Functions
    // ──────────────────────────────────────────────

    /// @notice Deposit ETH into the vault with a time lock
    /// @param lockDuration Duration in seconds before withdrawal is permitted
    function deposit(uint256 lockDuration) external payable {
        // Checks
        if (msg.value == 0) revert Vault__ZeroAmount();
        if (
            lockDuration < MIN_LOCK_DURATION || lockDuration > MAX_LOCK_DURATION
        ) {
            revert Vault__LockDurationInvalid();
        }
        if (deposits[msg.sender].amount != 0) revert Vault__AlreadyDeposited();

        // Effects
        uint256 unlocksAt = block.timestamp + lockDuration;
        deposits[msg.sender] = Deposit({
            amount: msg.value,
            unlocksAt: unlocksAt
        });

        emit VaultDeposited(msg.sender, msg.value, unlocksAt);
    }

    /// @notice Withdraw all deposited ETH after the lock period has passed
    function withdraw() external nonReentrant {
        // Checks
        Deposit memory dep = deposits[msg.sender];
        if (dep.amount == 0) revert Vault__NothingToWithdraw();
        if (block.timestamp < dep.unlocksAt) revert Vault__NotYetUnlocked();

        // Effects
        uint256 amount = dep.amount;
        delete deposits[msg.sender];

        emit VaultWithdrawn(msg.sender, amount);

        // Interactions
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert Vault__TransferFailed();
    }

    // ──────────────────────────────────────────────
    //  View Functions
    // ──────────────────────────────────────────────

    /// @notice View deposit details for any address
    /// @param depositor Address to query
    /// @return Deposit struct with amount and unlocksAt timestamp
    function getDeposit(
        address depositor
    ) external view returns (Deposit memory) {
        return deposits[depositor];
    }
}
