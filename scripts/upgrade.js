// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const {ethers,upgrades} = require("hardhat");
const hre = require("hardhat");


// Constants
const USDCAddress = "0x0fa8781a83e46826621b3bc094ea2a0212e71b23"
const MINTER_ROLE = "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6";


async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the Assets contract to deploy
  const assets = await hre.ethers.getContractFactory("DemoUpgrade");
  let asset = await assets.deploy();
  let a= await asset.deployed();
  await asset.initialize("moco", "mc", "uuu"); 

  console.log("upgraded Assets deployed to", asset.address);

  // Set minterRole for Store contract
  let tx = await asset.grantRole(
    MINTER_ROLE,
    "0x956e90159A30B9215a1dF3C480E52A6334771920"
  );

  await tx.wait();
  console.log("Grant minter role to Store contract done.")

  await asset.deployTransaction.wait([(confirms = 3)]);
  // verify the contracts
  await hre.run("verify:verify", {
    address: asset.address,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
