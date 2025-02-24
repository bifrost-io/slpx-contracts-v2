// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Token} from "../contracts/Token.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract TokenTest is Test {
    Token public token;
    ProxyAdmin public admin;
    TransparentUpgradeableProxy public proxy;
    Token public implement;
    ERC20Mock public erc20;
    address owner = address(9);

    error EnforcedPause();
    error NotRoleAdmin(address account);

    function setUp() public {
        erc20 = new ERC20Mock();
        admin = new ProxyAdmin(owner);
        token = new Token();
        proxy = new TransparentUpgradeableProxy(address(token), address(admin), "");
        implement = Token(address(proxy));
        implement.initialize(erc20, owner, "Bifrost Voucher BNC", "vBNC");

        erc20.mint(address(1), 1000);
    }

    function test_ChangeRoleAdmin() public {
        vm.startPrank(owner);

        assertEq(implement.rolesAdmin(address(0)), false);
        implement.changeRoleAdmin(address(0), true);
        assertEq(implement.rolesAdmin(address(0)), true);

        implement.changeRoleAdmin(address(0), false);
        assertEq(implement.rolesAdmin(address(0)), false);

        vm.stopPrank();
    }

    function test_RevertDeposit() public {
        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);

        vm.expectRevert(EnforcedPause.selector);
        implement.deposit(100, address(1));

        vm.stopPrank();
    }

    function test_Deposit() public {
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        implement.deposit(100, address(1));

        assertEq(erc20.balanceOf(address(1)), 900);
        assertEq(erc20.balanceOf(address(implement)), 100);
        assertEq(implement.balanceOf(address(1)), 100);
        vm.stopPrank();
    }

    function test_RevertMint() public {
        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);

        vm.expectRevert(EnforcedPause.selector);
        implement.mint(100, address(1));

        vm.stopPrank();
    }

    function test_Mint() public {
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        implement.mint(100, address(1));

        assertEq(erc20.balanceOf(address(1)), 900);
        assertEq(erc20.balanceOf(address(implement)), 100);
        assertEq(implement.balanceOf(address(1)), 100);

        implement.mint(100, address(1));
        assertEq(erc20.balanceOf(address(1)), 800);
        assertEq(erc20.balanceOf(address(implement)), 200);
        assertEq(implement.balanceOf(address(1)), 200);

        vm.stopPrank();
    }

    function test_RevertWithdraw() public {
        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);

        vm.expectRevert(EnforcedPause.selector);
        implement.withdraw(100, address(1), address(1));

        vm.stopPrank();
    }

    function test_Withdraw() public {
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        implement.deposit(100, address(1));
        implement.withdraw(50, address(1), address(1));
        assertEq(erc20.balanceOf(address(1)), 950);
        assertEq(erc20.balanceOf(address(implement)), 50);
        assertEq(implement.balanceOf(address(1)), 50);

        implement.withdraw(50, address(1), address(1));
        assertEq(erc20.balanceOf(address(1)), 1000);
        assertEq(erc20.balanceOf(address(implement)), 0);
        assertEq(implement.balanceOf(address(1)), 0);

        vm.stopPrank();
    }

    function test_RevertRedeem() public {
        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);

        vm.expectRevert(EnforcedPause.selector);
        implement.redeem(100, address(1), address(1));

        vm.stopPrank();
    }

    function test_Redeem() public {
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        implement.mint(100, address(1));
        implement.redeem(50, address(1), address(1));
        assertEq(erc20.balanceOf(address(1)), 950);
        assertEq(erc20.balanceOf(address(implement)), 50);
        assertEq(implement.balanceOf(address(1)), 50);

        implement.redeem(50, address(1), address(1));
        assertEq(erc20.balanceOf(address(1)), 1000);
        assertEq(erc20.balanceOf(address(implement)), 0);
        assertEq(implement.balanceOf(address(1)), 0);

        vm.stopPrank();
    }

    function test_ERC6160_Mint() public {
        vm.startPrank(owner);
        implement.changeRoleAdmin(address(1), true);
        vm.startPrank(address(1));
        implement.mint(address(1), 100);
        assertEq(implement.balanceOf(address(1)), 100);

        implement.mint(address(1), 100);
        assertEq(implement.balanceOf(address(1)), 200);

        vm.stopPrank();
    }

    function test_ERC6160_Burn() public {
        vm.startPrank(owner);
        implement.changeRoleAdmin(address(1), true);
        vm.startPrank(address(1));
        implement.mint(address(1), 100);
        assertEq(implement.balanceOf(address(1)), 100);

        implement.burn(address(1), 50);
        assertEq(implement.balanceOf(address(1)), 50);

        implement.burn(address(1), 50);
        assertEq(implement.balanceOf(address(1)), 0);

        vm.stopPrank();
    }

    function test_Revert_ERC6160() public {
        vm.startPrank(address(1));
        vm.expectRevert(abi.encodeWithSelector(NotRoleAdmin.selector, address(1)));
        implement.mint(address(1), 100);

        vm.expectRevert(abi.encodeWithSelector(NotRoleAdmin.selector, address(1)));
        implement.burn(address(1), 100);

        vm.stopPrank();
    }

    function testFuzz_Deposit(uint256 assets) public {
        vm.assume(assets > 0 && assets <= 1000);
        
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), assets);
        implement.deposit(assets, address(1));

        assertEq(erc20.balanceOf(address(1)), 1000 - assets);
        assertEq(erc20.balanceOf(address(implement)), assets);
        assertEq(implement.balanceOf(address(1)), assets);
        vm.stopPrank();
    }

    function testFuzz_Mint(uint256 shares) public {
    vm.assume(shares > 0 && shares <= 1000);
    
    vm.startPrank(owner);
    implement.unpause();
    implement.changeRoleAdmin(address(1), true);
    vm.stopPrank();

    vm.startPrank(address(1));
    erc20.approve(address(implement), shares);
    implement.mint(shares, address(1));

    assertEq(implement.balanceOf(address(1)), shares);
    vm.stopPrank();
}

    function testFuzz_Withdraw(uint256 assets) public {
        vm.assume(assets > 0 && assets <= 1000);
        
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        implement.deposit(1000, address(1));
        
        implement.withdraw(assets, address(1), address(1));
        
        assertEq(erc20.balanceOf(address(1)), assets);
        assertEq(implement.balanceOf(address(1)), 1000 - assets);
        vm.stopPrank();
    }

    function testFuzz_Redeem(uint256 shares) public {
        vm.assume(shares > 0 && shares <= 1000);
        
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        implement.deposit(1000, address(1));
        
        implement.redeem(shares, address(1), address(1));
        
        assertEq(implement.balanceOf(address(1)), 1000 - shares);
        assertEq(erc20.balanceOf(address(1)), shares);
        vm.stopPrank();
    } 
    

    function testFuzz_OverflowDeposit() public {
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        uint256 shares = implement.deposit(0, address(1));
        assertEq(shares, 0);
        vm.stopPrank();
    }

    function test_TotalSupplyInvariant() public {
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        implement.deposit(500, address(1));
        implement.withdraw(200, address(1), address(1));
        
        assertEq(implement.totalSupply(), implement.totalAssets());
        vm.stopPrank();
    }

    function test_PauseAndUnpause() public {
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 100);
        implement.deposit(100, address(1));

        vm.startPrank(owner);
        implement.pause();
        
        vm.startPrank(address(1));
        erc20.approve(address(implement), 100);
        vm.expectRevert(EnforcedPause.selector);
        implement.deposit(100, address(1));
        vm.stopPrank();
    }

    function test_SequentialOperations() public {
        vm.startPrank(owner);
        implement.unpause();
        vm.stopPrank();

        vm.startPrank(address(1));
        erc20.approve(address(implement), 1000);
        
        implement.deposit(100, address(1));
        assertEq(implement.balanceOf(address(1)), 100);
        
        implement.withdraw(50, address(1), address(1));
        assertEq(implement.balanceOf(address(1)), 50);
        
        implement.deposit(30, address(1));
        assertEq(implement.balanceOf(address(1)), 80);
        
        implement.withdraw(80, address(1), address(1));
        assertEq(implement.balanceOf(address(1)), 0);
        vm.stopPrank();
    }

    function test_OwnershipTransfer() public {
        address newOwner = address(2);
        
        vm.startPrank(owner);
        implement.transferOwnership(newOwner);
        vm.stopPrank();
        
        assertEq(implement.owner(), newOwner);
        
        vm.startPrank(newOwner);
        implement.unpause();
        vm.stopPrank();
    } 


}
