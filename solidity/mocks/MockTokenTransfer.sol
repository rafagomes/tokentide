// contracts/mocks/MockTokenTransfer.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MockTokenTransfer {
    event TokenTransferred(
        address token,
        address recipient,
        uint256 amountOrTokenId,
        address caller
    );

    // Mock transferToken function
    function transferToken(
        address token,
        address recipient,
        uint256 amountOrTokenId
    ) external returns (bool) {
        emit TokenTransferred(token, recipient, amountOrTokenId, msg.sender);
        return true; // Always return success
    }
}
