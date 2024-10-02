// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Pausable.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import './libraries/TokenTypes.sol';
import './interfaces/ITokenIdentifier.sol';

/**
 * @title TokenIdentifier
 * @dev A contract to identify and transfer different types of tokens (ERC20, ERC721, ERC1155)
 */
contract TokenIdentifier is
    ReentrancyGuard,
    Pausable,
    AccessControl,
    ITokenIdentifier
{
    bytes4 private constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 private constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes32 public constant AUTHORIZED_ROLE = keccak256('AUTHORIZED_ROLE');

    // Mapping to cache identified token types for efficiency
    mapping(address => TokenTypes.TokenType) private tokenTypeCache;

    // Event emitted when token detection fails
    event DetectionFailed(
        address indexed token,
        string reason,
        address indexed sender,
        uint256 timestamp
    );

    /**
     * @notice Constructor to set the initial roles and pause state
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUTHORIZED_ROLE, msg.sender);
        _pause();
    }

    /**
     * @notice Identify the type of the token (ERC20, ERC721, ERC1155) at a given address
     * @param token The address of the token contract to identify
     * @return TokenType The type of the token identified
     */
    function identifyTokenType(
        address token
    )
        external
        whenNotPaused
        onlyRole(AUTHORIZED_ROLE)
        returns (TokenTypes.TokenType)
    {
        TokenTypes.TokenType cachedType = tokenTypeCache[token];
        if (cachedType != TokenTypes.TokenType.UNKNOWN) {
            return cachedType;
        }

        if (!_isContract(token)) {
            _emitDetectionFailed(token, 'Address is not a contract');
            return _cacheTokenType(token, TokenTypes.TokenType.UNKNOWN);
        }

        // Identify the token type
        TokenTypes.TokenType identifiedType = _identifyERC721(token);
        if (identifiedType != TokenTypes.TokenType.UNKNOWN) {
            return _cacheTokenType(token, identifiedType);
        }

        identifiedType = _identifyERC1155(token);
        if (identifiedType != TokenTypes.TokenType.UNKNOWN) {
            return _cacheTokenType(token, identifiedType);
        }

        identifiedType = _identifyERC20(token);
        if (identifiedType != TokenTypes.TokenType.UNKNOWN) {
            return _cacheTokenType(token, identifiedType);
        }

        _emitDetectionFailed(token, 'Could not identify token type');
        return _cacheTokenType(token, TokenTypes.TokenType.UNKNOWN);
    }

    /**
     * @notice Check if an address is a contract
     * @param addr The address to check
     * @return bool True if the address is a contract, false otherwise
     */
    function _isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @notice Attempt to identify if the token is an ERC721
     * @param token The address of the token contract
     * @return TokenType The identified token type (ERC721 or UNKNOWN)
     */
    function _identifyERC721(
        address token
    ) private returns (TokenTypes.TokenType) {
        try IERC165(token).supportsInterface(ERC721_INTERFACE_ID) returns (
            bool isERC721
        ) {
            if (isERC721) {
                return TokenTypes.TokenType.ERC721;
            }
        } catch {
            _emitDetectionFailed(token, 'ERC721 check failed');
        }
        return TokenTypes.TokenType.UNKNOWN;
    }

    /**
     * @notice Attempt to identify if the token is an ERC1155
     * @param token The address of the token contract
     * @return TokenType The identified token type (ERC1155 or UNKNOWN)
     */
    function _identifyERC1155(
        address token
    ) private returns (TokenTypes.TokenType) {
        try IERC165(token).supportsInterface(ERC1155_INTERFACE_ID) returns (
            bool isERC1155
        ) {
            if (isERC1155) {
                return TokenTypes.TokenType.ERC1155;
            }
        } catch {
            _emitDetectionFailed(token, 'ERC1155 check failed');
        }
        return TokenTypes.TokenType.UNKNOWN;
    }

    /**
     * @notice Attempt to identify if the token is an ERC20
     * @param token The address of the token contract
     * @return TokenType The identified token type (ERC20 or UNKNOWN)
     */
    function _identifyERC20(
        address token
    ) private returns (TokenTypes.TokenType) {
        try IERC20(token).totalSupply() returns (uint256) {
            try IERC20(token).balanceOf(address(this)) returns (uint256) {
                return TokenTypes.TokenType.ERC20;
            } catch {
                _emitDetectionFailed(token, 'balanceOf check failed for ERC20');
            }
        } catch {
            _emitDetectionFailed(token, 'totalSupply check failed for ERC20');
        }
        return TokenTypes.TokenType.UNKNOWN;
    }

    /**
     * @notice Emit a DetectionFailed event
     * @param token The address of the token contract
     * @param reason The reason for the detection failure
     */
    function _emitDetectionFailed(address token, string memory reason) private {
        emit DetectionFailed(token, reason, msg.sender, block.timestamp);
    }

    /**
     * @notice Cache the identified token type
     * @param token The address of the token contract
     * @param tokenType The identified token type
     * @return TokenType The cached token type
     */
    function _cacheTokenType(
        address token,
        TokenTypes.TokenType tokenType
    ) private returns (TokenTypes.TokenType) {
        tokenTypeCache[token] = tokenType;
        return tokenType;
    }
}
