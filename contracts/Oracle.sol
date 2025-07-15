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
import {Bytes} from "@polytope-labs/solidity-merkle-trees/src/trie/Bytes.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract Oracle is IIsmpModule, Initializable, OwnableUpgradeable, PausableUpgradeable {
    using Math for uint256;
    using Bytes for bytes;

    /// @notice Fee denominator
    uint16 private constant FEE_DENOMINATOR = 10000;

    /// @notice Bifrost send message module name
    bytes private constant BIFROST_SEND_MESSAGE_MODULE_NAME = bytes("bif-slpx");

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

    bytes private _bifrostChainId;

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
    /// @notice Throws if the caller is not Bifrost
    error NotFromBifrost();

    modifier onlyIsmpHost() {
        if (_msgSender() != _host) {
            revert NotIsmpHost();
        }
        _;
    }

    modifier onlyFromBifrost(PostRequest calldata request) {
        if (!request.source.equals(_bifrostChainId) || !request.from.equals(BIFROST_SEND_MESSAGE_MODULE_NAME)) {
            revert NotFromBifrost();
        }
        _;
    }

    function initialize(address owner, address hostAddress, bytes memory bifrostChainId) public initializer {
        __Ownable_init(owner);
        __Pausable_init();
        _host = hostAddress;
        _bifrostChainId = bifrostChainId;
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

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Get vToken by token.
    /// @param _token The token address
    /// @param _tokenAmount The token amount
    /// @param rounding The rounding mode
    /// @return The vToken amount
    function getVTokenAmountByToken(address _token, uint256 _tokenAmount, Math.Rounding rounding)
        public
        view
        whenNotPaused
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

    /// @notice Get token by vToken.
    /// @param _token The token address
    /// @param _vTokenAmount The vToken amount
    /// @param rounding The rounding mode
    /// @return The token amount
    function getTokenAmountByVToken(address _token, uint256 _vTokenAmount, Math.Rounding rounding)
        public
        view
        whenNotPaused
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

    /// @notice Accept the post request
    /// @param incoming The incoming post request
    /// @dev The post request is from Bifrost
    function onAccept(IncomingPostRequest calldata incoming)
        external
        override
        onlyIsmpHost
        onlyFromBifrost(incoming.request)
    {
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
