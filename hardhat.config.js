require("dotenv").config();

require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-solhint");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("hardhat-contract-sizer");
require("hardhat-interface-generator");
require("@openzeppelin/hardhat-upgrades");

const { task } = require("hardhat/config");

// const PRIVATE_KEY = process.env.PRIVATE_KEY;
const withOptimizations = true;
const defaultNetwork = "hardhat"; // "hardhat" for tests

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: withOptimizations,
        runs: 200,
      },
    },
  },
  defaultNetwork: defaultNetwork,
  networks: {
    hardhat: {
      blockGasLimit: 10000000,
      allowUnlimitedContractSize: !withOptimizations,
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/PZd297vs-VHFPPcF4mRaayWFRgdHKn6I`,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      // gas: 19_000_000,
      // gasPrice: 100_000_000_000,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/19de54b594234ffb978a4e81f18a9827`,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/Wv3e5nXZ2iUmDVYSU_ZdcDkCSsIqX9iz`,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    bsctest_maintoken: {
      url: `https://endpoints.omniatech.io/v1/bsc/testnet/public`,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    bsctest_token: {
      url: `https://endpoints.omniatech.io/v1/bsc/testnet/public`,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    bsc_maintoken: {
      url: `https://endpoints.omniatech.io/v1/bsc/mainnet/public`,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    bsc_token: {
      url: `https://endpoints.omniatech.io/v1/bsc/mainnet/public`,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  contractSizer: {
    alphaSort: false,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: false,
  },
  mocha: {
    timeout: 9999999999,
  },
};
