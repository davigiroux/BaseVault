// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BaseVault} from "../src/BaseVault.sol";

contract DeployScript is Script {
    function run() external returns (BaseVault) {
        vm.startBroadcast();
        BaseVault vault = new BaseVault();
        vm.stopBroadcast();

        console.log("BaseVault deployed to:", address(vault));
        console.log("Owner:", vault.owner());

        return vault;
    }
}
