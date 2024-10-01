// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

/**
 * @title TokenIdentifier
 * @dev A contract to identify and transfer different types of tokens (ERC20, ERC721, ERC1155)
 */
contract TokenIdentifier is ReentrancyGuard {
    bytes4 private constant ERC721_INTERFACE_ID = 0x80ac58cd;
    bytes4 private constant ERC1155_INTERFACE_ID = 0xd9b67a26;

    // Enumeration representing supported token types
    enum TokenType {
        UNKNOWN,
        ERC20,
        ERC721,
        ERC1155
    }

    // Mapping to cache identified token types for efficiency
    mapping(address => TokenType) private tokenTypeCache;

    // Event emitted when token detection fails
    event DetectionFailed(
        address indexed token,
        string reason,
        address indexed sender
    );

    /**
     * @notice Identify the type of the token (ERC20, ERC721, ERC1155) at a given address
     * @dev Uses EIP-165 to identify ERC721 and ERC1155, and totalSupply/balanceOf checks for ERC20
     * @param token The address of the token contract to identify
     * @return TokenType The type of the token identified
     */
    function identifyTokenType(address token) external returns (TokenType) {
        uint256 size;
        assembly {
            size := extcodesize(token) // Check if the address is a contract
        }

        if (size == 0) {
            emit DetectionFailed(
                token,
                'Address is not a contract',
                msg.sender
            );
            tokenTypeCache[token] = TokenType.UNKNOWN;
            return TokenType.UNKNOWN;
        }

        if (tokenTypeCache[token] != TokenType.UNKNOWN) {
            return tokenTypeCache[token]; // Return cached token type if already identified
        }

        // Check for ERC721 interface support
        try IERC165(token).supportsInterface(ERC721_INTERFACE_ID) returns (
            bool isERC721
        ) {
            if (isERC721) {
                return (tokenTypeCache[token] = TokenType.ERC721);
            }
        } catch {
            emit DetectionFailed(token, 'ERC721 check failed', msg.sender);
        }

        // Check for ERC1155 interface support
        try IERC165(token).supportsInterface(ERC1155_INTERFACE_ID) returns (
            bool isERC1155
        ) {
            if (isERC1155) {
                return (tokenTypeCache[token] = TokenType.ERC1155);
            }
        } catch {
            emit DetectionFailed(token, 'ERC1155 check failed', msg.sender);
        }

        // Check for ERC20 by calling totalSupply and balanceOf
        try IERC20(token).totalSupply() returns (uint256) {
            try IERC20(token).balanceOf(address(this)) returns (uint256) {
                return (tokenTypeCache[token] = TokenType.ERC20);
            } catch {
                emit DetectionFailed(
                    token,
                    'balanceOf check failed for ERC20',
                    msg.sender
                );
            }
        } catch {
            emit DetectionFailed(
                token,
                'totalSupply check failed for ERC20',
                msg.sender
            );
        }

        emit DetectionFailed(
            token,
            'Could not identify token type',
            msg.sender
        );
        tokenTypeCache[token] = TokenType.UNKNOWN;
        return TokenType.UNKNOWN;
    }
}
