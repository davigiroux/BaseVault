// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BaseVaultV2} from "../src/BaseVaultV2.sol";

contract DeployV2Script is Script {
    // Aave v3 addresses — override via env or edit before deploying to mainnet
    address constant AAVE_POOL_SEPOLIA = 0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27;
    address constant WETH_GATEWAY_SEPOLIA = 0x0568130e794429D2eEBC4dafE18f25Ff1a1ed8b6;
    address constant WETH_BASE = 0x4200000000000000000000000000000000000006;

    function run() external returns (BaseVaultV2) {
        vm.startBroadcast();
        BaseVaultV2 vault = new BaseVaultV2(AAVE_POOL_SEPOLIA, WETH_GATEWAY_SEPOLIA, WETH_BASE);
        vm.stopBroadcast();

        console.log("BaseVaultV2 deployed to:", address(vault));

        return vault;
    }
}
