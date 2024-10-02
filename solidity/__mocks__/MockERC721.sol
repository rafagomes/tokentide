// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract MockERC721 is ERC721 {
    uint256 private _nextTokenId = 3;

    constructor() ERC721('MockERC721', 'M721') {
        _mint(msg.sender, 1);
        _mint(msg.sender, 2);
    }

    function mint(address to) external {
        _safeMint(to, _nextTokenId);
        _nextTokenId++;
    }
}
