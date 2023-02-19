// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

/**
* 质押数据存储合约
*/
contract StakeData is Ownable, Pausable {
    using SafeERC20 for IERC20;

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

    // 是否是主代币
    bool private isMainToken;

    address private stakingBank;
    IERC20 private rewardsToken;
    IERC20 private stakingToken;

    // 质押奖励收益 1e8
    uint256 private rewardRate;

    // 管理费率 1e8
    uint256 private manageFeeRate;

    // 邀请收益 1e8
    uint256 private referrerRate;

    // 质押总量
    uint256 private totalStaked;

    // 质押收益开始计算时间
    uint256 private stakeRewardsStartTime;
    // 开始计算管理费时间
    uint256 private manageFeeStartTime;


    // 所有质押记录 address => StakeRecordId => StakeRecord  关联address和StakeRecord public
    mapping(address => mapping(uint256 => StakeRecord)) private addressStakeRecord;

    // 质押奖励历史记录 address => StakeRecordId => RewardsRecordId => RewardsRecord 关联StakeRecord和RewardsRecord
    mapping(address => mapping(uint256 => mapping(uint256 => RewardsRecord))) private stakeRecordRewardsRecord;

    // 用户地址和用户信息的映射关系
    mapping(address => UserInfo) private addressUserInfo;

    // 保存所有质押过的用户地址
    address[] private stateRecordAddressKeys;

    // Mapping of the referrer(value) of user(key)
    mapping(address => address) private userReferrer;
    // Mapping of the users(value) of referrer(key)
    mapping(address => address[]) private referrerUsers;

    // 允许调用此合约Get的地址
    mapping(address => bool) callGetContract;
    // 允许调用此合约Set的地址
    mapping(address => bool) callSetContract;


    /** 构造函数 */
    constructor(
        bool _isMainToken,
        address _stakingToken,
        address _stakingBank,
        address _rewardsToken,
        uint256 _rewardRate,
        uint256 _stakeRewardsStartTime,
        uint256 _manageFeeStartTime,
        uint256 _manageFeeRate
    ) {
        require(!isMainToken && _stakingToken != address(0), "staking token address cannot be 0");
        require(!isMainToken && _stakingBank != address(0), "staking bank address cannot be 0");
        require(_rewardRate > 0, "reward rate must be greater than 0");

        isMainToken = _isMainToken;
        stakingBank = _stakingBank;
        if (_isMainToken) {
            stakingToken = IERC20(_stakingToken);
        }
        rewardsToken = IERC20(_rewardsToken);
        rewardRate = _rewardRate;
        stakeRewardsStartTime = _stakeRewardsStartTime;
        manageFeeStartTime = _manageFeeStartTime;
        manageFeeRate = _manageFeeRate;
    }

    modifier _callGet {
        require(callGetContract[msg.sender] || msg.sender == owner(), "you can't call get function");
        _;
    }

    modifier _callSet {
        require(callSetContract[msg.sender] || msg.sender == owner(), "you can't call get function");
        _;
    }

    function getIsMainToken() view public _callGet returns (bool)  {
        return isMainToken;
    }

    function setIsMainToken(bool _isMainToken) public onlyOwner {
        isMainToken = _isMainToken;
    }

    function setStakingBank(address _stakingBank) public onlyOwner {
        require(_stakingBank != address(0), "staking bank address cannot be 0");
        stakingBank = _stakingBank;
    }

    function getStakingBank() view public _callGet returns (address) {
        return stakingBank;
    }

    function setRewardsToken(address _rewardsToken) public onlyOwner {
        rewardsToken = IERC20(_rewardsToken);
    }

    function getRewardsToken() view public _callGet returns (IERC20) {
        return IERC20(rewardsToken);
    }

    function setStakingToken(address _stakingToken) public onlyOwner {
        require(_stakingToken != address(0), "staking bank address cannot be 0");
        stakingToken = IERC20(_stakingToken);
    }

    function getStakingToken() view public _callGet returns (IERC20) {
        return stakingToken;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        require(_rewardRate != 0, "staking rewad rate cannot be 0");
        rewardRate = _rewardRate;
    }

    function getRewardRate() view public _callGet returns (uint256) {
        return rewardRate;
    }

    function setManageFeeRate(uint256 _manageFeeRate) public onlyOwner {
        require(_manageFeeRate != 0, "manage fee rate cannot be 0");
        manageFeeRate = _manageFeeRate;
    }

    function getManageFeeRate() view public _callGet returns (uint256) {
        return manageFeeRate;
    }

    function setReferrerRate(uint256 _referrerRate) public _callSet {
        require(_referrerRate != 0, "referrer rate cannot be 0");
        referrerRate = _referrerRate;
    }

    function getReferrerRate() view public _callGet returns (uint256) {
        return referrerRate;
    }

    function setTotalStaked(uint256 _totalStaked) public _callSet {
        require(_totalStaked != 0, "totalStakedcannot be 0");
        totalStaked = _totalStaked;
    }

    function getTotalStaked() public view _callGet returns (uint256) {
        return totalStaked;
    }

    function setStakeRewardsStartTime(uint256 _stakeRewardsStartTime) public onlyOwner {
        require(_stakeRewardsStartTime != 0, "staking time cannot be 0");
        stakeRewardsStartTime = _stakeRewardsStartTime;
    }

    function getStakeRewardsStartTime() view public _callGet returns (uint256) {
        return stakeRewardsStartTime;
    }

    function setManageFeeStartTime(uint256 _manageFeeStartTime) public onlyOwner {
        require(_manageFeeStartTime != 0, "staking time cannot be 0");
        manageFeeStartTime = _manageFeeStartTime;
    }

    function getManageFeeStartTime() view public _callGet returns (uint256) {
        return manageFeeStartTime;
    }

    function getAddressStakeRecord(address _account, uint256 _stakeRecordId) view public _callGet returns (StakeRecord memory){
        return addressStakeRecord[_account][_stakeRecordId];
    }

    function setAddressStakeRecord(address _account, uint256 _stakeRecordId, StakeRecord memory _stakeRecord) public _callSet {
        addressStakeRecord[_account][_stakeRecordId] = _stakeRecord;
    }

    function getStakeRecordRewardsRecord(address _account, uint256 _stakeRecordId, uint256 _rewardsRecordId) view public _callGet returns (RewardsRecord memory){
        return stakeRecordRewardsRecord[_account][_stakeRecordId][_rewardsRecordId];
    }

    function setStakeRecordRewardsRecord(address _account, uint256 _stakeRecordId, uint256 _rewardsRecordId, RewardsRecord memory _rewardsRecord) public _callSet {
        stakeRecordRewardsRecord[_account][_stakeRecordId][_rewardsRecordId] = _rewardsRecord;
    }

    function getAddressUserInfo(address _account) view public _callGet returns (UserInfo memory){
        return addressUserInfo[_account];
    }

    function setAddressUserInfo(address _account, UserInfo memory _userInfo) public _callSet {
        addressUserInfo[_account] = _userInfo;
    }

    function getStateRecordAddressKeys(uint256 _index) view public _callGet returns (address){
        return stateRecordAddressKeys[_index];
    }

    function getStateRecordAddressKeysSize() view public _callGet returns (uint256){
        return stateRecordAddressKeys.length;
    }

    function pushStateRecordAddressKeys(address _account) public _callSet {
        stateRecordAddressKeys.push(_account);
    }

    function getUserReferrer(address _user) view public _callGet returns (address){
        return userReferrer[_user];
    }

    function setUserReferrer(address _user, address _referrer) public _callSet {
        userReferrer[_user] = _referrer;
    }

    function getReferrerUsers(address _referrer) view public _callGet returns (address[] memory){
        return referrerUsers[_referrer];
    }

    function pushReferrerUsers(address _referrer, address _users) public _callSet {
        referrerUsers[_referrer].push(_users);
    }

    function addCallGetContract(address _account) public onlyOwner {
        callGetContract[_account] = true;
    }

    function addCallSetContract(address _account) public onlyOwner {
        callSetContract[_account] = true;
    }

    function deleteCallGetContract(address _account) public onlyOwner {
        callGetContract[_account] = false;
    }

    function deleteCallSetContract(address _account) public onlyOwner {
        callSetContract[_account] = false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

}
