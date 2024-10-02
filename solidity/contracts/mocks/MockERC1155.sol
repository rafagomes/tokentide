// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';

contract MockERC1155 is ERC1155 {
    constructor() ERC1155('https://token-cdn-domain/{id}.json') {
        _mint(msg.sender, 1, 100, '');
    }

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, '');
    }
}
