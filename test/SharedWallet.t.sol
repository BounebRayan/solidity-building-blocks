// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {SharedWallet} from "../src/SharedWallet.sol";

contract RejectEther {
    receive() external payable {
        revert("no ether");
    }
}

contract SharedWalletTest is Test {
    SharedWallet public sharedWallet;

    address public wallet1;
    address public wallet2;
    address public wallet3;
    address public nonOwner;

    function setUp() public {
        wallet1 = makeAddr("wallet1");
        wallet2 = makeAddr("wallet2");
        wallet3 = makeAddr("wallet3");
        nonOwner = makeAddr("nonOwner");

        vm.deal(wallet1, 100 ether);
        vm.deal(wallet2, 100 ether);
        vm.deal(wallet3, 100 ether);
        vm.deal(nonOwner, 100 ether);

        address[] memory owners = new address[](3);
        owners[0] = wallet1;
        owners[1] = wallet2;
        owners[2] = wallet3;
        sharedWallet = new SharedWallet(owners, 2);
    }

    // ========================
    // Constructor Tests
    // ========================

    function test_constructor_setsOwnersCorrectly() public view {
        assertTrue(sharedWallet.isOwner(wallet1));
        assertTrue(sharedWallet.isOwner(wallet2));
        assertTrue(sharedWallet.isOwner(wallet3));
        assertFalse(sharedWallet.isOwner(nonOwner));
    }

    function test_constructor_setsOwnerArrayCorrectly() public view {
        assertEq(sharedWallet.owners(0), wallet1);
        assertEq(sharedWallet.owners(1), wallet2);
        assertEq(sharedWallet.owners(2), wallet3);
    }

    function test_constructor_revertsOnEmptyOwners() public {
        address[] memory owners = new address[](0);
        vm.expectRevert(SharedWallet.InvalidOwnerArray.selector);
        new SharedWallet(owners, 1);
    }

    function test_constructor_revertsOnZeroThreshold() public {
        address[] memory owners = new address[](1);
        owners[0] = wallet1;
        vm.expectRevert(SharedWallet.InvalidThreshold.selector);
        new SharedWallet(owners, 0);
    }

    function test_constructor_revertsOnThresholdExceedingOwners() public {
        address[] memory owners = new address[](2);
        owners[0] = wallet1;
        owners[1] = wallet2;
        vm.expectRevert(SharedWallet.InvalidThreshold.selector);
        new SharedWallet(owners, 3);
    }

    function test_constructor_revertsOnDuplicateOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = wallet1;
        owners[1] = wallet1;
        vm.expectRevert(SharedWallet.InvalidAddress.selector);
        new SharedWallet(owners, 1);
    }

    function test_constructor_revertsOnZeroAddressOwner() public {
        address[] memory owners = new address[](2);
        owners[0] = address(0);
        owners[1] = wallet1;
        vm.expectRevert(SharedWallet.InvalidAddress.selector);
        new SharedWallet(owners, 1);
    }

    function test_constructor_thresholdEqualToOwnerCount() public {
        address[] memory owners = new address[](2);
        owners[0] = wallet1;
        owners[1] = wallet2;
        SharedWallet sw = new SharedWallet(owners, 2);
        assertTrue(sw.isOwner(wallet1));
        assertTrue(sw.isOwner(wallet2));
    }

    // ========================
    // Deposit Tests
    // ========================

    function test_deposit_acceptsEtherFromOwner() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 1 ether}();

        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 1 ether);
    }

    function test_deposit_acceptsEtherFromNonOwner() public {
        vm.prank(nonOwner);
        sharedWallet.deposit{value: 5 ether}();

        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 5 ether);
    }

    function test_deposit_multipleDepositsAccumulate() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 2 ether}();
        vm.prank(wallet2);
        sharedWallet.deposit{value: 3 ether}();

        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 5 ether);
    }

    // ========================
    // proposeTransaction Tests
    // ========================

    function test_proposeTransaction_success() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(wallet2, 1 ether, "Pay wallet2");
    }

    function test_proposeTransaction_emitsEvent() public {
        vm.prank(wallet1);
        vm.expectEmit(true, true, true, true);
        emit SharedWallet.ProposalCreated(0, wallet1, wallet2, 1 ether, "Pay wallet2");
        sharedWallet.proposeTransaction(wallet2, 1 ether, "Pay wallet2");
    }

    function test_proposeTransaction_revertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(SharedWallet.NotOwner.selector);
        sharedWallet.proposeTransaction(wallet1, 1 ether, "Pay wallet1");
    }

    function test_proposeTransaction_revertsForZeroAddress() public {
        vm.prank(wallet1);
        vm.expectRevert("Invalid address");
        sharedWallet.proposeTransaction(address(0), 1 ether, "Pay nobody");
    }

    function test_proposeTransaction_revertsForZeroAmount() public {
        vm.prank(wallet1);
        vm.expectRevert("Invalid amount");
        sharedWallet.proposeTransaction(wallet2, 0, "Pay wallet2");
    }

    function test_proposeTransaction_revertsForEmptyDescription() public {
        vm.prank(wallet1);
        vm.expectRevert("Invalid description");
        sharedWallet.proposeTransaction(wallet2, 1 ether, "");
    }

    function test_proposeTransaction_multipleProposalsIncrementId() public {
        vm.startPrank(wallet1);

        vm.expectEmit(true, true, true, true);
        emit SharedWallet.ProposalCreated(0, wallet1, wallet2, 1 ether, "First");
        sharedWallet.proposeTransaction(wallet2, 1 ether, "First");

        vm.expectEmit(true, true, true, true);
        emit SharedWallet.ProposalCreated(1, wallet1, wallet3, 2 ether, "Second");
        sharedWallet.proposeTransaction(wallet3, 2 ether, "Second");

        vm.stopPrank();
    }

    // ========================
    // approveProposal Tests
    // ========================

    function test_approveProposal_success() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
    }

    function test_approveProposal_emitsEvent() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet2);
        vm.expectEmit(true, true, false, false);
        emit SharedWallet.ProposalApproved(0, wallet2);
        sharedWallet.approveProposal(0);
    }

    function test_approveProposal_revertsForNonOwner() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(nonOwner);
        vm.expectRevert(SharedWallet.NotOwner.selector);
        sharedWallet.approveProposal(0);
    }

    function test_approveProposal_revertsForInvalidId() public {
        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.InvalidId.selector);
        sharedWallet.approveProposal(0);
    }

    function test_approveProposal_revertsIfAlreadyApproved() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.AlreadyApproved.selector);
        sharedWallet.approveProposal(0);
    }

    function test_approveProposal_revertsIfExecuted() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        sharedWallet.executeProposal(0);

        vm.prank(wallet3);
        vm.expectRevert(SharedWallet.ProposalAlreadyExecuted.selector);
        sharedWallet.approveProposal(0);
    }

    function test_approveProposal_multipleOwners() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);
        vm.prank(wallet3);
        sharedWallet.approveProposal(0);
    }

    // ========================
    // revokeApproval Tests
    // ========================

    function test_revokeApproval_success() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        sharedWallet.revokeApproval(0);
    }

    function test_revokeApproval_emitsEvent() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        vm.expectEmit(true, true, false, false);
        emit SharedWallet.ApprovalRevoked(0, wallet1);
        sharedWallet.revokeApproval(0);
    }

    function test_revokeApproval_revertsForNonOwner() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(nonOwner);
        vm.expectRevert(SharedWallet.NotOwner.selector);
        sharedWallet.revokeApproval(0);
    }

    function test_revokeApproval_revertsForInvalidId() public {
        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.InvalidId.selector);
        sharedWallet.revokeApproval(99);
    }

    function test_revokeApproval_revertsIfNotApproved() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet2);
        vm.expectRevert(SharedWallet.NotAlreadyApproved.selector);
        sharedWallet.revokeApproval(0);
    }

    function test_revokeApproval_revertsIfExecuted() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        sharedWallet.executeProposal(0);

        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.ProposalAlreadyExecuted.selector);
        sharedWallet.revokeApproval(0);
    }

    function test_revokeApproval_canReapproveAfterRevoke() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        sharedWallet.revokeApproval(0);

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
    }

    // ========================
    // executeProposal Tests
    // ========================

    function test_executeProposal_success() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        uint256 recipientBefore = nonOwner.balance;

        vm.prank(wallet1);
        sharedWallet.executeProposal(0);

        assertEq(nonOwner.balance, recipientBefore + 1 ether);
        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 9 ether);
    }

    function test_executeProposal_emitsEvent() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        vm.expectEmit(true, true, false, true);
        emit SharedWallet.ProposalExecuted(0, nonOwner, 1 ether);
        sharedWallet.executeProposal(0);
    }

    function test_executeProposal_revertsForNonOwner() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(nonOwner);
        vm.expectRevert(SharedWallet.NotOwner.selector);
        sharedWallet.executeProposal(0);
    }

    function test_executeProposal_revertsForInvalidId() public {
        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.InvalidId.selector);
        sharedWallet.executeProposal(0);
    }

    function test_executeProposal_revertsIfAlreadyExecuted() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        sharedWallet.executeProposal(0);

        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.ProposalAlreadyExecuted.selector);
        sharedWallet.executeProposal(0);
    }

    function test_executeProposal_revertsIfInsufficientApprovals() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.InsufficientApproval.selector);
        sharedWallet.executeProposal(0);
    }

    function test_executeProposal_revertsIfInsufficientBalance() public {
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.InsufficientBalanceInContract.selector);
        sharedWallet.executeProposal(0);
    }

    function test_executeProposal_revertsIfTransferFails() public {
        RejectEther rejecter = new RejectEther();

        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(address(rejecter), 1 ether, "Pay rejecter");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.TransactionFailed.selector);
        sharedWallet.executeProposal(0);
    }

    function test_executeProposal_revertsAfterRevokedBelowThreshold() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(wallet2);
        sharedWallet.revokeApproval(0);

        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.InsufficientApproval.selector);
        sharedWallet.executeProposal(0);
    }

    // ========================
    // getBalance Tests
    // ========================

    function test_getBalance_returnsZeroInitially() public {
        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 0);
    }

    function test_getBalance_revertsForNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(SharedWallet.NotOwner.selector);
        sharedWallet.getBalance();
    }

    function test_getBalance_updatesAfterDeposit() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 3 ether}();

        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 3 ether);
    }

    function test_getBalance_updatesAfterExecution() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 4 ether, "Pay someone");

        vm.prank(wallet1);
        sharedWallet.approveProposal(0);
        vm.prank(wallet2);
        sharedWallet.approveProposal(0);

        vm.prank(wallet1);
        sharedWallet.executeProposal(0);

        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 6 ether);
    }

    // ========================
    // End-to-End / Integration
    // ========================

    function test_fullFlow_proposeApproveExecute() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 5 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 2 ether, "Monthly salary");

        vm.prank(wallet2);
        sharedWallet.approveProposal(0);
        vm.prank(wallet3);
        sharedWallet.approveProposal(0);

        uint256 balBefore = nonOwner.balance;
        vm.prank(wallet3);
        sharedWallet.executeProposal(0);

        assertEq(nonOwner.balance, balBefore + 2 ether);

        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 3 ether);
    }

    function test_multipleProposals_independentExecution() public {
        vm.prank(wallet1);
        sharedWallet.deposit{value: 10 ether}();

        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 1 ether, "First payment");
        vm.prank(wallet1);
        sharedWallet.proposeTransaction(nonOwner, 2 ether, "Second payment");

        vm.prank(wallet1);
        sharedWallet.approveProposal(1);
        vm.prank(wallet2);
        sharedWallet.approveProposal(1);

        vm.prank(wallet1);
        sharedWallet.executeProposal(1);

        vm.prank(wallet1);
        vm.expectRevert(SharedWallet.InsufficientApproval.selector);
        sharedWallet.executeProposal(0);

        vm.prank(wallet1);
        assertEq(sharedWallet.getBalance(), 8 ether);
    }
}
