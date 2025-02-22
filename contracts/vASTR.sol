// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

contract vASTR is Initializable, ERC4626Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC165Upgradeable {
    using Math for uint256;

    /// @notice mapping of admins of defined roles
    mapping(address => bool) public rolesAdmin;

    /// @notice Emitted when role admin is changed
    event RoleAdminChanged(address indexed account, bool isAdmin);

    /// @notice Throws if the caller is not a role admin
    error NotRoleAdmin(address account);

    function initialize(IERC20 asset, address owner) public initializer {
        __ERC20_init("Bifrost Voucher ASTR", "vASTR");
        __ERC4626_init(asset);
        __Ownable_init(owner);
        __Pausable_init();
        __ERC165_init();
        _pause();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function changeRoleAdmin(address _account, bool _isAdmin) external onlyOwner {
        rolesAdmin[_account] = _isAdmin;
    }

    function _isRoleAdmin() internal view returns (bool) {
        return rolesAdmin[_msgSender()];
    }

    // =================== ERC4626 functions ===================
    function deposit(uint256 assets, address receiver) public virtual override whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual override whenNotPaused returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        whenNotPaused
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        whenNotPaused
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    // =================== ERC6160 functions ===================
    function mint(address _to, uint256 _amount) public {
        if (!_isRoleAdmin()) {
            revert NotRoleAdmin(_msgSender());
        }
        super._mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        if (!_isRoleAdmin()) {
            revert NotRoleAdmin(_msgSender());
        }
        super._burn(_from, _amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4626).interfaceId || interfaceId == type(IERC20).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
