require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,  // Fixes "stack too deep"
    },
  },
  networks: {
    core: {
      url: "https://rpc.coredao.org",
      accounts: process.env.CORE_PRIVATE_KEY ? [process.env.CORE_PRIVATE_KEY] : [],
      chainId: 1116,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};