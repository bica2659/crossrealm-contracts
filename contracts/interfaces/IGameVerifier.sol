// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGameVerifier {
    function validateMove(uint _gameId, string calldata _move, bytes32 _oldHash, bytes32 _newHash) external view returns (bool);
    function verifyProof(uint _gameId, bytes calldata _proof) external view returns (bool);
    function updateFen(uint _gameId, string calldata _newFen) external;
}