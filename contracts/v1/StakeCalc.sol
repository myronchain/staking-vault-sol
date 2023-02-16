// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";
import "./stake_data.sol";

/**
* 质押计算合约，质押代币存储合约
*/
contract StakingVaultCalc is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Staked(address _from, uint256 _amount);
    event Withdraw(address _from, uint256 _amount);
    event WithdrawOwner(address _from, uint256 _amount);
    event RewardStakeClaimed(address _from, uint256 _amount);
    event RewardReferrerClaimed(address _from, uint256 _amount);

    StakingVaultData private svData;

    /** 构造函数 */
    constructor(address counterAddress) {
        // TEST
        svData = StakingVaultData(counterAddress);
    }

    // 质押、提取本金、提取收益时更新相关数值
    modifier _updateRecord(address _account, uint256 _type, uint256 _amount) {
        require(_account != address(0), "_account must not be zero address");
        require(_type > 0, "_type must > 0");
        require(_amount > 0, "amount must > 0");
        // _type: 1-质押，2-提取本金，3-提取质押收益，4-Owner提取合约内Token，5-提取推荐收益
        StakingVaultData.UserInfo memory userInfo = svData.getAddressUserInfo(_account);

        // RewardsRecord[] memory _rewardsRecord;
        if (_type == 1) {
            // 质押
            svData.setTotalStaked(svData.getTotalStaked()+ _amount);
            if(!userInfo.exsits){
                svData.pushUserStateRecordKeys(_account);
                userInfo.exsits = true;
            }

            // address => StakeRecordId => StakeRecord
            StakingVaultData.StakeRecord memory _stakeRecord ;
            _stakeRecord.stakeAmount = _amount;
            _stakeRecord.rewardsLastUpdatedTime = block.timestamp;
            _stakeRecord.manageFee = 0;
            _stakeRecord.stakeTime = block.timestamp;
            _stakeRecord.rewardsRecordSize = 0;
            svData.setAddressStakeRecord(_account,userInfo.stakeRecordSize,_stakeRecord);
            userInfo.stakeRecordSize ++;
            userInfo.stakeAmount += _amount;
        } else if (_type == 2) {
            // 提取本金
            require(
                userInfo.stakeAmount - userInfo.manageFeeAmount >= _amount,
                "your balance is lower than staking amount"
            );
            userInfo.stakeAmount -= _amount;
            for (uint256 i = 0; i < userInfo.stakeRecordSize; ++i) {
                StakingVaultData.StakeRecord memory _addressStakeRecord = svData.getAddressStakeRecord(_account,i);
                uint256 _balance = _addressStakeRecord.stakeAmount - _addressStakeRecord.manageFee;
                if (_balance <= 0){
                    continue;
                }
                if (_balance <= _amount) {
                    // 此质押数额不足提取本金
                    _amount -= _balance;
                    _addressStakeRecord.stakeAmount = 0;
                    userInfo.stakeRecordSize --;
                } else {
                    _addressStakeRecord.stakeAmount -= _amount;
                    _amount = 0;
                }
                svData.setAddressStakeRecord(_account,i,_addressStakeRecord) ;
            }

            svData.setTotalStaked(svData.getTotalStaked() - _amount);
        } else if (_type == 3) {
            // 提取质押收益
            require(
                _getRewardsBalance(_account) < _amount,
                "your balance is lower than staking rewards amount"
            );
            // 更新提取收益的总额
            userInfo.stakeRewardsWithdrawAmount += _amount;
        } else if (_type == 4) {
            // 提取合约内代币
            svData.setTotalStaked(svData.getTotalStaked() - _amount);
        } else if (_type == 5) {
            // 提取推荐收益
            require(
                userInfo.referrerRewardsAmount - userInfo.referrerRewardsWithdrawAmount > _amount,
                "your balance is lower than referrer rewards amount"
            );
            userInfo.referrerRewardsWithdrawAmount += _amount;
        } else {
            require(false, "_type error");
        }
        svData.setAddressUserInfo(_account,userInfo);
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // _transfer 用于主代币转出、Token转入转出
    function _transfer(IERC20 token, address _from, address _to, uint256 _value) private {
        require(
            _from != address(0) || _from != address(this),
            "from address can't be 0 when from is not this contract"
        );
        require(_to != address(0), "to address can't be 0");
        require(_value != 0, "value can't be 0");
        if (svData.getIsMainToken()) {
            // 主代币转出
            // Call returns a boolean value indicating success or failure.
            (bool sent,) = _to.call{value : _value}("");
            require(sent, "Failed to send Ether");
        } else {
            token.safeTransferFrom(_from, _to, _value);
        }
    }

    /** 质押相关 */
    // 收到主代币认为调用质押函数
    receive() external payable{
        mainTokenStake();
    }

    // 查看合约主代币金额
    function getMainTokenBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // 主代币转账
    function mainTokenStake() public payable nonReentrant _updateRecord(msg.sender, 1, msg.value) {
        require(msg.value > 0, "amount must > 0");
        emit Staked(msg.sender, msg.value);
    }

    // 质押
    function tokenStake(
        uint256 _amount
    ) public nonReentrant _updateRecord(msg.sender, 1, _amount) {
        require(_amount > 0, "amount must >  0");
        _transfer(svData.getStakingToken(), msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    // ✅ 获取总质押人数和总质押金额
    function getStakeNum(uint256 startTime, uint256 endTime) public view returns(uint256, uint256) {
        uint256 count = 0;
        uint256 sum = 0;
        for(uint256 i=0;i<svData.getUserStateRecordKeysSize();++i){
            uint256 _stakeRecordsSize = svData.getAddressUserInfo(svData.getUserStateRecordKeys(i)).stakeRecordSize;
            bool addedCount = false;
            for(uint256 j=0;j<_stakeRecordsSize;++j){
                if (svData.getAddressStakeRecord(svData.getUserStateRecordKeys(i),j).stakeTime >= startTime &&  svData.getAddressStakeRecord(svData.getUserStateRecordKeys(i),j).stakeTime <= endTime) {
                    if (!addedCount){
                        count ++;
                        addedCount = true;
                    }
                    sum +=svData.getAddressStakeRecord(svData.getUserStateRecordKeys(i),j).stakeAmount;
                }
            }
        }
        return (count,sum);
    }

    // 获取用户质押总额
    function stakedOf(address _account) public view returns (uint256) {
        return svData.getAddressUserInfo(_account).stakeAmount;
    }

    // 获取质押余额，减去管理费部分的余额
    function getStakeBalance(address _account) public view returns (uint256) {
        return svData.getAddressUserInfo(_account).stakeAmount - svData.getAddressUserInfo(_account).manageFeeAmount;
    }

    /** 提取相关 */
    // ✅ 提取本金
    function withdrawStake(
        uint256 _amount
    ) public nonReentrant _updateRecord(msg.sender, 2, _amount) {
        _transfer(svData.getStakingToken(), address(this), msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    // 提取质押收益
    function claimStakeReward(uint256 _amount) public nonReentrant _updateRecord(msg.sender, 3, _amount) {
        _transfer(svData.getRewardsToken(), svData.getStakingBank(), msg.sender, _amount);
        emit RewardStakeClaimed(msg.sender, _amount);
    }

    // 提取奖励收益
    function claimReferrerReward(uint256 _amount) public nonReentrant _updateRecord(msg.sender, 5, _amount) {
        _transfer(svData.getRewardsToken(), svData.getStakingBank(), msg.sender, _amount);
        emit RewardReferrerClaimed(msg.sender, _amount);
    }

    // 提取本金+收益
    function claimAllReward(address _account) public nonReentrant  {
        // 提取本金
        uint256 _amount1 = svData.getAddressUserInfo(_account).stakeAmount - svData.getAddressUserInfo(_account).manageFeeAmount;
        if (_amount1 > 0){
            _updateRecordHelper(2,_amount1);
            _transfer(svData.getStakingToken(), svData.getStakingBank(), msg.sender, _amount1);
            emit Withdraw(msg.sender, _amount1);
        }
        // 提取收益奖励
        uint256 _amount2 = svData.getAddressUserInfo(_account).stakeRewardsAmount - svData.getAddressUserInfo(_account).stakeRewardsWithdrawAmount;
        if (_amount2 > 0){
            _updateRecordHelper(3,_amount2);
            _transfer(svData.getRewardsToken(), svData.getStakingBank(), msg.sender, _amount2);
            emit RewardStakeClaimed(msg.sender, _amount2);
        }
        // 提取推荐奖励
        uint256 _amount3 = svData.getAddressUserInfo(_account).referrerRewardsAmount - svData.getAddressUserInfo(_account).referrerRewardsWithdrawAmount;
        if (_amount3 > 0){
            _updateRecordHelper(5,_amount3);
            _transfer(svData.getRewardsToken(), svData.getStakingBank(), msg.sender, _amount3);
            emit RewardReferrerClaimed(msg.sender, _amount3);
        }
    }

    // _updateRecord辅助函数
    function _updateRecordHelper(uint256 _amount, uint256 _type) _updateRecord(msg.sender, _type, _amount) private  {    }

    // Owner提取代币
    function withdrawOwner(
        uint256 _amount
    ) public nonReentrant onlyOwner _updateRecord(msg.sender, 4, _amount) {
        _transfer(svData.getStakingToken(), address(this), msg.sender, _amount);
        emit WithdrawOwner(msg.sender, _amount);
    }

    // 计算收益，更新收益，接受外部调用
    function calculateReward() public {
        for(uint256 i=0;i<svData.getUserStateRecordKeysSize();++i){
            // 增加的用户质押奖励总额
            uint256 _addStakeRewardsAmount = 0;
            StakingVaultData.UserInfo memory userInfo = svData.getAddressUserInfo(svData.getUserStateRecordKeys(i));
            for(uint256 j=0;j<userInfo.stakeRecordSize;++j){
                // 更新质押奖励
                StakingVaultData.StakeRecord memory _stakeRecords = svData.getAddressStakeRecord(svData.getUserStateRecordKeys(i),j);
                if (_stakeRecords.stakeAmount == 0){
                    continue;
                }
                if (block.timestamp >= svData.getStakeRewardsStartTime() + _stakeRecords.rewardsLastUpdatedTime) {
                    _stakeRecords.rewardsLastUpdatedTime = block.timestamp;
                    uint256 _rewardAmount = _stakeRecords.stakeAmount * svData.getRewardRate() / 1e4;
                    // TODO 新增质押奖励历史记录 address => StakeRecordId => RewardsRecordId => RewardsRecord 关联StakeRecord和RewardsRecord
                    StakingVaultData.RewardsRecord memory _rewardsRecord = svData.getStakeRecordRewardsRecord(svData.getUserStateRecordKeys(i),j, _stakeRecords.rewardsRecordSize);
                    _rewardsRecord.stakeAmount = _stakeRecords.stakeAmount;
                    _rewardsRecord.rewardsAmount = _rewardAmount;
                    _rewardsRecord.lastCalcTime = block.timestamp;
                    _addStakeRewardsAmount += _rewardAmount;
                    svData.setStakeRecordRewardsRecord(svData.getUserStateRecordKeys(i),j, _stakeRecords.rewardsRecordSize,_rewardsRecord);
                }
                svData.setAddressStakeRecord(svData.getUserStateRecordKeys(i),j,_stakeRecords);
            }
            svData.setAddressUserInfo(svData.getUserStateRecordKeys(i),userInfo);
        }
    }

    // 更新管理费用，然后将邀请奖励费用transfer给推荐人
    function calculateManageFee() public {
        for(uint256 i=0;i<svData.getUserStateRecordKeysSize();++i){
            // 增加的用户管理费总额
            uint256 _addManangeAmount = 0;
            // 增加的用户邀请奖励总额
            uint256 _addReferrerRewardsAmount = 0;
            StakingVaultData.UserInfo memory userInfo = svData.getAddressUserInfo(svData.getUserStateRecordKeys(i));
            for(uint256 j=0;j<userInfo.stakeRecordSize;++j){
                StakingVaultData.StakeRecord memory _stakeRecords = svData.getAddressStakeRecord(svData.getUserStateRecordKeys(i),j);
                // 更新质押管理费
                if(_stakeRecords.manageFee == 0 && block.timestamp >= svData.getManageFeeStartTime() +_stakeRecords.stakeTime){
                    _stakeRecords.manageFee = svData.getManageFeeRate()  * _stakeRecords.stakeAmount / 1e4;
                    _addManangeAmount += _stakeRecords.manageFee;
                    // 更新邀请奖励
                    _addReferrerRewardsAmount+=svData.getRewardRate() * _stakeRecords.stakeAmount / 1e4;
                }
                svData.setAddressStakeRecord(svData.getUserStateRecordKeys(i),j,_stakeRecords);
            }
            // 更新推荐人的推荐奖励
            userInfo.referrerRewardsAmount += _addReferrerRewardsAmount;
            svData.setAddressUserInfo(svData.getUserStateRecordKeys(i),userInfo);
        }
    }

    // 获取指定人的收益历史总额
    function getRewardCount(address _account) public view returns (uint256) {
        return svData.getAddressUserInfo(_account).stakeRewardsAmount;
    }

    // 获取收益余额
    function _getRewardsBalance(address _account) private view returns (uint256) {
        return svData.getAddressUserInfo(_account).stakeRewardsAmount - svData.getAddressUserInfo(_account).stakeRewardsWithdrawAmount;
    }

    function getRewardsBalance(address _account) public view returns (uint256) {
        return _getRewardsBalance(_account);
    }

    // 获取指定人邀请收益历史总额
    function getReferrerRewardCount(address _account) public view returns (uint256) {
        return svData.getAddressUserInfo(_account).referrerRewardsAmount;
    }

    // 获取指定人邀请收益余额
    function getReferrerRewardsBalance(address _account) public view returns (uint256) {
        return svData.getAddressUserInfo(_account).referrerRewardsAmount - svData.getAddressUserInfo(_account).referrerRewardsWithdrawAmount;
    }


    /** 邀请人相关 */
    function setReferrer(address _referrer) public {
        require(svData.getUserReferrer(msg.sender) != address(0), "Already set referrer");
        svData.setUserReferrer(msg.sender, _referrer);
        svData.pushReferrerUsers(_referrer,msg.sender);
    }

}
