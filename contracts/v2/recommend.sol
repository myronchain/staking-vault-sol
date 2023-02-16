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
        svData = StakingVaultData(counterAddress);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /** 邀请人相关 */
    function setReferrer(address _referrer) public {
        require(svData.getUserReferrer(msg.sender) != address(0), "Already set referrer");
        svData.setUserReferrer(msg.sender, _referrer);
        svData.pushReferrerUsers(_referrer,msg.sender);
    }

}
