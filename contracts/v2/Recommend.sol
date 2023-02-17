// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";
import "./StakeData.sol";

/**
* 邀请人相关
*/
contract Recommend is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Staked(address _from, uint256 _amount);
    event Withdraw(address _from, uint256 _amount);
    event WithdrawOwner(address _from, uint256 _amount);
    event RewardStakeClaimed(address _from, uint256 _amount);
    event RewardReferrerClaimed(address _from, uint256 _amount);

    StakeData private svData;

    /** 构造函数 */
    constructor(address _stakeDataAddress) {
        svData = StakeData(_stakeDataAddress);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setReferrer(address _referrer) public {
        require(_referrer != address(0), "_referrer is 0");
        require(svData.getUserReferrer(msg.sender) == address(0), "Already set referrer");
        svData.setUserReferrer(msg.sender, _referrer);
        svData.pushReferrerUsers(_referrer, msg.sender);
    }

    function getReferrer() public returns (address) {
        return svData.getUserReferrer(msg.sender);
    }

}
