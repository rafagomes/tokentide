// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import './ITokenIdentifier.sol';

/**
 * @title ITokenTransfer
 * @dev Interface for the TokenTransfer contract
 */
interface ITokenTransfer {
    function transferToken(
        address token,
        address sender,
        address recipient,
        uint256 amountOrTokenId
    ) external;

    function tokenIdentifier() external view returns (ITokenIdentifier);
}
