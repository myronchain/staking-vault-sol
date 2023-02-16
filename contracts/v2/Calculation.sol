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
contract Calculation is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Staked(address _from, uint256 _amount);
    event Withdraw(address _from, uint256 _amount);
    event WithdrawOwner(address _from, uint256 _amount);
    event RewardStakeClaimed(address _from, uint256 _amount);
    event RewardReferrerClaimed(address _from, uint256 _amount);

    StakingVaultData private svData;

    /** 构造函数 */
    constructor(address counterAddress) {
        svData = StakingVaultData(counterAddress);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
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

}
