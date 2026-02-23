// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    address public owner;
    address public user1;
    address public user2;

    uint256 constant FEE_PERCENT = 1;
    uint256 constant MIN_BALANCE = 1 ether;

    function setUp() public {
        // Deploy: msg.sender becomes owner
        bank = new Bank();
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Give users ETH so they can send transactions and deposit
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    // ----- Deposit -----

    function test_deposit_increasesBalance() public {
        vm.prank(user1);
        bank.deposit{value: 10 ether}();

        // 10 ether - 1% fee = 9.9 ether credited
        assertEq(bank.getBalance(user1), 9.9 ether);
    }

    function test_deposit_revertZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(Bank.InvalidAmount.selector);
        bank.deposit{value: 0}();
    }

    function test_deposit_emitsEvent() public {
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit Bank.Deposit(user1, 10 ether);
        bank.deposit{value: 10 ether}();
    }

    // ----- Withdraw -----

    function test_withdraw_decreasesBalanceAndSendsEth() public {
        vm.prank(user1);
        bank.deposit{value: 10 ether}();
        // user1 balance in contract = 9.9 ether

        uint256 user1Before = user1.balance;
        vm.prank(user1);
        bank.withdraw(1 ether);
        uint256 user1After = user1.balance;

        assertEq(bank.getBalance(user1), 9.9 ether - 1 ether - 0.01 ether); // 8.89 ether left
        assertEq(user1After - user1Before, 1 ether);
    }

    function test_withdraw_revertInsufficientBalance() public {
        vm.prank(user1);
        bank.deposit{value: 1 ether}(); // 0.99 ether credited
        vm.prank(user1);
        vm.expectRevert(Bank.InsufficientBalance.selector);
        bank.withdraw(1 ether); // more than 0.99
    }

    function test_withdraw_revertMinBalanceNotMet() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}(); // 4.95 ether credited; min must stay >= 1 ether
        vm.prank(user1);
        vm.expectRevert(Bank.MinBalanceNotMet.selector);
        bank.withdraw(4 ether); // would leave 0.95 - 0.04 = 0.91 < 1 ether
    }

    function test_withdraw_revertZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(Bank.InvalidAmount.selector);
        bank.withdraw(0);
    }

    // ----- Transfer -----

    function test_transfer_updatesBothBalances() public {
        vm.prank(user1);
        bank.deposit{value: 10 ether}();

        vm.prank(user1);
        bank.transfer(user2, 2 ether);

        assertEq(bank.getBalance(user1), 9.9 ether - 2 ether - 0.02 ether);
        assertEq(bank.getBalance(user2), 2 ether);
    }

    function test_transfer_revertInvalidAccount() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}();
        vm.prank(user1);
        vm.expectRevert(Bank.InvalidAccount.selector);
        bank.transfer(address(0), 1 ether);
    }

    function test_transfer_revertZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(Bank.InvalidAmount.selector);
        bank.transfer(user2, 0);
    }

    // ----- View / access -----

    function test_getBalance_revertInvalidAccount() public {
        vm.expectRevert(Bank.InvalidAccount.selector);
        bank.getBalance(address(0));
    }

    // ----- Pause / Unpause -----

    function test_pause_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(Bank.NotOwner.selector);
        bank.pause();
    }

    function test_pause_unpause_blocksDeposit() public {
        bank.pause();
        vm.prank(user1);
        vm.expectRevert(Bank.Paused.selector);
        bank.deposit{value: 1 ether}();

        bank.unpause();
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        assertEq(bank.getBalance(user1), 0.99 ether);
    }

    function test_unpause_onlyWhenPaused() public {
        vm.expectRevert(Bank.NotPaused.selector);
        bank.unpause();
    }

    // ----- Owner config -----

    function test_setTransactionFeePercentage_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(Bank.NotOwner.selector);
        bank.setTransactionFeePercentage(2);
    }

    function test_setMinBalance_onlyOwner() public {
        vm.prank(user1);
        vm.expectRevert(Bank.NotOwner.selector);
        bank.setMinBalance(0.5 ether);
    }

    function test_setTransactionFeePercentage_updatesFee() public {
        bank.setTransactionFeePercentage(2);
        vm.prank(user1);
        bank.deposit{value: 100 ether}();
        // 2% fee -> 98 ether credited
        assertEq(bank.getBalance(user1), 98 ether);
    }

    function test_setMinBalance_affectsWithdraw() public {
        bank.setMinBalance(0.5 ether);
        vm.prank(user1);
        bank.deposit{value: 5 ether}(); // 4.95 credited
        vm.prank(user1);
        bank.withdraw(4 ether); // 4.95 - 4 - 0.04 = 0.91, need >= 0.5 -> ok
        assertEq(bank.getBalance(user1), 0.91 ether);
    }

    // ----- Emergency withdraw -----

    function test_emergencyWithdrawAll_onlyWhenPaused() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}();
        vm.expectRevert(Bank.NotPaused.selector);
        bank.emergencyWithdrawAll(owner);
    }

    function test_emergencyWithdrawAll_onlyOwner() public {
        bank.pause();
        vm.prank(user1);
        vm.expectRevert(Bank.NotOwner.selector);
        bank.emergencyWithdrawAll(user1);
    }

    function test_emergencyWithdrawAll_sendsAllToRecipient() public {
        vm.prank(user1);
        bank.deposit{value: 5 ether}();
        uint256 contractBalance = address(bank).balance;
        bank.pause();

        uint256 ownerBefore = owner.balance;
        bank.emergencyWithdrawAll(owner);
        assertEq(owner.balance, ownerBefore + contractBalance);
        assertEq(address(bank).balance, 0);
    }

    // Allow test contract to receive ETH (e.g. from emergencyWithdrawAll)
    receive() external payable {}
}
