// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/VTokenBase.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@polytope-labs/ismp-solidity/interfaces/IDispatcher.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 ether);
    }
}

contract MockOracle {
    function getPrice() external pure returns (uint256) {
        return 1 ether;
    }
}

contract MockDispatcher is IDispatcher {
    function dispatch(DispatchPost memory post) external payable override returns (bytes32) {
        return bytes32(0);
    }

    function dispatch(DispatchGet memory request) external payable override returns (bytes32) {
        return bytes32(0);
    }

    function dispatch(DispatchPostResponse memory response) external payable override returns (bytes32) {
        return bytes32(0);
    }

    function feeToken() external view override returns (address) {
        return address(0);
    }

    function fundRequest(bytes32 commitment, uint256 amount) external payable override {
        // Do nothing
    }

    function fundResponse(bytes32 commitment, uint256 amount) external payable override {
        // Do nothing
    }

    function nonce() external view override returns (uint256) {
        return 0;
    }

    function perByteFee(bytes memory dest) external view override returns (uint256) {
        return 0;
    }

    function uniswapV2Router() external view override returns (address) {
        return address(0);
    }
}

contract TestVToken is VTokenBase {
    function initialize(
        address _asset,
        string memory _name,
        string memory _symbol,
        address _oracle,
        address _dispatcher
    ) public initializer {
        __VTokenBase_init(IERC20(_asset), msg.sender, _name, _symbol);

        oracle = Oracle(_oracle);
        dispatcher = IDispatcher(_dispatcher);
    }
}

contract VTokenBaseTest is Test {
    TestVToken public vToken;
    MockERC20 public underlyingToken;
    MockOracle public oracle;
    MockDispatcher public dispatcher;

    address public owner = address(1);
    address public user = address(2);
    address public triggerAddress = address(3);

    function setUp() public {
        // Deploy mock contracts
        underlyingToken = new MockERC20();
        oracle = new MockOracle();
        dispatcher = new MockDispatcher();

        // Deploy VTokenBase
        vToken = new TestVToken();

        // Initialize with owner
        vm.prank(owner);
        vToken.initialize(address(underlyingToken), "VToken", "VTK", address(oracle), address(dispatcher));

        // Setup roles
        vm.prank(owner);
        vToken.setTriggerAddress(triggerAddress);

        // Unpause the contract
        vm.prank(owner);
        vToken.unpause();

        // Transfer tokens to user
        underlyingToken.transfer(user, 1000 ether);

        // Approve VToken to spend user's tokens
        vm.prank(user);
        underlyingToken.approve(address(vToken), type(uint256).max);
    }

    function test_Initialize() public {
        assertEq(vToken.name(), "VToken");
        assertEq(vToken.symbol(), "VTK");
        assertEq(address(vToken.oracle()), address(oracle));
        assertEq(address(vToken.dispatcher()), address(dispatcher));
        assertEq(vToken.owner(), owner);
        assertEq(vToken.triggerAddress(), triggerAddress);
        assertFalse(vToken.paused());
    }

    function test_SetOracle() public {
        // Setup
        address newOracle = address(0x1234);

        // Test: Only owner can set oracle
        vm.prank(owner);
        vToken.setOracle(newOracle);
        assertEq(address(vToken.oracle()), newOracle);

        // Test: Non-owner cannot set oracle
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        vToken.setOracle(newOracle);
    }

    function test_SetDispatcher() public {
        // Setup
        address newDispatcher = address(0x1234);

        // Test: Only owner can set dispatcher
        vm.prank(owner);
        vToken.setDispatcher(newDispatcher);
        assertEq(address(vToken.dispatcher()), newDispatcher);

        // Test: Non-owner cannot set dispatcher
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        vToken.setDispatcher(newDispatcher);
    }

    function test_SetMaxRedeemRequestsPerUser() public {
        // Setup
        uint256 newMaxRequests = 5;

        // Test: Only owner can set max redeem requests
        vm.prank(owner);
        vToken.setMaxRedeemRequestsPerUser(newMaxRequests);
        assertEq(vToken.maxRedeemRequestsPerUser(), newMaxRequests);

        // Test: Non-owner cannot set max redeem requests
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        vToken.setMaxRedeemRequestsPerUser(newMaxRequests);
    }

    function test_PauseUnpause() public {
        // Test: Only owner can pause
        vm.prank(owner);
        vToken.pause();
        assertTrue(vToken.paused());

        // Test: Non-owner cannot pause
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        vToken.pause();

        // Test: Only owner can unpause
        vm.prank(owner);
        vToken.unpause();
        assertFalse(vToken.paused());

        // Test: Non-owner cannot unpause
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        vToken.unpause();
    }

    function test_ChangeRoleAdmin() public {
        // Setup
        address role = address(0x5678);

        // Test: Only owner can change role admin
        vm.prank(owner);
        vToken.changeRoleAdmin(role, true);
        assertTrue(vToken.rolesAdmin(role));

        // Test: Non-owner cannot change role admin
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        vToken.changeRoleAdmin(role, true);
    }

    function test_SetTriggerAddress() public {
        // Setup
        address newTrigger = address(0x1234);

        // Test: Only owner can set trigger address
        vm.prank(owner);
        vToken.setTriggerAddress(newTrigger);
        assertEq(vToken.triggerAddress(), newTrigger);

        // Test: Non-owner cannot set trigger address
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user));
        vToken.setTriggerAddress(newTrigger);
    }

    function test_PauseUnpauseFunctionality() public {
        // Setup
        uint256 amount = 1000;

        // Grant role admin to owner
        vm.prank(owner);
        vToken.changeRoleAdmin(owner, true);

        // Mint tokens to user
        vm.prank(owner);
        vToken.mint(user, amount);

        // Test: Cannot deposit when paused
        vm.prank(owner);
        vToken.pause();
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vToken.deposit(amount, user);

        // Test: Cannot withdraw when paused
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vToken.withdraw(amount, user, user);

        // Test: Cannot redeem when paused
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        vToken.redeem(amount, user, user);

        // Test: Functions work after unpause
        vm.prank(owner);
        vToken.unpause();
    }

    // function test_Deposit() public {
    //     vm.prank(user);
    //     uint256 shares = vToken.deposit(100 ether, user);

    //     assertEq(vToken.balanceOf(user), shares);
    //     assertEq(underlyingToken.balanceOf(user), 900 ether);
    //     assertEq(underlyingToken.balanceOf(address(vToken)), 100 ether);
    // }

    // function test_Withdraw() public {
    //     // First deposit
    //     vm.prank(user);
    //     vToken.deposit(100 ether, user);

    //     // Then withdraw
    //     vm.prank(user);
    //     uint256 assets = vToken.withdraw(50 ether, user, user);

    //     assertEq(assets, 50 ether);
    //     assertEq(underlyingToken.balanceOf(user), 950 ether);
    //     assertEq(underlyingToken.balanceOf(address(vToken)), 50 ether);
    // }

    // function test_BatchClaim() public {
    //     // Setup
    //     address user1 = address(1);
    //     address user2 = address(2);
    //     uint256 amount = 1000;

    //     // Mint tokens to users
    //     vToken.mint(user1, amount);
    //     vToken.mint(user2, amount);

    //     // Create redeem requests
    //     vm.prank(user1);
    //     vToken.redeem(amount, user1, user1);

    //     vm.prank(user2);
    //     vToken.redeem(amount, user2, user2);

    //     // Process batch claim
    //     vm.prank(triggerAddress);
    //     vToken.batchClaim(2); // Process 2 requests

    //     // Verify
    //     assertEq(vToken.balanceOf(user1), 0);
    //     assertEq(vToken.balanceOf(user2), 0);
    //     assertEq(underlyingToken.balanceOf(user1), amount);
    //     assertEq(underlyingToken.balanceOf(user2), amount);
    // }

    // function test_OnlyTriggerAddressCanBatchClaim() public {
    //     // Setup
    //     address user = address(1);
    //     uint256 amount = 1000;

    //     // Mint tokens to user
    //     vToken.mint(user, amount);

    //     // Create redeem request
    //     vm.prank(user);
    //     vToken.redeem(amount, user, user);

    //     // Try to process batch claim with non-trigger address
    //     vm.expectRevert(abi.encodeWithSelector(VTokenBase.NotTriggerAddress.selector, address(this)));
    //     vToken.batchClaim(1); // Try to process 1 request
    // }

    // function test_OnlyOwnerCanSetMaxRedeemRequests() public {
    //     vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", address(this)));
    //     vToken.setMaxRedeemRequestsPerUser(5);
    // }
}
