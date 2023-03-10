// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//import "hardhat/console.sol";
import "./StakeData.sol";

/**
* 质押计算合约，质押代币存储合约
*/
contract Withdraw is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event WithdrawStake(address _from, uint256 _amount);
    event WithdrawOwner(address _from, uint256 _amount);
    event RewardStakeClaimed(address _from, uint256 _amount);
    event RewardReferrerClaimed(address _from, uint256 _amount);

    StakeData private svData;

    /** 构造函数 */
    constructor(address _stakeDataAddress) {
        svData = StakeData(_stakeDataAddress);
    }

    receive() external payable {
    }

    // 质押、提取本金、提取收益时更新相关数值
    modifier _updateRecord(address _account, uint256 _type, uint256 _amount) {
        require(_account != address(0), "_account must not be zero address");
        require(_type > 0, "_type must > 0");
        require(_amount > 0, "amount must > 0");
        // _type: 1-质押，2-提取本金，3-提取质押收益，4-Owner提取合约内Token，5-提取邀请收益
        StakeData.UserInfo memory userInfo = svData.getAddressUserInfo(_account);

        if (_type == 1) {
            // 质押
        } else if (_type == 2) {
            // 提取本金
            require(
                userInfo.stakeAmount - userInfo.manageFeeAmount >= _amount,
                "your balance is lower than staking amount"
            );
            userInfo.stakeAmount -= _amount;
            for (uint256 i = 0; i < userInfo.stakeRecordSize; ++i) {
                StakeData.StakeRecord memory _addressStakeRecord = svData.getAddressStakeRecord(_account, i);
                uint256 _balance = _addressStakeRecord.stakeAmount - _addressStakeRecord.manageFee;
                if (_balance <= 0) {
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
                svData.setAddressStakeRecord(_account, i, _addressStakeRecord);
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
            // 提取邀请收益
            require(
                userInfo.referrerRewardsAmount - userInfo.referrerRewardsWithdrawAmount > _amount,
                "your balance is lower than referrer rewards amount"
            );
            userInfo.referrerRewardsWithdrawAmount += _amount;
        } else {
            require(false, "_type error");
        }
        svData.setAddressUserInfo(_account, userInfo);
        _;
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

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // 查看合约主代币金额
    function getMainTokenBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /** 提取相关 */
    // 提取本金
    function withdrawStake(
        uint256 _amount
    ) public nonReentrant _updateRecord(msg.sender, 2, _amount) {
        _transfer(svData.getStakingToken(), svData.getStakingBank(), msg.sender, _amount);
        emit WithdrawStake(msg.sender, _amount);
    }

    // 提取质押收益
    function claimStakeReward(uint256 _amount) public nonReentrant _updateRecord(msg.sender, 3, _amount) {
        _transfer(svData.getRewardsToken(), svData.getStakingBank(), msg.sender, _amount);
        emit RewardStakeClaimed(msg.sender, _amount);
    }

    // 提取邀请奖励收益
    function claimReferrerReward(uint256 _amount) public nonReentrant _updateRecord(msg.sender, 5, _amount) {
        _transfer(svData.getRewardsToken(), svData.getStakingBank(), msg.sender, _amount);
        emit RewardReferrerClaimed(msg.sender, _amount);
    }

    // 提取本金+质押收益+邀请奖励
    function claimAllReward() public nonReentrant {
        // 提取本金
        uint256 _amount1 = svData.getAddressUserInfo(msg.sender).stakeAmount - svData.getAddressUserInfo(msg.sender).manageFeeAmount;
        if (_amount1 > 0) {
            _updateRecordHelper(2, _amount1);
            _transfer(svData.getStakingToken(), svData.getStakingBank(), msg.sender, _amount1);
            emit WithdrawStake(msg.sender, _amount1);
        }
        // 提取收益奖励
        uint256 _amount2 = svData.getAddressUserInfo(msg.sender).stakeRewardsAmount - svData.getAddressUserInfo(msg.sender).stakeRewardsWithdrawAmount;
        if (_amount2 > 0) {
            _updateRecordHelper(3, _amount2);
            _transfer(svData.getRewardsToken(), svData.getStakingBank(), msg.sender, _amount2);
            emit RewardStakeClaimed(msg.sender, _amount2);
        }
        // 提取邀请奖励
        uint256 _amount3 = svData.getAddressUserInfo(msg.sender).referrerRewardsAmount - svData.getAddressUserInfo(msg.sender).referrerRewardsWithdrawAmount;
        if (_amount3 > 0) {
            _updateRecordHelper(5, _amount3);
            _transfer(svData.getRewardsToken(), svData.getStakingBank(), msg.sender, _amount3);
            emit RewardReferrerClaimed(msg.sender, _amount3);
        }
    }

    // 将所有人的邀请奖励费用发送给给对应的邀请人
    function sendAllReferrerRewards() public onlyOwner {
        for (uint256 i = 0; i < svData.getStateRecordAddressKeysSize(); ++i) {
            address _account = svData.getStateRecordAddressKeys(i);
            // 提取邀请奖励
            uint256 _amount = svData.getAddressUserInfo(_account).referrerRewardsAmount - svData.getAddressUserInfo(_account).referrerRewardsWithdrawAmount;
            if (_amount > 0) {
                _updateRecordHelper(5, _amount);
                _transfer(svData.getRewardsToken(), svData.getStakingBank(), svData.getUserReferrer(_account), _amount);
                emit RewardReferrerClaimed(msg.sender, _amount);
            }
        }
    }

    // _updateRecord辅助函数
    function _updateRecordHelper(uint256 _type, uint256 _amount) _updateRecord(msg.sender, _type, _amount) private {}

    // Owner提取代币
    function withdrawOwner(
        uint256 _amount
    ) public nonReentrant onlyOwner _updateRecord(msg.sender, 4, _amount) {
        _transfer(svData.getStakingToken(), address(this), msg.sender, _amount);
        emit WithdrawOwner(msg.sender, _amount);
    }

    // 获取收益余额
    function _getRewardsBalance(address _account) private view returns (uint256) {
        return svData.getAddressUserInfo(_account).stakeRewardsAmount - svData.getAddressUserInfo(_account).stakeRewardsWithdrawAmount;
    }

}
