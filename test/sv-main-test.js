// const { describe, beforeEach, it } = require('mocha');
const {expect} = require("chai");
const {ethers, web3} = require("hardhat");

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

  let ERC20MockFactory;
  let StakeDataFactory;
  let WithdrawFactory;
  let StakeEntryFactory;
  let RecommendFactory;
  let erc20MockContract;
  let stakeDataContract;
  let withdrawContract;
  let stakeEntryContract;
  let recommendContract;

  // constants
  const STAKING_TOKEN_BUSD_TEST = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  const STAKING_BANK = "0xfF171DDfB3236940297808345f7e32C4b5BF097f";
  const REWARDS_TOKEN = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  // 使用的时候除以1e8  2.5%
  const REWARD_RATE = 60000000;
  // 单位: ms
  const STAKE_REWARDS_START_TIME = 2;
  const MANAGE_FEE_START_TIME = 2;
  // 使用的时候除以1e8  5%
  const MANAGE_FEE_RATE = 5000000;

  // 质押用户质押数量
  const stakedAmount1 = ETH("10");
  const stakedAmount2 = ETH("20");
  const stakedAmount3 = ETH("30");

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    Log("START TO DEPLOYED CONTRACT");
    [admin, owner, stakeUser1, stakeUser2, stakeUser3] = await ethers.getSigners();

    ERC20MockFactory = await ethers.getContractFactory("ERC20Mock");
    erc20MockContract = await ERC20MockFactory.deploy(1e10);
    await erc20MockContract.deployed();
    Log("Deployed success. ERC20Mock Contract address: " + erc20MockContract.address + ", Deploy Address: " + admin.address)

    // Get the ContractFactory
    StakeDataFactory = await ethers.getContractFactory("StakeData");
    stakeDataContract = await StakeDataFactory.deploy(true, STAKING_TOKEN_BUSD_TEST, STAKING_BANK, REWARDS_TOKEN, REWARD_RATE, STAKE_REWARDS_START_TIME,
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
    stakeEntryContract = await StakeEntryFactory.deploy(stakeDataContract.address, withdrawContract.address);
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
    let bool = (stakeDataContract.getIsMainToken())
    Log("stakeEntryContract main token:"+bool);
    let stakeUser1Balance = (await web3.eth.getBalance(stakeUser1.address)).toString()
    Log("StakeUser1Balance before staking: " + stakeUser1Balance);
    await stakeUser1.sendTransaction({
      to: stakeEntryContract.address, value: stakedAmount1,
    }, function (err, hash) {
      if (err) {
        Log(err);
      }
    });
    stakeUser1Balance = (await web3.eth.getBalance(stakeUser1.address)).toString()
    Log("StakeUser1Balance after staking: " + stakeUser1Balance);
    const amount1 = (await web3.eth.getBalance(stakeEntryContract.address)).toString()
    Log("StakeData Contract Main Token Amount1: " + amount1);

    // 第二个人质押
    let stakeUser2Balance = (await web3.eth.getBalance(stakeUser2.address)).toString()
    Log("StakeUser2Balance before staking: " + stakeUser2Balance);
    await stakeUser2.sendTransaction({
      to: stakeEntryContract.address, value: stakedAmount2,
    }, function (err, hash) {
      if (err) {
        Log(err);
      }
    });
    stakeUser2Balance = (await web3.eth.getBalance(stakeUser2.address)).toString()
    Log("StakeUser2Balance after staking: " + stakeUser2Balance);
    const amount2 = (await web3.eth.getBalance(stakeEntryContract.address)).toString()
    Log("StakeData Contract Main Token Amount2: " + amount2);

    // admin 质押
    let adminBalance = (await web3.eth.getBalance(admin.address)).toString()
    Log("admin Balance before staking: " + stakeUser2Balance);
    await admin.sendTransaction({
      to: stakeEntryContract.address, value: stakedAmount3,
    }, function (err, hash) {
      if (err) {
        Log(err);
      }
    });
    adminBalance = (await web3.eth.getBalance(admin.address)).toString()
    Log("Admin Balance after staking: " + adminBalance);
    const amount3 = (await web3.eth.getBalance(stakeEntryContract.address)).toString()
    Log("StakeData Contract Main Token Amount3: " + amount3);
  });

  describe("TransferOwnership", async function () {
    it("Should set the right owner", async function () {
      await stakeDataContract.transferOwnership(owner.address.toLowerCase());
      const svOwner = await stakeDataContract.owner();
      expect(svOwner.toLowerCase()).to.equal(owner.address.toLowerCase());
    });
  });

  describe("Stake", function () {

    let stakedAmount1 = ETH("10");
    let stakedAmount2 = ETH("20");

    it("Should stake correctly for staker", async function () {
      // 验证质押人的质押总额
      const _stakedAmount1 = await stakeEntryContract.getStakeAmount(stakeUser1.address);
      expect(_stakedAmount1).to.equal(stakedAmount1);
      const _stakedAmount2 = await stakeEntryContract.getStakeAmount(stakeUser2.address);
      expect(_stakedAmount2).to.equal(stakedAmount2);
    });

    it("Should stake correctly for contract", async function () {
      // 验证合约质押总额
      const _totalStaked = await stakeEntryContract.getTotalStaked();
      expect(_totalStaked).to.equal(stakedAmount1.add(stakedAmount2).add(stakedAmount3));
    });
  });


  describe("Calculation Rewards", function () {

    it("Should get rewards correctly for staker", async function () {
      sleep(STAKE_REWARDS_START_TIME);
      // 验证质押人的质押总额
      await stakeEntryContract.calculateReward();
      const _rewardsUser1 = await stakeEntryContract.getRewardCount(stakeUser1.address);
      expect(_rewardsUser1).to.equal(stakedAmount1.mul(REWARD_RATE).div(1e8));
    });

  });

  describe("Calculation Manage Fee", function () {

    it("Should stake balance correctly for staker after reduce manage fee", async function () {
      // 验证质押人的管理费是否扣除
      await stakeEntryContract.calculateManageFee();
      const _stakeBalanceUser1 = await stakeEntryContract.getStakeBalance(stakeUser1.address);
      expect(_stakeBalanceUser1).to.equal(stakedAmount1.sub(stakedAmount1.mul(MANAGE_FEE_RATE).div(1e8)));
    });
  });

  describe("Withdraw", function () {

    it("Should withdraw stake balance correctly for staker", async function () {
      let _adminBalance = (await web3.eth.getBalance(admin.address)).toString()
      const _stakeBalanceAdmin1 = await stakeEntryContract.getStakeBalance(admin.address);
      Log("admin balance1:" + _adminBalance);
      Log("admin stake balance1:" + _stakeBalanceAdmin1);
      // 提取本金
      await withdrawContract.withdrawStake(ETH("1"));
      _adminBalance = (await web3.eth.getBalance(admin.address)).toString()
      const _stakeBalanceAdmin2 = await stakeEntryContract.getStakeBalance(admin.address);
      Log("admin balance2:" + _adminBalance);
      Log("admin stake balance2:" + _stakeBalanceAdmin2);
      expect(_stakeBalanceAdmin1).to.equal(_stakeBalanceAdmin2.add(ETH("1")));
    });

    it("Should can withdraw all rewards", async function () {
      let _adminBalance1 = (await web3.eth.getBalance(admin.address)).toString()
      Log("admin balance1:" + _adminBalance1);

      await withdrawContract.claimAllReward(admin.address);

      let _adminBalance2 = (await web3.eth.getBalance(admin.address)).toString()
      Log("admin balance2:" + _adminBalance2);

      expect(_adminBalance1).to.not.equal(_adminBalance2);
    })

    it("Should can withdraw all token by owner", async function () {
      let _adminBalance1 = (await web3.eth.getBalance(admin.address)).toString()
      Log("admin balance1:" + _adminBalance1);

      await withdrawContract.withdrawOwner(1);

      let _adminBalance2 = (await web3.eth.getBalance(admin.address)).toString()
      Log("admin balance2:" + _adminBalance2);

      expect(_adminBalance1).to.not.equal(_adminBalance2);
    })
  });

  describe("Recommend", function () {

    it("Should get referrer correctly for user", async function () {
      const _referrer = await recommendContract.getReferrer();
      expect(_referrer).to.equal(ethers.constants.AddressZero);
      await recommendContract.setReferrer(stakeUser1.address);
      const _referrerNew = await recommendContract.getReferrer();
      expect(_referrerNew).to.equal(stakeUser1.address);
    });
  });

});
