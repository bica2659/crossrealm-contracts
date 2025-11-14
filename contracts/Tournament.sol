// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Hub.sol";
import "./Rewards.sol";

contract Tournament is Ownable {
    struct TournamentInfo {
        uint id;
        string name;
        string gameType; // e.g., "chess"
        uint entryFee;
        address token; // Native or ERC20
        uint maxPlayers;
        uint prizePool;
        address[] participants;
        bool active;
        address winner;
        uint startTime;
        uint endTime;
    }

    mapping(uint => TournamentInfo) public tournaments;
    uint public tournamentCount;
    address public hubAddress;
    address payable public rewardsAddress;

    event TournamentCreated(uint id, string name, uint entryFee, uint maxPlayers);
    event PlayerJoined(uint tournamentId, address player);
    event TournamentEnded(uint tournamentId, address winner, uint prize);

    constructor(address _hub, address payable _rewards) Ownable(msg.sender) {
    hubAddress = _hub;
    rewardsAddress = _rewards;
}

    function createTournament(
        string memory _name,
        string memory _gameType,
        uint _entryFee,
        address _token,
        uint _maxPlayers,
        uint _durationHours
    ) external onlyOwner {
        tournamentCount++;
        uint id = tournamentCount;
        uint endTime = block.timestamp + (_durationHours * 1 hours);

        tournaments[id] = TournamentInfo({
            id: id,
            name: _name,
            gameType: _gameType,
            entryFee: _entryFee,
            token: _token,
            maxPlayers: _maxPlayers,
            prizePool: 0,
            participants: new address[](0),
            active: true,
            winner: address(0),
            startTime: block.timestamp,
            endTime: endTime
        });

        emit TournamentCreated(id, _name, _entryFee, _maxPlayers);
    }

    function joinTournament(uint _tournamentId) external payable {
        TournamentInfo storage tournament = tournaments[_tournamentId];
        require(tournament.active, "Tournament not active");
        require(tournament.participants.length < tournament.maxPlayers, "Full");
        require(block.timestamp < tournament.endTime, "Ended");

        if (tournament.token == address(0)) {
            require(msg.value == tournament.entryFee, "Incorrect fee");
            // Contribute to pot
            Rewards(rewardsAddress).contributeToPot{value: tournament.entryFee / 10}(tournament.entryFee / 10, tournament.token);
        } else {
            IERC20(tournament.token).transferFrom(msg.sender, address(this), tournament.entryFee);
            Rewards(rewardsAddress).contributeToPot(tournament.entryFee / 10, tournament.token);
        }

        tournament.participants.push(msg.sender);
        tournament.prizePool += tournament.entryFee;
        emit PlayerJoined(_tournamentId, msg.sender);
    }

    // Stub: Call after games complete (integrate with Hub events)
    function endTournament(uint _tournamentId, address _winner) external onlyOwner {
        TournamentInfo storage tournament = tournaments[_tournamentId];
        require(tournament.active, "Not active");
        require(block.timestamp >= tournament.endTime || tournament.participants.length == 1, "Ongoing");

        tournament.active = false;
        tournament.winner = _winner;
        uint payout = tournament.prizePool;

        if (tournament.token == address(0)) {
            payable(_winner).transfer(payout);
        } else {
            IERC20(tournament.token).transfer(_winner, payout);
        }

        emit TournamentEnded(_tournamentId, _winner, payout);
    }

    // Frontend helpers
    function getTournamentParticipants(uint _tournamentId) external view returns (address[] memory) {
        return tournaments[_tournamentId].participants;
    }

    receive() external payable {}
}