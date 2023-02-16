// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";
/**
* 质押合约 TODO 为了测试现在开放了字段的public
*/
contract StakingVault is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Staked(address _from, uint256 _amount);
    event Withdraw(address _from, uint256 _amount);
    event WithdrawOwner(address _from, uint256 _amount);
    event RewardStakeClaimed(address _from, uint256 _amount);
    event RewardReferrerClaimed(address _from, uint256 _amount);

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
        // 质押奖励历史记录index, rewardsRecords value的size
        uint256 rewardsRecordSize;
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
        bool exsits;
        // 质押总额，不扣除管理费
        uint256 stakeAmount;
        // 管理费总额
        uint256 manageFeeAmount;
        // 用户质押奖励总额
        uint256 stakeRewardsAmount;
        // 用户质押奖励提取总额
        uint256 stakeRewardsWithdrawAmount;
        // 用户邀请奖励（指定时间链下调用合约更新，与质押管理费一起刷新）
        uint256 referrerRewardsAmount;
        // 用户邀请奖励提取总额
        uint256 referrerRewardsWithdrawAmount;
        // 所有质押记录Size, rewardsRecords的value的size
        uint256 stakeRecordSize;
    }

    // Whether it is a main token staking(e.g. BNB)
    bool private isMainToken;

    address private stakingBank;
    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    // Reward rate per second per token staked 万分之N
    uint256 private rewardRate;

    // 管理费率 万分之N
    uint256 private manageFeeRate;

    // 推荐收益 万分之N
    uint256 private referrRate;

    // Total amount of tokens staked
    uint256 private totalSupply;

    // The minimum staking period to start calculating the earnings
    uint256 private stakingTime;

    // 质押收益开始计算时间
    uint256 private stakeRewardsStartTime;
    // 开始计算管理费时间
    uint256 private manageFeeStartTime;


    // TODO 所有质押记录 address => StakeRecordId => StakeRecord  关联address和StakeRecord public
    mapping(address => mapping(uint256 => StakeRecord)) public addressStakeRecord;

    // TODO 质押奖励历史记录 StakeRecordId => RewardsRecordId => RewardsRecord 关联StakeRecord和RewardsRecord
    mapping(uint256 => mapping(uint256 => RewardsRecord)) public stakeRecordRewardsRecord;

    // Mapping of staked record
    mapping(address => UserInfo) public addressUserInfo;

    address[] public userStateRecordKeys;

    // Mapping of the referrer(value) of user(key)
    mapping(address => address) private userReferrer;
    // Mapping of the users(value) of referrer(key)
    mapping(address => address[]) private referrerUsers;


    /** 构造函数 */
    constructor(
    // bool _isMainToken,
    // address _stakingToken,
    // address _stakingBank,
    // uint256 _rewardRate
    ) {
        // TEST
        bool _isMainToken = true;
        address _stakingToken = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        address _stakingBank = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        uint256 _rewardRate = 1;
        stakeRewardsStartTime = 3600 * 24 * 30;
        manageFeeStartTime = 3600 * 24 * 1;
        require(
            !isMainToken && _stakingToken != address(0),
            "StakingVault: it's not a main token stake. staking token address cannot be 0"
        );
        require(!isMainToken && _stakingBank != address(0), "StakingVault: staking bank address cannot be 0");
        require(_rewardRate > 0, "StakingVault: reward rate must be greater than 0");

        isMainToken = _isMainToken;
        stakingBank = _stakingBank;
        if (_isMainToken) {
            stakingToken = IERC20(_stakingToken);
        }
        rewardsToken = IERC20(_stakingToken);
        rewardRate = _rewardRate;
    }

    // 质押、提取本金、提取收益时更新相关数值
    modifier _updateRecord(address _account, uint256 _type, uint256 _amount) {
        require(_account != address(0), "StakingVault: _account must not be zero address");
        require(_type > 0, "StakingVault: _type must > 0");
        require(_amount > 0, "StakingVault: amount must > 0");
        // _type: 1-质押，2-提取本金，3-提取质押收益，4-Owner提取合约内Token，5-提取推荐收益
        UserInfo storage userInfo = addressUserInfo[_account];
        // RewardsRecord[] memory _rewardsRecord;
        if (_type == 1) {
            // 质押
            totalSupply += _amount;

            if(!userInfo.exsits){
                userStateRecordKeys.push(_account);
                userInfo.exsits = true;
            }

            // address => StakeRecordId => StakeRecord
            StakeRecord storage _stakeRecord = addressStakeRecord[_account][userInfo.stakeRecordSize];
            _stakeRecord.stakeAmount = _amount;
            _stakeRecord.rewardsLastUpdatedTime = block.timestamp;
            _stakeRecord.manageFee = 0;
            _stakeRecord.stakeTime = block.timestamp;
            _stakeRecord.rewardsRecordSize = 0;

            userInfo.stakeRecordSize ++;
            userInfo.stakeAmount += _amount;
        } else if (_type == 2) {
            // 提取本金
            require(
                userInfo.stakeAmount - userInfo.manageFeeAmount >= _amount,
                "StakingVault: your balance is lower than staking amount"
            );
            userInfo.stakeAmount -= _amount;
            for (uint256 i = 0; i < userInfo.stakeRecordSize; ++i) {
                uint256 _balance = addressStakeRecord[_account][i].stakeAmount - addressStakeRecord[_account][i].manageFee;
                if (_balance <= 0){
                    continue;
                }
                if (_balance <= _amount) {
                    // 此质押数额不足提取本金
                    _amount -= _balance;
                    delete addressStakeRecord[_account][i];
                    userInfo.stakeRecordSize --;
                } else {
                    addressStakeRecord[_account][i].stakeAmount -= _amount;
                    _amount = 0;
                }
            }
            totalSupply -= _amount;
        } else if (_type == 3) {
            // 提取质押收益
            require(
                _getRewardsBalance(_account) < _amount,
                "StakingVault: your balance is lower than staking rewards amount"
            );
            // 更新提取收益的总额
            userInfo.stakeRewardsWithdrawAmount += _amount;
        } else if (_type == 4) {
            // 提取合约内代币
            totalSupply -= _amount;
        } else if (_type == 5) {
            // 提取推荐收益
            require(
                userInfo.referrerRewardsAmount - userInfo.referrerRewardsWithdrawAmount > _amount,
                "StakingVault: your balance is lower than referrer rewards amount"
            );
            userInfo.referrerRewardsWithdrawAmount += _amount;
        } else {
            require(false, "StakingVault: _type error");
        }
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
            "StakingVault: from address can't be 0 when from is not this contract"
        );
        require(_to != address(0), "StakingVault: to address can't be 0");
        require(_value != 0, "StakingVault: value can't be 0");
        if (isMainToken) {
            // 主代币转出
            // Call returns a boolean value indicating success or failure.
            (bool sent,) = _to.call{value : _value}("");
            require(sent, "StakingVault: Failed to send Ether");
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
        require(msg.value > 0, "StakingVault: amount must be greater than 0");
        emit Staked(msg.sender, msg.value);
    }

    // 质押
    function tokenStake(
        uint256 _amount
    ) public nonReentrant _updateRecord(msg.sender, 1, _amount) {
        require(_amount > 0, "StakingVault: amount must be greater than 0");
        _transfer(stakingToken, msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function setStakingBank(address _stakingBank) public onlyOwner {
        require(_stakingBank != address(0), "StakingVault: staking bank address cannot be 0");
        stakingBank = _stakingBank;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        require(_rewardRate != 0, "StakingVault: staking rewad rate cannot be 0");
        rewardRate = _rewardRate;
    }

    function setStakingTime(uint256 _stakingTime) public onlyOwner {
        require(_stakingTime != 0, "StakingVault: staking time cannot be 0");
        stakingTime = _stakingTime;
    }

    function setManageFeeRate(uint256 _manageFeeRate) public onlyOwner {
        require(_manageFeeRate != 0, "StakingVault: manage fee rate cannot be 0");
        manageFeeRate = _manageFeeRate;
    }

    function setReferrRate(uint256 _referrRate) public onlyOwner {
        require(_referrRate != 0, "StakingVault: referr rate cannot be 0");
        referrRate = _referrRate;
    }

    // 获取质押总量
    function totalStaked() public view returns (uint256) {
        return totalSupply;
    }

    // ✅ 获取总质押人数和总质押金额
    function getStakeNum(uint256 startTime, uint256 endTime) public view returns(uint256, uint256) {
        uint256 count = 0;
        uint256 sum = 0;
        for(uint256 i=0;i<userStateRecordKeys.length;++i){
            uint256 _stakeRecordsSize = addressUserInfo[userStateRecordKeys[i]].stakeRecordSize;
            bool addedCount = false;
            for(uint256 j=0;j<_stakeRecordsSize;++j){
                if (addressStakeRecord[userStateRecordKeys[i]][j].stakeTime >= startTime &&  addressStakeRecord[userStateRecordKeys[i]][j].stakeTime <= endTime) {
                    if (!addedCount){
                        count ++;
                        addedCount = true;
                    }
                    sum +=addressStakeRecord[userStateRecordKeys[i]][j].stakeAmount;
                }
            }
        }
        return (count,sum);
    }

    // 获取用户质押总额
    function stakedOf(address _account) public view returns (uint256) {
        return addressUserInfo[_account].stakeAmount;
    }

    // 获取质押余额，减去管理费部分的余额
    function getStakeBalance(address _account) public view returns (uint256) {
        return addressUserInfo[_account].stakeAmount - addressUserInfo[_account].manageFeeAmount;
    }

    /** 提取相关 */
    // ✅ 提取本金
    function withdrawStake(
        uint256 _amount
    ) public nonReentrant _updateRecord(msg.sender, 2, _amount) {
        _transfer(stakingToken, address(this), msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    // 提取质押收益
    function claimStakeReward(uint256 _amount) public nonReentrant _updateRecord(msg.sender, 3, _amount) {
        require(_amount >= 0, "StakingVault: claim amount must > 0");
        _transfer(rewardsToken, stakingBank, msg.sender, _amount);
        emit RewardStakeClaimed(msg.sender, _amount);
    }

    // 提取质押收益
    function claimReferrerReward(uint256 _amount) public nonReentrant _updateRecord(msg.sender, 5, _amount) {
        require(_amount >= 0, "StakingVault: claim amount must > 0");
        _transfer(rewardsToken, stakingBank, msg.sender, _amount);
        emit RewardReferrerClaimed(msg.sender, _amount);
    }

    // 提取本金+收益
    function claimAllReward(address _account) public nonReentrant  {
        // 提取本金
        uint256 _amount1 = addressUserInfo[_account].stakeAmount - addressUserInfo[_account].manageFeeAmount;
        if (_amount1 > 0){
            _updateRecordHelper(2,_amount1);
            _transfer(stakingToken, stakingBank, msg.sender, _amount1);
            emit Withdraw(msg.sender, _amount1);
        }
        // 提取收益奖励
        uint256 _amount2 = addressUserInfo[_account].stakeRewardsAmount - addressUserInfo[_account].stakeRewardsWithdrawAmount;
        if (_amount2 > 0){
            _updateRecordHelper(3,_amount2);
            _transfer(rewardsToken, stakingBank, msg.sender, _amount2);
            emit RewardStakeClaimed(msg.sender, _amount2);
        }
        // 提取推荐奖励
        uint256 _amount3 = addressUserInfo[_account].referrerRewardsAmount - addressUserInfo[_account].referrerRewardsWithdrawAmount;
        if (_amount3 > 0){
            _updateRecordHelper(5,_amount3);
            _transfer(rewardsToken, stakingBank, msg.sender, _amount3);
            emit RewardReferrerClaimed(msg.sender, _amount3);
        }
    }

    // _updateRecord辅助函数
    function _updateRecordHelper(uint256 _amount, uint256 _type) _updateRecord(msg.sender, _type, _amount) private  {    }

    // Owner提取代币
    function withdrawOwner(
        uint256 _amount
    ) public nonReentrant onlyOwner _updateRecord(msg.sender, 4, _amount) {
        require(_amount > 0, "StakingVault: _amount must be > 0");
        _transfer(stakingToken, address(this), msg.sender, _amount);
        emit WithdrawOwner(msg.sender, _amount);
    }

    // 计算收益，更新收益，接受外部调用
    function calculateReward() public {
        // for(uint256 i=0;i<userStateRecordKeys.length;++i){
        //     // 增加的用户质押奖励总额
        //     uint256 _addStakeRewardsAmount = 0;
        //     StakeRecord[] storage _stakeRecords = userStateRecord[userStateRecordKeys[i]].stakeRecords;
        //     for(uint256 j=0;j<_stakeRecords.length;++j){
        //         // 更新质押奖励
        //         if (block.timestamp >= stakeRewardsStartTime + _stakeRecords[j].rewardsLastUpdatedTime) {
        //             _stakeRecords[j].rewardsLastUpdatedTime = block.timestamp;
        //             uint256 _rewardAmount = _stakeRecords[j].stakeAmount * rewardRate / 1e4;
        //             _stakeRecords[j].rewardsRecords.push(RewardsRecord({
        //             stakeAmount:  _stakeRecords[j].stakeAmount,
        //             rewardsAmount: _rewardAmount,
        //             lastCalcTime: block.timestamp
        //             }));
        //             _addStakeRewardsAmount += _rewardAmount;
        //         }
        //     }
        // }
    }

    // 更新管理费用，然后将邀请奖励费用transfer给推荐人
    function calculateManageFee() public {
        // for(uint256 i=0;i<userStateRecordKeys.length;++i){
        //     // 增加的用户管理费总额
        //     uint256 _addManangeAmount = 0;
        //     // 增加的用户邀请奖励总额
        //     uint256 _addReferrerRewardsAmount = 0;
        //     StakeRecord[] storage _stakeRecords = userStateRecord[userStateRecordKeys[i]].stakeRecords;
        //     for(uint256 j=0;j<_stakeRecords.length;++j){
        //         // 更新质押管理费
        //         if(_stakeRecords[j].manageFee == 0 && block.timestamp >= manageFeeStartTime +_stakeRecords[j].stakeTime){
        //             _stakeRecords[j].manageFee = manageFeeRate  * _stakeRecords[j].stakeAmount / 1e4;
        //             _addManangeAmount += _stakeRecords[j].manageFee;
        //             // 更新邀请奖励
        //             _addReferrerRewardsAmount+=referrRate * _stakeRecords[j].stakeAmount / 1e4;
        //         }
        //     }
        //     // 更新推荐人的推荐奖励
        //     userStateRecord[userReferrer[userStateRecordKeys[i]]].referrerRewardsAmount += _addReferrerRewardsAmount;
        // }
    }

    // 获取指定人的收益历史总额
    function getRewardCount(address _account) public view returns (uint256) {
        return addressUserInfo[_account].stakeRewardsAmount;
    }

    // 获取收益余额
    function _getRewardsBalance(address _account) private view returns (uint256) {
        return addressUserInfo[_account].stakeRewardsAmount - addressUserInfo[_account].stakeRewardsWithdrawAmount;
    }

    function getRewardsBalance(address _account) public view returns (uint256) {
        return _getRewardsBalance(_account);
    }

    // 获取指定人邀请收益历史总额
    function getReferrerRewardCount(address _account) public view returns (uint256) {
        return addressUserInfo[_account].referrerRewardsAmount;
    }

    function _getReferrerRewardsBalance(address _account) private view returns (uint256) {
        return addressUserInfo[_account].referrerRewardsAmount - addressUserInfo[_account].referrerRewardsWithdrawAmount;
    }

    // 获取指定人邀请收益余额
    function getReferrerRewardsBalance(address _account) public view returns (uint256) {
        return _getReferrerRewardsBalance(_account);
    }


    /** 邀请人相关 */
    function setReferrer(address _referrer) public {
        require(userReferrer[msg.sender] != address(0), "StakingVault: already set referrer");
        userReferrer[msg.sender] = _referrer;
        referrerUsers[_referrer].push(msg.sender);
    }

    function getReferrer() public view  returns (address){
        return userReferrer[msg.sender];
    }

    /** --- */

    /** TEST */
    function getlen() public view returns (uint256) {
        return userStateRecordKeys.length;
    }


    function setA(address a) public {
        userStateRecordKeys.push(a);
    }

    function nowTime() public view returns (uint256) {
        return block.timestamp;
    }

    function getuserStateRecord(address _address) public returns(UserInfo memory ) {
        UserInfo memory tmp =  addressUserInfo[_address];
        return tmp;
    }

    struct A {
        uint256 a1;
        uint256 bSize;
    }

    struct B {
        uint256 b1;
    }

    A[] public t;


    mapping(uint256 => B) tmp;

    function getArrTest() public{
        t.push(A({a1:0,bSize:0}));
        A storage a = t[t.length];
        a.a1 = t.length;
        a.bSize ++;
    }

}
