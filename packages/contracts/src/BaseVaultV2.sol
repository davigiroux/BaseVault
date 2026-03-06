// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";
import {IWETHGateway} from "./interfaces/IWETHGateway.sol";

/// @title BaseVaultV2
/// @notice Multi-vault commitment savings — deposit ETH or whitelisted ERC-20 tokens into time-locked vaults.
///         When yield is enabled, idle funds are deployed to Aave v3 and returned with principal on withdrawal.
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
        bool yielding; // Whether funds are deployed to Aave
        address aToken; // Aave aToken address (address(0) if not yielding)
    }

    // ──────────────────────────────────────────────
    //  Constants
    // ──────────────────────────────────────────────

    uint256 public constant MIN_LOCK_DURATION = 1 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;

    // ──────────────────────────────────────────────
    //  Immutables
    // ──────────────────────────────────────────────

    /// @notice Aave v3 Pool — address(0) means yield is structurally disabled
    address public immutable AAVE_POOL;

    /// @notice Aave v3 WETHGateway for ETH deposits/withdrawals
    address public immutable WETH_GATEWAY;

    /// @notice Canonical WETH address used to look up the aWETH token from Aave
    address public immutable WETH;

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    /// @notice Per-user array of vaults (supports multiple concurrent vaults)
    mapping(address => Vault[]) private s_vaults;

    /// @notice Owner-controlled whitelist of accepted ERC-20 tokens
    mapping(address => bool) public whitelistedAssets;

    /// @notice Cached Aave aToken address per depositable asset (address(0) = ETH)
    mapping(address => address) public aTokenForAsset;

    /// @notice Total principal (in underlying units) currently held via Aave per aToken
    /// @dev Used for proportional yield accounting across concurrent vaults sharing an asset
    mapping(address => uint256) private s_totalATokenPrincipal;

    /// @notice When false, new deposits skip Aave and hold funds directly in the contract
    bool public yieldEnabled;

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
    event YieldToggled(bool enabled);

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

    /// @param aavePool   Aave v3 Pool address. Pass address(0) to disable yield entirely.
    /// @param wethGateway Aave v3 WETHGateway address.
    /// @param weth       Canonical WETH address (used to resolve aWETH from Aave).
    constructor(address aavePool, address wethGateway, address weth) Ownable(msg.sender) {
        AAVE_POOL = aavePool;
        WETH_GATEWAY = wethGateway;
        WETH = weth;

        if (aavePool != address(0) && weth != address(0)) {
            yieldEnabled = true;
            // Cache aWETH so deposit() never needs an external view call for ETH vaults
            aTokenForAsset[address(0)] =
                IAavePool(aavePool).getReserveData(weth).aTokenAddress;
        }
    }

    // ──────────────────────────────────────────────
    //  External Functions
    // ──────────────────────────────────────────────

    /// @notice Deposit an asset into a new time-locked vault
    /// @param asset        Token address, or address(0) for ETH (uses msg.value)
    /// @param amount       Amount for ERC-20 deposits (ignored for ETH)
    /// @param lockDuration Duration in seconds before withdrawal is permitted
    /// @return vaultId     Index of the newly created vault for this user
    function deposit(address asset, uint256 amount, uint256 lockDuration)
        external
        payable
        nonReentrant
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

            // Pull tokens before writing state — safe: vault doesn't exist yet, reentrancy guard active
            IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        }

        // Determine yield parameters
        address aToken = aTokenForAsset[asset];
        bool willYield = yieldEnabled && AAVE_POOL != address(0) && aToken != address(0);

        // Effects
        uint256 unlocksAt = block.timestamp + lockDuration;
        vaultId = s_vaults[msg.sender].length;

        s_vaults[msg.sender].push(
            Vault({
                id: vaultId,
                asset: asset,
                principal: depositAmount,
                unlocksAt: unlocksAt,
                yielding: willYield,
                aToken: willYield ? aToken : address(0)
            })
        );

        if (willYield) {
            s_totalATokenPrincipal[aToken] += depositAmount;
        }

        emit VaultDeposited(msg.sender, vaultId, asset, depositAmount, unlocksAt);

        // Interactions — supply to Aave
        if (willYield) {
            if (asset == address(0)) {
                IWETHGateway(WETH_GATEWAY).depositETH{value: depositAmount}(
                    AAVE_POOL, address(this), 0
                );
            } else {
                IERC20(asset).forceApprove(AAVE_POOL, depositAmount);
                IAavePool(AAVE_POOL).supply(asset, depositAmount, address(this), 0);
            }
        }
    }

    /// @notice Withdraw principal (and any accrued yield) from a vault after its lock period
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

        // Capture values before zeroing
        uint256 principal = vault.principal;
        address asset = vault.asset;
        bool yielding = vault.yielding;
        address aToken = vault.aToken;

        // Effects — zero principal and update aToken tracking before any interaction
        vault.principal = 0;

        uint256 totalReturn;
        uint256 yieldAmount;

        if (yielding) {
            uint256 totalPrincipal = s_totalATokenPrincipal[aToken];
            s_totalATokenPrincipal[aToken] -= principal;

            // Read live aToken balance after state is updated (safe: nonReentrant, aToken is trusted)
            uint256 aTokenBalance = IERC20(aToken).balanceOf(address(this));

            // Proportional share: this vault's fraction of the total aToken pool
            totalReturn =
                totalPrincipal > 0 ? (aTokenBalance * principal) / totalPrincipal : principal;
            yieldAmount = totalReturn > principal ? totalReturn - principal : 0;
        } else {
            totalReturn = principal;
        }

        emit VaultWithdrawn(msg.sender, vaultId, asset, principal, yieldAmount);

        // Interactions
        if (yielding) {
            if (asset == address(0)) {
                // Gateway requires prior approval to pull aWETH from this contract
                IERC20(aToken).forceApprove(WETH_GATEWAY, totalReturn);
                IWETHGateway(WETH_GATEWAY).withdrawETH(AAVE_POOL, totalReturn, msg.sender);
            } else {
                // Pool burns aTokens from msg.sender (this contract) directly — no approval needed
                IAavePool(AAVE_POOL).withdraw(asset, totalReturn, msg.sender);
            }
        } else {
            if (asset == address(0)) {
                (bool success,) = msg.sender.call{value: principal}("");
                if (!success) revert Vault__TransferFailed();
            } else {
                IERC20(asset).safeTransfer(msg.sender, principal);
            }
        }
    }

    // ──────────────────────────────────────────────
    //  Owner Functions
    // ──────────────────────────────────────────────

    /// @notice Add an ERC-20 token to the whitelist
    /// @dev If Aave is configured, also caches the aToken address for yield routing
    /// @param token Address of the ERC-20 token to whitelist
    function whitelistAsset(address token) external onlyOwner {
        whitelistedAssets[token] = true;
        if (AAVE_POOL != address(0)) {
            aTokenForAsset[token] = IAavePool(AAVE_POOL).getReserveData(token).aTokenAddress;
        }
        emit AssetWhitelisted(token);
    }

    /// @notice Remove an ERC-20 token from the whitelist
    /// @dev Existing vaults are unaffected — their aToken is stored in the Vault struct
    /// @param token Address of the ERC-20 token to remove
    function removeAsset(address token) external onlyOwner {
        whitelistedAssets[token] = false;
        emit AssetRemoved(token);
    }

    /// @notice Enable or disable Aave yield deployment for new deposits
    /// @dev Does not affect existing yielding vaults — those always withdraw via Aave
    /// @param enabled True to enable, false to disable
    function setYieldEnabled(bool enabled) external onlyOwner {
        yieldEnabled = enabled;
        emit YieldToggled(enabled);
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
    /// @param user    Address to query
    /// @param vaultId Index of the vault
    /// @return The vault at the given index
    function getVault(address user, uint256 vaultId) external view returns (Vault memory) {
        if (vaultId >= s_vaults[user].length) {
            revert Vault__InvalidVaultId(vaultId);
        }
        return s_vaults[user][vaultId];
    }

    /// @notice Returns the live accrued yield for a vault (0 if not yielding or already withdrawn)
    /// @param user    Address of the vault owner
    /// @param vaultId Index of the vault
    function totalYield(address user, uint256 vaultId) external view returns (uint256) {
        if (vaultId >= s_vaults[user].length) revert Vault__InvalidVaultId(vaultId);

        Vault memory v = s_vaults[user][vaultId];
        if (!v.yielding || v.principal == 0) return 0;

        uint256 totalPrincipal = s_totalATokenPrincipal[v.aToken];
        if (totalPrincipal == 0) return 0;

        uint256 aTokenBalance = IERC20(v.aToken).balanceOf(address(this));
        uint256 currentValue = (aTokenBalance * v.principal) / totalPrincipal;
        return currentValue > v.principal ? currentValue - v.principal : 0;
    }
}
