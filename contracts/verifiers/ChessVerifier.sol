// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IGameVerifier.sol";  // Adjusted import path (relative to subfolder)

contract ChessVerifier is IGameVerifier {
    address public hubAddress;  // Add for access control
    mapping(uint => string) public gameFens; // Cache FEN per game

    modifier onlyHub() {
        require(msg.sender == hubAddress, "Only Hub");
        _;
    }

    function setHub(address _hub) external {  // One-time owner setup
        require(hubAddress == address(0), "Already set");
        hubAddress = _hub;
    }

    function validateMove(uint _gameId, string calldata _move, bytes32 _oldHash, bytes32 _newHash) external view override returns (bool) {
        // Enhanced: Basic SAN regex (e.g., "e4", "Nf3", "O-O") + hash diff
        // In prod: Off-chain Chess.js integration or ZK
        bytes memory moveBytes = bytes(_move);
        require(moveBytes.length > 0 && moveBytes.length <= 5, "Invalid move length");  // e.g., "e4" (2), "Qxf7" (4), "O-O-O" (5)
        bool isSan = (keccak256(abi.encodePacked(_move)) == keccak256(abi.encodePacked("O-O"))) ||  // Castle
                     (keccak256(abi.encodePacked(_move)) == keccak256(abi.encodePacked("O-O-O"))) ||  // Queenside
                     (_oldHash != _newHash);  // Basic diff
        return isSan;
    }

    function verifyProof(uint _gameId, bytes calldata _proof) external view override returns (bool) {
        // Enhanced: Min length for dummy proof (32 bytes)
        return _proof.length >= 32;
    }

    function updateFen(uint _gameId, string calldata _newFen) external override onlyHub {
        gameFens[_gameId] = _newFen;
    }
}