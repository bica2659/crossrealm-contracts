// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Hub is Ownable {
    struct Game {
        uint id;
        string gameType;
        uint stake;
        address token;
        address creator;
        address player2;
        bool isAI;
        bool isPrivate;
        address referral;
        bool zeroGas;
        bool active;
    }
    mapping(uint => Game) public games;
    uint public gameCount;
    address public rewardsContract;

    event GameCreated(uint id, address creator, string gameType, uint stake);

    constructor(address _rewards) Ownable(msg.sender) {
        rewardsContract = _rewards;
    }

    function createGame(
        string memory _gameType,
        uint _stake,
        address _token,
        bool _isPrivate,
        address _referral,
        bool _isAI,
        bool _zeroGas
    ) external payable {
        require(_stake >= 0.01 ether, "Min stake 0.01");
        uint potContribution = (_stake * 3) / 100;
        uint netStake = _stake - potContribution;

        if (_token == address(0)) {
            require(msg.value == _stake, "Wrong value");
        } else {
            IERC20(_token).transferFrom(msg.sender, address(this), netStake);
        }

        (bool success, ) = rewardsContract.call{value: potContribution}(
            abi.encodeWithSignature("contributeToPot(uint256,address)", potContribution, _token)
        );
        require(success, "Pot failed");

        gameCount++;
        games[gameCount] = Game({
            id: gameCount,
            gameType: _gameType,
            stake: netStake,
            token: _token,
            creator: msg.sender,
            player2: address(0),
            isAI: _isAI,
            isPrivate: _isPrivate,
            referral: _referral,
            zeroGas: _zeroGas,
            active: true
        });

        emit GameCreated(gameCount, msg.sender, _gameType, netStake);
    }
}