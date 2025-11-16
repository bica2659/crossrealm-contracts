// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IGameVerifier.sol";  // Relative path from subfolder

contract CheckersVerifier is IGameVerifier {
    address public hubAddress;
    mapping(uint => string) public gameFens;

    modifier onlyHub() {
        require(msg.sender == hubAddress, "Only Hub");
        _;
    }

    function setHub(address _hub) external {
        require(hubAddress == address(0), "Already set");
        hubAddress = _hub;
    }

    function validateMove(uint _gameId, string calldata _move, bytes32 _oldHash, bytes32 _newHash) external view override returns (bool) {
        // Enhanced: Checkers move format "row,col-row,col" (e.g., "5,2-4,3") + hash diff
        // In prod: Parse for diagonal/jump rules, update FEN
        bytes memory moveBytes = bytes(_move);
        require(moveBytes.length == 7, "Invalid format");  // e.g., "5,2-4,3" (7 chars: digits, commas, dash)
        require(moveBytes[3] == bytes1('-'), "Missing dash");
        // Basic coord check (0-7 for rows/cols)
        bool validCoords = (uint8(moveBytes[0]) >= 48 && uint8(moveBytes[0]) <= 55) &&  // '0'-'7' row1
                           (uint8(moveBytes[2]) >= 48 && uint8(moveBytes[2]) <= 55) &&  // col1
                           (uint8(moveBytes[5]) >= 48 && uint8(moveBytes[5]) <= 55) &&  // row2
                           (uint8(moveBytes[7]) >= 48 && uint8(moveBytes[7]) <= 55);    // col2 (note: index 7 for last digit)
        return validCoords && _oldHash != _newHash;
    }

    function verifyProof(uint _gameId, bytes calldata _proof) external view override returns (bool) {
        return _proof.length >= 32;
    }

    function updateFen(uint _gameId, string calldata _newFen) external override onlyHub {
        gameFens[_gameId] = _newFen;
    }
}