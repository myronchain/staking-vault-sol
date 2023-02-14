// const { describe, beforeEach, it } = require('mocha');
const { expect } = require("chai");
const { ethers, upgrades} = require("hardhat");

function getTokenId(modelId, number) {
  return (modelId * (2 ** 32)) + number
}

describe("StakingVault", function () {
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
  let nft;
  let nftV2;

  // constants
  const ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const MAINTAIN_ROLE = "0x339759585899103d2ace64958e37e18ccb0504652c81d4a1b8aa80fe2126ab95";
  const MINTER_ROLE = "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [admin, maintainer, minter, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Get the ContractFactory
    StakingVaultFactory = await ethers.getContractFactory("StakingVault");
    StakingVaultV2Factory = await ethers.getContractFactory("StakingVaultV2");
    nft = await upgrades.deployProxy(StakingVaultFactory,
      ["StakingVault", "SV", "http://dddd"],
      {initializer: "initialize", kind: 'uups'})
    await nft.deployed();
    let tx = await nft.grantRole(
      MAINTAIN_ROLE,
      maintainer.address
    );
    await tx.wait();

    tx = await nft.grantRole(
      MINTER_ROLE,
      minter.address
    );
    await tx.wait();

    tx = await nft.grantRole(
      MINTER_ROLE,
      admin.address
    );
    await tx.wait();
  });

  describe("Deployment", function () {
    it("Should set the right admin / maintainer / minter", async function () {
      const isAdmin = await nft.hasRole(
        ADMIN_ROLE,
        admin.address
      );
      expect(isAdmin).to.equal(true);

      const isMaintainer = await nft.hasRole(
        MAINTAIN_ROLE,
        maintainer.address
      );
      expect(isMaintainer).to.equal(true);

      const isMinter = await nft.hasRole(
        MINTER_ROLE,
        minter.address
      );
      expect(isMinter).to.equal(true);
    });
  });

  describe("Transactions", function () {
    it("Should mint correctly", async function () {
      const tx = await nft.mint(admin.address, 1, 1);
      await tx.wait();
      const _balance = await nft.balanceOf(admin.address);
      expect(_balance).to.equal(1);
    });

    it("Should mint with correct token ID", async function () {
      let tx = await nft.mint(admin.address, 1, 1);
      let rc = await tx.wait();
      let event = rc.events.find((event) => event.event === "Transfer");
      let [from, to, value] = event.args;
      expect(value.eq(getTokenId(1, 1))).to.be.true;

      tx = await nft.mint(admin.address, 1, 1);
      rc = await tx.wait();
      event = rc.events.find((event) => event.event === "Transfer");
      [from, to, value] = event.args;
      expect(value.eq(getTokenId(1, 2))).to.be.true;

      tx = await nft.mint(admin.address, 2, 1);
      rc = await tx.wait();
      event = rc.events.find((event) => event.event === "Transfer");
      [from, to, value] = event.args;
      expect(value.eq(getTokenId(2, 1))).to.be.true;

      tx = await nft.mint(admin.address, 2, 1);
      rc = await tx.wait();
      event = rc.events.find((event) => event.event === "Transfer");
      [from, to, value] = event.args;
      expect(value.eq(getTokenId(2, 2))).to.be.true;
    });

    it("Should not able to transfer when paused", async function () {
      let tx, rc, event;
      tx = await nft.mint(admin.address, 1, 1);
      rc = await tx.wait();
      event = rc.events.find((event) => event.event === "Transfer");
      let [from, to, tokenId] = event.args;

      tx = await nft.pause();
      await tx.wait();

      await expect(
        nft.mint(admin.address, 1, 1)
      ).to.be.revertedWith("ERC721Pausable: token transfer while paused");

      await expect(
        nft.transferFrom(admin.address, maintainer.address, tokenId)
      ).to.be.revertedWith("ERC721Pausable: token transfer while paused");

      tx = await nft.unpause();
      await tx.wait();

      tx = await nft.mint(admin.address, 1, 1);
      await tx.wait();
    });

    it("Should have correct token URI", async function () {
      let tx, rc, event;
      tx = await nft.mint(admin.address, 1, 1);
      rc = await tx.wait();
      event = rc.events.find((event) => event.event === "Transfer");
      let [from, to, tokenId] = event.args;
      let uri = await nft.tokenURI(tokenId);
      expect(uri).to.equal("https://" + tokenId)
    })

    it("Should have correct model URI", async function () {
      let tx, rc, event;
      tx = await nft.mint(admin.address, 1, 1);
      rc = await tx.wait();
      event = rc.events.find((event) => event.event === "Transfer");
      let [from, to, tokenId] = event.args;

      // set model ID
      tx = await nft.setModelURIBatch([1], ["testURI"])
      await tx.wait();
      let uri = await nft.modelURIByTokenId(tokenId);
      expect(uri).to.equal("testURI")

      uri = await nft.modelURI(1);
      expect(uri).to.equal("testURI")
    })

    it("Should have correct modelId", async function () {
      let tx, rc, event;
      tx = await nft.mint(admin.address, 10001, 2);
      rc = await tx.wait();
      event = rc.events.find((event) => event.event === "Transfer");
      let [from, to, tokenId] = event.args;

      let modelId = await nft.getModelId(tokenId);
      expect(modelId).to.equal(10001);
    })

    it("MintBatch should mint correct amount", async function () {
      let tx, rc, event;
      tx = await nft.mintBatch([[admin.address, 1, 3]]);
      await tx.wait();
      let _balance = await nft.balanceOf(admin.address);
      expect(_balance).to.equal(3);

      tx = await nft.mintBatch([[admin.address, 1, 10], [admin.address, 2, 100], [maintainer.address, 1, 30]]);
      await tx.wait();
      _balance = await nft.balanceOf(admin.address);
      expect(_balance).to.equal(113);

      _balance = await nft.balanceOf(maintainer.address);
      expect(_balance).to.equal(30);
    })

    it("TransferBatch should work", async function () {
      let tx = await nft.mintBatch([[admin.address, 1, 10], [admin.address, 2, 100], [admin.address, 1, 30]]);
      await tx.wait();

      nft.safeTransferFromBatch(admin.address,
        maintainer.address,
        [getTokenId(1,1), getTokenId(2,1), getTokenId(2,2)],
      );

      let _balance = await nft.balanceOf(maintainer.address);
      expect(_balance).to.equal(3);
    })

    it("TransferFromToAddresses should work", async function () {
      let tx = await nft.mintBatch([[admin.address, 1, 10], [admin.address, 2, 100], [admin.address, 1, 30]]);
      await tx.wait();

      nft.safeTransferFromToAddresses(admin.address,
        [maintainer.address, minter.address, minter.address],
        [getTokenId(1,1), getTokenId(2,1), getTokenId(2,2)],
      );

      let _balance = await nft.balanceOf(maintainer.address);
      expect(_balance).to.equal(1);

      _balance = await nft.balanceOf(minter.address);
      expect(_balance).to.equal(2);
    })

    it("Should have correct tokenData", async function () {
      let tx = await nft.mint(admin.address, 1, 1);
      await tx.wait();
      // const _balance = await nft.balanceOf(admin.address);
      // expect(_balance).to.equal(1);
      const tokenId = getTokenId(1,1);
      const testTokenData = "test data for token";
      tx = await nft.setTokenDataBatch([tokenId], [testTokenData]);
      await tx.wait();

      let tokenData = await nft.tokenData(tokenId);
      expect(tokenData).to.equal(testTokenData);
    })
  });

  describe('uups mode upgrade', function () {

    it('V1 name is correct', async function () {
      expect((await nft.name()).toString()).to.equal('StakingVault');
    })

    it('upgrade StakingVault to V2 and verify name', async function () {
      const StakingVaultV2Factory = await ethers.getContractFactory('StakingVaultV2');
      nftV2 = (await upgrades.upgradeProxy(nft, StakingVaultFactoryV2));
      expect((await nftV2.name()).toString()).to.equal('StakingVault');
    })
  })
});
