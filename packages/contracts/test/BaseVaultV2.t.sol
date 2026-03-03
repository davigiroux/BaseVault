// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BaseVaultV2} from "../src/BaseVaultV2.sol";

contract BaseVaultV2Test is Test {
    BaseVaultV2 public vault;
    address public user = makeAddr("user");

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

    function setUp() public {
        vault = new BaseVaultV2();
        vm.deal(user, 100 ether);
    }

    // ── Deployment ──────────────────────────────

    function test_constants_areSet() public view {
        assertEq(vault.MIN_LOCK_DURATION(), 1 days);
        assertEq(vault.MAX_LOCK_DURATION(), 365 days);
    }

    // ── deposit() happy path ────────────────────

    function test_deposit_recordsVault() public {
        vm.prank(user);
        uint256 id = vault.deposit{value: 1 ether}(30 days);

        assertEq(id, 0);
        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertEq(v.id, 0);
        assertEq(v.asset, address(0));
        assertEq(v.principal, 1 ether);
        assertEq(v.unlocksAt, block.timestamp + 30 days);
        assertEq(v.yielding, false);
    }

    function test_deposit_emitsEvent() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit VaultDeposited(user, 0, address(0), 1 ether, block.timestamp + 30 days);
        vault.deposit{value: 1 ether}(30 days);
    }

    function test_deposit_contractReceivesETH() public {
        vm.prank(user);
        vault.deposit{value: 5 ether}(30 days);
        assertEq(address(vault).balance, 5 ether);
    }

    function test_deposit_returnsIncrementingIds() public {
        vm.startPrank(user);
        uint256 id0 = vault.deposit{value: 1 ether}(30 days);
        uint256 id1 = vault.deposit{value: 2 ether}(60 days);
        uint256 id2 = vault.deposit{value: 3 ether}(90 days);
        vm.stopPrank();

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    // ── deposit() reverts ───────────────────────

    function test_deposit_revertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(BaseVaultV2.Vault__ZeroAmount.selector);
        vault.deposit{value: 0}(30 days);
    }

    function test_deposit_revertsOnDurationTooShort() public {
        vm.prank(user);
        vm.expectRevert(BaseVaultV2.Vault__LockDurationInvalid.selector);
        vault.deposit{value: 1 ether}(1 hours);
    }

    function test_deposit_revertsOnDurationTooLong() public {
        vm.prank(user);
        vm.expectRevert(BaseVaultV2.Vault__LockDurationInvalid.selector);
        vault.deposit{value: 1 ether}(366 days);
    }

    // ── Multi-vault ─────────────────────────────

    function test_multiVault_threeConcurrentVaults() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(30 days);
        vault.deposit{value: 2 ether}(60 days);
        vault.deposit{value: 3 ether}(90 days);
        vm.stopPrank();

        BaseVaultV2.Vault[] memory vaults = vault.getVaults(user);
        assertEq(vaults.length, 3);
        assertEq(vaults[0].principal, 1 ether);
        assertEq(vaults[1].principal, 2 ether);
        assertEq(vaults[2].principal, 3 ether);
    }

    function test_multiVault_independentUnlockTimes() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(30 days);
        vault.deposit{value: 1 ether}(90 days);
        vm.stopPrank();

        BaseVaultV2.Vault memory v0 = vault.getVault(user, 0);
        BaseVaultV2.Vault memory v1 = vault.getVault(user, 1);
        assertEq(v0.unlocksAt, block.timestamp + 30 days);
        assertEq(v1.unlocksAt, block.timestamp + 90 days);
    }

    // ── withdraw() happy path ───────────────────

    function test_withdraw_transfersETHAfterLock() public {
        vm.prank(user);
        vault.deposit{value: 5 ether}(30 days);

        vm.warp(block.timestamp + 31 days);

        uint256 balanceBefore = user.balance;
        vm.prank(user);
        vault.withdraw(0);

        assertEq(user.balance, balanceBefore + 5 ether);
        assertEq(address(vault).balance, 0);
    }

    function test_withdraw_zerosPrincipal() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(30 days);

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vault.withdraw(0);

        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertEq(v.principal, 0);
        // unlocksAt preserved — vault still in array, just marked withdrawn
        assertTrue(v.unlocksAt > 0);
    }

    function test_withdraw_emitsEvent() public {
        vm.prank(user);
        vault.deposit{value: 2 ether}(30 days);

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit VaultWithdrawn(user, 0, address(0), 2 ether, 0);
        vault.withdraw(0);
    }

    function test_withdraw_succeedsAtExactUnlockTime() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(30 days);

        vm.warp(block.timestamp + 30 days);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(vault.getVault(user, 0).principal, 0);
    }

    // ── withdraw() independence ─────────────────

    function test_withdraw_vault0DoesNotAffectVault1() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(30 days);
        vault.deposit{value: 2 ether}(60 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vault.withdraw(0);

        // Vault 0 withdrawn
        assertEq(vault.getVault(user, 0).principal, 0);
        // Vault 1 untouched
        assertEq(vault.getVault(user, 1).principal, 2 ether);
    }

    function test_withdraw_canDepositAfterWithdrawing() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(30 days);

        vm.warp(block.timestamp + 31 days);
        vault.withdraw(0);

        // New deposit gets next id
        uint256 newId = vault.deposit{value: 2 ether}(60 days);
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
        vault.deposit{value: 1 ether}(30 days);

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
        vault.deposit{value: 1 ether}(30 days);
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
        vault.deposit{value: 1 ether}(30 days);
        vault.deposit{value: 2 ether}(60 days);
        vm.stopPrank();

        BaseVaultV2.Vault[] memory vaults = vault.getVaults(user);
        assertEq(vaults.length, 2);
        assertEq(vaults[0].id, 0);
        assertEq(vaults[0].principal, 1 ether);
        assertEq(vaults[1].id, 1);
        assertEq(vaults[1].principal, 2 ether);
    }

    // ── Fuzz tests ──────────────────────────────

    function testFuzz_deposit_recordsAmount(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(30 days);
        assertEq(vault.getVault(user, 0).principal, amount);
    }

    function testFuzz_deposit_lockDurationInRange(uint256 duration) public {
        duration = bound(duration, 1 days, 365 days);
        vm.prank(user);
        vault.deposit{value: 1 ether}(duration);
        assertEq(vault.getVault(user, 0).unlocksAt, block.timestamp + duration);
    }

    function testFuzz_withdraw_succeedsAfterLock(uint96 amount, uint256 duration) public {
        vm.assume(amount > 0);
        duration = bound(duration, 1 days, 365 days);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(duration);

        vm.warp(block.timestamp + duration);
        vm.prank(user);
        vault.withdraw(0);

        assertEq(vault.getVault(user, 0).principal, 0);
        assertEq(user.balance, amount);
    }

    function testFuzz_multiVault_createAndWithdrawInRandomOrder(uint8 n) public {
        n = uint8(bound(n, 1, 10));
        uint256 totalDeposited;

        vm.startPrank(user);

        // Create N vaults with 1 ether each, varying lock durations
        for (uint256 i = 0; i < n; i++) {
            uint256 lockDuration = 1 days + (i * 1 days);
            vault.deposit{value: 1 ether}(lockDuration);
            totalDeposited += 1 ether;
        }

        // Warp past longest lock
        vm.warp(block.timestamp + uint256(n) * 1 days + 1);

        // Withdraw in reverse order
        for (uint256 i = n; i > 0; i--) {
            vault.withdraw(i - 1);
        }

        vm.stopPrank();

        // All vaults withdrawn
        BaseVaultV2.Vault[] memory vaults = vault.getVaults(user);
        for (uint256 i = 0; i < vaults.length; i++) {
            assertEq(vaults[i].principal, 0);
        }
        assertEq(user.balance, 100 ether); // started with 100, deposited and got it all back
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
        vault.deposit{value: 1 ether}(30 days);
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
