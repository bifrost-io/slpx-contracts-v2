// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {Oracle} from "./Oracle.sol";
import {IDispatcher, DispatchPost} from "@polytope-labs/ismp-solidity/interfaces/IDispatcher.sol";
import {StateMachine} from "@polytope-labs/ismp-solidity/interfaces/StateMachine.sol";

abstract contract VTokenBase is
    Initializable,
    ERC4626Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC165Upgradeable
{
    using Math for uint256;
    using SafeERC20 for IERC20;

    // =================== Type declarations ===================
    /// @notice Async operation type
    enum AsyncOperation {
        MINT,
        REDEEM
    }

    /// @notice Redeem request structure
    struct RedeemRequest {
        address receiver;
        uint256 assets;
        uint256 startTime;
    }

    // =================== Constants ===================
    /// @notice Bifrost SLPX pallet identifier
    bytes private constant BIFROST_SLPX = bytes("bif-slpx");

    /// @notice Bifrost chain ID
    uint256 private constant BIFROST_CHAIN_ID = 2030;

    // =================== State variables ===================
    /// @notice mapping of admins of defined roles
    mapping(address => bool) public rolesAdmin;

    Oracle public oracle;

    IDispatcher public dispatcher;

    /// @notice Current cycle minted VToken amount
    uint256 public currentCycleMintVTokenAmount;

    /// @notice Current cycle minted Token amount
    uint256 public currentCycleMintTokenAmount;

    /// @notice Current cycle redeemed Token amount
    uint256 public currentCycleRedeemVTokenAmount;

    /// @notice Trigger address
    address public triggerAddress;

    /// @notice Redeem request mapping
    mapping(uint256 => RedeemRequest) public redeemQueue;

    /// @notice Next request ID
    uint256 public nextRequestId;

    /// @notice Current processing index of redeem queue
    uint256 public redeemQueueIndex;

    /// @notice Maximum number of redeem requests per user
    uint256 public maxRedeemRequestsPerUser;

    /// @notice User redeem request index mapping
    mapping(address => uint256[]) public userRedeemRequests;

    // =================== Events ===================
    /// @notice Emitted when role admin is changed
    event RoleAdminChanged(address indexed account, bool isAdmin);

    /// @notice Emitted when trigger address is changed
    event TriggerAddressChanged(address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when Oracle contract is changed
    event OracleChanged(address indexed oldOracle, address indexed newOracle);

    /// @notice Emitted when Dispatcher contract is changed
    event DispatcherChanged(address indexed oldDispatcher, address indexed newDispatcher);

    /// @notice Emitted when batch claim is processed
    event BatchClaimProcessed(uint256 startIndex, uint256 endIndex, uint256 processedCount);

    /// @notice Emitted when async mint operation is completed
    event AsyncMintCompleted(uint256 tokenAmount, uint256 vTokenAmount);

    /// @notice Emitted when async redeem operation is completed
    event AsyncRedeemCompleted(uint256 vTokenAmount);

    /// @notice Emitted when max redeem requests per user is changed
    event MaxRedeemRequestsPerUserChanged(uint256 oldLimit, uint256 newLimit);

    /// @notice Emitted when a redeem request is successfully processed
    event RedeemRequestSuccess(
        uint256 indexed requestId, address indexed receiver, uint256 assets, uint256 startTime, uint256 endTime
    );

    // =================== Errors ===================
    /// @notice Throws if the caller is not a role admin
    error NotRoleAdmin(address account);

    /// @notice Throws if the caller is not the trigger address
    error NotTriggerAddress(address account);

    /// @notice Throws if user has reached maximum redeem requests limit
    error MaxRedeemRequestsReached(address user, uint256 currentCount, uint256 maxLimit);

    /// @notice Throws if the batch size is greater than the number of requests
    error InvalidBatchSize();

    /// @notice Throws if the batch size is larger than the actual available requests
    error BatchSizeTooLarge(uint256 requestedSize, uint256 actualSize);

    /// @notice Throws if the request ID is not found in the user's request list
    error RequestIdNotFound(address user, uint256 requestId);

    // =================== Modifiers ===================
    /// @notice Modifier: Only trigger address can call
    modifier onlyTriggerAddress() {
        if (_msgSender() != triggerAddress) {
            revert NotTriggerAddress(_msgSender());
        }
        _;
    }

    /// @notice Modifier: Only role admin can call
    modifier onlyRoleAdmin() {
        if (!rolesAdmin[_msgSender()]) {
            revert NotRoleAdmin(_msgSender());
        }
        _;
    }

    function __VTokenBase_init(IERC20 _asset, address _owner, string memory _name, string memory _symbol)
        internal
        onlyInitializing
    {
        __ERC20_init(_name, _symbol);
        __ERC4626_init(_asset);
        __Ownable_init(_owner);
        __Pausable_init();
        __ERC165_init();
        _pause();
    }

    function setOracle(address _oracle) external onlyOwner {
        address oldOracle = address(oracle);
        oracle = Oracle(_oracle);
        emit OracleChanged(oldOracle, _oracle);
    }

    function setDispatcher(address _dispatcher) external onlyOwner {
        address oldDispatcher = address(dispatcher);
        dispatcher = IDispatcher(_dispatcher);
        emit DispatcherChanged(oldDispatcher, _dispatcher);
    }

    function setMaxRedeemRequestsPerUser(uint256 _maxRedeemRequestsPerUser) external onlyOwner {
        uint256 oldLimit = maxRedeemRequestsPerUser;
        maxRedeemRequestsPerUser = _maxRedeemRequestsPerUser;
        emit MaxRedeemRequestsPerUserChanged(oldLimit, _maxRedeemRequestsPerUser);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function changeRoleAdmin(address _account, bool _isAdmin) external onlyOwner {
        rolesAdmin[_account] = _isAdmin;
        emit RoleAdminChanged(_account, _isAdmin);
    }

    function setTriggerAddress(address _triggerAddress) external onlyOwner {
        address oldAddress = triggerAddress;
        triggerAddress = _triggerAddress;
        emit TriggerAddressChanged(oldAddress, _triggerAddress);
    }

    function asyncMint() external onlyTriggerAddress {
        // burn currentCycleMintTokenAmount
        _burn(address(this), currentCycleMintTokenAmount);

        // Send mint request to Bifrost
        DispatchPost memory post = DispatchPost({
            body: abi.encode(block.chainid, AsyncOperation.MINT, currentCycleMintTokenAmount, currentCycleMintVTokenAmount),
            dest: StateMachine.polkadot(BIFROST_CHAIN_ID),
            timeout: 0,
            to: BIFROST_SLPX,
            fee: 0,
            payer: _msgSender()
        });
        dispatcher.dispatch(post);

        // reset currentCycleMintVTokenAmount and currentCycleMintTokenAmount
        uint256 tokenAmount = currentCycleMintTokenAmount;
        uint256 vTokenAmount = currentCycleMintVTokenAmount;
        currentCycleMintVTokenAmount = 0;
        currentCycleMintTokenAmount = 0;

        emit AsyncMintCompleted(tokenAmount, vTokenAmount);
    }

    function asyncRedeem() external onlyTriggerAddress {
        // Send redeem request to Bifrost
        DispatchPost memory post = DispatchPost({
            body: abi.encode(block.chainid, AsyncOperation.REDEEM, currentCycleRedeemVTokenAmount),
            dest: StateMachine.polkadot(BIFROST_CHAIN_ID),
            timeout: 0,
            to: BIFROST_SLPX,
            fee: 0,
            payer: _msgSender()
        });
        dispatcher.dispatch(post);

        // reset currentCycleRedeemVTokenAmount
        uint256 vTokenAmount = currentCycleRedeemVTokenAmount;
        currentCycleRedeemVTokenAmount = 0;

        emit AsyncRedeemCompleted(vTokenAmount);
    }

    function batchClaim(uint256 batchSize) external onlyTriggerAddress {
        if (redeemQueueIndex >= nextRequestId) {
            revert InvalidBatchSize();
        }

        // Calculate actual batch size
        uint256 actualBatchSize = nextRequestId - redeemQueueIndex;
        if (batchSize > actualBatchSize) {
            revert BatchSizeTooLarge(batchSize, actualBatchSize);
        }

        // Process redeem requests
        for (uint256 i = redeemQueueIndex; i < redeemQueueIndex + batchSize; i++) {
            RedeemRequest memory request = redeemQueue[i];
            if (request.assets > 0) {
                // Check if already processed
                // Remove index from userRedeemRequests
                uint256[] storage userRequests = userRedeemRequests[request.receiver];
                bool found = false;
                for (uint256 j = 0; j < userRequests.length; j++) {
                    if (userRequests[j] == i) {
                        // Move last element to current position and remove last element
                        userRequests[j] = userRequests[userRequests.length - 1];
                        userRequests.pop();
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    revert RequestIdNotFound(request.receiver, i);
                }
                SafeERC20.safeTransfer(IERC20(asset()), request.receiver, request.assets);
                // Mark as processed
                delete redeemQueue[i];
                // Emit success event
                emit RedeemRequestSuccess(i, request.receiver, request.assets, request.startTime, block.timestamp);
            }
        }

        // Update processing index
        redeemQueueIndex += batchSize;

        emit BatchClaimProcessed(redeemQueueIndex - batchSize, redeemQueueIndex, batchSize);
    }

    // =================== ERC4626 functions ===================
    function totalAssets() public view virtual override returns (uint256) {
        (uint256 tokenAmount,) = oracle.poolInfo(address(asset()));
        return tokenAmount;
    }

    function convertToShares(uint256 assets) public view virtual override returns (uint256) {
        return oracle.getVTokenAmountByToken(address(asset()), assets);
    }

    function convertToAssets(uint256 shares) public view virtual override returns (uint256) {
        return oracle.getTokenAmountByVToken(address(asset()), shares);
    }

    function maxDeposit(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return balanceOf(owner);
    }

    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) public virtual override whenNotPaused returns (uint256) {
        currentCycleMintTokenAmount += assets;
        uint256 vTokenAmount = super.deposit(assets, receiver);
        currentCycleMintVTokenAmount += vTokenAmount;
        return vTokenAmount;
    }

    function mint(uint256 shares, address receiver) public virtual override whenNotPaused returns (uint256) {
        currentCycleMintVTokenAmount += shares;
        uint256 tokenAmount = super.mint(shares, receiver);
        currentCycleMintTokenAmount += tokenAmount;
        return tokenAmount;
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        whenNotPaused
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        whenNotPaused
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // Check if user has reached maximum redeem requests limit
        if (maxRedeemRequestsPerUser > 0 && userRedeemRequests[owner].length >= maxRedeemRequestsPerUser) {
            revert MaxRedeemRequestsReached(owner, userRedeemRequests[owner].length, maxRedeemRequestsPerUser);
        }

        _burn(owner, shares);

        // Create redeem request
        uint256 requestId = nextRequestId;
        redeemQueue[requestId] = RedeemRequest({receiver: receiver, assets: assets, startTime: block.timestamp});
        userRedeemRequests[owner].push(requestId);
        nextRequestId++;

        currentCycleRedeemVTokenAmount += shares;

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    function getUserRedeemRequests(address user) public view returns (RedeemRequest[] memory) {
        uint256[] memory requestIds = userRedeemRequests[user];
        RedeemRequest[] memory requests = new RedeemRequest[](requestIds.length);
        for (uint256 i = 0; i < requestIds.length; i++) {
            requests[i] = redeemQueue[requestIds[i]];
        }
        return requests;
    }

    // =================== ERC6160 functions ===================
    function mint(address _to, uint256 _amount) public onlyRoleAdmin {
        super._mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyRoleAdmin {
        super._burn(_from, _amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC4626).interfaceId || interfaceId == type(IERC20).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
