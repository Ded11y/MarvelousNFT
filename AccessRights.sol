// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AccessRights is Pausable, AccessControl {

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CLEVEL_ROLE = keccak256("CLEVEL_ROLE");

    modifier onlyCEO() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Drakons Central Market: Only the CEO is allowed to call this function.");
        _;
    }

    modifier onlyCLevel() {
        require(hasRole(CLEVEL_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Drakons Central Market: Only the CEO is allowed to call this function.");
        _;
    }

}
