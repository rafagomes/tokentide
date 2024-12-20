// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import './interfaces/ITokenTransfer.sol';
import './interfaces/IGiftHolder.sol';
import './interfaces/IGiftManager.sol';

/**
 * @title GiftManager
 * @dev A contract to manage the creation and claiming of gifts
 */
contract GiftManager is
    ReentrancyGuard,
    IGiftManager,
    Pausable,
    AccessControl,
    Ownable
{
    IGiftHolder public immutable giftHolder;
    ITokenTransfer public immutable tokenTransfer;
    bytes32 public constant AUTHORIZED_ROLE = keccak256('AUTHORIZED_ROLE');
    address public tokenTransferAddress;
    address public recipientAddress;
    uint128 public nftFee = 0.005 ether;
    uint128 public percentageFee = 3; // 3%

    /**
     * @notice Struct to store gift details
     */
    struct Gift {
        address tokenAddress;
        uint256 amountOrTokenId;
        address sender;
        TokenTypes.TokenType tokenType;
        uint256 fee;
        bool claimed;
        uint256 expiryTime;
    }

    /**
     * @notice Mapping to store gift details using recipient's email hash
     */
    mapping(bytes32 => Gift) public gifts;

    // Custom errors for more descriptive error handling
    error InvalidTokenTransferAddress();
    error InvalidGiftHolderAddress();
    error InvalidRecipientHash();
    error InvalidTokenAddress();
    error SelfGiftingNotAllowed();
    error GiftAlreadyExists();
    error GiftNotFound();
    error GiftAlreadyClaimed();
    error NotSender();
    error GiftNotExpiredYet();

    /**
     * @param token Address of the token contract
     * @param recipient Address of the recipient
     * @param amountOrTokenId Amount of tokens or tokenId
     * @param sender Address of the sender
     */
    event GiftCreated(
        address indexed token,
        address indexed recipient,
        uint256 amountOrTokenId,
        address indexed sender
    );

    /**
     * @param giftId Hash of the recipient's email
     * @param recipient Address of the recipient
     * @param fee Fee charged for the gift
     */
    event GiftClaimed(
        bytes32 indexed giftId,
        address indexed recipient,
        uint256 fee
    );

    /**
     * @param giftId Hash of the recipient's email
     * @param sender Address of the sender
     * @param tokenAddress Address of the token contract
     * @param amountOrTokenId Amount of tokens or tokenId
     * @param tokenType Type of token (ERC20, ERC721, ERC1155)
     * @param fee Fee charged for the gift
     */
    event GiftDeposited(
        bytes32 indexed giftId,
        address indexed sender,
        address indexed tokenAddress,
        uint256 amountOrTokenId,
        TokenTypes.TokenType tokenType,
        uint256 fee
    );

    /**
     * @param percentageFee Fee percentage charged for ERC20 tokens
     * @param nftFee Fixed Fee charged for ERC721 and ERC1155 tokens
     */
    event FeesUpdated(uint256 percentageFee, uint256 nftFee);

    /**
     * @notice Constructor to set the TokenTransfer and GiftHolder contract addresses
     * @param _tokenTransferAddress Address of the deployed TokenTransfer contract
     * @param _giftHolderAddress Address of the deployed GiftHolder contract
     */
    constructor(
        address _tokenTransferAddress,
        address _giftHolderAddress
    ) Ownable(msg.sender) {
        if (_tokenTransferAddress == address(0))
            revert InvalidTokenTransferAddress();
        if (_giftHolderAddress == address(0)) revert InvalidGiftHolderAddress();

        tokenTransfer = ITokenTransfer(_tokenTransferAddress);
        giftHolder = IGiftHolder(_giftHolderAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Update the fees charged for gifts
     * @param _percentageFee Fee percentage charged for ERC20 tokens
     * @param _nftFee Fixed Fee charged for ERC721 and ERC1155 tokens
     */
    function updateFees(
        uint128 _percentageFee,
        uint128 _nftFee
    ) external onlyOwner whenNotPaused {
        percentageFee = _percentageFee;
        nftFee = _nftFee;
        emit FeesUpdated(_percentageFee, _nftFee);
    }

    /**
     * @notice Deposit a gift for a recipient
     * @param tokenAddress Address of the token contract
     * @param amountOrTokenId Amount of tokens or tokenId
     * @param recipientHash Hash of the recipient's email
     */
    function depositGift(
        address tokenAddress,
        bytes32 recipientHash,
        uint256 amountOrTokenId,
        uint256 expiryTimeInSeconds
    ) public payable nonReentrant whenNotPaused {
        _validateGiftParameters(tokenAddress, recipientHash);

        // Identify the token type using TokenIdentifier via TokenTransfer
        TokenTypes.TokenType tokenType = tokenTransfer
            .tokenIdentifier()
            .identifyTokenType(tokenAddress);

        // Calculate the fee based on token type
        uint256 fee = (tokenType == TokenTypes.TokenType.ERC20)
            ? (amountOrTokenId * percentageFee) / 100
            : nftFee;

        // Call the GiftHolder to handle the actual transfer of tokens
        giftHolder.depositGift{ value: msg.value }(
            tokenAddress,
            msg.sender,
            recipientHash,
            amountOrTokenId,
            tokenType,
            fee
        );

        // Store gift details
        gifts[recipientHash] = Gift(
            tokenAddress,
            amountOrTokenId,
            msg.sender,
            tokenType,
            fee,
            false,
            block.timestamp + expiryTimeInSeconds
        );

        emit GiftDeposited(
            recipientHash,
            msg.sender,
            tokenAddress,
            amountOrTokenId,
            tokenType,
            fee
        );
    }

    /**
     * @notice Claim a gift using the recipient's email hash
     * @param emailHash Hash of the recipient's email
     */
    function claimGift(
        bytes32 emailHash
    ) external payable nonReentrant whenNotPaused {
        Gift storage gift = gifts[emailHash];
        if (gift.tokenAddress == address(0)) revert GiftNotFound();
        if (gift.claimed) revert GiftAlreadyClaimed();

        gift.claimed = true;

        giftHolder.claimGift{ value: msg.value }(
            gift.tokenAddress,
            msg.sender,
            gift.amountOrTokenId,
            gift.fee
        );

        emit GiftClaimed(emailHash, msg.sender, gift.fee);

        delete gifts[emailHash];
    }

    /**
     * @notice Allows sender to reclaim their gift if it expires
     */
    function reclaimGift(
        bytes32 recipientHash
    ) external nonReentrant whenNotPaused {
        Gift storage gift = gifts[recipientHash];
        if (gift.claimed) revert GiftAlreadyClaimed();
        if (block.timestamp <= gift.expiryTime) revert GiftNotExpiredYet();
        if (gift.sender != msg.sender) revert NotSender();

        giftHolder.claimGift(
            gift.tokenAddress,
            gift.sender,
            gift.amountOrTokenId,
            0
        );

        emit GiftClaimed(recipientHash, gift.sender, 0);

        delete gifts[recipientHash];
    }

    /**
     * @notice Directly transfer tokens to a recipient
     * @param token Address of the token contract
     * @param recipient Address of the recipient
     * @param amountOrTokenId Amount of tokens or tokenId
     */
    function directTokenTransfer(
        address token,
        address recipient,
        uint256 amountOrTokenId
    ) external nonReentrant whenNotPaused {
        tokenTransfer.transferToken(
            token,
            msg.sender,
            recipient,
            amountOrTokenId
        );
    }

    /**
     * @notice Deposit multiple gifts in a batch
     */
    function batchDepositGift(
        address tokenAddress,
        bytes32[] calldata recipientHashes,
        uint256[] calldata amountsOrTokenIds,
        uint256 expiryTimeInSeconds
    ) external payable nonReentrant whenNotPaused {
        require(
            amountsOrTokenIds.length == recipientHashes.length,
            'Input arrays must have the same length'
        );

        for (uint256 i = 0; i < recipientHashes.length; i++) {
            depositGift(
                tokenAddress,
                recipientHashes[i],
                amountsOrTokenIds[i],
                expiryTimeInSeconds
            );
        }
    }

    /**
     * @notice Validate the gift parameters
     * @param tokenAddress Address of the token contract
     * @param recipientHash Hash of the recipient's email
     */
    function _validateGiftParameters(
        address tokenAddress,
        bytes32 recipientHash
    ) internal view {
        if (msg.sender == address(this)) revert SelfGiftingNotAllowed();
        if (recipientHash == bytes32(0)) revert InvalidRecipientHash();
        if (tokenAddress == address(0)) revert InvalidTokenAddress();
        if (gifts[recipientHash].tokenAddress != address(0))
            revert GiftAlreadyExists();
    }
}
