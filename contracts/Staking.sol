// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking is Ownable {
    IERC20 public stakingToken; // CORE token (or native via payable)
    IERC20 public rewardsToken; // CORE for rewards
    uint public rewardRate = 15; // Basis points for ~15% APY (adjustable)
    uint public lastUpdateTime;
    uint public rewardPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;
    mapping(address => uint) public balances;

    uint private _totalSupply;

    event Staked(address indexed user, uint amount);
    event Withdrawn(address indexed user, uint amount);
    event RewardPaid(address indexed user, uint reward);
    event FundsContributed(uint amount); // For auto-top from pots

    constructor(address _stakingToken, address _rewardsToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        lastUpdateTime = block.timestamp;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    // Payable for native CORE
    function stake(uint amount) external payable updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        if (address(stakingToken) == address(0)) {
            require(msg.value == amount, "Incorrect ETH value");
        } else {
            stakingToken.transferFrom(msg.sender, address(this), amount);
        }
        _totalSupply += amount;
        balances[msg.sender] += amount;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        _totalSupply -= amount;
        balances[msg.sender] -= amount;
        if (address(stakingToken) == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            stakingToken.transfer(msg.sender, amount);
        }
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // Auto-fund from Rewards pot (10% cut)
    function contributeFunds(uint amount) external payable onlyOwner {
        require(msg.value == amount || msg.value == 0, "Value mismatch");
        emit FundsContributed(amount);
    }

    function earned(address account) public view returns (uint) {
        return (balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }

    function rewardPerToken() public view returns (uint) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        uint timeDelta = block.timestamp - lastUpdateTime;
        return rewardPerTokenStored + ((timeDelta * rewardRate * 1e16) / _totalSupply); // ~15% APY
    }

    function totalSupply() external view returns (uint) {
        return _totalSupply;
    }

    receive() external payable {}
}