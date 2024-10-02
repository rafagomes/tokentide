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

    // Custom Errors
    error UnsupportedTokenType(address token);
    error InvalidContractAddress(address token);
    error ERC20IdentificationFailed(address token, string reason);
    error ERC721IdentificationFailed(address token);
    error ERC1155IdentificationFailed(address token);

    // Event emitted when token detection fails
    event DetectionFailed(
        address indexed token,
        string reason,
        address indexed sender,
        uint256 timestamp
    );

    // Event emitted when a token type is cached
    event TokenTypeCached(
        address indexed token,
        TokenTypes.TokenType tokenType,
        uint256 timestamp
    );

    /**
     * @notice Constructor to set the default admin role
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUTHORIZED_ROLE, msg.sender);
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
     * @notice Retrieve the cached token type for a given token address
     * @param token The address of the token contract
     * @return TokenType The cached token type
     */
    function getCachedTokenType(
        address token
    ) external view returns (TokenTypes.TokenType) {
        return tokenTypeCache[token];
    }

    /**
     * @notice check if an address is a contract
     */
    function _isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @notice Identify an ERC721 token
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
            _emitDetectionFailed(token, 'ERC721 identification failed');
        }
        return TokenTypes.TokenType.UNKNOWN;
    }

    /**
     * @notice Identify an ERC1155 token
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
            _emitDetectionFailed(token, 'ERC721 identification failed');
        }
        return TokenTypes.TokenType.UNKNOWN;
    }

    /**
     * @notice Identify an ERC20 token
     */
    function _identifyERC20(
        address token
    ) private returns (TokenTypes.TokenType) {
        try IERC20(token).totalSupply() returns (uint256) {
            try IERC20(token).balanceOf(address(this)) returns (uint256) {
                return TokenTypes.TokenType.ERC20;
            } catch {
                _emitDetectionFailed(token, 'ERC721 identification failed');
            }
        } catch (bytes memory reason) {
            revert ERC20IdentificationFailed(token, _decodeReason(reason));
        }
        return TokenTypes.TokenType.UNKNOWN;
    }

    /**
     * @notice Emit an event when token detection fails
     */
    function _emitDetectionFailed(address token, string memory reason) private {
        emit DetectionFailed(token, reason, msg.sender, block.timestamp);
    }

    /**
     * @notice Cache the token type for a given token address
     */
    function _cacheTokenType(
        address token,
        TokenTypes.TokenType tokenType
    ) private returns (TokenTypes.TokenType) {
        tokenTypeCache[token] = tokenType;
        emit TokenTypeCached(token, tokenType, block.timestamp);
        return tokenType;
    }

    /**
     * @notice Decode the revert reason
     */
    function _decodeReason(
        bytes memory reason
    ) private pure returns (string memory) {
        if (reason.length == 0) {
            return 'Unknown Error';
        } else {
            return string(reason);
        }
    }
}
