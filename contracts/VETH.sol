// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {VToken} from "./VToken.sol";
import {IWETH} from "./interfaces/IWETH.sol";

contract VETH is VToken {
    /// @notice Thrown when ETH is not sent
    error EthNotSent();

    /// @notice Thrown when ETH transfer failed
    error EthTransferFailed();

    function depositWithETH() external payable whenNotPaused returns (uint256) {
        if (msg.value == 0) {
            revert EthNotSent();
        }
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
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert EthTransferFailed();
        }
        return amount;
    }
}
