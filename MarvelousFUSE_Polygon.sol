// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;
}

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
contract MarvelousFUSE_PoS is AccessControl, ERC20Pausable, AccessControlMixin, ContextMixin, IChildToken, NativeMetaTransaction, AccessRights  {
    using SafeMath for uint256;
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    uint256 public maximumSupply;
    uint256 public initialSupply;

    event MintTokens(address minter, address account, uint256 amount);
  
    constructor (string memory name_, string memory symbol_, address childChainManager) public ERC20(name_, symbol_) {
        _setupContractId("MarvelousFUSE (PoS)");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CREATOR_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, childChainManager);
 
        maximumSupply = 500000000 * (10 ** 18);
        initialSupply = 150000000 * (10 ** 18);

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

    function mint(address account, uint256 amount) external only(MINTER_ROLE) {
        _mintTokens(account, amount);
    }    
    
    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */
    function deposit(address user, bytes calldata depositData)
        external
        override
        only(DEPOSITOR_ROLE)
    {
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }


}
