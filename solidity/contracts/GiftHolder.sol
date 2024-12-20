// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './interfaces/ITokenTransfer.sol';
import './interfaces/IGiftHolder.sol';

using SafeERC20 for IERC20;

/**
 * @title GiftHolderContract
 * @dev A contract that allows users to send gifts (tokens or NFTs) to email addresses,
 * where recipients can claim the gifts using their email hash
 */
contract GiftHolder is
    ReentrancyGuard,
    IERC721Receiver,
    IERC1155Receiver,
    ERC165,
    IGiftHolder,
    AccessControl,
    Pausable
{
    ITokenTransfer public tokenTransfer;
    bytes32 public constant AUTHORIZED_ROLE = keccak256('AUTHORIZED_ROLE');
    address public adminAddress;

    event GiftReceived(
        address indexed tokenAddress,
        address indexed sender,
        bytes32 recipientHash,
        uint256 amountOrTokenId,
        uint8 tokenType,
        uint256 fee
    );

    event GiftClaimProcessed(
        address indexed tokenAddress,
        address indexed recipient,
        uint256 amountOrTokenId,
        uint256 fee
    );

    constructor(address _tokenTransferAddress) {
        require(
            _tokenTransferAddress != address(0),
            'Invalid TokenTransfer address'
        );
        tokenTransfer = ITokenTransfer(_tokenTransferAddress);
        adminAddress = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUTHORIZED_ROLE, msg.sender);
    }

    /**
     * @notice Deposit a gift for a recipient
     * @param tokenAddress Address of the token contract
     * @param sender Address of the sender
     * @param amountOrTokenId Amount of tokens or tokenId
     * @param recipientHash Hash of the recipient's email
     * @param tokenType Type of the token (ERC20, ERC721, ERC1155)
     * @param fee Fee charged for handling the gift
     */
    function depositGift(
        address tokenAddress,
        address sender,
        bytes32 recipientHash,
        uint256 amountOrTokenId,
        TokenTypes.TokenType tokenType,
        uint256 fee
    ) external payable nonReentrant onlyRole(AUTHORIZED_ROLE) {
        tokenTransfer.transferToken(
            tokenAddress,
            sender,
            address(this),
            amountOrTokenId
        );

        emit GiftReceived(
            tokenAddress,
            sender,
            recipientHash,
            amountOrTokenId,
            uint8(tokenType),
            fee
        );
    }

    /**
     * @notice Claim a gift
     * @param tokenAddress Address of the token contract
     * @param recipient Address of the gift recipient
     * @param amountOrTokenId Amount of ERC20 tokens or tokenId for ERC721/ERC1155
     * @param fee Fee to transfer to the owner
     */
    function claimGift(
        address tokenAddress,
        address recipient,
        uint256 amountOrTokenId,
        uint256 fee
    ) external payable nonReentrant onlyRole(AUTHORIZED_ROLE) {
        require(recipient != address(0), 'Invalid recipient address');

        IERC20(tokenAddress).approve(address(tokenTransfer), amountOrTokenId);

        // Transfer the token using the TokenTransfer contract
        tokenTransfer.transferToken(
            tokenAddress,
            address(this),
            recipient,
            amountOrTokenId
        );

        // Transfer the fee to the owner
        if (msg.value > 0 && fee > 0) {
            require(msg.value >= fee, 'Insufficient ETH for fee');
            (bool success, ) = adminAddress.call{ value: fee, gas: 2300 }('');
            require(success, 'Fee transfer to owner failed');
        }

        emit GiftClaimProcessed(tokenAddress, recipient, amountOrTokenId, fee);
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
     * @notice ERC721Receiver hook to receive ERC721 tokens
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
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
    )
        public
        view
        virtual
        override(AccessControl, ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Update the admin address
     */
    function updateAdmin(
        address newAdmin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAdmin != address(0), 'Invalid admin address');
        revokeRole(DEFAULT_ADMIN_ROLE, adminAddress);
        adminAddress = newAdmin;
        grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
    }
}
