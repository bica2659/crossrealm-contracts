// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrossRealmNFT is ERC721, Ownable {
    uint public nextTokenId = 1;

    constructor() ERC721("CrossRealmNFT", "CRNFT") Ownable(msg.sender) {}

    function mintWinStreak(address _to) external onlyOwner {
        _safeMint(_to, nextTokenId);
        nextTokenId++;
    }

    function equip(uint _tokenId, string memory _gameType) external {
        require(ownerOf(_tokenId) == msg.sender, "Not owner");
    }
}