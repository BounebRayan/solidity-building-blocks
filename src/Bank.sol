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
    error MinBalanceNotMet();
    error TransactionFailed();
    error NotOwner();
    error Paused();
    error NotPaused();

    address private owner;
    bool private paused;
    mapping(address => uint256) private balances;
    uint256 private totalDeposits;
    uint16 private transactionFeePercentage;
    uint256 private minBalance;

    constructor() {
        owner = msg.sender;
        paused = false;
        transactionFeePercentage = 1;
        minBalance = 1 ether;
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

    /// @notice Set the transaction fee percentage
    function setTransactionFeePercentage(uint16 _transactionFeePercentage) public onlyOwner {
        transactionFeePercentage = _transactionFeePercentage;
    }

    /// @notice Set the min balance
    function setMinBalance(uint256 _minBalance) public onlyOwner {
        minBalance = _minBalance;
    }

    /// @notice Get the transaction fee percentage
    function getTransactionFeePercentage() public view onlyOwner returns (uint16) {
        return transactionFeePercentage;
    }

    /// @notice Get the min balance
    function getMinBalance() public view onlyOwner returns (uint256) {
        return minBalance;
    }

    /// @notice Deposit ETH into the bank
    function deposit() public payable whenNotPaused {
        if (msg.value == 0) {
            revert InvalidAmount();
        }

        balances[msg.sender] += msg.value - (msg.value * transactionFeePercentage / 100);
        totalDeposits += msg.value - (msg.value * transactionFeePercentage / 100);
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Withdraw ETH amount from the bank
    function withdraw(uint256 amount) public whenNotPaused {
        if (amount == 0) {
            revert InvalidAmount();
        }

        uint256 balance = balances[msg.sender];
        uint256 fee = amount * transactionFeePercentage / 100;

        if (balance < amount + fee) {
            revert InsufficientBalance();
        }
        if (balance - amount - fee < minBalance) {
            revert MinBalanceNotMet();
        }

        balances[msg.sender] -= amount + fee;
        totalDeposits -= amount + fee;
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
        uint256 fee = amount * transactionFeePercentage / 100;

        if (balance < amount + fee) {
            revert InsufficientBalance();
        }
        if (balance - amount - fee < minBalance) {
            revert MinBalanceNotMet();
        }

        balances[msg.sender] -= amount + fee;
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

    /// @notice Get the total deposits of the contract
    function getTotalDeposits() public view onlyOwner returns (uint256) {
        return totalDeposits;
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
