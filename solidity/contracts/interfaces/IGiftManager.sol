// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

/**
 * @title IGiftManager
 * @dev Interface for the GiftManager contract
 */
interface IGiftManager {
    function depositGift(
        address tokenAddress,
        uint256 amountOrTokenId,
        bytes32 recipientHash
    ) external payable;

    function claimGift(bytes32 emailHash) external payable;

    function updateFees(uint128 percentageFee, uint128 nftFee) external;

    function directTokenTransfer(
        address token,
        address recipient,
        uint256 amountOrTokenId
    ) external;
}
