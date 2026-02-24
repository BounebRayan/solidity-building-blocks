// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract SharedWallet {
    event ProposalCreated(uint256 indexed id, address indexed proposer, address indexed to, uint256 amount, string description);
    event ProposalApproved(uint256 indexed id, address indexed approver);
    event ProposalExecuted(uint256 indexed id, address indexed to, uint256 amount);

    struct Proposal {
        uint256 id;
        uint256 amount;
        address to;
        mapping(address => bool) approvers;
        bool isExecuted;
        string description;
        address proposer;
        uint256 approvalCount;
    }

    mapping(address => bool) public isOwner;
    Proposal[] private proposals;
    uint256 private threshold;

    error InvalidOwnerArray();
    error InvalidAddress();
    error NotOwner();
    error TransactionFailed();
    error AlreadyApproved();
    error InvalidThreshold();
    error InvalidId();
    error ProposalAlreadyExecuted();
    
    constructor(address[] memory _owners, uint256 _threshold) {
        if (_owners.length == 0) {
            revert InvalidOwnerArray();
        }
        if (_threshold == 0 || _threshold > _owners.length) {
            revert InvalidThreshold();
        }
        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == address(0) || isOwner[_owners[i]]) {
                revert InvalidAddress();
            }
            isOwner[_owners[i]] = true;
        }
        threshold = _threshold;
    }

    /// @notice Modifier to check if the caller is an owner
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert NotOwner();
        }
        _;
    }
    
    /// @notice Modifier to check if the proposal is already executed
    modifier isValidId(uint256 _id) {
        if (_id >= proposals.length) {
            revert InvalidId();
        }
        _;
    }

    /// @notice Modifier to check if the caller has already approved the proposal
    modifier notHasAlreadyApproved(uint256 _id) {
        if (proposals[_id].approvers[msg.sender] == true) {
            revert AlreadyApproved();
        }
        _;
    }

    /// @notice Modifier to check if the proposal is not executed
    modifier notExecuted(uint256 _id) {
        if (proposals[_id].isExecuted) {
            revert ProposalAlreadyExecuted();
        }
        _;
    }
    /// @notice Function to deposit ETH into the wallet
    function deposit() public payable {       
    }

    /// @notice Function to propose a transaction
    function proposeTransaction(address _to, uint256 _amount, string memory _description) public onlyOwner {
        proposals.push();
        uint256 id = proposals.length - 1;

        Proposal storage p = proposals[id];
        p.amount = _amount;
        p.to = _to;
        p.description = _description;
        p.proposer = msg.sender;
        p.isExecuted = false;
        p.approvalCount = 0;
        emit ProposalCreated(proposals.length - 1, msg.sender, _to, _amount, _description);
    }

    /// @notice Function to approve a proposal
    function approveProposal(uint256 _id) public onlyOwner isValidId(_id) notHasAlreadyApproved(_id) notExecuted(_id) {
        proposals[_id].approvers[msg.sender] = true;
        proposals[_id].approvalCount++;
        emit ProposalApproved(_id, msg.sender);
        if (proposals[_id].approvalCount >= threshold && !proposals[_id].isExecuted) {
            require(address(this).balance >= proposals[_id].amount, "Insufficient balance");
            proposals[_id].isExecuted = true;
            (bool success, ) = payable(proposals[_id].to).call{value: proposals[_id].amount}("");
            if (!success) {
                revert TransactionFailed();
            }
            emit ProposalExecuted(_id, proposals[_id].to, proposals[_id].amount);
        }
    }
    
}