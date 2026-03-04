// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract NFTScratch is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    address private _contractOwner;

    string private _name;
    string private _symbol;

    error OnlyContractOwner();
    error NotTokenOwner();
    error NotOwnerOrApproved();
    error TokenDoesNotExist();
    error TokenAlreadyExists();
    error ZeroAddress();
    error TransferToNonReceiver();
    error ApprovalToCurrentOwner();

    constructor(string memory name_, string memory symbol_) {
        _contractOwner = msg.sender;
        _name = name_;
        _symbol = symbol_;
    }

    modifier onlyContractOwner() {
        if (msg.sender != _contractOwner) revert OnlyContractOwner();
        _;
    }

    modifier tokenExists(uint256 tokenId) {
        if (_owners[tokenId] == address(0)) revert TokenDoesNotExist();
        _;
    }

    // ─── ERC165 ──────────────────────────────────────────────

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == 0x80ac58cd // ERC721
                || interfaceId == 0x5b5e139f // ERC721Metadata
                || interfaceId == 0x01ffc9a7; // ERC165
    }

    // ─── ERC721 Metadata ─────────────────────────────────────

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) external view tokenExists(tokenId) returns (string memory) {
        return "";
    }

    // ─── ERC721 Core ─────────────────────────────────────────

    function balanceOf(address owner_) external view returns (uint256) {
        if (owner_ == address(0)) revert ZeroAddress();
        return _balances[owner_];
    }

    function ownerOf(uint256 tokenId) external view tokenExists(tokenId) returns (address) {
        return _owners[tokenId];
    }

    function approve(address to, uint256 tokenId) external tokenExists(tokenId) {
        address tokenOwner = _owners[tokenId];
        if (to == tokenOwner) revert ApprovalToCurrentOwner();
        if (msg.sender != tokenOwner && !_operatorApprovals[tokenOwner][msg.sender]) {
            revert NotOwnerOrApproved();
        }
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view tokenExists(tokenId) returns (address) {
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        if (operator == address(0)) revert ZeroAddress();
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner_, address operator) external view returns (bool) {
        return _operatorApprovals[owner_][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerOrApproved();
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotOwnerOrApproved();
        _transfer(from, to, tokenId);
        _checkOnERC721Received(msg.sender, from, to, tokenId, data);
    }

    // ─── Minting ─────────────────────────────────────────────

    function mint(address to, uint256 tokenId) external onlyContractOwner {
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != address(0)) revert TokenAlreadyExists();
        _balances[to]++;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    // ─── Internals ───────────────────────────────────────────

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (_owners[tokenId] != from) revert NotTokenOwner();
        if (to == address(0)) revert ZeroAddress();

        _tokenApprovals[tokenId] = address(0);
        _balances[from]--;
        _balances[to]++;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view tokenExists(tokenId) returns (bool) {
        address tokenOwner = _owners[tokenId];
        return (spender == tokenOwner || _tokenApprovals[tokenId] == spender || _operatorApprovals[tokenOwner][spender]);
    }

    function _checkOnERC721Received(address operator, address from, address to, uint256 tokenId, bytes memory data)
        private
    {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(operator, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert TransferToNonReceiver();
                }
            } catch {
                revert TransferToNonReceiver();
            }
        }
    }
}
