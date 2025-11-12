// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Rewards is Ownable {
    address public devAddress;
    mapping(uint => uint) public monthlyTotalStake;
    mapping(address => mapping(uint => uint)) public userClaimable;
    mapping(address => uint) public userGamesPlayed;
    address public hubContract;

    event ContributionAdded(uint amount, address from, uint timestamp);

    constructor(address _dev) Ownable(msg.sender) {
        devAddress = _dev;
    }

    function setHub(address _hub) external onlyOwner {
        hubContract = _hub;
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
        userClaimable[_user][_timestamp] = 0;

        if (_token == address(0)) {
            payable(_user).transfer(claimable);
        } else {
            IERC20(_token).transfer(_user, claimable);
        }
    }

    function getClaimableRewards(address _user, uint _timestamp, address _token) public view returns (uint) {
        uint pot = (monthlyTotalStake[_timestamp] * 3) / 100;
        uint participation = (pot * 20) / 100;
        uint userShare = (userGamesPlayed[_user] * participation) / _getTotalGames(_timestamp);
        uint multiplier = getTierMultiplier(_user);
        return userShare * multiplier / 100;
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

    function _getTotalGames(uint _timestamp) internal pure returns (uint) {
        return 100; // Stub
    }

    receive() external payable {}
}