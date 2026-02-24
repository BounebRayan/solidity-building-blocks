// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/SharedWallet.sol";

contract SharedWalletScript is Script {
    function run() public {
        vm.startBroadcast();
        address[] memory owners = new address[](3);
        owners[0] = vm.envAddress("WALLET1_ADDRESS");
        owners[1] = vm.envAddress("WALLET2_ADDRESS");
        owners[2] = vm.envAddress("WALLET3_ADDRESS");
        new SharedWallet(owners, 2);
        vm.stopBroadcast();
    }
}
