// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";

/**
* 质押计算合约，质押代币存储合约
*/
interface IStakeEntry {

    event Staked(address _from, uint256 _amount);
    event Withdraw(address _from, uint256 _amount);
    event WithdrawOwner(address _from, uint256 _amount);
    event RewardStakeClaimed(address _from, uint256 _amount);
    event RewardReferrerClaimed(address _from, uint256 _amount);


    // 主代币质押
    function mainTokenStake() external payable;

    // Token质押
    function tokenStake(uint256 _amount) external;

    // 获取总质押人数和总质押金额
    function getStakeNum(uint256 startTime, uint256 endTime) external view returns (uint256, uint256);

    // 获取用户质押总额
    function getStakeAmount(address _account) external view returns (uint256);

    // 获取质押余额，减去管理费部分的余额
    function getStakeBalance(address _account) external view returns (uint256);

    // 计算更新收益，接受外部调用
    function calculateReward() external;

    // 更新管理费用
    function calculateManageFee() external;

    // 获取指定人的收益历史总额
    function getRewardCount(address _account) external view returns (uint256);

    // 获取收益余额
    function getRewardsBalance(address _account) external view returns (uint256);

    function getTotalStaked() external view returns (uint256);

    // 获取指定人邀请收益历史总额
    function getReferrerRewardCount(address _account) external view returns (uint256);

    // 获取指定人邀请收益余额
    function getReferrerRewardsBalance(address _account) external view returns (uint256);

    function getWithdrawContractAddress() view external returns (address);

    function setWithdrawContractAddress(address _withdrawAddress) external;

}
