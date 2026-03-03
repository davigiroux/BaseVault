// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BaseVaultV2} from "../src/BaseVaultV2.sol";

contract DeployV2Script is Script {
    function run() external returns (BaseVaultV2) {
        vm.startBroadcast();
        BaseVaultV2 vault = new BaseVaultV2();
        vm.stopBroadcast();

        console.log("BaseVaultV2 deployed to:", address(vault));

        return vault;
    }
}
