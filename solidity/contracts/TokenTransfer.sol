// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import './interfaces/ITokenIdentifier.sol';
import './libraries/TokenTypes.sol';
import './interfaces/ITokenTransfer.sol';

// Enables the use of safetransfers for ERC20 tokens
using SafeERC20 for IERC20;

/**
 * @title TokenTransfer
 * @dev A contract to transfer tokens of different types (ERC20, ERC721, ERC1155) to a recipient
 */
contract TokenTransfer is
    ReentrancyGuard,
    Pausable,
    AccessControl,
    ITokenTransfer
{
    ITokenIdentifier public immutable tokenIdentifier;
    bytes32 public constant AUTHORIZED_ROLE = keccak256('AUTHORIZED_ROLE');

    event TokenTransferred(
        address indexed token,
        address indexed recipient,
        uint256 amountOrTokenId,
        address indexed sender
    );

    /**
     * @notice Constructor to set the TokenIdentifier contract address
     * @param _tokenIdentifierAddress Address of the deployed TokenIdentifier contract
     */
    constructor(address _tokenIdentifierAddress) {
        require(
            _tokenIdentifierAddress != address(0),
            'Invalid TokenIdentifier address'
        );
        tokenIdentifier = ITokenIdentifier(_tokenIdentifierAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUTHORIZED_ROLE, msg.sender);
    }

    /**
     * @notice Transfer tokens to a recipient based on their type (ERC20, ERC721, or ERC1155)
     * @param token The address of the token contract
     * @param recipient The recipient's address
     * @param amountOrTokenId Amount of ERC20 tokens or token ID for ERC721/ERC1155
     */
    function transferToken(
        address token,
        address recipient,
        uint256 amountOrTokenId
    ) external nonReentrant whenNotPaused onlyRole(AUTHORIZED_ROLE) {
        // Check for caching
        TokenTypes.TokenType tokenType = tokenIdentifier.getCachedTokenType(
            token
        );

        // If the token type is not cached (UNKNOWN), then identify and cache it
        if (tokenType == TokenTypes.TokenType.UNKNOWN) {
            tokenType = tokenIdentifier.identifyTokenType(token);
        }

        require(
            tokenType != TokenTypes.TokenType.UNKNOWN,
            'Unsupported token type'
        );
        require(recipient != msg.sender, 'Cannot transfer to yourself');

        if (tokenType == TokenTypes.TokenType.ERC20) {
            _transferERC20(token, recipient, amountOrTokenId);
        } else if (tokenType == TokenTypes.TokenType.ERC721) {
            _transferERC721(token, recipient, amountOrTokenId);
        } else if (tokenType == TokenTypes.TokenType.ERC1155) {
            _transferERC1155(token, recipient, amountOrTokenId);
        }

        emit TokenTransferred(token, recipient, amountOrTokenId, msg.sender);
    }

    /**
     * @dev Internal function to handle ERC20 transfers using SafeERC20
     */
    function _transferERC20(
        address token,
        address recipient,
        uint256 amount
    ) internal {
        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            'Insufficient ERC20 balance'
        );
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount,
            'ERC20 allowance insufficient'
        );

        IERC20(token).safeTransferFrom(msg.sender, recipient, amount);
    }

    /**
     * @dev Internal function to handle ERC721 transfers
     */
    function _transferERC721(
        address token,
        address recipient,
        uint256 tokenId
    ) internal {
        require(
            IERC721(token).getApproved(tokenId) == address(this) ||
                IERC721(token).isApprovedForAll(msg.sender, address(this)),
            'Contract not approved for ERC721 transfer'
        );
        IERC721(token).safeTransferFrom(msg.sender, recipient, tokenId);
    }

    /**
     * @dev Internal function to handle ERC1155 transfers
     */
    function _transferERC1155(
        address token,
        address recipient,
        uint256 tokenId
    ) internal {
        require(
            IERC1155(token).isApprovedForAll(msg.sender, address(this)),
            'Contract not approved for ERC1155 transfer'
        );
        IERC1155(token).safeTransferFrom(msg.sender, recipient, tokenId, 1, '');
    }
}
