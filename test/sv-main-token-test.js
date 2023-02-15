// const { describe, beforeEach, it } = require('mocha');
const {expect} = require("chai");
const {ethers, upgrades} = require("hardhat");

describe("StakingVault Main Token Test", function () {
  let admin;
  let maintainer;
  let minter;
  // eslint-disable-next-line no-unused-vars
  let addr1;
  // eslint-disable-next-line no-unused-vars
  let addr2;
  // eslint-disable-next-line no-unused-vars
  let addrs;

  let StakingVaultFactory;
  let svMainToken;
  let nftV2;

  // constants
  let DEPLOYED_ADDRESS = "0x?";
  const STAKING_TOKEN_BUSD_TEST = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
  const STAKING_BANK = "0xfF171DDfB3236940297808345f7e32C4b5BF097f";
  const REWARD_RATE = 1000;
  const ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const MAINTAIN_ROLE = "0x339759585899103d2ace64958e37e18ccb0504652c81d4a1b8aa80fe2126ab95";
  const MINTER_ROLE = "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [admin, maintainer, minter, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Get the ContractFactory
    StakingVaultFactory = await ethers.getContractFactory("StakingVault");
    DEPLOYED_ADDRESS = (await StakingVaultFactory.signer.getAddress()).toLowerCase();
    svMainToken = await StakingVaultFactory.deploy(true, STAKING_TOKEN_BUSD_TEST, STAKING_BANK, REWARD_RATE);
    await svMainToken.deployed();
    console.log("Deployed success. Contract address: " + svMainToken.address + ", Deploy Address: "+ DEPLOYED_ADDRESS)
    // upgrades contract
    // StakingVaultV2Factory = await ethers.getContractFactory("StakingVaultV2");
    // svMainToken = await upgrades.deployProxy(StakingVaultFactory,
    //   [true, STAKING_TOKEN_BUSD_TEST, STAKING_BANK, REWARD_RATE],
    //   {initializer: "initialize", kind: 'uups'})
    // await svMainToken.deployed();
  });

  describe("Deployment", async function () {
    it("Should set the right owner", async function () {
      const svOwner = await svMainToken.owner();
      expect(svOwner.toLowerCase()).to.equal(DEPLOYED_ADDRESS);
    });
  });

  describe("Stake", function () {
    it("Should stake correctly", async function () {
      const tx = await svMainToken.mainTokenStake();
      tx.values(1);
      await tx.wait();
    });
  });
  //   it("Should mint with correct token ID", async function () {
  //     let tx = await svMainToken.mint(admin.address, 1, 1);
  //     let rc = await tx.wait();
  //     let event = rc.events.find((event) => event.event === "Transfer");
  //     let [from, to, value] = event.args;
  //     expect(value.eq(getTokenId(1, 1))).to.be.true;
  //
  //     tx = await svMainToken.mint(admin.address, 1, 1);
  //     rc = await tx.wait();
  //     event = rc.events.find((event) => event.event === "Transfer");
  //     [from, to, value] = event.args;
  //     expect(value.eq(getTokenId(1, 2))).to.be.true;
  //
  //     tx = await svMainToken.mint(admin.address, 2, 1);
  //     rc = await tx.wait();
  //     event = rc.events.find((event) => event.event === "Transfer");
  //     [from, to, value] = event.args;
  //     expect(value.eq(getTokenId(2, 1))).to.be.true;
  //
  //     tx = await svMainToken.mint(admin.address, 2, 1);
  //     rc = await tx.wait();
  //     event = rc.events.find((event) => event.event === "Transfer");
  //     [from, to, value] = event.args;
  //     expect(value.eq(getTokenId(2, 2))).to.be.true;
  //   });
  //
  //   it("Should not able to transfer when paused", async function () {
  //     let tx, rc, event;
  //     tx = await svMainToken.mint(admin.address, 1, 1);
  //     rc = await tx.wait();
  //     event = rc.events.find((event) => event.event === "Transfer");
  //     let [from, to, tokenId] = event.args;
  //
  //     tx = await svMainToken.pause();
  //     await tx.wait();
  //
  //     await expect(
  //       svMainToken.mint(admin.address, 1, 1)
  //     ).to.be.revertedWith("ERC721Pausable: token transfer while paused");
  //
  //     await expect(
  //       svMainToken.transferFrom(admin.address, maintainer.address, tokenId)
  //     ).to.be.revertedWith("ERC721Pausable: token transfer while paused");
  //
  //     tx = await svMainToken.unpause();
  //     await tx.wait();
  //
  //     tx = await svMainToken.mint(admin.address, 1, 1);
  //     await tx.wait();
  //   });
  //
  //   it("Should have correct token URI", async function () {
  //     let tx, rc, event;
  //     tx = await svMainToken.mint(admin.address, 1, 1);
  //     rc = await tx.wait();
  //     event = rc.events.find((event) => event.event === "Transfer");
  //     let [from, to, tokenId] = event.args;
  //     let uri = await svMainToken.tokenURI(tokenId);
  //     expect(uri).to.equal("https://" + tokenId)
  //   })
  //
  //   it("Should have correct model URI", async function () {
  //     let tx, rc, event;
  //     tx = await svMainToken.mint(admin.address, 1, 1);
  //     rc = await tx.wait();
  //     event = rc.events.find((event) => event.event === "Transfer");
  //     let [from, to, tokenId] = event.args;
  //
  //     // set model ID
  //     tx = await svMainToken.setModelURIBatch([1], ["testURI"])
  //     await tx.wait();
  //     let uri = await svMainToken.modelURIByTokenId(tokenId);
  //     expect(uri).to.equal("testURI")
  //
  //     uri = await svMainToken.modelURI(1);
  //     expect(uri).to.equal("testURI")
  //   })
  //
  //   it("Should have correct modelId", async function () {
  //     let tx, rc, event;
  //     tx = await svMainToken.mint(admin.address, 10001, 2);
  //     rc = await tx.wait();
  //     event = rc.events.find((event) => event.event === "Transfer");
  //     let [from, to, tokenId] = event.args;
  //
  //     let modelId = await svMainToken.getModelId(tokenId);
  //     expect(modelId).to.equal(10001);
  //   })
  //
  //   it("MintBatch should mint correct amount", async function () {
  //     let tx, rc, event;
  //     tx = await svMainToken.mintBatch([[admin.address, 1, 3]]);
  //     await tx.wait();
  //     let _balance = await svMainToken.balanceOf(admin.address);
  //     expect(_balance).to.equal(3);
  //
  //     tx = await svMainToken.mintBatch([[admin.address, 1, 10], [admin.address, 2, 100], [maintainer.address, 1, 30]]);
  //     await tx.wait();
  //     _balance = await svMainToken.balanceOf(admin.address);
  //     expect(_balance).to.equal(113);
  //
  //     _balance = await svMainToken.balanceOf(maintainer.address);
  //     expect(_balance).to.equal(30);
  //   })
  //
  //   it("TransferBatch should work", async function () {
  //     let tx = await svMainToken.mintBatch([[admin.address, 1, 10], [admin.address, 2, 100], [admin.address, 1, 30]]);
  //     await tx.wait();
  //
  //     svMainToken.safeTransferFromBatch(admin.address,
  //       maintainer.address,
  //       [getTokenId(1,1), getTokenId(2,1), getTokenId(2,2)],
  //     );
  //
  //     let _balance = await svMainToken.balanceOf(maintainer.address);
  //     expect(_balance).to.equal(3);
  //   })
  //
  //   it("TransferFromToAddresses should work", async function () {
  //     let tx = await svMainToken.mintBatch([[admin.address, 1, 10], [admin.address, 2, 100], [admin.address, 1, 30]]);
  //     await tx.wait();
  //
  //     svMainToken.safeTransferFromToAddresses(admin.address,
  //       [maintainer.address, minter.address, minter.address],
  //       [getTokenId(1,1), getTokenId(2,1), getTokenId(2,2)],
  //     );
  //
  //     let _balance = await svMainToken.balanceOf(maintainer.address);
  //     expect(_balance).to.equal(1);
  //
  //     _balance = await svMainToken.balanceOf(minter.address);
  //     expect(_balance).to.equal(2);
  //   })
  //
  //   it("Should have correct tokenData", async function () {
  //     let tx = await svMainToken.mint(admin.address, 1, 1);
  //     await tx.wait();
  //     // const _balance = await nft.balanceOf(admin.address);
  //     // expect(_balance).to.equal(1);
  //     const tokenId = getTokenId(1,1);
  //     const testTokenData = "test data for token";
  //     tx = await svMainToken.setTokenDataBatch([tokenId], [testTokenData]);
  //     await tx.wait();
  //
  //     let tokenData = await svMainToken.tokenData(tokenId);
  //     expect(tokenData).to.equal(testTokenData);
  //   })
  // });

  // describe('uups mode upgrade', function () {
  //
  //   it('V1 name is correct', async function () {
  //     expect((await svMainToken.name()).toString()).to.equal('StakingVault');
  //   })
  //
  //   it('upgrade StakingVault to V2 and verify name', async function () {
  //     const StakingVaultV2Factory = await ethers.getContractFactory('StakingVaultV2');
  //     nftV2 = (await upgrades.upgradeProxy(svMainToken, StakingVaultFactoryV2));
  //     expect((await nftV2.name()).toString()).to.equal('StakingVault');
  //   })
  // })
});
