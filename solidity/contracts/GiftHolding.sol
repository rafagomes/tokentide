// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "./TokenIdentifier.sol";

using SafeERC20 for IERC20;

/**
 * @title GiftHoldingContract
 * @dev A contract that allows users to send gifts (tokens or NFTs) to email addresses,
 * where recipients can claim the gifts using their email hash
 */
contract GiftHolding is ReentrancyGuard, IERC1155Receiver, ERC165 {
    TokenIdentifier public immutable tokenIdentifier;

    /**
     * @notice Struct to store gift details
     */
    struct Gift {
        address tokenAddress;
        uint256 amountOrTokenId;
        address sender;
        TokenIdentifier.TokenType tokenType;
        uint256 fee;
        bool claimed;
    }

    mapping(bytes32 => Gift) public gifts;
    address public immutable owner;
    uint128 public nftFee = 0.005 ether; // 0.005 ETH
    uint128 public percentageFee = 3; // 3%

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
        TokenIdentifier.TokenType tokenType,
        uint256 fee
    );

    /**
     * @param percentageFee Fee percentage charged for ERC20 tokens
     * @param nftFee Fixed Fee charged for ERC721 and ERC1155 tokens
     */
    event FeesUpdated(uint256 percentageFee, uint256 nftFee);

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

    constructor(address _tokenIdentifierAddress) {
        require(
            _tokenIdentifierAddress != address(0),
            "Invalid TokenIdentifier address"
        );
        owner = msg.sender;
        tokenIdentifier = TokenIdentifier(_tokenIdentifierAddress);
    }

    /**
     * @notice Modifier to allow only the owner to call a function
     */
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "GiftHolding: Only owner is allowed to call this function"
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

        TokenIdentifier.TokenType tokenType = tokenIdentifier.identifyTokenType(
            tokenAddress
        );

        require(
            tokenType != TokenIdentifier.TokenType.UNKNOWN,
            "GiftHolding: Unsupported token type"
        );

        uint256 fee = _handleTokenTransfer(
            tokenType,
            tokenAddress,
            amountOrTokenId
        );

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
            "No gift found for this email"
        );
        require(!gift.claimed, "Gift already claimed");

        gift.claimed = true;

        if (gift.tokenType == TokenIdentifier.TokenType.ERC20) {
            uint256 amountAfterFee = gift.amountOrTokenId - gift.fee;
            IERC20(gift.tokenAddress).safeTransfer(msg.sender, amountAfterFee);
        } else if (gift.tokenType == TokenIdentifier.TokenType.ERC721) {
            require(msg.value >= gift.fee, "Insufficient ETH for fee");
            IERC721(gift.tokenAddress).safeTransferFrom(
                address(this),
                msg.sender,
                gift.amountOrTokenId
            );
        } else if (gift.tokenType == TokenIdentifier.TokenType.ERC1155) {
            require(msg.value >= gift.fee, "Insufficient ETH for fee");
            IERC1155(gift.tokenAddress).safeTransferFrom(
                address(this),
                msg.sender,
                gift.amountOrTokenId,
                1,
                ""
            );
        }

        (bool success, ) = owner.call{value: gift.fee, gas: 2300}("");
        require(success, "Transfer failed");

        delete gifts[emailHash];

        emit GiftClaimed(emailHash, msg.sender, gift.fee);
    }

    receive() external payable {}

    /**
     * @notice Validate the gift parameters
     * @param tokenAddress Address of the token contract
     * @param recipientHash Hash of the recipient's email
     */
    function _validateGiftParameters(
        address tokenAddress,
        bytes32 recipientHash
    ) internal view {
        require(msg.sender != address(this), "Cannot gift to self");
        require(recipientHash != bytes32(0), "Invalid recipient hash");
        require(
            tokenAddress != address(0),
            "GiftHolding: Invalid token address"
        );
        require(
            gifts[recipientHash].tokenAddress == address(0),
            "GiftHolding: Gift already exists"
        );
    }

    /**
     * @notice Handle token transfer based on the token type
     * @param tokenType Type of token (ERC20, ERC721, ERC1155)
     * @param tokenAddress Address of the token contract
     * @param amountOrTokenId Amount of tokens or tokenId
     */
    function _handleTokenTransfer(
        TokenIdentifier.TokenType tokenType,
        address tokenAddress,
        uint256 amountOrTokenId
    ) internal returns (uint256 fee) {
        if (tokenType == TokenIdentifier.TokenType.ERC20) {
            return _transferERC20(tokenAddress, amountOrTokenId);
        } else if (tokenType == TokenIdentifier.TokenType.ERC721) {
            return _transferERC721(tokenAddress, amountOrTokenId);
        } else if (tokenType == TokenIdentifier.TokenType.ERC1155) {
            return _transferERC1155(tokenAddress, amountOrTokenId);
        }
    }

    /**
     * @notice Transfer ERC20 tokens to the contract
     * @param tokenAddress Address of the token contract
     * @param amount Amount of tokens
     */
    function _transferERC20(
        address tokenAddress,
        uint256 amount
    ) internal returns (uint256 fee) {
        fee = (amount * percentageFee) / 100;

        require(
            IERC20(tokenAddress).balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount,
            "Allowance insufficient"
        );

        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    /**
     * @notice Transfer ERC721 tokens to the contract
     * @param tokenAddress Address of the token contract
     * @param tokenId Token ID
     */
    function _transferERC721(
        address tokenAddress,
        uint256 tokenId
    ) internal returns (uint256 fee) {
        require(
            IERC721(tokenAddress).ownerOf(tokenId) == msg.sender,
            "Not the token owner"
        );
        require(
            IERC721(tokenAddress).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(tokenAddress).getApproved(tokenId) == address(this),
            "Not approved for transfer"
        );

        IERC721(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        fee = nftFee;
    }

    /**
     * @notice Transfer ERC1155 tokens to the contract
     * @param tokenAddress Address of the token contract
     * @param tokenId Token ID
     */
    function _transferERC1155(
        address tokenAddress,
        uint256 tokenId
    ) internal returns (uint256 fee) {
        require(
            IERC1155(tokenAddress).balanceOf(msg.sender, tokenId) > 0,
            "Not enough balance"
        );
        require(
            IERC1155(tokenAddress).isApprovedForAll(msg.sender, address(this)),
            "Not approved for transfer"
        );

        IERC1155(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            1,
            ""
        );
        fee = nftFee;
    }

    /**
     * @notice ERC1155Receiver hook to receive ERC1155 tokens
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @notice ERC1155Receiver hook to receive ERC1155 tokens in a batch
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @notice ERC1155Receiver hook to reject ERC1155 tokens
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
