require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,  // Fixes "stack too deep" errors
    },
  },
  networks: {
    core: {
      url: "https://rpc.coredao.org",
      accounts: process.env.CORE_PRIVATE_KEY ? [process.env.CORE_PRIVATE_KEY] : [],  // Safe check for undefined
      chainId: 1116,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,  // For CoreScan verification (optional)
  },
};