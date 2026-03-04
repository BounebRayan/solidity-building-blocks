// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GovernanceToken.sol";

contract DAOGovernance is Ownable {
    GovernanceToken public immutable token;
    uint256 public proposalThreshold;

    struct Proposal {
        address proposer;
        address target;
        bytes data;
        uint256 value;
        uint256 snapshotBlock;
        uint256 startBlock;
        uint256 endBlock;
        uint256 quorum;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
    }

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed,
        Canceled
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }

    struct Receipt {
        bool hasVoted;
        VoteType support;
        uint256 weight;
    }

    mapping(uint256 => Proposal) private _proposals;
    uint256 public proposalCount;
    mapping(uint256 => mapping(address => Receipt)) private _receipts;

    event ProposalCreated(
        uint256 indexed proposalId,
        address proposer,
        address target,
        uint256 startBlock,
        uint256 endBlock,
        uint256 quorum
    );
    event VoteCast(uint256 indexed proposalId, address indexed voter, VoteType support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    constructor(GovernanceToken _token, uint256 _proposalThreshold) Ownable(msg.sender) {
        token = _token;
        proposalThreshold = _proposalThreshold;
    }

    receive() external payable {}

    // ──────────────────── Views ────────────────────

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId < proposalCount, "Invalid proposal");
        Proposal storage p = _proposals[proposalId];

        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;
        if (block.number < p.startBlock) return ProposalState.Pending;
        if (block.number <= p.endBlock) return ProposalState.Active;

        if (_quorumReached(p) && _voteSucceeded(p)) {
            return ProposalState.Succeeded;
        }
        return ProposalState.Defeated;
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        require(proposalId < proposalCount, "Invalid proposal");
        return _proposals[proposalId];
    }

    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return _receipts[proposalId][voter];
    }

    // ──────────────────── Actions ────────────────────

    function createProposal(
        address target,
        bytes calldata data,
        uint256 value,
        uint256 startBlock,
        uint256 endBlock,
        uint256 quorum
    ) external returns (uint256) {
        require(token.getVotes(msg.sender) >= proposalThreshold, "Below proposal threshold");
        require(startBlock > block.number, "Start must be future block");
        require(endBlock > startBlock, "End must be after start");
        require(target != address(0), "Invalid target");
        require(quorum > 0, "Quorum must be > 0");

        uint256 proposalId = proposalCount++;

        _proposals[proposalId] = Proposal({
            proposer: msg.sender,
            target: target,
            data: data,
            value: value,
            snapshotBlock: block.number,
            startBlock: startBlock,
            endBlock: endBlock,
            quorum: quorum,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            canceled: false
        });

        emit ProposalCreated(proposalId, msg.sender, target, startBlock, endBlock, quorum);
        return proposalId;
    }

    function castVote(uint256 proposalId, VoteType support) external {
        require(state(proposalId) == ProposalState.Active, "Voting not active");

        Receipt storage receipt = _receipts[proposalId][msg.sender];
        require(!receipt.hasVoted, "Already voted");

        Proposal storage p = _proposals[proposalId];
        uint256 weight = token.getPastVotes(msg.sender, p.snapshotBlock);
        require(weight > 0, "No voting power");

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.weight = weight;

        if (support == VoteType.For) {
            p.forVotes += weight;
        } else if (support == VoteType.Against) {
            p.againstVotes += weight;
        } else {
            p.abstainVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external payable {
        require(state(proposalId) == ProposalState.Succeeded, "Not succeeded");

        Proposal storage p = _proposals[proposalId];
        p.executed = true;

        (bool success, bytes memory returnData) = p.target.call{value: p.value}(p.data);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            }
            revert("Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        require(proposalId < proposalCount, "Invalid proposal");
        Proposal storage p = _proposals[proposalId];
        require(msg.sender == p.proposer || msg.sender == owner(), "Not authorized");
        require(!p.executed, "Already executed");
        require(!p.canceled, "Already canceled");

        p.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    // ──────────────────── Admin ────────────────────

    function setProposalThreshold(uint256 newThreshold) external onlyOwner {
        proposalThreshold = newThreshold;
    }

    // ──────────────────── Internal ────────────────────

    function _quorumReached(Proposal storage p) private view returns (bool) {
        return (p.forVotes + p.againstVotes + p.abstainVotes) >= p.quorum;
    }

    function _voteSucceeded(Proposal storage p) private view returns (bool) {
        return p.forVotes > p.againstVotes;
    }
}
