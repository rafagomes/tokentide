// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import '../libraries/TokenTypes.sol';

/**
 * @title IGiftHolder
 * @dev Interface for the GiftHolder contract
 */
interface IGiftHolder {
    function depositGift(
        address tokenAddress,
        uint256 amountOrTokenId,
        bytes32 recipientHash,
        TokenTypes.TokenType tokenType,
        uint256 fee
    ) external payable;

    function claimGift(
        address tokenAddress,
        address recipient,
        uint256 amountOrTokenId,
        uint256 fee
    ) external payable;
}
