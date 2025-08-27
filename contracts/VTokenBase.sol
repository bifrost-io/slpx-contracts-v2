// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {Oracle} from "./Oracle.sol";
import {ITokenGateway, TeleportParams} from "./interfaces/ITokenGateway.sol";
import {IDispatcher, DispatchPost} from "@polytope-labs/ismp-solidity/interfaces/IDispatcher.sol";
import {StateMachine} from "@polytope-labs/ismp-solidity/interfaces/StateMachine.sol";
import {BridgeVault} from "./BridgeVault.sol";

abstract contract VTokenBase is
    Initializable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC165Upgradeable
{
    using Math for uint256;
    using SafeERC20 for IERC20;

    // =================== Type declarations ===================
    /// @notice Redeem request structure
    struct Withdrawal {
        uint256 queued;
        uint256 pending;
    }

    // =================== Constants ===================

    /// @notice Bifrost Token Gateway
    bytes32 private constant BIFROST_TOKEN_GATEWAY = 0x6d6f646ca09b1c60e86502450000000000000000000000000000000000000000;

    // =================== State variables ===================
    /// @notice mapping of admins of defined roles
    mapping(address => bool) public rolesAdmin;

    /// @notice Token gateway
    ITokenGateway public tokenGateway;

    /// @notice Bridge vault
    BridgeVault public bridgeVault;

    /// @notice Oracle
    Oracle public oracle;

    /// @notice Trigger address
    address public triggerAddress;

    /// @notice Bifrost destination
    bytes public bifrostDest;

    /// @notice Current cycle minted VToken amount
    uint256 public currentCycleMintVTokenAmount;

    /// @notice Current cycle minted Token amount
    uint256 public currentCycleMintTokenAmount;

    /// @notice Current cycle redeemed Token amount
    uint256 public currentCycleRedeemVTokenAmount;

    /// @notice Queued claim amount
    uint256 public queuedWithdrawal;

    /// @notice Completed claim amount
    uint256 public completedWithdrawal;

    /// @notice Withdraw queue mapping
    mapping(address => Withdrawal[]) public withdrawals;

    /// @notice  Max withdraw count
    uint256 public maxWithdrawCount;

    // =================== Events ===================
    /// @notice Emitted when role admin is changed
    event RoleAdminChanged(address indexed account, bool isAdmin);

    /// @notice Emitted when trigger address is changed
    event TriggerAddressChanged(address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when Oracle contract is changed
    event OracleChanged(address indexed oldOracle, address indexed newOracle);

    /// @notice Emitted when TokenGateway contract is changed
    event TokenGatewayChanged(address indexed oldTokenGateway, address indexed newTokenGateway);

    /// @notice Emitted when Bifrost destination is changed
    event BifrostDestChanged(bytes oldBifrostDest, bytes newBifrostDest);

    /// @notice Emitted when async mint operation is completed
    event AsyncMintCompleted(uint256 tokenAmount, uint256 vTokenAmount);

    /// @notice Emitted when async redeem operation is completed
    event AsyncRedeemCompleted(uint256 vTokenAmount);

    /// @notice Emitted when BridgeVault contract is changed
    event BridgeVaultChanged(address indexed oldBridgeVault, address indexed newBridgeVault);

    /// @notice Emitted when a claim is successfully processed
    event WithdrawalCompleted(address indexed receiver, uint256 tokenAmount);


    /// @notice Emitted when a claim is successfully processed
    event WithdrawalCompletedTo(address indexed caller, address indexed receiver, uint256 tokenAmount);

    /// @notice Emitted when max withdraw count is changed
    event MaxWithdrawCountChanged(uint256 maxWithdrawCount);

    // =================== Errors ===================
    /// @notice Throws if the caller is not a role admin
    error NotRoleAdmin(address account);

    /// @notice Throws if the caller is not the trigger address
    error NotTriggerAddress(address account);

    /// @notice Throws if the token amount is greater than the pending amount
    error ExceedPermittedAmount(uint256 tokenAmount, uint256 pendingAmount);

    error InsufficientWithdrawAmount(uint256 tokenAmount, uint256 availableAmount);

    /// @notice Throws if the withdraw count is greater than the max withdraw count
    error ExceedMaxWithdrawCount(uint256 withdrawCount);

    /// @notice Throws if the data parameter is invalid (last 20 bytes must be bridgeVault address)
    error InvalidDataParameter(address data, address expectedBridgeVault);

    // =================== Modifiers ===================
    /// @notice Modifier: Only trigger address can call
    modifier onlyTriggerAddress() {
        if (_msgSender() != triggerAddress) {
            revert NotTriggerAddress(_msgSender());
        }
        _;
    }

    /// @notice Modifier: Only role admin can call
    modifier onlyRoleAdmin() {
        if (!rolesAdmin[_msgSender()]) {
            revert NotRoleAdmin(_msgSender());
        }
        _;
    }

    function __VTokenBase_init(IERC20 _asset, address _owner, string memory _name, string memory _symbol)
        internal
        onlyInitializing
    {
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        __Ownable_init(_owner);
        __Pausable_init();
        __ERC165_init();
        _pause();
    }

    function setOracle(address _oracle) external onlyOwner {
        address oldOracle = address(oracle);
        oracle = Oracle(_oracle);
        emit OracleChanged(oldOracle, _oracle);
    }

    function setTokenGateway(address _tokenGateway) external onlyOwner {
        address oldTokenGateway = address(tokenGateway);
        tokenGateway = ITokenGateway(_tokenGateway);
        emit TokenGatewayChanged(oldTokenGateway, _tokenGateway);
    }

    function setBifrostDest(bytes memory _bifrostDest) external onlyOwner {
        bytes memory oldBifrostDest = bifrostDest;
        bifrostDest = _bifrostDest;
        emit BifrostDestChanged(oldBifrostDest, _bifrostDest);
    }

    function setTriggerAddress(address _triggerAddress) external onlyOwner {
        address oldAddress = triggerAddress;
        triggerAddress = _triggerAddress;
        emit TriggerAddressChanged(oldAddress, _triggerAddress);
    }

    function setBridgeVault(address payable _bridgeVault) external onlyOwner {
        address oldBridgeVault = address(bridgeVault);
        bridgeVault = BridgeVault(_bridgeVault);
        emit BridgeVaultChanged(oldBridgeVault, _bridgeVault);
    }

    function setMaxWithdrawCount(uint256 _maxWithdrawCount) external onlyOwner {
        maxWithdrawCount = _maxWithdrawCount;
        emit MaxWithdrawCountChanged(_maxWithdrawCount);
    }

    function approveTokenGateway(address token) external onlyOwner {
        IERC20(token).approve(address(tokenGateway), type(uint256).max);
    }

    function withdrawFeeToken(address token, uint256 amount, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function changeRoleAdmin(address _account, bool _isAdmin) external onlyOwner {
        rolesAdmin[_account] = _isAdmin;
        emit RoleAdminChanged(_account, _isAdmin);
    }

    function asyncMint(uint256 relayerFee, uint64 timeout) external payable onlyTriggerAddress {
        bytes memory data = abi.encode(uint32(block.chainid), currentCycleMintVTokenAmount);
        bytes32 assetId = keccak256(bytes(ERC20(asset()).symbol()));
        TeleportParams memory params = TeleportParams({
            amount: currentCycleMintTokenAmount,
            relayerFee: relayerFee,
            assetId: assetId,
            redeem: true,
            to: BIFROST_TOKEN_GATEWAY,
            dest: bifrostDest,
            timeout: timeout,
            nativeCost: 0,
            data: data
        });
        tokenGateway.teleport(params);

        emit AsyncMintCompleted(currentCycleMintTokenAmount, currentCycleMintVTokenAmount);
        // reset currentCycleMintVTokenAmount and currentCycleMintTokenAmount
        currentCycleMintVTokenAmount = 0;
        currentCycleMintTokenAmount = 0;
    }

    function asyncRedeem(uint256 relayerFee, uint64 timeout, bytes32 to, bytes memory data)
        external
        payable
        onlyTriggerAddress
    {
        // Validate data parameter: last 20 bytes must be bridgeVault address
        if (data.length < 20) {
            revert InvalidDataParameter(address(0), address(bridgeVault));
        }

        address dataBridgeVault;
        assembly {
            // Get the last 20 bytes from data
            // data.length is stored at data pointer
            // We need to read from data + 32 + (data.length - 20)
            let dataLength := mload(data)
            let startPos := add(data, add(32, sub(dataLength, 20)))
            dataBridgeVault := shr(96, mload(startPos))
        }

        // Compare addresses as integers to handle case differences
        if (dataBridgeVault != address(bridgeVault)) {
            revert InvalidDataParameter(dataBridgeVault, address(bridgeVault));
        }

        // Send redeem request to Bifrost
        bytes32 assetId = keccak256(bytes(symbol()));
        TeleportParams memory params = TeleportParams({
            amount: currentCycleRedeemVTokenAmount,
            relayerFee: relayerFee,
            assetId: assetId,
            redeem: true,
            to: to,
            dest: bifrostDest,
            timeout: timeout,
            nativeCost: 0,
            data: data
        });
        tokenGateway.teleport(params);
        emit AsyncRedeemCompleted(currentCycleRedeemVTokenAmount);
        currentCycleRedeemVTokenAmount = 0;
    }

    function increaseCurrentCycleAmount(
        uint256 _currentCycleTokenAmount,
        uint256 _currentCycleVTokenAmount,
        uint256 _currentCycleRedeemVTokenAmount
    ) external onlyTriggerAddress {
        currentCycleMintTokenAmount += _currentCycleTokenAmount;
        currentCycleMintVTokenAmount += _currentCycleVTokenAmount;
        currentCycleRedeemVTokenAmount += _currentCycleRedeemVTokenAmount;
    }

    function withdrawComplete() external {
        withdrawCompleteTo(msg.sender);
    }

    function withdrawCompleteTo(address receiver) public returns (uint256) {
        Withdrawal[] storage _withdrawals = withdrawals[msg.sender];
        (uint256 totalAvailableAmount, uint256 pendingDeleteIndex, uint256 pendingDeleteAmount) =
            canWithdrawalAmount(msg.sender);

        unchecked {
            for (uint256 i = 0; i < pendingDeleteIndex; i++) {
                _withdrawals.pop();
            }
        }

        if (pendingDeleteAmount > 0) {
            _withdrawals[_withdrawals.length - 1].pending -= pendingDeleteAmount;
            _withdrawals[_withdrawals.length - 1].queued += pendingDeleteAmount;
        }

        completedWithdrawal += totalAvailableAmount;
        bridgeVault.withdrawToken(address(asset()), receiver, totalAvailableAmount);
        emit WithdrawalCompletedTo(msg.sender, receiver, totalAvailableAmount);
        return totalAvailableAmount;
    }

    function getTotalBalance() public view returns (uint256) {
        return bridgeVault.getBalance(address(asset())) + completedWithdrawal;
    }

    function canWithdrawalAmount(address target) public view returns (uint256, uint256, uint256) {
        Withdrawal[] memory _withdrawals = withdrawals[target];
        uint256 totalAvailableAmount = 0;
        uint256 totalBalance = getTotalBalance();
        uint256 pendingDeleteIndex = 0;
        uint256 pendingDeleteAmount = 0;
        for (uint256 i = _withdrawals.length; i > 0; i--) {
            uint256 index = i - 1;
            if (totalBalance > _withdrawals[index].queued) {
                uint256 currentAvailableAmount = totalBalance - _withdrawals[index].queued;
                if (currentAvailableAmount < _withdrawals[index].pending) {
                    totalAvailableAmount += currentAvailableAmount;
                    pendingDeleteAmount += currentAvailableAmount;
                    break;
                } else {
                    totalAvailableAmount += _withdrawals[index].pending;
                    currentAvailableAmount -= _withdrawals[index].pending;
                    pendingDeleteIndex += 1;
                }
            }
        }
        return (totalAvailableAmount, pendingDeleteIndex, pendingDeleteAmount);
    }

    function getWithdrawals(address target) public view returns (Withdrawal[] memory) {
        return withdrawals[target];
    }

    // =================== ERC4626 functions ===================
    function totalAssets() public view virtual override returns (uint256) {
        (uint256 tokenAmount,) = oracle.poolInfo(address(asset()));
        return tokenAmount;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return oracle.getVTokenAmountByToken(address(asset()), assets, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return oracle.getTokenAmountByVToken(address(asset()), shares, rounding);
    }

    function deposit(uint256 assets, address receiver) public virtual override whenNotPaused returns (uint256) {
        currentCycleMintTokenAmount += assets;
        uint256 vTokenAmount = super.deposit(assets, receiver);
        currentCycleMintVTokenAmount += vTokenAmount;
        return vTokenAmount;
    }

    function mint(uint256 shares, address receiver) public virtual override whenNotPaused returns (uint256) {
        currentCycleMintVTokenAmount += shares;
        uint256 tokenAmount = super.mint(shares, receiver);
        currentCycleMintTokenAmount += tokenAmount;
        return tokenAmount;
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

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        _mint(address(this), shares);

        // Update withdrawal info
        Withdrawal[] storage _withdrawals = withdrawals[caller];
        uint256 length = _withdrawals.length;

        if (length >= maxWithdrawCount) {
            revert ExceedMaxWithdrawCount(length);
        }

        _withdrawals.push();
        if (length > 0) {
            unchecked {
                for (uint256 i = length; i > 0; i--) {
                    _withdrawals[i] = _withdrawals[i - 1];
                }
            }
        }

        _withdrawals[0] = Withdrawal({queued: queuedWithdrawal, pending: assets});
        queuedWithdrawal += assets;
        // Update current cycle redeem amounts
        currentCycleRedeemVTokenAmount += shares;

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    // =================== ERC6160 functions ===================
    function mint(address _to, uint256 _amount) public onlyRoleAdmin {
        super._mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyRoleAdmin {
        super._burn(_from, _amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4626).interfaceId || interfaceId == type(IERC20).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
