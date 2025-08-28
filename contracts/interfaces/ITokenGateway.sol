// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

struct TeleportParams {
    // amount to be sent
    uint256 amount;
    // Relayer fee
    uint256 relayerFee;
    // The token identifier to send
    bytes32 assetId;
    // Redeem ERC20 on the destination?
    bool redeem;
    // recipient address
    bytes32 to;
    // recipient state machine
    bytes dest;
    // request timeout in seconds
    uint64 timeout;
    // Amount of native token to pay for dispatching the request
    // if 0 will use the `IIsmpHost.feeToken`
    uint256 nativeCost;
    // destination contract call data
    bytes data;
}

interface ITokenGateway {
    function teleport(TeleportParams calldata teleportParams) external payable;
}
