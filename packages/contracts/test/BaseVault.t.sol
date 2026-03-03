// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BaseVault} from "../src/BaseVault.sol";

contract BaseVaultTest is Test {
    BaseVault public vault;
    address public user = makeAddr("user");

    event VaultDeposited(
        address indexed depositor,
        uint256 amount,
        uint256 unlocksAt
    );
    event VaultWithdrawn(address indexed depositor, uint256 amount);

    function setUp() public {
        vault = new BaseVault();
        vm.deal(user, 100 ether);
    }

    // ── Deployment ──────────────────────────────

    function test_owner_isDeployer() public view {
        assertEq(vault.owner(), address(this));
    }

    function test_constants_areSet() public view {
        assertEq(vault.MIN_LOCK_DURATION(), 1 days);
        assertEq(vault.MAX_LOCK_DURATION(), 365 days);
    }

    // ── deposit() happy path ────────────────────

    function test_deposit_recordsAmountAndUnlockTime() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(30 days);

        BaseVault.Deposit memory dep = vault.getDeposit(user);
        assertEq(dep.amount, 1 ether);
        assertEq(dep.unlocksAt, block.timestamp + 30 days);
    }

    function test_deposit_emitsEvent() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit VaultDeposited(user, 1 ether, block.timestamp + 30 days);
        vault.deposit{value: 1 ether}(30 days);
    }

    function test_deposit_contractReceivesETH() public {
        vm.prank(user);
        vault.deposit{value: 5 ether}(30 days);
        assertEq(address(vault).balance, 5 ether);
    }

    // ── deposit() reverts ───────────────────────

    function test_deposit_revertsOnZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(BaseVault.Vault__ZeroAmount.selector);
        vault.deposit{value: 0}(30 days);
    }

    function test_deposit_revertsOnDurationTooShort() public {
        vm.prank(user);
        vm.expectRevert(BaseVault.Vault__LockDurationInvalid.selector);
        vault.deposit{value: 1 ether}(1 hours);
    }

    function test_deposit_revertsOnDurationTooLong() public {
        vm.prank(user);
        vm.expectRevert(BaseVault.Vault__LockDurationInvalid.selector);
        vault.deposit{value: 1 ether}(366 days);
    }

    function test_deposit_revertsIfAlreadyDeposited() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(30 days);

        vm.expectRevert(BaseVault.Vault__AlreadyDeposited.selector);
        vault.deposit{value: 1 ether}(30 days);
        vm.stopPrank();
    }

    // ── withdraw() happy path ───────────────────

    function test_withdraw_transfersETHAfterLock() public {
        vm.prank(user);
        vault.deposit{value: 5 ether}(30 days);

        vm.warp(block.timestamp + 31 days);

        uint256 balanceBefore = user.balance;
        vm.prank(user);
        vault.withdraw();

        assertEq(user.balance, balanceBefore + 5 ether);
        assertEq(address(vault).balance, 0);
    }

    function test_withdraw_clearsDepositRecord() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(30 days);

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vault.withdraw();

        BaseVault.Deposit memory dep = vault.getDeposit(user);
        assertEq(dep.amount, 0);
        assertEq(dep.unlocksAt, 0);
    }

    function test_withdraw_emitsEvent() public {
        vm.prank(user);
        vault.deposit{value: 2 ether}(30 days);

        vm.warp(block.timestamp + 31 days);
        vm.prank(user);
        vm.expectEmit(true, false, false, true);
        emit VaultWithdrawn(user, 2 ether);
        vault.withdraw();
    }

    function test_withdraw_allowsRedepositAfter() public {
        vm.startPrank(user);
        vault.deposit{value: 1 ether}(30 days);

        vm.warp(block.timestamp + 31 days);
        vault.withdraw();

        vault.deposit{value: 2 ether}(60 days);
        vm.stopPrank();

        assertEq(vault.getDeposit(user).amount, 2 ether);
    }

    // ── withdraw() reverts ──────────────────────

    function test_withdraw_revertsIfNoDeposit() public {
        vm.prank(user);
        vm.expectRevert(BaseVault.Vault__NothingToWithdraw.selector);
        vault.withdraw();
    }

    function test_withdraw_revertsBeforeLockExpires() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(30 days);

        vm.warp(block.timestamp + 29 days);
        vm.prank(user);
        vm.expectRevert(BaseVault.Vault__NotYetUnlocked.selector);
        vault.withdraw();
    }

    function test_withdraw_succeedsAtExactUnlockTime() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(30 days);

        vm.warp(block.timestamp + 30 days);
        vm.prank(user);
        vault.withdraw();

        assertEq(vault.getDeposit(user).amount, 0);
    }

    // ── getDeposit() ────────────────────────────

    function test_getDeposit_returnsZeroForNewAddress() public view {
        BaseVault.Deposit memory dep = vault.getDeposit(address(1));
        assertEq(dep.amount, 0);
        assertEq(dep.unlocksAt, 0);
    }

    // ── Fuzz tests ──────────────────────────────

    function testFuzz_deposit_recordsAmount(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(30 days);
        assertEq(vault.getDeposit(user).amount, amount);
    }

    function testFuzz_deposit_lockDurationInRange(uint256 duration) public {
        duration = bound(duration, 1 days, 365 days);
        vm.prank(user);
        vault.deposit{value: 1 ether}(duration);
        assertEq(vault.getDeposit(user).unlocksAt, block.timestamp + duration);
    }

    function testFuzz_withdraw_succeedsAfterLock(
        uint96 amount,
        uint256 duration
    ) public {
        vm.assume(amount > 0);
        duration = bound(duration, 1 days, 365 days);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(duration);

        vm.warp(block.timestamp + duration);
        vm.prank(user);
        vault.withdraw();

        assertEq(vault.getDeposit(user).amount, 0);
        assertEq(user.balance, amount);
    }

    // ── Reentrancy ──────────────────────────────

    function test_withdraw_resistsReentrancy() public {
        ReentrantAttacker attacker = new ReentrantAttacker(vault);
        vm.deal(address(attacker), 10 ether);

        attacker.attack();

        vm.warp(block.timestamp + 31 days);
        vm.expectRevert();
        attacker.reentrantWithdraw();
    }
}

/// @dev Malicious contract that tries to re-enter withdraw() via receive()
contract ReentrantAttacker {
    BaseVault private immutable vault;
    uint256 private attackCount;

    constructor(BaseVault _vault) {
        vault = _vault;
    }

    function attack() external {
        vault.deposit{value: 1 ether}(30 days);
    }

    function reentrantWithdraw() external {
        attackCount = 0;
        vault.withdraw();
    }

    receive() external payable {
        if (attackCount < 1) {
            attackCount++;
            vault.withdraw();
        }
    }
}
