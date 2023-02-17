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

    // Whether it is a main token staking(e.g. BNB)
    bool private isMainToken;

    address private stakingBank;
    IERC20 private rewardsToken;
    IERC20 private stakingToken;

    // Reward rate per second per token staked 万分之N
    uint256 private rewardRate;

    // 管理费率 万分之N
    uint256 private manageFeeRate;

    // 推荐收益 万分之N
    uint256 private referrRate;

    // Total amount of tokens staked
    uint256 private totalStaked;

    // The minimum staking period to start calculating the earnings
    uint256 private stakingTime;

    // 质押收益开始计算时间
    uint256 private stakeRewardsStartTime;
    // 开始计算管理费时间
    uint256 private manageFeeStartTime;


    // TODO 所有质押记录 address => StakeRecordId => StakeRecord  关联address和StakeRecord public
    mapping(address => mapping(uint256 => StakeRecord)) private addressStakeRecord;

    // TODO 质押奖励历史记录 address => StakeRecordId => RewardsRecordId => RewardsRecord 关联StakeRecord和RewardsRecord
    mapping(address => mapping(uint256 => mapping(uint256 => RewardsRecord))) private stakeRecordRewardsRecord;

    // Mapping of staked record
    mapping(address => UserInfo) private addressUserInfo;

    address[] private userStateRecordKeys;

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
        require(!isMainToken && _stakingToken != address(0),"staking token address cannot be 0");
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
        require(callGetContract[msg.sender],"you can't call get function");
        _;
    }

    modifier _callSet {
        require(callSetContract[msg.sender],"you can't call get function");
        _;
    }

    function getIsMainToken() view public  _callGet returns (bool)  {
        return isMainToken;
    }

    function setIsMainToken(bool _isMainToken) public _callSet {
        isMainToken = _isMainToken;
    }

    function setStakingBank(address _stakingBank) public _callSet {
        require(_stakingBank != address(0), "staking bank address cannot be 0");
        stakingBank = _stakingBank;
    }

    function getStakingBank() view public _callGet returns (address) {
        return stakingBank;
    }

    function setRewardsToken(IERC20 _rewardsToken) public _callSet {
        rewardsToken = _rewardsToken;
    }

    function getRewardsToken() view public _callGet returns (IERC20) {
        return IERC20(rewardsToken);
    }

    function setStakingToken(address _stakingToken) public _callSet {
        require(_stakingToken != address(0), "staking bank address cannot be 0");
        stakingToken = IERC20(_stakingToken);
    }

    function getStakingToken() view public _callGet returns (IERC20) {
        return stakingToken;
    }

    function setRewardRate(uint256 _rewardRate) public _callSet {
        require(_rewardRate != 0, "staking rewad rate cannot be 0");
        rewardRate = _rewardRate;
    }

    function getRewardRate() view public _callGet returns (uint256) {
        return rewardRate;
    }

    function setManageFeeRate(uint256 _manageFeeRate) public _callSet {
        require(_manageFeeRate != 0, "manage fee rate cannot be 0");
        manageFeeRate = _manageFeeRate;
    }

    function getManageFeeRate() view public _callGet returns (uint256) {
        return manageFeeRate;
    }

    function setReferrRate(uint256 _referrRate) public _callSet {
        require(_referrRate != 0, "referr rate cannot be 0");
        referrRate = _referrRate;
    }

    function getReferrRate() view public _callGet returns (uint256) {
        return referrRate;
    }

    function setTotalStaked(uint256 _totalStaked) public _callSet {
        require(_totalStaked != 0, "totalStakedcannot be 0");
        console.log("setTotalStaked: ", _totalStaked);
        totalStaked = _totalStaked;
    }

    function getTotalStaked() public view _callGet returns (uint256) {
        return totalStaked;
    }

    function setStakingTime(uint256 _stakingTime) public _callSet {
        require(_stakingTime != 0, "staking time cannot be 0");
        stakingTime = _stakingTime;
    }

    function getStakingTime() view public _callGet returns (uint256) {
        return stakingTime;
    }

    function setStakeRewardsStartTime(uint256 _stakeRewardsStartTime) public _callSet {
        require(_stakeRewardsStartTime != 0, "staking time cannot be 0");
        stakeRewardsStartTime = _stakeRewardsStartTime;
    }

    function getStakeRewardsStartTime() view public _callGet returns (uint256) {
        return stakeRewardsStartTime;
    }

    function setManageFeeStartTime(uint256 _manageFeeStartTime) public _callSet{
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

    function setAddressUserInfo(address _account , UserInfo memory _userInfo) public _callSet {
        addressUserInfo[_account] = _userInfo;
    }

    function getUserStateRecordKeys(uint256 _index) view public _callGet returns (address){
        return userStateRecordKeys[_index];
    }

    function getUserStateRecordKeysSize() view public _callGet returns (uint256){
        return userStateRecordKeys.length;
    }

    function pushUserStateRecordKeys(address _account) public _callSet {
        userStateRecordKeys.push(_account);
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

    function pushReferrerUsers(address _referrer,address _users) public _callSet {
        referrerUsers[_referrer].push(_users);
    }

    function addCallGetContract(address _account) public onlyOwner{
        callGetContract[_account] = true;
    }

    function addCallSetContract(address _account) public onlyOwner{
        callSetContract[_account] = true;
    }

    function deleteCallGetContract(address _account) public onlyOwner{
        callGetContract[_account] = false;
    }

    function deleteCallSetContract(address _account) public onlyOwner{
        callSetContract[_account] = false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

}
