// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers, upgrades} = require("hardhat");
const hre = require("hardhat");


// Constants
const network_configs = {
    bsctest_maintoken: {
        STAKING_TOKEN: "0x72042D9AD9a32a889f0130A1476393eC0234b1b4", // 质押Token地址，主代币质押不需要此值
        STAKING_BANK: "0xfF171DDfB3236940297808345f7e32C4b5BF097f", // 质押银行，用于提取奖励
        REWARDS_TOKEN: "0x72042D9AD9a32a889f0130A1476393eC0234b1b4", // 奖励Token地址，主代币不需要此值
        STAKE_REWARDS_START_TIME: 3600000 * 24 * 30, // 质押奖励计算周期(单位: s，下同)
        REWARD_RATE: 60000000, // 质押奖励系数(精度为8，例如10000000代表0.1，下同)
        MANAGE_FEE_START_TIME: 3600000 * 24 * 1, // 管理费计算周期
        MANAGE_FEE_RATE: 5000000, // 管理费系数
        REFERRER_RATE: 2500000, // 邀请奖励系数
    }, bsctest_token: {
        STAKING_TOKEN: "0x72042D9AD9a32a889f0130A1476393eC0234b1b4",
        STAKING_BANK: "0xfF171DDfB3236940297808345f7e32C4b5BF097f",
        REWARDS_TOKEN: "0x72042D9AD9a32a889f0130A1476393eC0234b1b4",
        STAKE_REWARDS_START_TIME: 3600000 * 24 * 30,
        REWARD_RATE: 60000000,
        MANAGE_FEE_START_TIME: 3600000 * 24 * 1,
        MANAGE_FEE_RATE: 5000000,
        REFERRER_RATE: 2500000,
    },
}

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    // We get the Assets contract to deploy

    let isMainToken;

    if (hre.network.name === "bsctest_maintoken" || hre.network.name === "bsc_maintoken") {
        isMainToken = true;
    } else if (hre.network.name === "bsctest_token" || hre.network.name === "bsc_token") {
        isMainToken = false;
    }

    console.log("Network: ", hre.network.name);
    console.log("Is Main Token: ", isMainToken);
    // Get the ContractFactory
    const StakeDataFactory = await ethers.getContractFactory("StakeData");
    const stakeDataContract = await StakeDataFactory.deploy(isMainToken, network_configs[hre.network.name].ERC20_ADDRESS, network_configs[hre.network.name].STAKING_BANK, network_configs[hre.network.name].REWARDS_TOKEN, network_configs[hre.network.name].REWARD_RATE, network_configs[hre.network.name].STAKE_REWARDS_START_TIME, network_configs[hre.network.name].MANAGE_FEE_START_TIME, network_configs[hre.network.name].MANAGE_FEE_RATE, network_configs[hre.network.name].REFERRER_RATE);
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
    console.log("SET LIMITS OF AUTHORITY SUCCESS")

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
