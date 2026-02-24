// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract SharedWallet {
    event ProposalCreated(
        uint256 indexed id, address indexed proposer, address indexed to, uint256 amount, string description
    );
    event ProposalApproved(uint256 indexed id, address indexed approver);
    event ProposalExecuted(uint256 indexed id, address indexed to, uint256 amount);
    event ApprovalRevoked(uint256 indexed id, address indexed approver);

    struct Proposal {
        uint256 amount;
        address to;
        mapping(address => bool) approvers;
        bool isExecuted;
        string description;
        address proposer;
        uint256 approvalCount;
    }

    mapping(address => bool) public isOwner;
    address[] public owners;
    Proposal[] private proposals;
    uint256 private threshold;

    error InvalidOwnerArray();
    error InvalidAddress();
    error NotOwner();
    error TransactionFailed();
    error AlreadyApproved();
    error NotAlreadyApproved();
    error InvalidThreshold();
    error InvalidId();
    error ProposalAlreadyExecuted();
    error InsufficientApproval();
    error InsufficientBalanceInContract();

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
            owners.push(_owners[i]);
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

    /// @notice Modifier to check if the caller has not approved the proposal
    modifier hasAlreadyApproved(uint256 _id) {
        if (proposals[_id].approvers[msg.sender] == false) {
            revert NotAlreadyApproved();
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
    function deposit() public payable {}

    /// @notice Function to propose a transaction
    function proposeTransaction(address _to, uint256 _amount, string memory _description) public onlyOwner {
        require(_to != address(0), "Invalid address");
        require(_amount > 0, "Invalid amount");
        require(bytes(_description).length > 0, "Invalid description");
        proposals.push();
        uint256 id = proposals.length - 1;
        // Need to use storage to avoid copying the proposal to memory because of the mapping proposals.push(Proposal({...}));
        Proposal storage p = proposals[id];
        p.amount = _amount;
        p.to = _to;
        p.description = _description;
        p.proposer = msg.sender;

        emit ProposalCreated(id, msg.sender, _to, _amount, _description);
    }

    /// @notice Function to approve a proposal
    function approveProposal(uint256 _id) public onlyOwner isValidId(_id) notHasAlreadyApproved(_id) notExecuted(_id) {
        Proposal storage p = proposals[_id];
        p.approvers[msg.sender] = true;
        p.approvalCount++;
        emit ProposalApproved(_id, msg.sender);
    }

    /// @notice Function to revoke an approval
    function revokeApproval(uint256 _id) public onlyOwner isValidId(_id) hasAlreadyApproved(_id) notExecuted(_id) {
        Proposal storage p = proposals[_id];
        p.approvers[msg.sender] = false;
        p.approvalCount--;
        emit ApprovalRevoked(_id, msg.sender);
    }

    /// @notice Function to execute a proposal
    function executeProposal(uint256 _id) public onlyOwner isValidId(_id) notExecuted(_id) {
        Proposal storage p = proposals[_id];
        if (p.approvalCount < threshold) {
            revert InsufficientApproval();
        }
        if (address(this).balance < p.amount) {
            revert InsufficientBalanceInContract();
        }
        p.isExecuted = true;
        (bool success,) = payable(p.to).call{value: p.amount}("");
        if (!success) {
            revert TransactionFailed();
        }
        emit ProposalExecuted(_id, p.to, p.amount);
    }

    /// @notice Function to get the balance of the contract
    function getBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }
}
