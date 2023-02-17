// const { describe, beforeEach, it } = require('mocha');
const {expect} = require("chai");
const {ethers, web3} = require("hardhat");
const {int} = require("hardhat/internal/core/params/argumentTypes");

const ETH = (value) => ethers.utils.parseEther(value);

const sleep = ms => new Promise(r => setTimeout(r, ms));

function Log(msg) {
  console.log("\t" + msg);
}

describe("StakingVault Main Token Test", function () {
  let admin;
  let owner;
  // eslint-disable-next-line no-unused-vars
  let stakeUser1;
  // eslint-disable-next-line no-unused-vars
  let stakeUser2;
  // eslint-disable-next-line no-unused-vars
  let stakeUser3;

  let StakeDataFactory;
  let WithdrawFactory;
  let StakeEntryFactory;
  let RecommendFactory;
  let stakeDataContract;
  let withdrawContract;
  let stakeEntryContract;
  let recommendContract;

  // constants
  const STAKING_TOKEN_BUSD_TEST = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  const STAKING_BANK = "0xfF171DDfB3236940297808345f7e32C4b5BF097f";
  const REWARDS_TOKEN = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  // 使用的时候除以1e8  2.5%
  const REWARD_RATE = 25000000;
  // 单位: ms
  const STAKE_REWARDS_START_TIME = 10;
  const MANAGE_FEE_START_TIME = 20;
  // 使用的时候除以1e8  5%
  const MANAGE_FEE_RATE = 50000000;

  // 质押用户质押数量
  const stakedAmount1 = ETH("10");
  const stakedAmount2 = ETH("20");

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    Log("START TO DEPLOYED CONTRACT");
    [admin, owner, stakeUser1, stakeUser2, stakeUser3] = await ethers.getSigners();

    // Get the ContractFactory
    StakeDataFactory = await ethers.getContractFactory("StakeData");
    stakeDataContract = await StakeDataFactory.deploy(
        true,
        STAKING_TOKEN_BUSD_TEST,
        STAKING_BANK,
        REWARDS_TOKEN,
        REWARD_RATE,
        STAKE_REWARDS_START_TIME,
        MANAGE_FEE_START_TIME,
        MANAGE_FEE_RATE
    );
    await stakeDataContract.deployed();
    Log("Deployed success. StakeData Contract address: " + stakeDataContract.address + ", Deploy Address: " + await stakeDataContract.owner())

    WithdrawFactory = await ethers.getContractFactory("Withdraw");
    withdrawContract = await WithdrawFactory.deploy(stakeDataContract.address);
    await withdrawContract.deployed();
    Log("Deployed success. Withdraw Contract address: " + withdrawContract.address + ", Deploy Address: " + await withdrawContract.owner())

    StakeEntryFactory = await ethers.getContractFactory("StakeEntry");
    stakeEntryContract = await StakeEntryFactory.deploy(stakeDataContract.address);
    await stakeEntryContract.deployed();
    Log("Deployed success. StakeEntry Contract address: " + stakeEntryContract.address + ", Deploy Address: " + await stakeEntryContract.owner())

    RecommendFactory = await ethers.getContractFactory("Recommend");
    recommendContract = await RecommendFactory.deploy(stakeDataContract.address);
    await recommendContract.deployed();
    Log("Deployed success. Recommend Contract address: " + recommendContract.address + ", Deploy Address: " + await recommendContract.owner())
    Log("DEPLOYED CONTRACT SUCCESS\n")
    // 添加调用权限
    stakeDataContract.addCallGetContract(withdrawContract.address);
    stakeDataContract.addCallSetContract(withdrawContract.address);
    stakeDataContract.addCallGetContract(stakeEntryContract.address);
    stakeDataContract.addCallSetContract(stakeEntryContract.address);
    stakeDataContract.addCallGetContract(recommendContract.address);
    stakeDataContract.addCallSetContract(recommendContract.address);

    // 模拟质押
    // 第一个人质押
    let stakeUser1Balance = (await web3.eth.getBalance(stakeUser1.address)).toString()
    Log("StakeUser1Balance before staking: " + stakeUser1Balance);

    await stakeUser1.sendTransaction({
      to: stakeEntryContract.address, value: stakedAmount1, // Sends exactly 1.0 ether
    }, function (err, hash) {
      Log("stake tx hash: " + hash)
    });
    stakeUser1Balance = (await web3.eth.getBalance(stakeUser1.address)).toString()
    Log("StakeUser1Balance after staking: " + stakeUser1Balance);

    const amount1 = (await web3.eth.getBalance(stakeDataContract.address)).toString()
    Log("Amount1: " + amount1);

    // 第二个人质押
    let stakeUser2Balance = (await web3.eth.getBalance(stakeUser2.address)).toString()
    Log("StakeUser2Balance before staking: " + stakeUser2Balance);

    await stakeUser2.sendTransaction({
      to: stakeEntryContract.address, value: stakedAmount2, // Sends exactly 1.0 ether
    }, function (err, hash) {
      Log("stake tx hash: " + hash)
    });
    stakeUser2Balance = (await web3.eth.getBalance(stakeUser2.address)).toString()
    Log("StakeUser2Balance after staking: " + stakeUser2Balance);

    const amount2 = (await web3.eth.getBalance(stakeDataContract.address)).toString()
    Log("Amount2: " + amount2);
  });

  // describe("TransferOwnership", async function () {
  //   it("Should set the right owner", async function () {
  //     await stakeDataContract.transferOwnership(owner.address.toLowerCase());
  //     const svOwner = await stakeDataContract.owner();
  //     expect(svOwner.toLowerCase()).to.equal(owner.address.toLowerCase());
  //   });
  // });
  //
  // describe("Stake", function () {
  //
  //   let stakedAmount1 = ETH("10");
  //   let stakedAmount2 = ETH("20");
  //
  //   it("Should stake correctly for staker", async function () {
  //     // 验证质押人的质押总额
  //     const _stakedAmount1 = await stakeEntryContract.stakedOf(stakeUser1.address);
  //     expect(_stakedAmount1).to.equal(stakedAmount1);
  //     const _stakedAmount2 = await stakeEntryContract.stakedOf(stakeUser2.address);
  //     expect(_stakedAmount2).to.equal(stakedAmount2);
  //   });
  //
  //   it("Should stake correctly for contract", async function () {
  //     // 验证合约质押总额
  //     const _totalStaked = await stakeEntryContract.getTotalStaked();
  //     expect(_totalStaked).to.equal(stakedAmount1.add(stakedAmount2));
  //   });
  // });


  describe("Calculation Rewards", function () {

    it("Should get rewards correctly for staker", async function () {
      sleep(STAKE_REWARDS_START_TIME);
      // 验证质押人的质押总额
      await stakeEntryContract.calculateReward();
      const _rewardsUser1 = await stakeEntryContract.getRewardCount(stakeUser1.address);
      Log(_rewardsUser1);
      // Log(stakedAmount2.mul(REWARD_RATE).div(1e8));
      expect(_rewardsUser1).to.equal(stakedAmount2.mul(REWARD_RATE).div(1e8));
    });

    it("Should stake correctly for contract", async function () {
      // 验证合约质押总额
      const _totalStaked = await stakeEntryContract.getTotalStaked();
      expect(_totalStaked).to.equal(stakedAmount1.add(stakedAmount2));
    });
  });

  describe("Calculation Manage Fee", function () {

    it("Should calculation manage fee correctly", async function () {
      // 验证质押人的质押总额
      await stakeEntryContract.calculateReward();
      const _rewardsUser1 = await stakeEntryContract.getRewardCount(stakeUser1.address);
      Log(_rewardsUser1);
      // Log(stakedAmount2.mul(REWARD_RATE).div(1e8));
      expect(_rewardsUser1).to.equal(stakedAmount2.mul(REWARD_RATE).div(1e8));
    });

    it("Should stake correctly for contract", async function () {
      // 验证合约质押总额
      const _totalStaked = await stakeEntryContract.getTotalStaked();
      expect(_totalStaked).to.equal(stakedAmount1.add(stakedAmount2));
    });
  });

});
