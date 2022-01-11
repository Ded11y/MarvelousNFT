// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IChildToken {
    function deposit(address user, bytes calldata depositData) external;
}

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import {AccessControlMixin} from "./AccessControlMixin.sol";
import {AccessRights} from "./AccessRights.sol";
import {ContextMixin} from "./ContextMixin.sol";
import {NativeMetaTransaction} from "./NativeMetaTransaction.sol";

/// @title MarvelousNFT
/// @author Marvelous Team
/// @dev The main token contract for BadDays Utility token

contract MarvelousNFT_PoS is ERC20Burnable, ERC20Pausable, AccessControl, AccessControlMixin, ContextMixin, IChildToken, NativeMetaTransaction, AccessRights  {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    address payable private seasonPoolWallet;
    address payable private liquidityPoolWallet;
    address payable private stakingPoolWallet;

    uint256 public maximumSupply;
    uint256 public minimumSupply;
    uint256 public burnRate;
    uint256 public initialSupply;
    uint256 public seasonBattlesPool;
    uint256 public liquidityPool;
    uint256 public stakingPool;

    mapping(address => bool) internal whitelisted;

    event BurnTokens(address _address, uint256 _amount);
    event UpdateBurnRate(uint256 _newRate);
    event MintTokens(address minter, address account, uint256 amount);
    event SetSeasonPoolWallet(address sender, address wallet);
    event SetLiquidityPoolWallet(address sender, address wallet);
    event SetStakingPoolWallet(address sender, address wallet);
    event WithdrawSeasonPool(address sender, uint256 amount);
    event WithdrawLiquidityPool(address sender, uint256 amount);
    event WithdrawStakingPool(address sender, uint256 amount);
    event UpdateWhitelist(address sender, address[] accounts, bool mode);


    constructor (string memory name_, string memory symbol_, address childChainManager) public ERC20(name_, symbol_) {
        _setupContractId("MarvelousNFT (PoS)");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CREATOR_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(DEPOSITOR_ROLE, childChainManager);

        whitelisted[msg.sender] = true;

        burnRate = 500; // 5.0% per tx of non-whitelisted address

        maximumSupply = 275000000 * (10 ** 18);
        initialSupply = 275000000 * (10 ** 18);
        minimumSupply = 50000000 * (10 ** 18);

        _initializeEIP712(name_);
    }

    function pause() external only(DEFAULT_ADMIN_ROLE) {
        super._pause();
    }

    function unpause() external only(DEFAULT_ADMIN_ROLE) {
        super._unpause();
    }

    // This is to support Native meta transactions
    // never use msg.sender directly, use _msgSender() instead
    function _msgSender() internal override view returns (address payable sender)
    {
        return ContextMixin.msgSender();
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */
    function deposit(address user, bytes calldata depositData) external override only(DEPOSITOR_ROLE)
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

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return super.transfer(to, _partialBurn(msg.sender, amount));
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        return super.transferFrom(from, to, _partialBurn(from, amount));
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override (ERC20, ERC20Pausable) {
        return super._beforeTokenTransfer(from, to, amount);
    }

    function _partialBurn(address from, uint256 amount) internal returns (uint256) {
        uint256 _burnAmount = 0;
        if (burnRate > 0) {
            _burnAmount = _calculateBurnAmount(from, amount);
        }

        if (_burnAmount > 0) {
            _transfer(from, address(this), _burnAmount);
            
            //2% for the staking pool
            stakingPool = stakingPool.add((_burnAmount.mul(2)).div(5));

             //1% for season battles prize pool
             seasonBattlesPool = seasonBattlesPool.add(_burnAmount.div(5));

             //1% for liquidity pool
             liquidityPool = liquidityPool.add(_burnAmount.div(5));

             //1% for burning tokens or 20% of the 5% tokens to be burned
             _burn(address(this), (_burnAmount.div(5)));

        }

        return amount.sub(_burnAmount);
    }

    function _calculateBurnAmount(address from, uint256 amount) internal view returns (uint256) {
        if (whitelisted[from]) return 0;
        uint256 _burnAmount = 0;

        //Calculate tokens to be burned
        if (totalSupply() > minimumSupply) {
            _burnAmount = amount.mul(burnRate).div(10000);
            uint256 _tryToBurn = totalSupply().sub(minimumSupply);
            if (_burnAmount > _tryToBurn) {
                _burnAmount = _tryToBurn;
            }
        }

        return _burnAmount;
    }

    function updateBurnRate(uint256 _newRate) external only(CREATOR_ROLE) {
        require(_newRate >= 0, "MarvelousNFT: Burn rate must be equal or greater than 0.");
        require(_newRate <= 800, "MarvelousNFT: Burn rate must be equal or less than 800.");
        burnRate = _newRate;

        emit UpdateBurnRate(burnRate);
    }

    function isWhitelisted(address _address) public view returns(bool) {
        return whitelisted[_address];
    }

    function updateWhitelist(address[] memory accounts, bool mode) external only(CREATOR_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelisted[accounts[i]] = mode;
        }
        emit UpdateWhitelist(_msgSender(), accounts, mode);
    }

    function setSeasonPoolWallet(address payable wallet) external virtual only(DEFAULT_ADMIN_ROLE) {
        seasonPoolWallet = wallet;
        emit SetSeasonPoolWallet(_msgSender(), wallet);
    }

    function setLiquidityPoolWallet(address payable wallet) external virtual only(DEFAULT_ADMIN_ROLE) {
        liquidityPoolWallet = wallet;
        emit SetLiquidityPoolWallet(_msgSender(), wallet);
    }
    
    function setStakingPoolWallet(address payable wallet) external virtual only(DEFAULT_ADMIN_ROLE) {
        stakingPoolWallet = wallet;
        emit SetStakingPoolWallet(_msgSender(), wallet);
    }

    function getSeasonPoolWallet() view external only(CREATOR_ROLE) returns (address wallet) {
        return seasonPoolWallet;
    }

    function getLiquidityPoolWallet() view external only(CREATOR_ROLE) returns (address wallet) {
        return liquidityPoolWallet;
    }

    function getStakingPoolWallet() view external only(CREATOR_ROLE) returns (address wallet) {
        return stakingPoolWallet;
    }
    
    function withdrawSeasonPool(uint256 amount) external only(DEFAULT_ADMIN_ROLE) {
        require(amount <= seasonBattlesPool, "MarvelousNFT: amount must be equal/less than current pool balance.");
        require(seasonPoolWallet != address(0), "MarvelousNFT: season pool wallet not defined.");
        seasonBattlesPool = seasonBattlesPool.sub(amount);
        _transfer(address(this), seasonPoolWallet, amount);

        emit WithdrawSeasonPool(_msgSender(), amount);
    }

    function withdrawLiquidityPool(uint256 amount) external only(DEFAULT_ADMIN_ROLE) {
        require(amount <= liquidityPool, "MarvelousNFT: amount must be equal/less than current pool balance.");
        require(liquidityPoolWallet != address(0), "MarvelousNFT: season pool wallet not defined.");
        liquidityPool = liquidityPool.sub(amount);
        _transfer(address(this), liquidityPoolWallet, amount);

        emit WithdrawLiquidityPool(_msgSender(), amount);
    }
    
    function withdrawStakingPool(uint256 amount) external only(DEFAULT_ADMIN_ROLE) {
        require(amount <= stakingPool, "MarvelousNFT: amount must be equal/less than current pool balance.");
        require(stakingPoolWallet != address(0), "MarvelousNFT: season pool wallet not defined.");
        stakingPool = stakingPool.sub(amount);
        _transfer(address(this), stakingPoolWallet, amount);

        emit WithdrawStakingPool(_msgSender(), amount);
    }

}
