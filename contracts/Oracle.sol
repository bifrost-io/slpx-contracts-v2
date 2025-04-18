// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {
    IIsmpModule,
    IncomingPostRequest,
    IncomingPostResponse,
    IncomingGetResponse,
    PostRequest,
    PostResponse,
    GetRequest
} from "@polytope-labs/ismp-solidity/interfaces/IIsmpModule.sol";

contract Oracle is IIsmpModule, Ownable {
    // =================== Constants ===================
    /// @notice Bifrost chain ID
    bytes private constant BIFROST_CHAIN_ID = bytes("2030");

    /// @notice Bifrost SLPX pallet identifier
    bytes private constant BIFROST_SLPX = bytes("bif-slpx");

    struct PoolInfo {
        uint256 tokenAmount;
        uint256 vTokenAmount;
    }

    struct RateInfo {
        uint8 mintRate;
        uint8 redeemRate;
    }

    RateInfo public rateInfo;

    mapping(address => PoolInfo) public poolInfo;

    address private _host;

    /// @notice Throws if the caller is not the ISMP host.
    error NotIsmpHost();
    /// @notice Throws if the caller is not from Bifrost
    error NotFromBifrost();
    /// @notice Throws if the pool is not ready
    error PoolNotReady();
    /// @notice Throws if the function is not implemented
    error NotImplemented();

    modifier onlyIsmpHost() {
        if (_msgSender() != _host) {
            revert NotIsmpHost();
        }
        _;
    }

    constructor(address hostAddress) Ownable(msg.sender) {
        _host = hostAddress;
    }

    /// Bifrost will set a fee and the data will be consistent with Bifrost Chain.
    function setRate(uint8 _mintRate, uint8 _redeemRate) external onlyOwner {
        rateInfo.mintRate = _mintRate;
        rateInfo.redeemRate = _redeemRate;
    }

    /// Get vToken by token.
    function getVTokenAmountByToken(address _token, uint256 _tokenAmount) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_token];
        if (pool.vTokenAmount == 0 || pool.tokenAmount == 0) {
            revert PoolNotReady();
        }
        uint256 mintFee = (rateInfo.mintRate * _tokenAmount) / 10000;
        uint256 tokenAmountExcludingFee = _tokenAmount - mintFee;
        uint256 vTokenAmount = (tokenAmountExcludingFee * pool.vTokenAmount) / pool.tokenAmount;
        return vTokenAmount;
    }

    /// Get token by vToken.
    function getTokenAmountByVToken(address _token, uint256 _vTokenAmount) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_token];
        if (pool.vTokenAmount == 0 || pool.tokenAmount == 0) {
            revert PoolNotReady();
        }
        uint256 redeemFee = (rateInfo.redeemRate * _vTokenAmount) / 10000;
        uint256 vTokenAmountExcludingFee = _vTokenAmount - redeemFee;
        uint256 tokenAmount = (vTokenAmountExcludingFee * pool.tokenAmount) / pool.vTokenAmount;
        return tokenAmount;
    }

    function onAccept(IncomingPostRequest memory incoming) external override onlyIsmpHost {
        // Check if request is from Bifrost
        if (
            keccak256(incoming.request.source) != keccak256(BIFROST_CHAIN_ID)
                || keccak256(incoming.request.from) != keccak256(BIFROST_SLPX)
        ) {
            revert NotFromBifrost();
        }

        bytes memory body = incoming.request.body;
        (address token, uint256 tokenAmount, uint256 vtokenAmount) = abi.decode(body, (address, uint256, uint256));
        poolInfo[token].tokenAmount = tokenAmount;
        poolInfo[token].vTokenAmount = vtokenAmount;
    }

    function onPostResponse(IncomingPostResponse memory) external view override onlyIsmpHost {
        revert NotImplemented();
    }

    function onGetResponse(IncomingGetResponse memory) external view override onlyIsmpHost {
        revert NotImplemented();
    }

    function onPostRequestTimeout(PostRequest memory) external view override onlyIsmpHost {
        revert NotImplemented();
    }

    function onPostResponseTimeout(PostResponse memory) external view override onlyIsmpHost {
        revert NotImplemented();
    }

    function onGetTimeout(GetRequest memory) external view override onlyIsmpHost {
        revert NotImplemented();
    }
}
