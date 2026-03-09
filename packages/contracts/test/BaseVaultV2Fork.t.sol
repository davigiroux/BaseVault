// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BaseVaultV2} from "../src/BaseVaultV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Fork tests for Aave v3 yield integration on Base Sepolia.
///         Requires BASE_SEPOLIA_RPC_URL env var. Tests are skipped automatically if unset.
contract BaseVaultV2ForkTest is Test {
    // ── Aave v3 Base Sepolia (from bgd-labs/aave-address-book) ──────────────
    address constant AAVE_POOL = 0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27;
    address constant WETH_GATEWAY = 0x0568130e794429D2eEBC4dafE18f25Ff1a1ed8b6;
    address constant WETH = 0x4200000000000000000000000000000000000006;

    BaseVaultV2 public vault;
    address public user = makeAddr("user");

    function setUp() public {
        string memory rpc = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }

        vm.createSelectFork(rpc);

        vault = new BaseVaultV2(AAVE_POOL, WETH_GATEWAY, WETH);
        vm.deal(user, 10 ether);
    }

    // ── Deployment ──────────────────────────────────────────────────────────

    function test_fork_aWETH_isResolvedFromAave() public view {
        address aWETH = vault.aTokenForAsset(address(0));
        assertTrue(aWETH != address(0), "aWETH not resolved");
    }

    // ── ETH deposit → yield accrual → withdrawal ────────────────────────────

    function test_fork_eth_depositSuppliesViaGateway() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertTrue(v.yielding, "vault should be yielding");

        address aWETH = vault.aTokenForAsset(address(0));
        uint256 aBalance = IERC20(aWETH).balanceOf(address(vault));
        assertApproxEqAbs(aBalance, 1 ether, 1e15, "aWETH balance should be ~1 ETH");
    }

    function test_fork_eth_yieldAccruesAfterWarp() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        vm.warp(block.timestamp + 30 days);

        // aToken.balanceOf reflects accrued interest on-the-fly via the liquidityIndex
        uint256 yield = vault.totalYield(user, 0);
        assertGt(yield, 0, "yield should have accrued after 30 days");
    }

    function test_fork_eth_withdrawReturnsPrincipalPlusYield() public {
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        vm.warp(block.timestamp + 31 days);

        uint256 before = user.balance;
        vm.prank(user);
        vault.withdraw(0);

        assertGt(user.balance, before + 1 ether, "should receive principal + yield");
        assertEq(vault.getVault(user, 0).principal, 0);
    }

    // ── WETH ERC-20 deposit → yield accrual → withdrawal ────────────────────

    function test_fork_weth_depositSuppliesViaPool() public {
        // Give user WETH by dealing directly
        deal(WETH, user, 1 ether);

        vault.whitelistAsset(WETH);
        address aWETH = vault.aTokenForAsset(WETH);
        assertTrue(aWETH != address(0), "aWETH for WETH not resolved");

        vm.startPrank(user);
        IERC20(WETH).approve(address(vault), 1 ether);
        vault.deposit(WETH, 1 ether, 30 days);
        vm.stopPrank();

        BaseVaultV2.Vault memory v = vault.getVault(user, 0);
        assertTrue(v.yielding);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
    }

    function test_fork_weth_yieldAccruesAfterWarp() public {
        deal(WETH, user, 1 ether);
        vault.whitelistAsset(WETH);

        vm.startPrank(user);
        IERC20(WETH).approve(address(vault), 1 ether);
        vault.deposit(WETH, 1 ether, 30 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days);

        assertGt(vault.totalYield(user, 0), 0, "yield should have accrued");
    }

    function test_fork_weth_withdrawReturnsPrincipalPlusYield() public {
        deal(WETH, user, 1 ether);
        vault.whitelistAsset(WETH);

        vm.startPrank(user);
        IERC20(WETH).approve(address(vault), 1 ether);
        vault.deposit(WETH, 1 ether, 30 days);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);

        uint256 before = IERC20(WETH).balanceOf(user);
        vm.prank(user);
        vault.withdraw(0);

        assertGt(IERC20(WETH).balanceOf(user), before + 1 ether, "should receive principal + yield");
    }

    // ── yieldEnabled toggle ──────────────────────────────────────────────────

    function test_fork_yieldDisabled_holdsFundsDirect() public {
        vault.setYieldEnabled(false);

        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);

        assertFalse(vault.getVault(user, 0).yielding);
        assertEq(address(vault).balance, 1 ether);
    }

    function test_fork_yieldDisabled_existingVaultStillWithdrawsFromAave() public {
        // Deposit while enabled
        vm.prank(user);
        vault.deposit{value: 1 ether}(address(0), 0, 30 days);
        assertTrue(vault.getVault(user, 0).yielding);

        // Disable yield and wait
        vault.setYieldEnabled(false);
        vm.warp(block.timestamp + 31 days);

        uint256 before = user.balance;
        vm.prank(user);
        vault.withdraw(0);

        assertGe(user.balance, before + 1 ether, "should receive at least principal back");
    }
}
