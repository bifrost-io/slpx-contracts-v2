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
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Oracle is IIsmpModule, Ownable {
    using Math for uint256;

    /// @notice Fee denominator
    uint16 private constant FEE_DENOMINATOR = 10000;

    struct PoolInfo {
        uint256 tokenAmount;
        uint256 vTokenAmount;
    }

    struct FeeRateInfo {
        uint16 mintFeeRate;
        uint16 redeemFeeRate;
    }

    FeeRateInfo public feeRateInfo;

    mapping(address => PoolInfo) public poolInfo;

    address private _host;

    // =================== Events ===================
    /// @notice Emitted when fee rates are changed
    event FeeRateChanged(uint16 newMintFeeRate, uint16 newRedeemFeeRate);

    /// @notice Emitted when token amount is set
    event SetTokenAmount(address, uint256, uint256);

    /// @notice Throws if the caller is not the ISMP host.
    error NotIsmpHost();
    /// @notice Throws if the pool is not ready
    error PoolNotReady();
    /// @notice Throws if the function is not implemented
    error NotImplemented();
    /// @notice Throws if the fee rate is invalid
    error InvalidFeeRate();

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
    function setFeeRate(uint16 _mintFeeRate, uint16 _redeemFeeRate) external onlyOwner {
        if (_mintFeeRate > FEE_DENOMINATOR || _redeemFeeRate > FEE_DENOMINATOR) {
            revert InvalidFeeRate();
        }
        feeRateInfo.mintFeeRate = _mintFeeRate;
        feeRateInfo.redeemFeeRate = _redeemFeeRate;
        emit FeeRateChanged(_mintFeeRate, _redeemFeeRate);
    }

    /// Get vToken by token.
    function getVTokenAmountByToken(address _token, uint256 _tokenAmount, Math.Rounding rounding)
        public
        view
        returns (uint256)
    {
        PoolInfo memory pool = poolInfo[_token];
        if (pool.vTokenAmount == 0 || pool.tokenAmount == 0) {
            revert PoolNotReady();
        }
        uint256 mintFee = _tokenAmount.mulDiv(feeRateInfo.mintFeeRate, FEE_DENOMINATOR, rounding);
        uint256 tokenAmountExcludingFee = _tokenAmount - mintFee;
        uint256 vTokenAmount = tokenAmountExcludingFee.mulDiv(pool.vTokenAmount, pool.tokenAmount, rounding);
        return vTokenAmount;
    }

    /// Get token by vToken.
    function getTokenAmountByVToken(address _token, uint256 _vTokenAmount, Math.Rounding rounding)
        public
        view
        returns (uint256)
    {
        PoolInfo memory pool = poolInfo[_token];
        if (pool.vTokenAmount == 0 || pool.tokenAmount == 0) {
            revert PoolNotReady();
        }
        uint256 redeemFee = _vTokenAmount.mulDiv(feeRateInfo.redeemFeeRate, FEE_DENOMINATOR, rounding);
        uint256 vTokenAmountExcludingFee = _vTokenAmount - redeemFee;
        uint256 tokenAmount = vTokenAmountExcludingFee.mulDiv(pool.tokenAmount, pool.vTokenAmount, rounding);
        return tokenAmount;
    }

    function onAccept(IncomingPostRequest memory incoming) external override onlyIsmpHost {
        bytes memory body = incoming.request.body;
        (address token, uint256 tokenAmount, uint256 vtokenAmount) = abi.decode(body, (address, uint256, uint256));
        poolInfo[token].tokenAmount = tokenAmount;
        poolInfo[token].vTokenAmount = vtokenAmount;
        emit SetTokenAmount(token, tokenAmount, vtokenAmount);
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
