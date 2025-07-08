// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {VTokenBase} from "../contracts/VTokenBase.sol";
import {BridgeVault} from "../contracts/BridgeVault.sol";
import {Oracle} from "../contracts/Oracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ITokenGateway, TeleportParams} from "../contracts/interfaces/ITokenGateway.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockVToken is VTokenBase {
    function initialize(IERC20 asset, address owner, string memory name, string memory symbol) public initializer {
        __VTokenBase_init(asset, owner, name, symbol);
    }
}

contract MockTokenGateway is ITokenGateway {
    function teleport(TeleportParams calldata params) external payable {
        // Mock implementation
    }
}

contract TestOracle is Oracle {
    constructor(address host) Oracle(host) {}
    function setPoolInfo(address token, uint256 tokenAmount, uint256 vTokenAmount) external {
        poolInfo[token] = PoolInfo({tokenAmount: tokenAmount, vTokenAmount: vTokenAmount});
    }
}

contract VTokenBaseTest is Test {
    MockVToken public vToken;
    BridgeVault public bridgeVault;
    MockToken public mockToken;
    Oracle public oracle;
    MockTokenGateway public tokenGateway;
    
    address public owner;
    address public triggerAddress;
    address public user1;
    address public user2;
    address public user3;
    
    event WithdrawCompleteCompleted(address indexed receiver, uint256 tokenAmount);
    event AsyncMintCompleted(uint256 tokenAmount, uint256 vTokenAmount);
    event AsyncRedeemCompleted(uint256 vTokenAmount);
    
    function setUp() public {
        owner = makeAddr("owner");
        triggerAddress = makeAddr("trigger");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        vm.startPrank(owner);
        
        // Deploy contracts
        mockToken = new MockToken();
        bridgeVault = new BridgeVault();
        bridgeVault.initialize(owner);
        oracle = new TestOracle(address(this));
        tokenGateway = new MockTokenGateway();
        
        // Deploy VToken
        vToken = new MockVToken();
        vToken.initialize(mockToken, owner, "Mock VToken", "mvMTK");
        
        // Setup VToken
        vToken.setBridgeVault(payable(address(bridgeVault)));
        vToken.setOracle(address(oracle));
        vToken.setTokenGateway(address(tokenGateway));
        vToken.setTriggerAddress(triggerAddress);
        vToken.setBifrostDest("0x1234567890abcdef");
        vToken.unpause();
        vToken.changeRoleAdmin(address(this), true);
        
        // Add VToken to BridgeVault
        bridgeVault.addVTokenAddress(address(vToken));
        
        // Setup Oracle with pool info
        oracle.setFeeRate(0, 0); // 1% fee
        TestOracle(address(oracle)).setPoolInfo(address(mockToken), 1000000 * 10**18, 1000000 * 10**18);
        vm.stopPrank();
    }
    
    function test_Initialization() public {
        assertEq(vToken.owner(), owner);
        assertEq(vToken.triggerAddress(), triggerAddress);
        assertEq(address(vToken.bridgeVault()), address(bridgeVault));
        assertEq(address(vToken.oracle()), address(oracle));
        assertEq(address(vToken.tokenGateway()), address(tokenGateway));
        assertFalse(vToken.paused());
    }
    
    function test_Deposit() public {
        uint256 initAmount = 1000;
        mockToken.mint(user1, initAmount);
        
        uint256 depositAmount = 100;
        vm.startPrank(user1);
        mockToken.approve(address(vToken), depositAmount);
        uint256 vTokenAmount = vToken.deposit(depositAmount, user1);
   
        assertEq(vToken.balanceOf(user1), vTokenAmount);
        assertEq(mockToken.balanceOf(address(vToken)), depositAmount);
        assertEq(mockToken.balanceOf(user1), initAmount - depositAmount);
        assertEq(vToken.currentCycleMintTokenAmount(), depositAmount);
        assertEq(vToken.currentCycleMintVTokenAmount(), vTokenAmount);

        mockToken.approve(address(vToken), depositAmount);
        uint256 vTokenAmount2 = vToken.deposit(depositAmount, user1);
        assertEq(vToken.balanceOf(user1), vTokenAmount + vTokenAmount2);
        assertEq(mockToken.balanceOf(address(vToken)), depositAmount * 2);
        assertEq(mockToken.balanceOf(user1), initAmount - depositAmount * 2);
        assertEq(vToken.currentCycleMintTokenAmount(), depositAmount * 2);
        assertEq(vToken.currentCycleMintVTokenAmount(), vTokenAmount + vTokenAmount2);
        vm.stopPrank();
    }
    
    function test_Mint() public {
        uint256 initAmount = 1000;
        mockToken.mint(user1, initAmount);
        uint256 mintAmount = 100;
        vm.startPrank(user1);
        mockToken.approve(address(vToken), mintAmount);
        uint256 tokenAmount = vToken.mint(mintAmount, user1);
        assertEq(vToken.balanceOf(user1), mintAmount);
        assertEq(mockToken.balanceOf(address(vToken)), tokenAmount);
        assertEq(mockToken.balanceOf(user1), initAmount - tokenAmount);
        assertEq(vToken.currentCycleMintTokenAmount(), tokenAmount);
        assertEq(vToken.currentCycleMintVTokenAmount(), mintAmount);

        mockToken.approve(address(vToken), mintAmount);
        uint256 tokenAmount2 = vToken.mint(mintAmount, user1);
        assertEq(vToken.balanceOf(user1), mintAmount * 2);
        assertEq(mockToken.balanceOf(address(vToken)), tokenAmount + tokenAmount2);
        assertEq(mockToken.balanceOf(user1), initAmount - tokenAmount - tokenAmount2);
        assertEq(vToken.currentCycleMintTokenAmount(), tokenAmount + tokenAmount2);
        assertEq(vToken.currentCycleMintVTokenAmount(), mintAmount * 2);
        vm.stopPrank();
    }
    
    function test_Redeem() public {
        uint256 depositAmount = 1000;
        uint256 redeemAmount = 100;
        vToken.mint(user1, depositAmount);
        vToken.mint(user2, depositAmount);
        vToken.mint(user3, depositAmount);

        vm.prank(user1);
        vToken.redeem(redeemAmount, user1, user1);
        (uint256 queued, uint256 pending) = vToken.withdrawals(user1);
        assertEq(queued, 0);
        assertEq(pending, redeemAmount);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), redeemAmount);
        assertEq(vToken.balanceOf(address(vToken)), redeemAmount);
        assertEq(vToken.balanceOf(user1), depositAmount - redeemAmount);
        assertEq(vToken.queuedWithdrawal(), redeemAmount);

        vm.prank(user2);
        vToken.redeem(redeemAmount, user2, user2);
        (queued, pending) = vToken.withdrawals(user2);
        assertEq(queued, redeemAmount);
        assertEq(pending, redeemAmount);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), redeemAmount * 2);
        assertEq(vToken.balanceOf(address(vToken)), redeemAmount * 2);
        assertEq(vToken.balanceOf(user2), depositAmount - redeemAmount);
        assertEq(vToken.queuedWithdrawal(), redeemAmount * 2);

        vm.prank(user3);
        vToken.redeem(redeemAmount, user3, user3); 
        (queued, pending) = vToken.withdrawals(user3);
        assertEq(queued, redeemAmount * 2);
        assertEq(pending, redeemAmount);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), redeemAmount * 3);
        assertEq(vToken.balanceOf(address(vToken)), redeemAmount * 3);
        assertEq(vToken.balanceOf(user3), depositAmount - redeemAmount);
        assertEq(vToken.queuedWithdrawal(), redeemAmount * 3);

        vm.prank(user1);
        vToken.redeem(redeemAmount, user1, user1);
        (queued, pending) = vToken.withdrawals(user1);
        assertEq(queued, redeemAmount * 2);
        assertEq(pending, redeemAmount * 2);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), redeemAmount * 4);
        assertEq(vToken.balanceOf(address(vToken)), redeemAmount * 4);
        assertEq(vToken.balanceOf(user1), depositAmount - redeemAmount * 2);
        assertEq(vToken.queuedWithdrawal(), redeemAmount * 4);

        vm.prank(user2);
        vToken.redeem(redeemAmount, user2, user2);
        (queued, pending) = vToken.withdrawals(user2);
        assertEq(queued, redeemAmount * 3);
        assertEq(pending, redeemAmount * 2);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), redeemAmount * 5);
        assertEq(vToken.balanceOf(address(vToken)), redeemAmount * 5);
        assertEq(vToken.balanceOf(user2), depositAmount - redeemAmount * 2);
        assertEq(vToken.queuedWithdrawal(), redeemAmount * 5);
    }


    function test_Withdraw() public {
        uint256 depositAmount = 1000;
        uint256 withdrawAmount = 100;
        vToken.mint(user1, depositAmount);
        vToken.mint(user2, depositAmount);
        vToken.mint(user3, depositAmount);

        vm.startPrank(user1);
        vToken.withdraw(withdrawAmount, user1, user1);
        (uint256 queued, uint256 pending) = vToken.withdrawals(user1);
        assertEq(queued, 0);
        assertEq(pending, withdrawAmount);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), withdrawAmount);
        assertEq(vToken.balanceOf(address(vToken)), withdrawAmount);
        assertEq(vToken.balanceOf(user1), depositAmount - withdrawAmount);
        assertEq(vToken.queuedWithdrawal(), withdrawAmount);
        vm.stopPrank();

        vm.startPrank(user2);
        vToken.withdraw(withdrawAmount, user2, user2);
        (queued, pending) = vToken.withdrawals(user2);
        assertEq(queued, withdrawAmount);
        assertEq(pending, withdrawAmount);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), withdrawAmount * 2);
        assertEq(vToken.balanceOf(address(vToken)), withdrawAmount * 2);
        assertEq(vToken.balanceOf(user2), depositAmount - withdrawAmount);
        assertEq(vToken.queuedWithdrawal(), withdrawAmount * 2);
        vm.stopPrank();

        vm.startPrank(user3);
        vToken.withdraw(withdrawAmount, user3, user3); 
        (queued, pending) = vToken.withdrawals(user3);
        assertEq(queued, withdrawAmount * 2);
        assertEq(pending, withdrawAmount);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), withdrawAmount * 3);
        assertEq(vToken.balanceOf(address(vToken)), withdrawAmount * 3);
        assertEq(vToken.balanceOf(user3), depositAmount - withdrawAmount);
        assertEq(vToken.queuedWithdrawal(), withdrawAmount * 3);
        vm.stopPrank();

        vm.startPrank(user1);
        vToken.withdraw(withdrawAmount, user1, user1);
        (queued, pending) = vToken.withdrawals(user1);
        assertEq(queued, withdrawAmount * 2);
        assertEq(pending, withdrawAmount * 2);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), withdrawAmount * 4);
        assertEq(vToken.balanceOf(address(vToken)), withdrawAmount * 4);
        assertEq(vToken.balanceOf(user1), depositAmount - withdrawAmount * 2);
        assertEq(vToken.queuedWithdrawal(), withdrawAmount * 4);
        vm.stopPrank();

        vm.startPrank(user2);
        vToken.withdraw(withdrawAmount, user2, user2);
        (queued, pending) = vToken.withdrawals(user2);
        assertEq(queued, withdrawAmount * 3);
        assertEq(pending, withdrawAmount * 2);
        assertEq(vToken.currentCycleRedeemVTokenAmount(), withdrawAmount * 5);
        assertEq(vToken.balanceOf(address(vToken)), withdrawAmount * 5);
        assertEq(vToken.balanceOf(user2), depositAmount - withdrawAmount * 2);
        assertEq(vToken.queuedWithdrawal(), withdrawAmount * 5);
        vm.stopPrank();
    }

    // TODO:
    function test_CanWithdrawAmount() public {
        uint256 depositAmount = 1000;
        uint256 withdrawAmount = 100;
        vToken.mint(user1, depositAmount);
        vToken.mint(user2, depositAmount);
        vToken.mint(user3, depositAmount);

        // first cycle withdraw
        vm.prank(user1);
        vToken.withdraw(withdrawAmount, user1, user1);
        vm.prank(user2);
        vToken.withdraw(withdrawAmount, user2, user2);
        vm.prank(user3);
        vToken.withdraw(withdrawAmount, user3, user3);

        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.canWithdrawalAmount(user3), 0);

        // Mock Async Redeem Success
        mockToken.mint(address(bridgeVault), 300);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 300);
        assertEq(vToken.canWithdrawalAmount(user1), 100);
        assertEq(vToken.canWithdrawalAmount(user2), 100);
        assertEq(vToken.canWithdrawalAmount(user3), 100);

        // user2 and user3 call withdrawComplete
        vm.prank(user2);
        vToken.withdrawComplete(100);
        vm.prank(user3);
        vToken.withdrawComplete(100);

        assertEq(vToken.canWithdrawalAmount(user1), 100);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.canWithdrawalAmount(user3), 0);


        // second cycle withdraw
        vm.prank(user1);
        vToken.withdraw(withdrawAmount, user1, user1);
        vm.prank(user2);
        vToken.withdraw(withdrawAmount, user2, user2);
        vm.prank(user3);
        vToken.withdraw(withdrawAmount, user3, user3);

        assertEq(vToken.canWithdrawalAmount(user1), 100);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.canWithdrawalAmount(user3), 0);

        // Mock Async Redeem Success
        mockToken.mint(address(bridgeVault), 300);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 400);
        assertEq(vToken.canWithdrawalAmount(user1), 200);
        assertEq(vToken.canWithdrawalAmount(user2), 100);
        assertEq(vToken.canWithdrawalAmount(user3), 100);

        // user1 and user2 call withdrawComplete
        vm.prank(user1);
        vToken.withdrawComplete(200);
        vm.prank(user2);
        vToken.withdrawComplete(100);

        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.canWithdrawalAmount(user3), 100);

        // Third cycle withdraw
        vm.prank(user1);
        vToken.withdraw(withdrawAmount, user1, user1);
        vm.prank(user2);
        vToken.withdraw(withdrawAmount, user2, user2);
        vm.prank(user3);
        vToken.withdraw(withdrawAmount, user3, user3);

        assertEq(mockToken.balanceOf(address(bridgeVault)), 100);
        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.canWithdrawalAmount(user3), 0);


        // Mock Async Redeem Success
        mockToken.mint(address(bridgeVault), 300);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 400);
        assertEq(vToken.canWithdrawalAmount(user1), 100);
        assertEq(vToken.canWithdrawalAmount(user2), 100);
        assertEq(vToken.canWithdrawalAmount(user3), 200);
    }
    
    function test_WithdrawComplete() public {
        uint256 initAmount = 1000;
        vToken.mint(user1, initAmount);
        vToken.mint(user2, initAmount);

        uint256 redeemAmount = 100;
        vm.prank(user1);
        vToken.redeem(redeemAmount, user1, user1);
        vm.prank(user2);
        vToken.redeem(redeemAmount, user2, user2);

        mockToken.mint(address(bridgeVault), 50);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 50);
        assertEq(vToken.canWithdrawalAmount(user1), 50);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.completedWithdrawal(), 0);
        assertEq(vToken.queuedWithdrawal(), 200);
        (uint256 queued, uint256 pending) = vToken.withdrawals(user1);
        assertEq(queued, 0);
        assertEq(pending, 100);
        (queued, pending) = vToken.withdrawals(user2);
        assertEq(queued, 100);
        assertEq(pending, 100);

        vm.prank(user1);
        vToken.withdrawComplete(10);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 40);
        assertEq(vToken.canWithdrawalAmount(user1), 40);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.completedWithdrawal(), 10);
        assertEq(vToken.queuedWithdrawal(), 200);

        vm.prank(user1);
        vToken.withdrawComplete(40);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 0);
        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.completedWithdrawal(), 50);
        assertEq(vToken.queuedWithdrawal(), 200);

        mockToken.mint(address(bridgeVault), 100);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 100);
        assertEq(vToken.canWithdrawalAmount(user1), 50);
        assertEq(vToken.canWithdrawalAmount(user2), 50);

        vm.prank(user1);
        vToken.withdrawComplete(0);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 50);
        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.canWithdrawalAmount(user2), 50);
        assertEq(vToken.completedWithdrawal(), 100);
        assertEq(vToken.queuedWithdrawal(), 200);
        
        vm.prank(user2);
        vToken.withdrawComplete(50);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 0);
        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.completedWithdrawal(), 150);
        assertEq(vToken.queuedWithdrawal(), 200);

        mockToken.mint(address(bridgeVault), 100);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 100);
        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.canWithdrawalAmount(user2), 50);
        assertEq(vToken.queuedWithdrawal(), 200);
        assertEq(vToken.completedWithdrawal(), 150);

        vm.prank(user2);
        vToken.withdrawComplete(0);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 50);
        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.canWithdrawalAmount(user2), 0);
        assertEq(vToken.completedWithdrawal(), 200);
        assertEq(vToken.queuedWithdrawal(), 200);
    }
    
    function test_WithdrawCompleteWithInsufficientBalance() public {
        uint256 initAmount = 1000;
        vToken.mint(user1, initAmount);
        vToken.mint(user2, initAmount);

        uint256 redeemAmount = 100;
        vm.prank(user1);
        vToken.redeem(redeemAmount, user1, user1);

        (uint256 queued, uint256 pending) = vToken.withdrawals(user1);
        assertEq(queued, 0);
        assertEq(pending, 100);
        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.completedWithdrawal(), 0);
        assertEq(vToken.queuedWithdrawal(), 100);

        vm.prank(user1);
        // will revert
        vm.expectRevert(abi.encodeWithSelector(VTokenBase.InsufficientWithdrawAmount.selector, redeemAmount, 0));
        vToken.withdrawComplete(redeemAmount);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(VTokenBase.InsufficientWithdrawAmount.selector, redeemAmount, 0));
        vToken.withdrawComplete(0);

        mockToken.mint(address(bridgeVault), 5);
        assertEq(mockToken.balanceOf(address(bridgeVault)), 5);
        assertEq(vToken.canWithdrawalAmount(user1), 5);

        vm.prank(user1);
        vToken.withdrawComplete(5);
        assertEq(vToken.completedWithdrawal(), 5);
        assertEq(vToken.queuedWithdrawal(), 100);
        assertEq(vToken.canWithdrawalAmount(user1), 0);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(VTokenBase.InsufficientWithdrawAmount.selector, 95, 0));
        vToken.withdrawComplete(0);  
    }
    
    function test_WithdrawCompleteWithExceedPermittedAmount() public {
        uint256 initAmount = 1000;
        vToken.mint(user1, initAmount);
        vToken.mint(user2, initAmount);

        uint256 redeemAmount = 100;
        vm.prank(user1);
        vToken.redeem(redeemAmount, user1, user1);

        (uint256 queued, uint256 pending) = vToken.withdrawals(user1);
        assertEq(queued, 0);
        assertEq(pending, 100);
        assertEq(vToken.canWithdrawalAmount(user1), 0);
        assertEq(vToken.completedWithdrawal(), 0);
        assertEq(vToken.queuedWithdrawal(), 100);

        vm.prank(user1);
        // will revert
        vm.expectRevert(abi.encodeWithSelector(VTokenBase.ExceedPermittedAmount.selector, 200, 100));
        vToken.withdrawComplete(200); 
    }
    
    function test_AsyncMint() public {
        uint256 initAmount = 1000;
        mockToken.mint(user1, initAmount);
        vm.prank(user1);
        mockToken.approve(address(vToken), 100);
        vm.prank(user1);
        vToken.deposit(100, user1);
        assertEq(vToken.currentCycleMintTokenAmount(), 100);
        assertEq(vToken.currentCycleMintVTokenAmount(), 100);

        vm.prank(triggerAddress);
        vToken.asyncMint(0, 0);
        assertEq(vToken.currentCycleMintTokenAmount(), 0);
        assertEq(vToken.currentCycleMintVTokenAmount(), 0);
    }
    
    function test_AsyncRedeem() public {
        vm.prank(owner);
        vToken.changeRoleAdmin(triggerAddress, true);
        vm.prank(triggerAddress);
        vToken.asyncRedeem(1000, 1000, bytes32(uint256(uint160(user1))), "");
        assertEq(vToken.currentCycleRedeemVTokenAmount(), 0);
    }
    
    function test_OnlyTriggerAddress() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(VTokenBase.NotTriggerAddress.selector, user1));
        vToken.asyncMint(1000, 1000);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(VTokenBase.NotTriggerAddress.selector, user1));
        vToken.asyncRedeem(1000, 1000, bytes32(uint256(uint160(user1))), "");
    }
    
    function test_OnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        vToken.setOracle(address(0));
        
        vm.prank(user1);
        vm.expectRevert();
        vToken.setTokenGateway(address(0));
        
        vm.prank(user1);
        vm.expectRevert();
        vToken.setTriggerAddress(address(0));
    }
    
    function test_OnlyRoleAdmin_Revert() public {
        assertFalse(vToken.rolesAdmin(user1));
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(VTokenBase.NotRoleAdmin.selector, user1));
        vToken.mint(user2, 1000);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(VTokenBase.NotRoleAdmin.selector, user1));
        vToken.burn(user2, 1000);
    }
    function test_OnlyRoleAdmin_Success() public {
        vm.prank(owner);
        vToken.changeRoleAdmin(user1, true);
        assertTrue(vToken.rolesAdmin(user1));
        vm.prank(user1);
        vToken.mint(user2, 1000);
        vm.prank(user1);
        vToken.burn(user2, 500);
        assertEq(vToken.balanceOf(user2), 500);
    }
    
    function test_RoleAdmin() public {
        assertFalse(vToken.rolesAdmin(user1));
        vm.prank(owner);
        vToken.changeRoleAdmin(user1, true);
        assertTrue(vToken.rolesAdmin(user1));
        vm.prank(user1);
        vToken.mint(user2, 1000);
        vm.prank(user1);
        vToken.burn(user2, 500);
        assertEq(vToken.balanceOf(user2), 500);
    }
    
    function test_PauseUnpause() public {
        assertFalse(vToken.paused());
        vm.prank(owner);
        vToken.pause();
        assertTrue(vToken.paused());
        mockToken.mint(user1, 1000);
        vm.startPrank(user1);
        mockToken.approve(address(vToken), 1000);
        vm.expectRevert();
        vToken.deposit(1000, user1);
        vm.stopPrank();
        vm.prank(owner);
        vToken.unpause();
        assertFalse(vToken.paused());
        mockToken.mint(user1, 1000);
        vm.startPrank(user1);
        mockToken.approve(address(vToken), 1000);
        vToken.deposit(1000, user1);
        vm.stopPrank();
    }
    
    function test_SupportsInterface() public {
        assertTrue(vToken.supportsInterface(type(IERC20).interfaceId));
        assertTrue(vToken.supportsInterface(type(IERC4626).interfaceId));
    }
    
    function test_WithdrawFeeToken() public {
        uint256 amount = 1000;
        mockToken.mint(address(vToken), amount);
        
        vm.prank(owner);
        vToken.withdrawFeeToken(address(mockToken), amount, user1);
        
        assertEq(mockToken.balanceOf(user1), amount);
    }
}
