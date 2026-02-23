// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Bank {
    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event Pause();
    event Unpause();

    error InvalidAmount();
    error InvalidAccount();
    error InsufficientBalance();
    error InsufficientBalanceInContract();
    error TransactionFailed();
    error NotOwner();
    error Paused();
    error NotPaused();

    address private owner;
    bool private paused;
    mapping(address => uint256) private balances;

    constructor() {
        owner = msg.sender;
        paused = false;
    }

    /// @notice Modifier to only allow the owner to call the function
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @notice Internal function to only allow the owner to call the function
    function _onlyOwner() internal view {
        if (msg.sender != owner) {
            revert NotOwner();
        }
    }

    /// @notice Modifier to only allow the function to be called when the contract is not paused
    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    /// @notice Internal function to only allow the function to be called when the contract is not paused
    function _whenNotPaused() internal view {
        if (paused) {
            revert Paused();
        }
    }

    /// @notice Modifier to only allow the function to be called when the contract is paused
    modifier whenPaused() {
        _whenPaused();
        _;
    }

    /// @notice Internal function to only allow the function to be called when the contract is paused
    function _whenPaused() internal view {
        if (!paused) {
            revert NotPaused();
        }
    }

    /// @notice Pause the contract
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

    /// @notice Unpause the contract
    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }

    /// @notice Deposit ETH into the bank
    function deposit() public payable {
        if (msg.value == 0) {
            revert InvalidAmount();
        }

        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Withdraw ETH amount from the bank
    function withdraw(uint256 amount) public whenNotPaused {
        if (amount == 0) {
            revert InvalidAmount();
        }

        uint256 balance = balances[msg.sender];
        if (balance < amount) {
            revert InsufficientBalance();
        }

        uint256 contractBalance = address(this).balance;
        if (contractBalance < amount) {
            revert InsufficientBalanceInContract();
        }

        balances[msg.sender] -= amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransactionFailed();
        }

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Transfer ETH amount from the caller to the account
    function transfer(address to, uint256 amount) public whenNotPaused {
        if (amount == 0) {
            revert InvalidAmount();
        }

        if (to == address(0)) {
            revert InvalidAccount();
        }

        uint256 balance = balances[msg.sender];
        if (balance < amount) {
            revert InsufficientBalance();
        }
        uint256 contractBalance = address(this).balance;
        if (contractBalance < amount) {
            revert InsufficientBalanceInContract();
        }

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
    }

    /// @notice Get the balance of the account
    function getBalance(address account) public view returns (uint256) {
        if (account == address(0)) {
            revert InvalidAccount();
        }

        return balances[account];
    }

    /// @notice Get the balance of the contract
    function getContractBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /// @notice Emergency withdraw all ETH from the contract
    function emergencyWithdrawAll(address to) public onlyOwner whenPaused {
        if (to == address(0)) {
            revert InvalidAccount();
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert InsufficientBalanceInContract();
        }

        (bool success,) = payable(to).call{value: balance}("");
        if (!success) {
            revert TransactionFailed();
        }

        emit EmergencyWithdraw(to, balance);
    }
}
