// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Token {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public maxSupply;
    address public owner;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    error NotOwner();
    error InvalidAmount();
    error InsufficientBalance();
    error InvalidAddress();
    error NotAllowed();
    error MaxSupplyReached();

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _maxSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        maxSupply = _maxSupply;
        owner = msg.sender;
    }

    /// @notice Modifier to check if the caller is the owner
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    /// @notice Modifier to check if the caller is allowed to spend tokens
    modifier allowedSpender(address from, uint256 _amount) {
        if (msg.sender != from && allowances[from][msg.sender] < _amount) {
            revert NotAllowed();
        }
        _;
    }

    /// @notice Function to get the balance of an account
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    /// @notice Function to transfer tokens to an account
    function transfer(address to, uint256 amount) public returns (bool) {
        if (to == address(0)) {
            revert InvalidAddress();
        }
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Function to transfer tokens to an account
    function transferFrom(address from, address to, uint256 amount) public allowedSpender(from, amount) returns (bool) {
        if (from == address(0) || to == address(0)) {
            revert InvalidAddress();
        }
        if (balances[from] < amount) {
            revert InsufficientBalance();
        }
        if (msg.sender != from && allowances[from][msg.sender] != type(uint256).max) {
            allowances[from][msg.sender] -= amount;
        }
        balances[from] -= amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice Function to approve an amount of tokens for a spender
    function approve(address spender, uint256 amount) public returns (bool) {
        if (spender == address(0) || msg.sender == spender) {
            revert InvalidAddress();
        }
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Function to get the allowance of a spender
    function allowance(address _owner, address _spender) public view returns (uint256) {
        if (_owner == address(0) || _spender == address(0)) {
            revert InvalidAddress();
        }
        return allowances[_owner][_spender];
    }

    /// @notice Function to mint tokens
    function mint(address to, uint256 amount) public onlyOwner {
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (to == address(0)) {
            revert InvalidAddress();
        }
        if (totalSupply + amount > maxSupply) {
            revert MaxSupplyReached();
        }
        totalSupply += amount;
        balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @notice Function to burn tokens
    function burn(uint256 amount) public {
        if (amount == 0) {
            revert InvalidAmount();
        }
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }
        totalSupply -= amount;
        balances[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
