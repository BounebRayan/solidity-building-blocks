// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20, Ownable {
    struct Checkpoint {
        uint256 fromBlock;
        uint256 votes;
    }

    mapping(address => address) private _delegates;
    mapping(address => Checkpoint[]) private _checkpoints;
    Checkpoint[] private _totalSupplyCheckpoints;

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes);

    constructor() ERC20("GovernanceToken", "GOV") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 1e18);
    }

    // --- Public View Functions ---

    function delegates(address account) public view returns (address) {
        return _delegates[account];
    }

    function getVotes(address account) public view returns (uint256) {
        uint256 len = _checkpoints[account].length;
        return len == 0 ? 0 : _checkpoints[account][len - 1].votes;
    }

    function getPastVotes(address account, uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "Block not yet mined");
        return _checkpointLookup(_checkpoints[account], blockNumber);
    }

    function getPastTotalSupply(uint256 blockNumber) public view returns (uint256) {
        require(blockNumber < block.number, "Block not yet mined");
        return _checkpointLookup(_totalSupplyCheckpoints, blockNumber);
    }

    function numCheckpoints(address account) public view returns (uint256) {
        return _checkpoints[account].length;
    }

    // --- Delegation ---

    function delegate(address delegatee) external {
        _delegate(msg.sender, delegatee);
    }

    // --- Internals ---

    function _delegate(address delegator, address delegatee) internal {
        require(delegatee != address(0), "Cannot delegate to zero address");

        address oldDelegate = _delegates[delegator];
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, oldDelegate, delegatee);

        _moveVotingPower(oldDelegate, delegatee, balanceOf(delegator));
    }

    /// @dev Hook into every transfer/mint/burn to move voting power accordingly.
    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);

        _moveVotingPower(_delegates[from], _delegates[to], amount);

        if (from == address(0)) {
            _writeTotalSupplyCheckpoint(amount, true);
        }
        if (to == address(0)) {
            _writeTotalSupplyCheckpoint(amount, false);
        }
    }

    function _moveVotingPower(address src, address dst, uint256 amount) private {
        if (src == dst || amount == 0) return;

        if (src != address(0)) {
            uint256 oldWeight = getVotes(src);
            uint256 newWeight = oldWeight - amount;
            _writeCheckpoint(src, oldWeight, newWeight);
        }

        if (dst != address(0)) {
            uint256 oldWeight = getVotes(dst);
            uint256 newWeight = oldWeight + amount;
            _writeCheckpoint(dst, oldWeight, newWeight);
        }
    }

    function _writeCheckpoint(address account, uint256 oldWeight, uint256 newWeight) private {
        Checkpoint[] storage ckpts = _checkpoints[account];
        uint256 len = ckpts.length;

        if (len > 0 && ckpts[len - 1].fromBlock == block.number) {
            ckpts[len - 1].votes = newWeight;
        } else {
            ckpts.push(Checkpoint({fromBlock: block.number, votes: newWeight}));
        }

        emit DelegateVotesChanged(account, oldWeight, newWeight);
    }

    function _writeTotalSupplyCheckpoint(uint256 amount, bool increase) private {
        uint256 len = _totalSupplyCheckpoints.length;
        uint256 oldValue = len == 0 ? 0 : _totalSupplyCheckpoints[len - 1].votes;
        uint256 newValue = increase ? oldValue + amount : oldValue - amount;

        if (len > 0 && _totalSupplyCheckpoints[len - 1].fromBlock == block.number) {
            _totalSupplyCheckpoints[len - 1].votes = newValue;
        } else {
            _totalSupplyCheckpoints.push(Checkpoint({fromBlock: block.number, votes: newValue}));
        }
    }

    /// @dev Binary search over sorted checkpoints to find votes at a given block.
    function _checkpointLookup(Checkpoint[] storage ckpts, uint256 blockNumber) private view returns (uint256) {
        uint256 len = ckpts.length;
        if (len == 0) return 0;

        if (ckpts[len - 1].fromBlock <= blockNumber) {
            return ckpts[len - 1].votes;
        }

        if (ckpts[0].fromBlock > blockNumber) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = len - 1;
        while (low < high) {
            uint256 mid = (low + high + 1) / 2;
            if (ckpts[mid].fromBlock <= blockNumber) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        return ckpts[low].votes;
    }
}
