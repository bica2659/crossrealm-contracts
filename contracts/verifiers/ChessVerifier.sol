// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IGameVerifier.sol";

contract ChessVerifier is IGameVerifier {
    mapping(uint => string) public gameFens; // Cache FEN per game

    function validateMove(uint _gameId, string calldata _move, bytes32 _oldHash, bytes32 _newHash) external view override returns (bool) {
        // Stub: Basic check - move is not empty, hashes differ
        // In prod: Integrate with off-chain Chess.js or ZK prover for SAN/FEN validation
        return bytes(_move).length > 0 && _oldHash != _newHash;
    }

    function verifyProof(uint _gameId, bytes calldata _proof) external view override returns (bool) {
        // Stub: Accept any non-empty proof (for zero-gas/Gelato)
        // In prod: Groth16 or Merkle proof verification
        return _proof.length > 0;
    }

    function updateFen(uint _gameId, string calldata _newFen) external override {
        // Only callable by Hub or relayer (add access control in prod)
        gameFens[_gameId] = _newFen;
    }
}