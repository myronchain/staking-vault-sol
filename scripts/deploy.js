// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers, upgrades} = require("hardhat");
const hre = require("hardhat");


// Constants
const network_configs = {
  bsctest: {
    ERC20_ADDRESS: "0x72042D9AD9a32a889f0130A1476393eC0234b1b4",
    STAKING_BANK: "0xfF171DDfB3236940297808345f7e32C4b5BF097f",
    REWARDS_TOKEN: "0x72042D9AD9a32a889f0130A1476393eC0234b1b4",
    STAKE_REWARDS_START_TIME: 3600000 * 24 * 30,
    REWARD_RATE: 60000000,
    MANAGE_FEE_START_TIME: 3600000 * 24 * 1,
    MANAGE_FEE_RATE: 5000000,
  },
}
let config;

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the Assets contract to deploy

  if (hre.network.name === "polygon") {
    config = network_configs.polygon
  } else {
    config = network_configs.rinkeby
  }

  console.log("Network: ", hre.network.name)
  // Get the ContractFactory
  const StakeDataFactory = await ethers.getContractFactory("StakeData");
  const stakeDataContract = await StakeDataFactory.deploy(true, network_configs[hre.network.name].ERC20_ADDRESS, network_configs[hre.network.name].STAKING_BANK, network_configs[hre.network.name].REWARDS_TOKEN, network_configs[hre.network.name].REWARD_RATE, network_configs[hre.network.name].STAKE_REWARDS_START_TIME, network_configs[hre.network.name].MANAGE_FEE_START_TIME, network_configs[hre.network.name].MANAGE_FEE_RATE);
  await stakeDataContract.deployed();
  console.log("Deployed success. StakeData Contract address: " + stakeDataContract.address + ", Deploy Address: " + await stakeDataContract.owner())

  const WithdrawFactory = await ethers.getContractFactory("Withdraw");
  const withdrawContract = await WithdrawFactory.deploy(stakeDataContract.address);
  await withdrawContract.deployed();
  console.log("Deployed success. Withdraw Contract address: " + withdrawContract.address + ", Deploy Address: " + await withdrawContract.owner())

  const StakeEntryFactory = await ethers.getContractFactory("StakeEntry");
  const stakeEntryContract = await StakeEntryFactory.deploy(stakeDataContract.address, withdrawContract.address);
  await stakeEntryContract.deployed();
  console.log("Deployed success. StakeEntry Contract address: " + stakeEntryContract.address + ", Deploy Address: " + await stakeEntryContract.owner())

  const RecommendFactory = await ethers.getContractFactory("Recommend");
  const recommendContract = await RecommendFactory.deploy(stakeDataContract.address);
  await recommendContract.deployed();
  console.log("Deployed success. Recommend Contract address: " + recommendContract.address + ", Deploy Address: " + await recommendContract.owner())
  console.log("DEPLOYED CONTRACT SUCCESS\n")

  // 添加调用权限
  console.log("SET LIMITS OF AUTHORITY")
  await stakeDataContract.addCallGetContract(withdrawContract.address);
  await stakeDataContract.addCallSetContract(withdrawContract.address);
  await stakeDataContract.addCallGetContract(stakeEntryContract.address);
  await stakeDataContract.addCallSetContract(stakeEntryContract.address);
  await stakeDataContract.addCallGetContract(recommendContract.address);
  await stakeDataContract.addCallSetContract(recommendContract.address);
  // 设置质押银行为提取合约，用于提取代币
  await stakeDataContract.setStakingBank(withdrawContract.address);
  console.log("SET LIMITS OF AUTHORITY SUCCESS\n")

  // verify the contracts
  // await hre.run("verify:verify", {
  //   address: implAddress,
  // });
  // await hre.run("verify:verify", {
  //   address: store.address,
  //   constructorArguments: [upgradedAssets.address, config.USDCAddress],
  // });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
