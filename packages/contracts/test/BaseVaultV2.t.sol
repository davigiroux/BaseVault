// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BaseVaultV2} from "../src/BaseVaultV2.sol";
import {IAavePool} from "../src/interfaces/IAavePool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BaseVaultV2Test is Test {
    BaseVaultV2 public vault;
    ERC20Mock public token;
    address public user = makeAddr("user");
    address public nonOwner = makeAddr("nonOwner");

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

    function setUp() public {
        // Deploy with no Aave — all yield paths are disabled, existing tests are unaffected
        vault = new BaseVaultV2(address(0), address(0), address(0));
        token = new ERC20Mock();
        vm.deal(user, 100 ether);
        token.mint(user, 1000e18);
        vault.whitelistAsset(address(token));
    }

    // ── Deployment ──────────────────────────────

    function test_constants_areSet() public view {
        assertEq(vault.MIN_LOCK_DURATION(), 1 days);
        assertEq(vault.MAX_LOCK_DURATION(), 365 days);
    }

    function test_owner_isDeployer() public view {
        assertEq(vault.owner(), address(this));
    }

    // ── Whitelist — owner functions ─────────────

    function test_whitelistAsset_setsMapping() public {
        ERC20Mock newToken = new ERC20Mock();
        vault.whitelistAsset(address(newToken));
        assertTrue(vault.whitelistedAssets(address(newToken)));
    }

    function test_whitelistAsset_emitsEvent() public {
        ERC20Mock newToken = new ERC20Mock();
        vm.expectEmit(true, false, false, false);
        emit AssetWhitelisted(address(newToken));
        vault.whitelistAsset(address(newToken));
    }

    function test_removeAsset_clearsMapping() public {
        vault.removeAsset(address(token));
        assertFalse(vault.whitelistedAssets(address(token)));
    }

    function test_removeAsset_emitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit AssetRemoved(address(token));
        vault.removeAsset(address(token));
    }

    function test_whitelistAsset_revertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        vault.whitelistAsset(address(token));
    }

    function test_removeAsset_revertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        vault.removeAsset(address(token));
    }

    // ── ETH deposit() happy path ────────────────

    function test_deposit_eth_recordsVault() public {
        vm.prank(user);
        uint256 id = vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        assertEq(id, 0);
        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertEq(v.id, 0);
        assertEq(v.asset, address(0));
        assertEq(v.principal, 1 ether);
        assertEq(v.unlocksAt, block.timestamp + 30 days);
        assertEq(v.yielding, false);
    }

    function test_deposit_eth_emitsEvent() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit VaultDeposited(user, 0, address(0), 1 ether, block.timestamp + 30 days);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
    }

    function test_deposit_eth_contractReceivesETH() public {
        vm.prank(user);
        vault.deposit{value: 5 ether}(address(0), 0, 30 days);
        assertEq(address(vault).balance, 5 ether);
    }

    function test_deposit_eth_returnsIncrementingIds() public {
        vm.startPrank(user);
        uint256 id0 = vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        uint256 id1 = vault.deposit{value: 2 ether}(address(0), 0, 60 days);
        uint256 id2 = vault.deposit{value: 3 ether}(address(0), 0, 90 days);
        vm.stopPrank();

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    // ── ETH deposit() reverts ───────────────────

    function test_deposit_eth_revertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(BaseVaultV2.Vault__ZeroAmount.selector);
        vault.deposit{value: 0}(address(0), 0, 30 days);
    }

    function test_deposit_revertsOnDurationTooShort() public {
        vm.prank(user);
        vm.expectRevert(BaseVaultV2.Vault__LockDurationInvalid.selector);
        vault.deposit{value: 1 ether}(address(0), 0, 1 hours);
    }

    function test_deposit_revertsOnDurationTooLong() public {
        vm.prank(user);
        vm.expectRevert(BaseVaultV2.Vault__LockDurationInvalid.selector);
        vault.deposit{value: 1 ether}(address(0), 0, 366 days);
    }

    // ── ERC-20 deposit() happy path ─────────────

    function test_deposit_erc20_recordsVault() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        uint256 id = vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();

        assertEq(id, 0);
        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertEq(v.asset, address(token));
        assertEq(v.principal, 100e18);
        assertEq(v.unlocksAt, block.timestamp + 30 days);
    }

    function test_deposit_erc20_pullsTokens() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), 100e18);
        assertEq(token.balanceOf(user), 900e18);
    }

    function test_deposit_erc20_emitsEvent() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vm.expectEmit(true, true, false, true);
        emit VaultDeposited(user, 0, address(token), 100e18, block.timestamp + 30 days);
        vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();
    }

    // ── ERC-20 deposit() reverts ────────────────

    function test_deposit_erc20_revertsIfNotWhitelisted() public {
        ERC20Mock rogue = new ERC20Mock();
        rogue.mint(user, 100e18);

        vm.startPrank(user);
        rogue.approve(address(vault), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseVaultV2.Vault__AssetNotWhitelisted.selector, address(rogue)
            )
        );
        vault.deposit(address(rogue), 100e18, 30 days);
        vm.stopPrank();
    }

    function test_deposit_erc20_revertsOnETHValueMismatch() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vm.expectRevert(BaseVaultV2.Vault__ETHValueMismatch.selector);
        vault.deposit{value: 1 ether}(address(token), 100e18, 30 days);
        vm.stopPrank();
    }

    function test_deposit_erc20_revertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(BaseVaultV2.Vault__ZeroAmount.selector);
        vault.deposit(address(token), 0, 30 days);
    }

    // ── Multi-vault (ETH) ───────────────────────

    function test_multiVault_threeConcurrentVaults() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        vault.deposit{value: 2 ether}(address(0), 0, 60 days);
        vault.deposit{value: 3 ether}(address(0), 0, 90 days);
        vm.stopPrank();

        BaseVaultV2.Vault[] memory vaults = vault.getVaults(user);
        assertEq(vaults.length, 3);
        assertEq(vaults[0].principal, 1 ether);
        assertEq(vaults[1].principal, 2 ether);
        assertEq(vaults[2].principal, 3 ether);
    }

    function test_multiVault_independentUnlockTimes() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        vault.deposit{value: 1 ether}(address(0), 0, 90 days);
        vm.stopPrank();

        BaseVaultV2.Vault memory v0 = vault.getVault(user, 0);
        BaseVaultV2.Vault memory v1 = vault.getVault(user, 1);
        assertEq(v0.unlocksAt, block.timestamp + 30 days);
        assertEq(v1.unlocksAt, block.timestamp + 90 days);
    }

    // ── Multi-asset vault ───────────────────────

    function test_multiAsset_ethAndErc20Simultaneously() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        token.approve(address(vault), 50e18);
        vault.deposit(address(token), 50e18, 60 days);
        vm.stopPrank();

        BaseVaultV2.Vault[] memory vaults = vault.getVaults(user);
        assertEq(vaults.length, 2);
        assertEq(vaults[0].asset, address(0));
        assertEq(vaults[0].principal, 1 ether);
        assertEq(vaults[1].asset, address(token));
        assertEq(vaults[1].principal, 50e18);
    }

    function test_multiAsset_withdrawEachIndependently() public {
        vm.startPrank(user);
        vault.deposit{value: 2 ether}(address(0), 0, 30 days);
        token.approve(address(vault), 50e18);
        vault.deposit(address(token), 50e18, 30 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);

        uint256 ethBefore = user.balance;
        uint256 tokenBefore = token.balanceOf(user);

        vm.startPrank(user);
        vault.withdraw(0); // ETH vault
        vault.withdraw(1); // ERC-20 vault
        vm.stopPrank();

        assertEq(user.balance, ethBefore + 2 ether);
        assertEq(token.balanceOf(user), tokenBefore + 50e18);
    }

    // ── ETH withdraw() happy path ───────────────

    function test_withdraw_eth_transfersETHAfterLock() public {
        vm.prank(user);
        vault.deposit{value: 5 ether}(address(0), 0, 30 days);

        vm.warp(block.timestamp + 31 days);

        uint256 balanceBefore = user.balance;
        vm.prank(user);
        vault.withdraw(0);

        assertEq(user.balance, balanceBefore + 5 ether);
        assertEq(address(vault).balance, 0);
    }

    function test_withdraw_eth_zerosPrincipal() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vault.withdraw(0);

        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertEq(v.principal, 0);
        assertTrue(v.unlocksAt > 0);
    }

    function test_withdraw_eth_emitsEvent() public {
        vm.prank(user);
        vault.deposit{value: 2 ether}(address(0), 0, 30 days);

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit VaultWithdrawn(user, 0, address(0), 2 ether, 0);
        vault.withdraw(0);
    }

    function test_withdraw_eth_succeedsAtExactUnlockTime() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        vm.warp(block.timestamp + 30 days);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(vault.getVault(user, 0).principal, 0);
    }

    // ── ERC-20 withdraw() happy path ────────────

    function test_withdraw_erc20_returnsTokens() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);

        uint256 balanceBefore = token.balanceOf(user);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(token.balanceOf(user), balanceBefore + 100e18);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_withdraw_erc20_emitsEvent() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit VaultWithdrawn(user, 0, address(token), 100e18, 0);
        vault.withdraw(0);
    }

    function test_withdraw_erc20_worksAfterAssetRemoved() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();

        // Owner removes asset from whitelist
        vault.removeAsset(address(token));

        vm.warp(block.timestamp + 31 days);

        uint256 balanceBefore = token.balanceOf(user);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(token.balanceOf(user), balanceBefore + 100e18);
    }

    // ── withdraw() independence ─────────────────

    function test_withdraw_vault0DoesNotAffectVault1() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        vault.deposit{value: 2 ether}(address(0), 0, 60 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(vault.getVault(user, 0).principal, 0);
        assertEq(vault.getVault(user, 1).principal, 2 ether);
    }

    function test_withdraw_canDepositAfterWithdrawing() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        vm.warp(block.timestamp + 31 days);
        vault.withdraw(0);

        uint256 newId = vault.deposit{value: 2 ether}(address(0), 0, 60 days);
        vm.stopPrank();

        assertEq(newId, 1);
        assertEq(vault.getVault(user, 1).principal, 2 ether);
    }

    // ── withdraw() reverts ──────────────────────

    function test_withdraw_revertsOnInvalidVaultId() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(BaseVaultV2.Vault__InvalidVaultId.selector, 0)
        );
        vault.withdraw(0);
    }

    function test_withdraw_revertsIfAlreadyWithdrawn() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        vm.warp(block.timestamp + 31 days);
        vm.startPrank(user);
        vault.withdraw(0);

        vm.expectRevert(
            abi.encodeWithSelector(BaseVaultV2.Vault__AlreadyWithdrawn.selector, 0)
        );
        vault.withdraw(0);
        vm.stopPrank();
    }

    function test_withdraw_revertsBeforeLockExpires() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        uint256 unlocksAt = block.timestamp + 30 days;

        vm.warp(block.timestamp + 29 days);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(BaseVaultV2.Vault__NotYetUnlocked.selector, unlocksAt)
        );
        vault.withdraw(0);
    }

    // ── getVaults() / getVault() ────────────────

    function test_getVaults_returnsEmptyForNewAddress() public view {
        BaseVaultV2.Vault[] memory vaults = vault.getVaults(address(1));
        assertEq(vaults.length, 0);
    }

    function test_getVault_revertsOnInvalidId() public {
        vm.expectRevert(
            abi.encodeWithSelector(BaseVaultV2.Vault__InvalidVaultId.selector, 0)
        );
        vault.getVault(user, 0);
    }

    function test_getVaults_returnsCorrectArray() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        vault.deposit{value: 2 ether}(address(0), 0, 60 days);
        vm.stopPrank();

        BaseVaultV2.Vault[] memory vaults = vault.getVaults(user);
        assertEq(vaults.length, 2);
        assertEq(vaults[0].id, 0);
        assertEq(vaults[0].principal, 1 ether);
        assertEq(vaults[1].id, 1);
        assertEq(vaults[1].principal, 2 ether);
    }

    // ── Fuzz tests (ETH) ────────────────────────

    function testFuzz_deposit_eth_recordsAmount(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(address(0), 0, 30 days);
        assertEq(vault.getVault(user, 0).principal, amount);
    }

    function testFuzz_deposit_lockDurationInRange(uint256 duration) public {
        duration = bound(duration, 1 days, 365 days);
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, duration);
        assertEq(vault.getVault(user, 0).unlocksAt, block.timestamp + duration);
    }

    function testFuzz_withdraw_eth_succeedsAfterLock(uint96 amount, uint256 duration) public {
        vm.assume(amount > 0);
        duration = bound(duration, 1 days, 365 days);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(address(0), 0, duration);

        vm.warp(block.timestamp + duration);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(vault.getVault(user, 0).principal, 0);
        assertEq(user.balance, amount);
    }

    function testFuzz_multiVault_createAndWithdrawInRandomOrder(uint8 n) public {
        n = uint8(bound(n, 1, 10));

        vm.startPrank(user);

        for (uint256 i = 0; i < n; i++) {
            uint256 lockDuration = 1 days + (i * 1 days);
            vault.deposit{value: 1 ether}(address(0), 0, lockDuration);
        }

        vm.warp(block.timestamp + uint256(n) * 1 days + 1);

        for (uint256 i = n; i > 0; i--) {
            vault.withdraw(i - 1);
        }

        vm.stopPrank();

        BaseVaultV2.Vault[] memory vaults = vault.getVaults(user);
        for (uint256 i = 0; i < vaults.length; i++) {
            assertEq(vaults[i].principal, 0);
        }
        assertEq(user.balance, 100 ether);
    }

    // ── Fuzz tests (ERC-20) ─────────────────────

    function testFuzz_deposit_erc20_recordsAmount(uint96 amount) public {
        vm.assume(amount > 0);
        token.mint(user, amount);

        vm.startPrank(user);
        token.approve(address(vault), amount);
        vault.deposit(address(token), amount, 30 days);
        vm.stopPrank();

        assertEq(vault.getVault(user, 0).principal, amount);
        assertEq(vault.getVault(user, 0).asset, address(token));
    }

    function testFuzz_withdraw_erc20_succeedsAfterLock(uint96 amount, uint256 duration) public {
        vm.assume(amount > 0);
        duration = bound(duration, 1 days, 365 days);
        token.mint(user, amount);

        vm.startPrank(user);
        token.approve(address(vault), amount);
        vault.deposit(address(token), amount, duration);
        vm.stopPrank();

        vm.warp(block.timestamp + duration);

        uint256 balanceBefore = token.balanceOf(user);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(vault.getVault(user, 0).principal, 0);
        assertEq(token.balanceOf(user), balanceBefore + amount);
    }

    // ── Reentrancy ──────────────────────────────

    function test_withdraw_resistsReentrancy() public {
        ReentrantAttackerV2 attacker = new ReentrantAttackerV2(vault);
        vm.deal(address(attacker), 10 ether);

        attacker.attack();

        vm.warp(block.timestamp + 31 days);
        vm.expectRevert();
        attacker.reentrantWithdraw();
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  Mock Aave contracts (unit tests only — fork tests use live Aave)
// ══════════════════════════════════════════════════════════════════════════════

/// @dev Minimal Aave Pool mock: pull underlying on supply, mint aTokens; burn aTokens on withdraw
contract MockAavePool {
    using SafeERC20 for IERC20;

    mapping(address => address) private s_aTokens;

    function setAToken(address asset, address aToken) external {
        s_aTokens[asset] = aToken;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        ERC20Mock(s_aTokens[asset]).mint(onBehalfOf, amount);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        // Pool has direct burn authority over aTokens (no approval needed from caller)
        ERC20Mock(s_aTokens[asset]).burn(msg.sender, amount);
        IERC20(asset).safeTransfer(to, amount);
        return amount;
    }

    function getReserveData(address asset)
        external
        view
        returns (IAavePool.ReserveData memory data)
    {
        data.aTokenAddress = s_aTokens[asset];
    }

    /// @dev Test helper: mint extra underlying to simulate yield that has accrued
    function simulateYield(address asset, address aToken, uint256 yieldAmount) external {
        ERC20Mock(asset).mint(address(this), yieldAmount);
        ERC20Mock(aToken).mint(msg.sender, yieldAmount); // caller = vault
    }
}

/// @dev Minimal WETH Gateway mock: hold ETH on depositETH, pull aWETH and return ETH on withdrawETH
contract MockWETHGateway {
    using SafeERC20 for IERC20;

    address private immutable s_aWETH;

    constructor(address aWETH) {
        s_aWETH = aWETH;
    }

    function depositETH(address, address onBehalfOf, uint16) external payable {
        ERC20Mock(s_aWETH).mint(onBehalfOf, msg.value);
    }

    function withdrawETH(address, uint256 amount, address to) external {
        // Caller (vault) must have approved gateway before calling
        IERC20(s_aWETH).safeTransferFrom(msg.sender, address(this), amount);
        (bool ok,) = to.call{value: amount}("");
        require(ok, "MockWETHGateway: ETH transfer failed");
    }

    receive() external payable {}
}

// ══════════════════════════════════════════════════════════════════════════════
//  Yield unit tests (mock Aave, no fork required)
// ══════════════════════════════════════════════════════════════════════════════

contract BaseVaultV2YieldTest is Test {
    BaseVaultV2 public vault;
    MockAavePool public mockPool;
    MockWETHGateway public mockGateway;
    ERC20Mock public token;
    ERC20Mock public aToken;
    ERC20Mock public aWETH;

    address public user = makeAddr("user");
    address public nonOwner = makeAddr("nonOwner");

    // Canonical WETH address (arbitrary for unit tests)
    address public constant WETH = address(0x4200000000000000000000000000000000000006);

    event YieldToggled(bool enabled);
    event VaultWithdrawn(
        address indexed depositor,
        uint256 indexed vaultId,
        address asset,
        uint256 principal,
        uint256 yield_
    );

    function setUp() public {
        aWETH = new ERC20Mock();
        aToken = new ERC20Mock();
        token = new ERC20Mock();

        mockPool = new MockAavePool();
        mockPool.setAToken(WETH, address(aWETH));
        mockPool.setAToken(address(token), address(aToken));

        mockGateway = new MockWETHGateway(address(aWETH));

        vault = new BaseVaultV2(address(mockPool), address(mockGateway), WETH);
        vault.whitelistAsset(address(token));

        vm.deal(user, 100 ether);
        token.mint(user, 1000e18);
    }

    // ── Constructor / initial state ─────────────────────────────────────────

    function test_yield_aaveAddressesStored() public view {
        assertEq(vault.AAVE_POOL(), address(mockPool));
        assertEq(vault.WETH_GATEWAY(), address(mockGateway));
        assertEq(vault.WETH(), WETH);
    }

    function test_yield_yieldEnabledByDefault() public view {
        assertTrue(vault.yieldEnabled());
    }

    function test_yield_aWETHCachedInConstructor() public view {
        assertEq(vault.aTokenForAsset(address(0)), address(aWETH));
    }

    function test_yield_erc20ATokenCachedOnWhitelist() public view {
        assertEq(vault.aTokenForAsset(address(token)), address(aToken));
    }

    // ── setYieldEnabled ─────────────────────────────────────────────────────

    function test_setYieldEnabled_togglesFlag() public {
        vault.setYieldEnabled(false);
        assertFalse(vault.yieldEnabled());
        vault.setYieldEnabled(true);
        assertTrue(vault.yieldEnabled());
    }

    function test_setYieldEnabled_emitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit YieldToggled(false);
        vault.setYieldEnabled(false);
    }

    function test_setYieldEnabled_revertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        vault.setYieldEnabled(false);
    }

    // ── ETH deposit with yield ──────────────────────────────────────────────

    function test_yield_ethDeposit_setsYieldingTrue() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertTrue(v.yielding);
        assertEq(v.aToken, address(aWETH));
    }

    function test_yield_ethDeposit_suppliesEthToGateway() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        // Vault should hold aWETH, not raw ETH
        assertEq(address(vault).balance, 0);
        assertEq(aWETH.balanceOf(address(vault)), 1 ether);
    }

    // ── ERC-20 deposit with yield ───────────────────────────────────────────

    function test_yield_erc20Deposit_setsYieldingTrue() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();

        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertTrue(v.yielding);
        assertEq(v.aToken, address(aToken));
    }

    function test_yield_erc20Deposit_suppliesTokensToPool() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();

        // Vault should hold aTokens, not raw ERC-20
        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(address(mockPool)), 100e18);
        assertEq(aToken.balanceOf(address(vault)), 100e18);
    }

    // ── Yield disabled (setYieldEnabled = false) ────────────────────────────

    function test_yield_disabled_depositsHeldInContract() public {
        vault.setYieldEnabled(false);

        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertFalse(v.yielding);
        assertEq(address(vault).balance, 1 ether);
        assertEq(aWETH.balanceOf(address(vault)), 0);
    }

    function test_yield_disabled_existingYieldVaultStillWithdrawsViaAave() public {
        // Deposit while yield is enabled
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        assertEq(aWETH.balanceOf(address(vault)), 1 ether);

        // Owner disables yield for new deposits
        vault.setYieldEnabled(false);

        // Existing vault still withdraws via Aave gateway
        vm.warp(block.timestamp + 31 days);
        uint256 before = user.balance;
        vm.prank(user);
        vault.withdraw(0);

        assertEq(user.balance, before + 1 ether);
        assertEq(aWETH.balanceOf(address(vault)), 0);
    }

    // ── ETH withdraw with yield ─────────────────────────────────────────────

    function test_yield_ethWithdraw_returnsPrincipalPlusYield() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        // Gateway now holds 1 ETH (from depositETH). Fund it with the additional yield ETH.
        uint256 yieldAmount = 0.01 ether;
        aWETH.mint(address(vault), yieldAmount);
        vm.deal(address(mockGateway), 1 ether + yieldAmount);

        vm.warp(block.timestamp + 31 days);
        uint256 before = user.balance;
        vm.prank(user);
        vault.withdraw(0);

        assertEq(user.balance, before + 1 ether + yieldAmount);
    }

    function test_yield_ethWithdraw_emitsCorrectYieldAmount() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        uint256 yieldAmount = 0.05 ether;
        aWETH.mint(address(vault), yieldAmount);
        vm.deal(address(mockGateway), 1 ether + yieldAmount);

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit VaultWithdrawn(user, 0, address(0), 1 ether, yieldAmount);
        vault.withdraw(0);
    }

    // ── ERC-20 withdraw with yield ──────────────────────────────────────────

    function test_yield_erc20Withdraw_returnsPrincipalPlusYield() public {
        vm.startPrank(user);
        token.approve(address(vault), 100e18);
        vault.deposit(address(token), 100e18, 30 days);
        vm.stopPrank();

        // Simulate 2e18 yield
        uint256 yieldAmount = 2e18;
        aToken.mint(address(vault), yieldAmount);
        token.mint(address(mockPool), yieldAmount);

        vm.warp(block.timestamp + 31 days);
        uint256 before = token.balanceOf(user);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(token.balanceOf(user), before + 100e18 + yieldAmount);
    }

    // ── totalYield view ─────────────────────────────────────────────────────

    function test_totalYield_returnsZeroWhenNotYielding() public {
        vault.setYieldEnabled(false);
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        assertEq(vault.totalYield(user, 0), 0);
    }

    function test_totalYield_returnsZeroBeforeYieldAccrues() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        assertEq(vault.totalYield(user, 0), 0);
    }

    function test_totalYield_reflectsAccruedYield() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        aWETH.mint(address(vault), 0.01 ether);

        assertEq(vault.totalYield(user, 0), 0.01 ether);
    }

    function test_totalYield_returnsZeroAfterWithdraw() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        aWETH.mint(address(vault), 0.01 ether);
        vm.deal(address(mockGateway), 1 ether + 0.01 ether);

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(vault.totalYield(user, 0), 0);
    }

    // ── Multi-vault proportional yield ──────────────────────────────────────

    function test_yield_proportional_twoEthVaults() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days); // vault 0: 1/3 of pool
        vault.deposit{value: 2 ether}(address(0), 0, 30 days); // vault 1: 2/3 of pool
        vm.stopPrank();

        // Simulate 0.03 ETH total yield on 3 ETH pool
        aWETH.mint(address(vault), 0.03 ether);

        // vault 0 gets 1/3 = 0.01 ETH, vault 1 gets 2/3 = 0.02 ETH
        assertEq(vault.totalYield(user, 0), 0.01 ether);
        assertEq(vault.totalYield(user, 1), 0.02 ether);
    }
}

// ══════════════════════════════════════════════════════════════════════════════

/// @dev Malicious contract that tries to re-enter withdraw() via receive()
contract ReentrantAttackerV2 {
    BaseVaultV2 private immutable vault;
    uint256 private attackCount;

    constructor(BaseVaultV2 _vault) {
        vault = _vault;
    }

    function attack() external {
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
    }

    function reentrantWithdraw() external {
        attackCount = 0;
        vault.withdraw(0);
    }

    receive() external payable {
        if (attackCount < 1) {
            attackCount++;
            vault.withdraw(0);
        }
    }
}
