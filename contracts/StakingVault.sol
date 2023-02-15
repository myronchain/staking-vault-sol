// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
1. 质押代币

8. 获取合约的质押总额
9. 获取指定人的质押总额

2. 提取本金
3. 提取质押收益
4. 提取推荐收益
5. 提取代币给Owner

6. 获取指定人的收益历史总额
7. 获取指定人的收益余额
14. TODO 获取指定人邀请收益历史总额
15. TODO 获取指定人邀请收益余额
10. TODO 更新收益相关数值

13. TODO 更新管理费用

11. 保存邀请人
12. 查看邀请人

*/
contract StakingVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Staked(address _from, uint256 _amount);
    event Withdraw(address _from, uint256 _amount);
    event WithdrawOwner(address _from, uint256 _amount);
    event RewardClaimed(address _from, uint256 _amount);

    // 一次质押的信息
    struct StakeRecord {
        // 质押数量
        uint256 stakeAmount;
        // 质押管理费（指定时间链下调用合约更新）
        uint256 manageFee;
        // 质押时间
        uint256 stakeTime;
        // 上次更新奖励的时间
        uint256 rewardsLastUpdatedTime;
        // 此质押奖励历史记录
        RewardsRecord[] rewardsRecords;
    }

    // 奖励记录，每达到一个周期新增一条记录
    struct RewardsRecord {
        // 质押数量
        uint256 stakeAmount;
        // 奖励数量（指定时间链下调用合约更新）
        uint256 rewardsAmount;
        // 计算时间
        uint256 lastCalcTime;
    }

    // 存放一个用户质押、奖励、提取详情
    struct UserInfo {
        // 质押总额
        uint256 stakedAmount;
        // 用户质押奖励总额（改名字）
        uint256 rewardsAmount;
        // TODO 用户邀请奖励（指定时间链下调用合约更新，与质押管理费一起刷新）
        uint256 referrerRewardsAmount;
        // 用户质押奖励提取总额（改名字）
        uint256 rewardsWithdrawAmount;
        // TODO 用户邀请奖励提取总额
        uint256 referrerRewardsWithdrawAmount;
        // 用户所有质押记录
        StakeRecord[] stakeRecords;
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

    // The minimum staking period to start calculating the earnings
    uint256 private stakingTime;

    // Mapping of staked record
    mapping(address => UserInfo) private userStateRecord;

    // Mapping of the referrer(value) of user(key)
    mapping(address => address) private userReferrer;
    // Mapping of the users(value) of referrer(key)
    mapping(address => address[]) private referrerUsers;


    /** 构造函数 */
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


    /** 合约控制部分 */
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }


    /** 质押配置 */
    function setStakingBank(address _stakingBank) public onlyOwner {
        require(
            _stakingBank != address(0),
            "StakingVault: staking bank address cannot be 0"
        );
        stakingBank = _stakingBank;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        require(
            _rewardRate != 0,
            "StakingVault: staking rewad rate cannot be 0"
        );
        rewardRate = _rewardRate;
    }

    function setStakingTime(uint256 _stakingTime) public onlyOwner {
        require(
            _stakingTime != 0,
            "StakingVault: staking time cannot be 0"
        );
        stakingTime = _stakingTime;
    }


    /** 质押信息查询 */

    // 计算用户质押总额 TODO 减去管理费用
    function _getStakedOf(address _account) private view returns (uint256){
        require(
            userStateRecord[_account].stakedAmount != 0,
            "StakingVault: you never stake"
        );
        uint256 amount = 0;
        for (uint256 i = 0; i < userStateRecord[_account].stakeRecords.length; ++i) {
            amount += userStateRecord[_account].stakeRecords[i].stakeAmount;
        }
        return amount;
    }

    // 获取用户质押总额
    function stakedOf(address _account) public view returns (uint256) {
        return userStateRecord[_account].stakedAmount;
    }

    // 计算用户收益总额
    function _getRewardOf(address _account) private view returns (uint256){
        require(
            userStateRecord[_account].stakedAmount != 0,
            "StakingVault: you never stake"
        );
        uint256 amount = 0;
        for (uint256 i = 0; i < userStateRecord[_account].stakeRecords.length; ++i) {
            RewardsRecord[] memory _rewardsRecord = userStateRecord[_account].stakeRecords[i].rewardsRecords;
            for (uint256 j = 0; j < _rewardsRecord.length; ++j) {
                amount += _rewardsRecord[j].rewardsAmount;
            }
        }
        return amount - userStateRecord[_account].rewardsWithdrawAmount;
    }

    // 获取收益总额
    function rewardOf(address _account) public view returns (uint256) {
        return userStateRecord[_account].rewardsAmount;
    }

    // 获取质押总量
    function totalStaked() public view returns (uint256) {
        return totalSupply;
    }



    /** 收益计算相关 */
    // 质押、提取本金、提取收益时更新相关数值
    // _type: 1-质押，2-提取本金，3-提取收益，4-Owner提取合约内Token
    function _updateRecord(address _account, uint256 _type, uint256 _amount) private {
        UserInfo memory userInfo = userStateRecord[_account];
        RewardsRecord[] memory _rewardsRecord;
        if (_type == 1) {
            // 质押
            userInfo.stakedAmount += _amount;
            userInfo.stakeRecords[userInfo.stakeRecords.length] = StakeRecord({
            stakeAmount : _amount,
            rewardsLastUpdatedTime : 0,
            rewardsRecords : _rewardsRecord,
            manageFee: 0,
            stakeTime: block.timestamp
            });
            totalSupply += _amount;
        } else if (_type == 2) {
            // 提取本金 TODO 减去管理费用
            require(
                userInfo.stakedAmount < _amount,
                "StakingVault: your balance is lower than staking amount"
            );
            userInfo.stakedAmount -= _amount;
            for (uint256 i = 0; i < userInfo.stakeRecords.length; ++i) {
                if (userInfo.stakeRecords[i].stakeAmount <= _amount) {
                    // 本次质押数额不足提取本金
                    _amount -= userInfo.stakeRecords[i].stakeAmount;
                    delete userInfo.stakeRecords[i];
                } else {
                    userInfo.stakeRecords[i].stakeAmount -= _amount;
                    _amount = 0;
                }
            }
            totalSupply -= _amount;
        } else if (_type == 3) {
            // 提取收益
            require(
                _getRewardsBalanceOf(_account) < _amount,
                "StakingVault: your balance is lower than staking rewards amount"
            );
            // 更新提取收益的总额
            userInfo.rewardsWithdrawAmount += _amount;
        } else if (_type == 4) {
            // 提取合约内代币
            totalSupply -= _amount;
        } else {
            require(
                false,
                "StakingVault: _type error"
            );
        }
    }


    /** 质押操作 */
    function stake(
        uint256 _amount
    ) public nonReentrant {
        require(_amount > 0, "StakingVault: amount must be greater than 0");

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        _updateRecord(msg.sender, 1, _amount);

        emit Staked(msg.sender, _amount);
    }


    /** 提取操作 */

    // 获取收益余额
    function _getRewardsBalanceOf(address _account) private view returns (uint256) {
        return userStateRecord[_account].rewardsAmount - userStateRecord[_account].rewardsWithdrawAmount;
    }

    // 质押用户提取
    function withdraw(
        uint256 _amount
    ) public nonReentrant {
        uint256 staked = userStateRecord[msg.sender].stakedAmount;
        require(
            _amount <= staked,
            "StakingVault: withdraw amount cannot be greater than staked amount"
        );
        require(staked > 0, "StakingVault: no tokens staked");

        stakingToken.safeTransferFrom(address(this), msg.sender, _amount);

        _updateRecord(msg.sender, 2, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    // 管理员提取
    function withdrawOwner(
        uint256 _amount
    ) public nonReentrant onlyOwner {
        require(_amount > 0, "StakingVault: _amount must be > 0");
        stakingToken.safeTransferFrom(address(this), msg.sender, _amount);
        _updateRecord(msg.sender, 4, _amount);
        emit WithdrawOwner(msg.sender, _amount);
    }



    /** 收益计算部分 */
    // TODO 计算收益，更新收益，接受外部调用
    function calculateReward(
        uint256 _amount,
        uint256 _from
    ) public view returns (uint256) {
        return ((_amount * (block.timestamp - _from)) * rewardRate) / 1e18;
    }

    /** 提取收益 */
    function claimReward(uint256 _amount) public nonReentrant {
        require(_amount >= 0, "StakingVault: claim amount must > 0");
        rewardsToken.safeTransferFrom(stakingBank, msg.sender, _amount);
        _updateRecord(msg.sender, 3, _amount);
        emit RewardClaimed(msg.sender, _amount);
    }

    /** 邀请人相关 */
    function setReferrer(address _referrer) public {
        require(
            userReferrer[msg.sender] != address(0),
            "StakingVault: already set referrer"
        );
        userReferrer[msg.sender] = _referrer;
        referrerUsers[_referrer][referrerUsers[_referrer].length] = msg.sender;
    }

    function getReferrer() public view  returns (address){
        return userReferrer[msg.sender];
    }
}
