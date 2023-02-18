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
interface IWithdraw {

    event Staked(address _from, uint256 _amount);
    event WithdrawStake(address _from, uint256 _amount);
    event WithdrawOwner(address _from, uint256 _amount);
    event RewardStakeClaimed(address _from, uint256 _amount);
    event RewardReferrerClaimed(address _from, uint256 _amount);

    function pause() external;

    function unpause() external;

    // 查看合约主代币金额
    function getMainTokenBalance() external view returns (uint256);

    /** 提取相关 */
    // 提取本金
    function withdrawStake(uint256 _amount) external;

    // 提取质押收益
    function claimStakeReward(uint256 _amount) external;

    // 提取邀请奖励收益
    function claimReferrerReward(uint256 _amount) external;

    // 提取本金+质押收益+邀请奖励
    function claimAllReward(address _account) external;

    // 将所有人的邀请奖励费用发送给给对应的邀请人
    function sendAllReferrerRewards() external;

    // Owner提取代币
    function withdrawOwner(uint256 _amount) external;

}
