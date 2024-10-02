// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import '../libraries/TokenTypes.sol';

/**
 * @title ITokenIdentifier
 * @dev Interface for the TokenIdentifier contract
 */
interface ITokenIdentifier {
    function identifyTokenType(
        address token
    ) external returns (TokenTypes.TokenType);

    function getCachedTokenType(
        address token
    ) external view returns (TokenTypes.TokenType);
}
