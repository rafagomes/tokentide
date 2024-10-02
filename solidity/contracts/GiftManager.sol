// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import './TokenTransfer.sol';
import './GiftHolder.sol';
import './interfaces/IGiftManager.sol';

/**
 * @title GiftManager
 * @dev A contract to manage the creation and claiming of gifts
 */
contract GiftManager is ReentrancyGuard, IGiftManager {
    GiftHolder public immutable giftHolder;
    TokenTransfer public immutable tokenTransfer;
    address public owner;
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
    }

    /**
     * @notice Mapping to store gift details using recipient's email hash
     */
    mapping(bytes32 => Gift) public gifts;

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
    constructor(address _tokenTransferAddress, address _giftHolderAddress) {
        require(
            _tokenTransferAddress != address(0),
            'Invalid TokenTransfer address'
        );
        require(_giftHolderAddress != address(0), 'Invalid GiftHolder address');
        owner = msg.sender;
        tokenTransfer = TokenTransfer(_tokenTransferAddress);
        giftHolder = GiftHolder(_giftHolderAddress);
    }

    /**
     * @notice Modifier to allow only the owner to call a function
     */
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            'GiftHolder: Only owner is allowed to call this function'
        );
        _;
    }

    /**
     * @notice Update the fees charged for gifts
     * @param _percentageFee Fee percentage charged for ERC20 tokens
     * @param _nftFee Fixed Fee charged for ERC721 and ERC1155 tokens
     */
    function updateFees(
        uint128 _percentageFee,
        uint128 _nftFee
    ) external onlyOwner {
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
        uint256 amountOrTokenId,
        bytes32 recipientHash
    ) external payable nonReentrant {
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
            amountOrTokenId,
            recipientHash,
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
            false
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
    function claimGift(bytes32 emailHash) external payable nonReentrant {
        Gift storage gift = gifts[emailHash];
        require(
            gift.tokenAddress != address(0),
            'No gift found for this email or already claimed'
        );
        require(!gift.claimed, 'Gift already claimed');

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
     * @notice Directly transfer tokens to a recipient
     * @param token Address of the token contract
     * @param recipient Address of the recipient
     * @param amountOrTokenId Amount of tokens or tokenId
     */
    function directTokenTransfer(
        address token,
        address recipient,
        uint256 amountOrTokenId
    ) external nonReentrant {
        tokenTransfer.transferToken(token, recipient, amountOrTokenId);
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
        require(msg.sender != address(this), 'Cannot gift to self');
        require(recipientHash != bytes32(0), 'Invalid recipient hash');
        require(
            tokenAddress != address(0),
            'GiftManager: Invalid token address'
        );
        require(
            gifts[recipientHash].tokenAddress == address(0),
            'GiftManager: Gift already exists'
        );
    }
}
