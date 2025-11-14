// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Rewards is Ownable {
    address public devAddress;
    mapping(uint => uint) public monthlyTotalStake;
    mapping(address => mapping(uint => uint)) public userClaimable;
    mapping(address => uint) public userGamesPlayed;
    mapping(address => uint) public userWins;
    mapping(address => uint) public userLosses;
    mapping(address => uint) public userTotalStakes;
    mapping(address => uint) public userElo;
    mapping(uint => uint) public monthlyTotalGames;
    address public hubContract;

    event ContributionAdded(uint amount, address from, uint timestamp);
    event GamesPlayedIncremented(address user, uint count);
    event UserELOUpdated(address user, uint newElo);

    constructor(address _dev) Ownable(msg.sender) {
        devAddress = _dev;
    }

    function setHub(address _hub) external onlyOwner {
        hubContract = _hub;
    }

    // Updated: Now tracks wins/losses and calls updateELO
    function incrementGamesPlayed(address _user, uint _wins, uint _losses) external {
        require(msg.sender == hubContract, "Only Hub");
        userGamesPlayed[_user] += 1;
        userWins[_user] += _wins;
        userLosses[_user] += _losses;
        userTotalStakes[_user] += 1; // Stub: Avg 1 CORE; update with real stake in prod
        uint timestamp = _getMonthStart(block.timestamp);
        monthlyTotalGames[timestamp]++;
        updateELO(_user);
        emit GamesPlayedIncremented(_user, userGamesPlayed[_user]);
    }

    function updateELO(address _user) internal {
        // Stub ELO calc (integrate full formula later)
        uint newElo = 1200 + (userWins[_user] * 20) - (userLosses[_user] * 10);
        userElo[_user] = newElo;
        emit UserELOUpdated(_user, newElo);
    }

    function contributeToPot(uint _amount, address _token) external payable {
        require(msg.sender == hubContract, "Only Hub");
        uint timestamp = _getMonthStart(block.timestamp);
        monthlyTotalStake[timestamp] += _amount;
        emit ContributionAdded(_amount, msg.sender, timestamp);
    }

    function claimRewards(address _user, uint _timestamp, address _token) external {
        uint claimable = getClaimableRewards(_user, _timestamp, _token);
        require(claimable > 0, "Nothing to claim");

        if (userClaimable[_user][_timestamp] == 0) {
            userClaimable[_user][_timestamp] = claimable;
        }
        uint payout = userClaimable[_user][_timestamp];
        userClaimable[_user][_timestamp] = 0;

        if (_token == address(0)) {
            payable(_user).transfer(payout);
        } else {
            IERC20(_token).transfer(_user, payout);
        }
    }

    function getClaimableRewards(address _user, uint _timestamp, address _token) public view returns (uint) {
        uint pot = (monthlyTotalStake[_timestamp] * 3) / 100;
        uint participation = (pot * 20) / 100;
        uint totalGames = _getTotalGames(_timestamp);
        uint userShare = totalGames > 0 ? (userGamesPlayed[_user] * participation) / totalGames : 0;
        uint multiplier = getTierMultiplier(_user);
        return userShare * multiplier / 100;
    }

    // New: getUserStats for frontend
    function getUserStats(address _user) external view returns (uint wins, uint losses, uint totalStakes, uint elo) {
        return (userWins[_user], userLosses[_user], userTotalStakes[_user], userElo[_user]);
    }

    function getUserGamesCount(address _user) external view returns (uint) {
        return userGamesPlayed[_user];
    }

    function getTierMultiplier(address _user) internal view returns (uint) {
        uint games = userGamesPlayed[_user];
        if (games >= 50) return 150;
        if (games >= 10) return 120;
        return 100;
    }

    function _getMonthStart(uint _time) internal pure returns (uint) {
        return (_time / 30 days) * 30 days;
    }

    function _getTotalGames(uint _timestamp) internal view returns (uint) {
        uint ts = _getMonthStart(_timestamp);
        return monthlyTotalGames[ts] > 0 ? monthlyTotalGames[ts] : 1; // Fixed: Avoid div by zero
    }

    receive() external payable {}
}