// const { describe, beforeEach, it } = require('mocha');
const {expect} = require("chai");
const {ethers, web3} = require("hardhat");
const {BigNumber} = require("ethers");

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
  let erc20Contract;
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
    erc20Contract = await ERC20MockFactory.deploy(1e10);
    await erc20Contract.deployed();
    Log("Deployed success. ERC20Mock Contract address: " + erc20Contract.address + ", Deploy Address: " + admin.address)

    // Get the ContractFactory
    StakeDataFactory = await ethers.getContractFactory("StakeData");
    stakeDataContract = await StakeDataFactory.deploy(false, erc20Contract.address, admin.address, erc20Contract.address, REWARD_RATE, STAKE_REWARDS_START_TIME,
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
    await stakeDataContract.addCallGetContract(withdrawContract.address);
    await stakeDataContract.addCallSetContract(withdrawContract.address);
    await stakeDataContract.addCallGetContract(stakeEntryContract.address);
    await stakeDataContract.addCallSetContract(stakeEntryContract.address);
    await stakeDataContract.addCallGetContract(recommendContract.address);
    await stakeDataContract.addCallSetContract(recommendContract.address);

    await stakeDataContract.setStakingToken(erc20Contract.address);

    await erc20Contract.approve(stakeEntryContract.address, BigNumber.from(1));
    await erc20Contract.approve(withdrawContract.address, BigNumber.from(1));

    // TODO token测试未完

    // 模拟质押
    // 第一个人质押
    // let boo = (stakeDataContract.getIsMainToken())
    // Log("stakeEntryContract main token:"+boo);
    let stakeUser1Balance = (await erc20Contract.balanceOf(admin.address)).toString()
    Log("StakeUser1Balance before staking: " + stakeUser1Balance);
    await stakeEntryContract.tokenStake(1)
    stakeUser1Balance = (await erc20Contract.balanceOf(admin.address)).toString()
    Log("StakeUser1Balance after staking: " + stakeUser1Balance);
    const amount1 = (await erc20Contract.balanceOf(stakeEntryContract.address)).toString()
    Log("StakeData Contract Main Token Amount1: " + amount1);

    // 第二个人质押
    // let stakeUser2Balance = (await web3.eth.getBalance(stakeUser2.address)).toString()
    // Log("StakeUser2Balance before staking: " + stakeUser2Balance);
    // await stakeUser2.sendTransaction({
    //   to: stakeEntryContract.address, value: stakedAmount2,
    // }, function (err, hash) {
    //   if (err) {
    //     Log(err);
    //   }
    // });
    // stakeUser2Balance = (await web3.eth.getBalance(stakeUser2.address)).toString()
    // Log("StakeUser2Balance after staking: " + stakeUser2Balance);
    // const amount2 = (await web3.eth.getBalance(stakeEntryContract.address)).toString()
    // Log("StakeData Contract Main Token Amount2: " + amount2);
    //
    // // admin 质押
    // let adminBalance = (await web3.eth.getBalance(stakeUser2.address)).toString()
    // Log("admin Balance before staking: " + stakeUser2Balance);
    // await admin.sendTransaction({
    //   to: stakeEntryContract.address, value: stakedAmount3,
    // }, function (err, hash) {
    //   if (err) {
    //     Log(err);
    //   }
    // });
    // adminBalance = (await web3.eth.getBalance(admin.address)).toString()
    // Log("Admin Balance after staking: " + adminBalance);
    // const amount3 = (await web3.eth.getBalance(stakeEntryContract.address)).toString()
    // Log("StakeData Contract Main Token Amount3: " + amount3);
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


  // describe("Calculation Rewards", function () {
  //
  //   it("Should get rewards correctly for staker", async function () {
  //     sleep(STAKE_REWARDS_START_TIME);
  //     // 验证质押人的质押总额
  //     await stakeEntryContract.calculateReward();
  //     const _rewardsUser1 = await stakeEntryContract.getRewardCount(stakeUser1.address);
  //     expect(_rewardsUser1).to.equal(stakedAmount1.mul(REWARD_RATE).div(1e8));
  //   });
  //
  //   it("Should stake correctly for contract", async function () {
  //     // 验证合约质押总额
  //     const _totalStaked = await stakeEntryContract.getTotalStaked();
  //     expect(_totalStaked).to.equal(stakedAmount1.add(stakedAmount2));
  //   });
  // });

  // describe("Calculation Manage Fee", function () {
  //
  //   it("Should stake balance correctly for staker after reduce manage fee", async function () {
  //     // 验证质押人的管理费是否扣除
  //     await stakeEntryContract.calculateManageFee();
  //     const _stakeBalanceUser1 = await stakeEntryContract.getStakeBalance(stakeUser1.address);
  //     expect(_stakeBalanceUser1).to.equal(stakedAmount1.sub(stakedAmount1.mul(MANAGE_FEE_RATE).div(1e8)));
  //   });
  // });

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
  });

  describe("Recommend", function () {

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
  });

});