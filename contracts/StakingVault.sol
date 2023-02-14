// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Staked(address _from, uint256 _amount);
    event Withdraw(address _from, uint256 _amount);
    event RewardClaimed(address _from, uint256 _amount);

    struct StakeState {
        uint256 amount;
        uint256 lastUpdated;
        uint256 previousReward;
    }

    // Whether it is a main token staking(e.g. BNB)
    bool private isMainToken;

    address private stakingBank;
    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    // Reward rate per second per token staked
    uint256 private rewardRate;

    // Total amount of tokens staked
    uint256 private totalSupply;

    // TODO Staking time 未知用途
    uint256 private stakingTime;

    // Mapping of staked record
    mapping(address => mapping(uint256 => StakeState)) private stakeRecordNew;
    mapping(address => StakeState) private stakeRecord;
    // Start index of staked record
    mapping(address => uint256) private stakeRecordStartIndex;

    // Mapping of the referrer(value) of user(key)
    mapping(address => address) private userReferrer;
    // Mapping of the user(value) of referrer(key)
    mapping(address => address) private referrerUser;

    constructor(
        bool _isMainToken,
        address _stakingToken,
        address _stakingBank,
        uint256 _rewardRate
    ) {
        require(
            !isMainToken && _stakingToken != address(0),
            "StakingVault: it's not a main token stake. staking token address cannot be 0"
        );
        require(
            !isMainToken && _stakingBank != address(0),
            "StakingVault: staking bank address cannot be 0"
        );
        require(
            _rewardRate > 0,
            "StakingVault: reward rate must be greater than 0"
        );

        isMainToken = _isMainToken;
        stakingBank = _stakingBank;
        if (_isMainToken) {
            stakingToken = IERC20(_stakingToken);
        }
        rewardsToken = IERC20(_stakingToken);
        rewardRate = _rewardRate;
    }

    function owner() public view override returns (address) {
        return super.owner();
    }

    function calculateReward(
        uint256 _amount,
        uint256 _from
    ) public view returns (uint256) {
        return ((_amount * (block.timestamp - _from)) * rewardRate) / 1e18;
    }

    function stakedOf(address _account) public view returns (uint256) {
        return stakeRecord[_account].amount;
    }

    function rewardOf(address _account) public view returns (uint256) {
        return
        stakeRecord[_account].previousReward +
        calculateReward(
            stakeRecord[_account].amount,
            stakeRecord[_account].lastUpdated
        );
    }

    function totalStaked() public view returns (uint256) {
        return totalSupply;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setStakingBank(address _stakingBank) public onlyOwner {
        require(
            _stakingBank != address(0),
            "StakingVault: staking bank address cannot be 0"
        );
        stakingBank = _stakingBank;
    }

    modifier updateReward(address _account) {
        uint256 staked = stakeRecord[_account].amount;
        if (staked > 0) {
            uint256 reward = calculateReward(
                staked,
                stakeRecord[_account].lastUpdated
            );
            stakeRecord[_account].previousReward += reward;
        }
        stakeRecord[msg.sender].lastUpdated = block.timestamp;
        _;
    }

    function stake(
        uint256 _amount
    ) public nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "StakingVault: amount must be greater than 0");

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        totalSupply += _amount;
        stakeRecord[msg.sender].amount += _amount;

        emit Staked(msg.sender, _amount);
    }

    function withdraw(
        uint256 _amount
    ) public nonReentrant updateReward(msg.sender) {
        uint256 staked = stakeRecord[msg.sender].amount;
        require(
            _amount <= staked,
            "StakingVault: withdraw amount cannot be greater than staked amount"
        );
        require(staked > 0, "StakingVault: no tokens staked");

        stakingToken.safeTransferFrom(address(this), msg.sender, _amount);

        totalSupply -= _amount;
        stakeRecord[msg.sender].amount -= _amount;
        emit Withdraw(msg.sender, _amount);
    }

    function claimReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = stakeRecord[msg.sender].previousReward;
        require(reward >= 0, "StakingVault: no rewards to claim");

        rewardsToken.safeTransferFrom(stakingBank, msg.sender, reward);
        stakeRecord[msg.sender].previousReward = 0;
        emit RewardClaimed(msg.sender, reward);
    }
}
