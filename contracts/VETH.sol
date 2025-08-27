// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {VToken} from "./VToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";

contract VETH is VToken {
    function depositWithETH() external payable whenNotPaused returns (uint256) {
        require(msg.value > 0, "Must send ETH");
        // Convert ETH to WETH (WETH will be sent to this contract)
        IWETH(address(asset())).deposit{value: msg.value}();

        currentCycleMintTokenAmount += msg.value;
        uint256 vTokenAmount = previewDeposit(msg.value);
        currentCycleMintVTokenAmount += vTokenAmount;

        _mint(msg.sender, vTokenAmount);
        emit Deposit(msg.sender, msg.sender, msg.value, vTokenAmount);
        return vTokenAmount;
    }

    function withdrawCompleteToETH() external whenNotPaused returns (uint256) {
        uint256 amount = super.withdrawCompleteTo(address(this));
        IWETH(address(asset())).withdraw(amount);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        return amount;
    }
}
