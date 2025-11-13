// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IGameVerifier.sol";

contract CheckersVerifier is IGameVerifier {
    mapping(uint => string) public gameFens; // Cache FEN per game

    function validateMove(uint _gameId, string calldata _move, bytes32 _oldHash, bytes32 _newHash) external view override returns (bool) {
        // Stub: Basic check - move format like "a3-b4", hashes differ
        // In prod: Parse move for diagonal/jump rules, update FEN
        return bytes(_move).length > 0 && _oldHash != _newHash;
    }

    function verifyProof(uint _gameId, bytes calldata _proof) external view override returns (bool) {
        // Stub: Accept any non-empty proof
        return _proof.length > 0;
    }

    function updateFen(uint _gameId, string calldata _newFen) external override {
        // Only callable by Hub or relayer
        gameFens[_gameId] = _newFen;
    }
}