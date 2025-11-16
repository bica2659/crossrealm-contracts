// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract GameChat {
    struct Message {
        address sender;
        string text;
        uint256 timestamp;
    }

    mapping(uint256 => Message[]) public messages;  // gameId => array of msgs
    mapping(address => bool) public muted;  // Optional: Mute spammers

    event MessageSent(uint256 indexed gameId, address indexed sender, string text, uint256 timestamp);

    function sendMessage(uint256 _gameId, string calldata _text) external {
        require(bytes(_text).length > 0 && bytes(_text).length <= 280, "Invalid text");  // Tweet-length limit
        require(!muted[msg.sender], "Muted");
        messages[_gameId].push(Message(msg.sender, _text, block.timestamp));
        emit MessageSent(_gameId, msg.sender, _text, block.timestamp);
    }

    function getMessages(uint256 _gameId) external view returns (Message[] memory) {
        return messages[_gameId];
    }

    // Owner mute (add Ownable if needed; stub for now)
    function mute(address _user) external {
        // Only callable by Hub/owner in prod—implement access
        muted[_user] = true;
    }

    receive() external payable {}  // For tips?
}