// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Staking.sol"; // Import for fund

contract Rewards is Ownable {
    address public devAddress;
    mapping(uint => uint) public monthlyTotalStake;
    mapping(address => mapping(uint => uint)) public userClaimable;
    mapping(address => uint) public userGamesPlayed;
    mapping(address => uint) public userWins;
    mapping(address => uint) public userLosses;
    mapping(address => uint) public userTotalStakes;
    mapping(address => uint) public userElo;
    mapping(address => address) public primaryReferrer; // Primary referrer
    mapping(address => mapping(uint => uint)) public referralEarnings; // Per referrer/month
    mapping(uint => uint) public monthlyDevPot; // 50% dev + rerouted bonus
    mapping(uint => uint) public monthlyTotalGames;
    address public hubContract;
    address payable public stakingAddress; // Payable for value transfers

    uint constant DEV_CUT = 50; // 50% dev
    uint constant REWARDS_CUT = 20; // 20% players
    uint constant REF_CUT = 10; // 10% referrals
    uint constant STAKING_CUT = 10; // 10% staking fund
    uint constant CREATOR_BONUS_CUT = 10; // 10% private creator (reroute to dev if public)

    event ContributionAdded(uint amount, address from, uint timestamp);
    event GamesPlayedIncremented(address user, uint count);
    event UserELOUpdated(address user, uint newElo);
    event ReferralEarned(address referrer, uint amount);
    event CreatorBonusEarned(address creator, uint amount, uint gameId);

    constructor(address _dev, address payable _staking) Ownable(msg.sender) {
        devAddress = _dev;
        stakingAddress = _staking;
    }

    function setHub(address _hub) external onlyOwner {
        hubContract = _hub;
    }

    function incrementGamesPlayed(address _user, uint _wins, uint _losses) external {
        require(msg.sender == hubContract, "Only Hub");
        userGamesPlayed[_user] += 1;
        userWins[_user] += _wins;
        userLosses[_user] += _losses;
        userTotalStakes[_user] += 1; // Stub avg 1 CORE
        uint month = _getMonthStart(block.timestamp);
        monthlyTotalGames[month]++;
        updateELO(_user);
        emit GamesPlayedIncremented(_user, userGamesPlayed[_user]);
    }

    function updateELO(address _user) internal {
        uint newElo = 1200 + (userWins[_user] * 20) - (userLosses[_user] * 10);
        userElo[_user] = newElo;
        emit UserELOUpdated(_user, newElo);
    }

    function contributeToPot(uint _amount, address _token) external payable {
        require(msg.sender == hubContract, "Only Hub");
        uint month = _getMonthStart(block.timestamp);

        uint devShare = _amount * DEV_CUT / 100;
        uint rewardsShare = _amount * REWARDS_CUT / 100;
        uint refShare = _amount * REF_CUT / 100;
        uint stakingShare = _amount * STAKING_CUT / 100;
        uint creatorBonusShare = _amount * CREATOR_BONUS_CUT / 100;

        monthlyDevPot[month] += devShare + creatorBonusShare; // Reroute if public
        monthlyTotalStake[month] += rewardsShare;
        // Ref: Added on endGame
        // Staking: Auto
        if (stakingAddress != address(0) && stakingShare > 0) {
            if (_token == address(0)) {
                Staking(stakingAddress).contributeFunds{value: stakingShare}(stakingShare);
            } else {
                IERC20(_token).transfer(stakingAddress, stakingShare);
            }
        }

        emit ContributionAdded(_amount, msg.sender, month);
    }

    function setPrimaryReferrer(address _user, address _referrer) external {
        require(msg.sender == hubContract, "Only Hub");
        if (primaryReferrer[_user] == address(0)) {
            primaryReferrer[_user] = _referrer;
        }
    }

    function addReferralCut(address _user, uint _potAmount, uint _month) external {
        require(msg.sender == hubContract, "Only Hub");
        address referrer = primaryReferrer[_user];
        if (referrer != address(0)) {
            uint refShare = _potAmount * REF_CUT / 100;
            referralEarnings[referrer][_month] += refShare;
            emit ReferralEarned(referrer, refShare);
        }
    }

    function addCreatorBonus(uint _gameId, address _creator, uint _potAmount) external {
        require(msg.sender == hubContract, "Only Hub");
        uint bonus = _potAmount * CREATOR_BONUS_CUT / 100;
        userClaimable[_creator][_getMonthStart(block.timestamp)] += bonus;
        emit CreatorBonusEarned(_creator, bonus, _gameId);
    }

    function autoFundStaking(uint _month) external onlyOwner {
        uint stakingShare = monthlyTotalStake[_month] * STAKING_CUT / 100;
        monthlyTotalStake[_month] -= stakingShare;
        if (stakingAddress != address(0) && stakingShare > 0) {
            if (address(0) == address(0)) { // Native
                Staking(stakingAddress).contributeFunds{value: stakingShare}(stakingShare);
            } else {
                IERC20(address(0)).transfer(stakingAddress, stakingShare); // Adjust token addr
            }
        }
    }

    function claimRewards(address _user, uint _timestamp, address _token) external {
        uint month = _getMonthStart(_timestamp);
        uint claimable = getClaimableRewards(_user, month, _token);
        uint refClaim = referralEarnings[_user][month];
        uint totalPayout = claimable + refClaim;
        require(totalPayout > 0, "Nothing to claim");

        userClaimable[_user][month] = 0;
        referralEarnings[_user][month] = 0;

        if (_token == address(0)) {
            payable(_user).transfer(totalPayout);
        } else {
            IERC20(_token).transfer(_user, totalPayout);
        }
    }

    function getClaimableRewards(address _user, uint _timestamp, address _token) public view returns (uint) {
        uint month = _getMonthStart(_timestamp);
        uint pot = monthlyTotalStake[month];
        uint participation = pot * REWARDS_CUT / 100;
        uint totalGames = _getTotalGames(month);
        uint userShare = totalGames > 0 ? (userGamesPlayed[_user] * participation) / totalGames : 0;
        uint multiplier = getTierMultiplier(_user);
        return userShare * multiplier / 100;
    }

    function devWithdraw(uint _month) external onlyOwner {
        uint devShare = monthlyDevPot[_month];
        monthlyDevPot[_month] = 0;
        if (address(0) == address(0)) { // Native
            payable(owner()).transfer(devShare);
        } else {
            // ERC20 transfer (adjust token)
        }
    }

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
        return monthlyTotalGames[ts] > 0 ? monthlyTotalGames[ts] : 1;
    }

    receive() external payable {}
}