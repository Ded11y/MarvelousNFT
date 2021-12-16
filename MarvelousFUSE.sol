// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import {AccessControlMixin} from "./AccessControlMixin.sol";
import {AccessRights} from "./AccessRights.sol";
import {ContextMixin} from "./ContextMixin.sol";
import {NativeMetaTransaction} from "./NativeMetaTransaction.sol";

/// @title MarvelousFUSE
/// @author Marvelous Team
/// @dev The main token contract for BadDays Utility token
contract MarvelousFUSE is AccessControl, ERC20Pausable, AccessControlMixin, ContextMixin, NativeMetaTransaction, AccessRights  {
    using SafeMath for uint256;
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PREDICATE_ROLE = keccak256("PREDICATE_ROLE");

    uint256 public maximumSupply;
    //uint256 public mintableTokens;
    //uint256 public mintedTokens;
    uint256 public initialSupply;

    event MintTokens(address minter, address account, uint256 amount);
  
    constructor (string memory name_, string memory symbol_) public ERC20(name_, symbol_) {
        _setupContractId("MarvelousFUSE");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CREATOR_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(PREDICATE_ROLE, _msgSender());

        maximumSupply = 500000000 * (10 ** 18);
        initialSupply = 150000000 * (10 ** 18);
        //mintableTokens = maximumSupply - initialSupply;

        _mint(msg.sender, initialSupply);
        _initializeEIP712(name_);
    }

    function pause() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MarvelousNFT: must have admin role to mint");
        super._pause();
    }

    function unpause() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MarvelousNFT: must have admin role to mint");
        super._unpause();
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal override view returns (address payable sender)
    {
        return ContextMixin.msgSender();
    }

    function _mintTokens(address account, uint256 amount) internal {
        uint256 afterMint = totalSupply().add(amount);
        require(afterMint <= maximumSupply, "MarvelousNFT: amount exceeds mintable tokens.");
        _mint(account, amount);

        emit MintTokens(_msgSender(), account, amount);
    }

    function mintTokens(address account, uint256 amount) external only(MINTER_ROLE) {
        _mintTokens(account, amount);
    }

    function mint(address account, uint256 amount) external only(PREDICATE_ROLE) {
        _mintTokens(account, amount);
    }

}
