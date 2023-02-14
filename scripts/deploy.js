// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers, upgrades} = require("hardhat");
const hre = require("hardhat");


// Constants
const MINTER_ROLE = "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";
const network_configs = {
  mumbai: {
    USDCAddress: "0x0fa8781a83e46826621b3bc094ea2a0212e71b23",
  },
  polygon : {
    USDCAddress: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
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
    config = network_configs.mumbai
  }

  console.log("Network: ", hre.network.name)
  console.log("Metadata URI: ", config.metadata_uri)

  const assets = await hre.ethers.getContractFactory("StakingVault");
  let upgradedAssets = await upgrades.deployProxy(assets,
    ["StakingVault", "SV", config.metadata_uri],
    {initializer: "initialize", kind: 'uups'})
  let a = await upgradedAssets.deployed();
  const implAddress = await upgrades.erc1967.getImplementationAddress(upgradedAssets.address);
  const adminAddress = await upgrades.erc1967.getAdminAddress(upgradedAssets.address)

  console.log("upgradedAssets proxy deployed to:", upgradedAssets.address);
  console.log("upgradedAssets admin deployed to", adminAddress);
  console.log("upgradedAssets implementation deployed to", implAddress);

  // We get the store contract to deploy
  const Stores = await ethers.getContractFactory("StakingVault");
  const store = await Stores.deploy(upgradedAssets.address, config.USDCAddress);

  await store.deployed();

  console.log("Store deployed to:", store.address);

  // Set minterRole for Store contract
  let tx = await upgradedAssets.grantRole(
    MINTER_ROLE,
    store.address
  );
  await tx.wait();
  console.log("Grant minter role to Store contract done.")

  await store.deployTransaction.wait([(confirms = 3)]);
  // verify the contracts
  await hre.run("verify:verify", {
    address: implAddress,
  });
  await hre.run("verify:verify", {
    address: store.address,
    constructorArguments: [upgradedAssets.address, config.USDCAddress],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
