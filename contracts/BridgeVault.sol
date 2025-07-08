// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title BridgeVault
 * @notice Cross-chain bridge vault contract, responsible for receiving tokens and ETH transferred from other chains, and providing withdrawal functionality
 * @dev Only the VToken contract can withdraw funds
 */
contract BridgeVault is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    // =================== State variables ===================

    /// @notice VToken contract addresses, only these addresses can withdraw funds
    mapping(address => bool) public vTokenAddresses;

    /// @notice Total number of VToken addresses
    uint256 public vTokenAddressCount;

    // =================== Events ===================

    /// @notice Emitted when VToken address is added
    event VTokenAddressAdded(address indexed vTokenAddress);

    /// @notice Emitted when VToken address is removed
    event VTokenAddressRemoved(address indexed vTokenAddress);

    /// @notice Emitted when ETH is received
    event EthReceived(address indexed from, uint256 amount);

    /// @notice Emitted when ERC20 token is withdrawn
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);

    /// @notice Emitted when emergency withdraw is executed
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);

    // =================== Errors ===================

    /// @notice Thrown when the caller is not a VToken contract
    error NotVTokenContract(address caller);

    /// @notice Thrown when VToken address is already added
    error VTokenAddressAlreadyExists(address vTokenAddress);

    /// @notice Thrown when VToken address does not exist
    error VTokenAddressNotFound(address vTokenAddress);

    /// @notice Thrown when withdrawal amount exceeds balance
    error InsufficientBalance(address token, uint256 requested, uint256 available);

    /// @notice Thrown when withdrawal address is zero address
    error InvalidWithdrawAddress();

    /// @notice Thrown when withdrawal amount is zero
    error ZeroWithdrawAmount();

    // =================== Modifiers ===================

    /// @notice Only VToken contracts can call
    modifier onlyVToken() {
        if (!vTokenAddresses[_msgSender()]) {
            revert NotVTokenContract(_msgSender());
        }
        _;
    }

    // =================== Initialization ===================

    /// @notice Initialize the contract
    /// @param _owner Contract owner
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    // =================== Receive Function ===================

    /// @notice Receive ETH
    receive() external payable whenNotPaused nonReentrant {
        emit EthReceived(_msgSender(), msg.value);
    }

    // =================== External Functions ==================

    /// @notice Withdraw ERC20 token (only VToken contract can call)
    /// @param token ERC20 token address, use address(0) for ETH
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function withdrawToken(address token, address to, uint256 amount) external onlyVToken whenNotPaused nonReentrant {
        if (to == address(0)) {
            revert InvalidWithdrawAddress();
        }

        if (amount == 0) {
            revert ZeroWithdrawAmount();
        }

        uint256 addressBalance = getBalance(token);
        if (amount > addressBalance) {
            revert InsufficientBalance(token, amount, addressBalance);
        }

        if (token == address(0)) {
            (bool success,) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit TokenWithdrawn(token, to, amount);
    }

    // =================== Admin Functions ===================

    /// @notice Add VToken contract address
    /// @param _vTokenAddress VToken contract address to add
    function addVTokenAddress(address _vTokenAddress) external onlyOwner {
        if (_vTokenAddress == address(0)) {
            revert InvalidWithdrawAddress();
        }

        if (vTokenAddresses[_vTokenAddress]) {
            revert VTokenAddressAlreadyExists(_vTokenAddress);
        }

        vTokenAddresses[_vTokenAddress] = true;
        vTokenAddressCount++;

        emit VTokenAddressAdded(_vTokenAddress);
    }

    /// @notice Remove VToken contract address
    /// @param _vTokenAddress VToken contract address to remove
    function removeVTokenAddress(address _vTokenAddress) external onlyOwner {
        if (!vTokenAddresses[_vTokenAddress]) {
            revert VTokenAddressNotFound(_vTokenAddress);
        }

        vTokenAddresses[_vTokenAddress] = false;
        vTokenAddressCount--;

        emit VTokenAddressRemoved(_vTokenAddress);
    }

    /// @notice Check if address is a VToken contract
    /// @param _vTokenAddress Address to check
    /// @return true if it's a VToken contract
    function isVTokenAddress(address _vTokenAddress) external view returns (bool) {
        return vTokenAddresses[_vTokenAddress];
    }

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Emergency withdraw (only owner can call)
    /// @param token ERC20 token address, use address(0) for ETH
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) {
            revert InvalidWithdrawAddress();
        }

        if (amount == 0) {
            revert ZeroWithdrawAmount();
        }

        uint256 addressBalance = getBalance(token);
        if (amount > addressBalance) {
            revert InsufficientBalance(token, amount, addressBalance);
        }

        if (token == address(0)) {
            (bool success,) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit EmergencyWithdraw(token, to, amount);
    }

    // =================== View Functions ===================

    /// @notice Get token balance
    /// @param token ERC20 token address, use address(0) for ETH
    /// @return balance
    function getBalance(address token) public view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }
}
