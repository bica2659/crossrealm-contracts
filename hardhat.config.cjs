require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: "shanghai"
    }
  },
  networks: {
    coreMainnet: {
      url: process.env.CORE_MAINNET_RPC || "https://rpc.coredao.org",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1116,
      gasPrice: "auto"
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
    customChains: [{
      network: "coreMainnet",
      chainId: 1116,
      urls: {
        apiURL: "https://api.scan.coredao.org/api",
        browserURL: "https://scan.coredao.org"
      }
    }]
  }
};