// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Bank} from "../src/Bank.sol";

contract BankScript is Script {
    function run() public {
        vm.startBroadcast();
        new Bank();
        vm.stopBroadcast();
    }
}
