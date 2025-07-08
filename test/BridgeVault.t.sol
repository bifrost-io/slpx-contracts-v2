// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BridgeVault} from "../contracts/BridgeVault.sol";
import {VToken} from "../contracts/VToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BridgeVaultTest is Test {
    BridgeVault public bridgeVault;
    VToken public vToken;
    MockToken public mockToken;
    
    address public owner;
    address public vTokenAddress;
    address public user;
    
    event EthReceived(address indexed from, uint256 amount);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);
    
    function setUp() public {
        owner = makeAddr("owner");
        vTokenAddress = makeAddr("vToken");
        user = makeAddr("user");
        
        vm.startPrank(owner);
        
        // Deploy BridgeVault
        bridgeVault = new BridgeVault();
        bridgeVault.initialize(owner);
        
        // Add VToken address
        bridgeVault.addVTokenAddress(vTokenAddress);
        
        // Deploy MockToken
        mockToken = new MockToken();
        
        vm.stopPrank();
    }
    
    function test_Initialize() public {
        assertEq(bridgeVault.owner(), owner);
        assertTrue(bridgeVault.isVTokenAddress(vTokenAddress));
        assertEq(bridgeVault.vTokenAddressCount(), 1);
    }
    
    function test_ReceiveEth() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        
        vm.expectEmit(true, false, false, true);
        emit EthReceived(user, 5 ether);
        
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        assertTrue(success);
        
        assertEq(address(bridgeVault).balance, 5 ether);
    }
    
    function test_ReceiveToken() public {
        uint256 amount = 1000 * 10**mockToken.decimals();
        mockToken.mint(user, amount);
        
        vm.startPrank(user);
        
        // Transfer token directly to bridge vault
        mockToken.transfer(address(bridgeVault), amount);
        vm.stopPrank();
        
        assertEq(mockToken.balanceOf(address(bridgeVault)), amount);
    }
    
    function test_WithdrawEth() public {
        // First deposit some ETH
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        assertTrue(success);
        
        // Only VToken contract can withdraw
        vm.prank(vTokenAddress);
        vm.expectEmit(true, true, false, true);
        emit TokenWithdrawn(address(0), user, 3 ether);
        
        bridgeVault.withdrawToken(address(0), user, 3 ether);
        
        assertEq(address(bridgeVault).balance, 2 ether);
        assertEq(user.balance, 8 ether); // 5 ether - 3 ether = 2 ether
    }
    
    function test_WithdrawToken() public {
        // First deposit some token
        uint256 amount = 1000 * 10**mockToken.decimals();
        mockToken.mint(user, amount);
        
        vm.startPrank(user);
        mockToken.transfer(address(bridgeVault), amount);
        vm.stopPrank();
        
        // Only VToken contract can withdraw
        vm.prank(vTokenAddress);
        vm.expectEmit(true, true, false, true);
        emit TokenWithdrawn(address(mockToken), user, amount / 2);
        
        bridgeVault.withdrawToken(address(mockToken), user, amount / 2);
        
        assertEq(mockToken.balanceOf(address(bridgeVault)), amount / 2);
        assertEq(mockToken.balanceOf(user), amount / 2);
    }
    
    function test_WithdrawEth_NotVToken() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        assertTrue(success);
        
        // Non-VToken contract call should fail
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(BridgeVault.NotVTokenContract.selector, user));
        bridgeVault.withdrawToken(address(0), user, 1 ether);
    }
    
    function test_WithdrawToken_NotVToken() public {
        uint256 amount = 1000 * 10**mockToken.decimals();
        mockToken.mint(user, amount);
        
        vm.startPrank(user);
        mockToken.transfer(address(bridgeVault), amount);
        vm.stopPrank();
        
        // Non-VToken contract call should fail
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(BridgeVault.NotVTokenContract.selector, user));
        bridgeVault.withdrawToken(address(mockToken), user, amount / 2);
    }
    
    function test_EmergencyWithdraw() public {
        // Deposit some ETH and token
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        assertTrue(success);
        
        uint256 amount = 1000 * 10**mockToken.decimals();
        mockToken.mint(user, amount);
        
        vm.startPrank(user);
        mockToken.transfer(address(bridgeVault), amount);
        vm.stopPrank();
        
        // Owner can emergency withdraw
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdraw(address(0), user, 2 ether);
        bridgeVault.emergencyWithdraw(address(0), user, 2 ether);
        
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdraw(address(mockToken), user, amount / 2);
        bridgeVault.emergencyWithdraw(address(mockToken), user, amount / 2);
        
        assertEq(address(bridgeVault).balance, 3 ether);
        assertEq(mockToken.balanceOf(address(bridgeVault)), amount / 2);
    }
    
    function test_PauseUnpause() public {
        vm.prank(owner);
        bridgeVault.pause();
        assertTrue(bridgeVault.paused());
        
        vm.prank(owner);
        bridgeVault.unpause();
        assertFalse(bridgeVault.paused());
    }
    
    function test_ReceiveEth_WhenPaused() public {
        vm.prank(owner);
        bridgeVault.pause();
        
        vm.deal(user, 10 ether);
        vm.prank(user);
        
        vm.expectRevert("EnforcedPause");
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        // Due to revert, success should be false, but no assertion needed as vm.expectRevert handles it
    }
    
    function test_AddVTokenAddress() public {
        address newVToken = makeAddr("newVToken");
        
        vm.prank(owner);
        bridgeVault.addVTokenAddress(newVToken);
        
        assertTrue(bridgeVault.isVTokenAddress(newVToken));
        assertEq(bridgeVault.vTokenAddressCount(), 2);
    }
    
    function test_RemoveVTokenAddress() public {
        vm.prank(owner);
        bridgeVault.removeVTokenAddress(vTokenAddress);
        
        assertFalse(bridgeVault.isVTokenAddress(vTokenAddress));
        assertEq(bridgeVault.vTokenAddressCount(), 0);
    }
    
    function test_AddVTokenAddress_AlreadyExists() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BridgeVault.VTokenAddressAlreadyExists.selector, vTokenAddress));
        bridgeVault.addVTokenAddress(vTokenAddress);
    }
    
    function test_RemoveVTokenAddress_NotFound() public {
        address nonExistentVToken = makeAddr("nonExistentVToken");
        
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(BridgeVault.VTokenAddressNotFound.selector, nonExistentVToken));
        bridgeVault.removeVTokenAddress(nonExistentVToken);
    }
    
    function test_AddVTokenAddress_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(BridgeVault.InvalidWithdrawAddress.selector);
        bridgeVault.addVTokenAddress(address(0));
    }
    
    function test_WithdrawToZeroAddress() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        assertTrue(success);
        
        vm.prank(vTokenAddress);
        vm.expectRevert(BridgeVault.InvalidWithdrawAddress.selector);
        bridgeVault.withdrawToken(address(0), address(0), 1 ether);
    }
    
    function test_WithdrawZeroAmount() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        assertTrue(success);
        
        vm.prank(vTokenAddress);
        vm.expectRevert(BridgeVault.ZeroWithdrawAmount.selector);
        bridgeVault.withdrawToken(address(0), user, 0);
    }
    
    function test_WithdrawInsufficientBalance() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        assertTrue(success);
        
        vm.prank(vTokenAddress);
        vm.expectRevert(abi.encodeWithSelector(BridgeVault.InsufficientBalance.selector, address(0), 10 ether, 5 ether));
        bridgeVault.withdrawToken(address(0), user, 10 ether);
    }
    
    function test_MultipleVTokenAddresses() public {
        // Add another VToken address
        address secondVToken = makeAddr("secondVToken");
        vm.prank(owner);
        bridgeVault.addVTokenAddress(secondVToken);
        
        // Deposit some ETH
        vm.deal(user, 10 ether);
        vm.prank(user);
        (bool success, ) = address(bridgeVault).call{value: 5 ether}("");
        assertTrue(success);
        
        // First VToken can withdraw
        vm.prank(vTokenAddress);
        bridgeVault.withdrawToken(address(0), user, 2 ether);
        
        // Second VToken can also withdraw
        vm.prank(secondVToken);
        bridgeVault.withdrawToken(address(0), user, 2 ether);
        
        assertEq(address(bridgeVault).balance, 1 ether);
        assertEq(bridgeVault.vTokenAddressCount(), 2);
    }
} 