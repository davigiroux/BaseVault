// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BaseVaultV2} from "../src/BaseVaultV2.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
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

    function setUp() public {
        vault = new BaseVaultV2();
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
