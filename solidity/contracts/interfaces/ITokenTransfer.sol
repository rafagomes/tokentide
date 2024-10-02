// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

/**
 * @title ITokenTransfer
 * @dev Interface for the TokenTransfer contract
 */
interface ITokenTransfer {
    function transferToken(
        address token,
        address recipient,
        uint256 amountOrTokenId
    ) external;
}
