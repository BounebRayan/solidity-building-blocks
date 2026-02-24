// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Claim(address indexed beneficiary, uint256 amount);
    event Funded(uint256 amount);

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable startTime;
    uint256 public immutable duration;
    uint256 public immutable cliff;

    uint256 public totalAllocation;
    uint256 public releasedAmount;

    error NotBeneficiary();
    error InvalidBeneficiary();
    error InvalidStartTime();
    error InvalidDuration();
    error InvalidCliff();
    error NothingToClaim();
    error ZeroAmount();

    modifier onlyBeneficiary() {
        if (msg.sender != beneficiary) revert NotBeneficiary();
        _;
    }

    constructor(address _token, address _beneficiary, uint256 _startTime, uint256 _duration, uint256 _cliff)
        Ownable(msg.sender)
    {
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        if (_startTime < block.timestamp) revert InvalidStartTime();
        if (_duration == 0) revert InvalidDuration();
        if (_cliff > _duration) revert InvalidCliff();

        token = IERC20(_token);
        beneficiary = _beneficiary;
        startTime = _startTime;
        duration = _duration;
        cliff = _cliff;
    }

    /**
     * @notice Fund the vesting contract
     * Owner must approve tokens first
     */
    function fund(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();

        totalAllocation += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Funded(amount);
    }

    /**
     * @notice Returns total vested amount at current timestamp
     */
    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < startTime + cliff) {
            return 0;
        }

        uint256 elapsed = block.timestamp - startTime;

        if (elapsed >= duration) {
            return totalAllocation;
        }

        return (totalAllocation * elapsed) / duration;
    }

    /**
     * @notice Returns amount currently claimable
     */
    function claimable() public view returns (uint256) {
        return vestedAmount() - releasedAmount;
    }

    /**
     * @notice Claim vested tokens
     */
    function claim() external onlyBeneficiary nonReentrant {
        uint256 amount = claimable();
        if (amount == 0) revert NothingToClaim();

        releasedAmount += amount;

        token.safeTransfer(beneficiary, amount);

        emit Claim(beneficiary, amount);
    }
}
