// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@polytope-labs/ismp-solidity/interfaces/IIsmpModule.sol";
import "@polytope-labs/ismp-solidity/interfaces/IDispatcher.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StorageValue} from "@polytope-labs/solidity-merkle-trees/src/Types.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IIsmpModule, BaseIsmpModule} from "@polytope-labs/ismp-solidity/interfaces/IIsmpModule.sol";
import {StateMachine} from "@polytope-labs/ismp-solidity/interfaces/StateMachine.sol";

contract Oracle is IIsmpModule, Ownable, Pausable {

    // =================== Constants ===================
    /// @notice Bifrost chain ID
    bytes constant private BIFROST_CHAIN_ID = bytes("2030");

    /// @notice Bifrost SLPX pallet identifier
    bytes constant private BIFROST_SLPX = bytes("bif-slpx");

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

    modifier onlyIsmpHost() {
        if (_msgSender() != _host) {
            revert NotIsmpHost();
        }
        _;
    }

    constructor(address _host) Ownable(msg.sender) Pausable() {
        _host = _host;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

     /// Bifrost will set a fee and the data will be consistent with Bifrost Chain.
    function setRate(uint8 _mintRate, uint8 _redeemRate) external onlyOwner {
        rateInfo.mintRate = _mintRate;
        rateInfo.redeemRate = _redeemRate;
    }

    /// Get vToken by token.
    function getVTokenAmountByToken(
        address _token,
        uint256 _tokenAmount
    ) public view whenNotPaused returns (uint256) {
        PoolInfo memory poolInfo = poolInfo[_token];
        require(
            poolInfo.vTokenAmount != 0 && poolInfo.tokenAmount != 0,
            "Not ready"
        );
        uint256 mintFee = (rateInfo.mintRate * _tokenAmount) / 10000;
        uint256 tokenAmountExcludingFee = _tokenAmount - mintFee;
        uint256 vTokenAmount = (tokenAmountExcludingFee *
            poolInfo.vTokenAmount) / poolInfo.tokenAmount;
        return vTokenAmount;
    }

    /// Get token by vToken.
    function getTokenAmountByVToken(
        address _token,
        uint256 _vTokenAmount
    ) public view whenNotPaused returns (uint256) {
        PoolInfo memory poolInfo = poolInfo[_token];
        require(
            poolInfo.vTokenAmount != 0 && poolInfo.tokenAmount != 0,
            "Not ready"
        );
        uint256 redeemFee = (rateInfo.redeemRate * _vTokenAmount) / 10000;
        uint256 vTokenAmountExcludingFee = _vTokenAmount - redeemFee;
        uint256 tokenAmount = (vTokenAmountExcludingFee *
            poolInfo.tokenAmount) / poolInfo.vTokenAmount;
        return tokenAmount;
    }

    function onAccept(IncomingPostRequest memory incoming) external override onlyIsmpHost {
        // Check if request is from Bifrost
        if (keccak256(incoming.request.source) != keccak256(BIFROST_CHAIN_ID) || 
            keccak256(incoming.request.from) != keccak256(BIFROST_SLPX)) {
            revert NotFromBifrost();
        }
        
        bytes memory body = incoming.request.body;
        (address token, uint256 tokenAmount, uint256 vtokenAmount) = abi.decode(body, (address, uint256, uint256));
        poolInfo[token].tokenAmount = tokenAmount;
        poolInfo[token].vTokenAmount = vtokenAmount;
    }

    function onPostResponse(IncomingPostResponse memory incoming) external override onlyIsmpHost {
        revert("Not implemented");
    }

    function onGetResponse(IncomingGetResponse memory) external override onlyIsmpHost {
        revert("Not implemented");
    }

    function onPostRequestTimeout(PostRequest memory) external override onlyIsmpHost {
        revert("Not implemented");
    }

    function onPostResponseTimeout(PostResponse memory) external override onlyIsmpHost {
        revert("Not implemented");
    }

    function onGetTimeout(GetRequest memory) external override onlyIsmpHost {
        revert("Not implemented");
    }
}
