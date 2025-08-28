// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VETH} from "../contracts/VETH.sol";
import {BridgeVault} from "../contracts/BridgeVault.sol";
import {Oracle} from "../contracts/Oracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWETH} from "../contracts/interfaces/IWETH.sol";
import {VToken} from "../contracts/VToken.sol";
import {ITokenGateway, TeleportParams} from "../contracts/interfaces/ITokenGateway.sol";

// Mock WETH contract for testing
contract MockWETH is ERC20, IWETH {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    // Store test contract reference for vm operations
    address public testContract;

    constructor() ERC20("Wrapped Ether", "WETH") {}

    function setTestContract(address _testContract) external {
        testContract = _testContract;
    }

    function deposit() external payable override {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 value) external override {
        require(balanceOf(msg.sender) >= value, "Insufficient balance");
        _burn(msg.sender, value);

        // For testing, simulate ETH transfer to the caller (contract)
        if (testContract != address(0)) {
            VETHTest(testContract).simulateETHTransfer(msg.sender, value);
        }

        emit Withdrawal(msg.sender, value);
    }

    // Allow contract to receive ETH
    receive() external payable {}

    // Helper function to mint WETH for testing
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockTokenGateway is ITokenGateway {
    function teleport(TeleportParams calldata params) external payable {
        // Mock implementation
    }
}

contract TestOracle is Oracle {
    function setPoolInfo(address token, uint256 tokenAmount, uint256 vTokenAmount) external {
        poolInfo[token] = PoolInfo({tokenAmount: tokenAmount, vTokenAmount: vTokenAmount});
    }
}

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockVETH is VETH {}

contract VETHTest is Test {
    MockVETH public veth;
    MockWETH public weth;
    BridgeVault public bridgeVault;
    Oracle public oracle;
    MockTokenGateway public tokenGateway;

    address public owner;
    address public triggerAddress;
    address public user1;
    address public user2;
    address public user3;

    // Events from MockVETH and base contracts
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Helper function for MockWETH to simulate ETH transfer
    function simulateETHTransfer(address to, uint256 value) external {
        vm.deal(to, to.balance + value);
    }

    function setUp() public {
        owner = makeAddr("owner");
        triggerAddress = makeAddr("trigger");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Give users some ETH for testing
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        vm.startPrank(owner);

        // Deploy contracts
        weth = new MockWETH();
        weth.setTestContract(address(this));

        bridgeVault = new BridgeVault();
        bridgeVault.initialize(owner);
        oracle = new TestOracle();
        oracle.initialize(owner, address(this), "0x1234567890abcdef");
        tokenGateway = new MockTokenGateway();

        // Deploy MockVETH
        veth = new MockVETH();
        veth.initialize(IERC20(address(weth)), owner, "Vault ETH", "vETH");

        // Setup MockVETH
        veth.setBridgeVault(payable(address(bridgeVault)));
        veth.setOracle(address(oracle));
        veth.setTokenGateway(address(tokenGateway));
        veth.setTriggerAddress(triggerAddress);
        veth.setBifrostDest("0x1234567890abcdef");
        veth.setMaxWithdrawCount(5);
        veth.unpause();
        veth.changeRoleAdmin(address(this), true);
        veth.changeRoleAdmin(owner, true);

        // Add MockVETH to BridgeVault
        bridgeVault.addVTokenAddress(address(veth));

        // Setup Oracle with pool info (1:1 ratio initially)
        oracle.setFeeRate(0, 0); // No fee for testing
        TestOracle(address(oracle)).setPoolInfo(address(weth), 1000000 * 10 ** 18, 1000000 * 10 ** 18);

        vm.stopPrank();
    }

    function test_DepositWithETH() public {
        uint256 depositAmount = 1 ether;
        uint256 initialWETHBalance = weth.balanceOf(address(veth));
        uint256 initialVETHBalance = veth.balanceOf(user1);
        uint256 userETHBefore = user1.balance;

        vm.prank(user1);
        weth.approve(address(veth), type(uint256).max);

        vm.prank(user1);
        veth.depositWithETH{value: depositAmount}();

        // Check WETH was deposited to the contract
        assertEq(weth.balanceOf(address(veth)), initialWETHBalance + depositAmount);

        // Check vETH tokens were minted (1:1 ratio initially)
        uint256 expectedShares = depositAmount; // 1:1 ratio
        assertEq(veth.balanceOf(user1), initialVETHBalance + expectedShares);

        // Check ETH was deducted from user
        assertEq(user1.balance, userETHBefore - depositAmount);

        // Check cycle tracking
        assertEq(veth.currentCycleMintTokenAmount(), depositAmount);
        assertEq(veth.currentCycleMintVTokenAmount(), expectedShares);
    }

    function test_withdrawCompleteToETH() public {
        uint256 userETHBefore = user1.balance;

        // Setup: mint vETH tokens to user1 and WETH to bridgeVault
        vm.prank(owner);
        veth.mint(address(user1), 1000);
        vm.prank(owner);
        weth.mint(address(bridgeVault), 50);

        // User withdraws some assets (this creates a withdrawal request)
        vm.prank(user1);
        veth.withdraw(100, user1, user1);

        // User completes withdrawal and gets ETH
        vm.prank(user1);
        veth.withdrawCompleteToETH();

        // Verify user received ETH and vToken balance decreased
        assertEq(user1.balance, userETHBefore + 50);
        assertEq(veth.balanceOf(user1), 1000 - 100);
    }
}
