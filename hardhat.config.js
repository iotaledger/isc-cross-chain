require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
require('solidity-docgen');

module.exports = {
  tokenName: process.env.TOKEN_NAME,
  tokenSymbol: process.env.TOKEN_SYMBOL,
  tokenDecimals: process.env.TOKEN_DECIMALS,
  tokenMaxSupply: process.env.TOKEN_SUPPLY,
  targetAddress: process.env.TARGET_ADDRESS,
  solidity: "0.8.20",
  networks: {
    ShimmerEVMTestnet: {
      url: process.env.SHIMMEREVM_JSONRPC || "https://json-rpc.evm.testnet.shimmer.network",
      chainId: process.env.SHIMMEREVM_CHAINID ? parseInt(process.env.SHIMMEREVM_CHAINID) : 1073,
      accounts: [ process.env.PRIVATE_KEY ]
    },
    OriginTestnet: {
      url: process.env.ORIGIN_NODE_URL,
      chainId: parseInt(process.env.ORIGIN_NETWORK_ID),
      accounts: [ process.env.DEPLOYER_PRIVATE_KEY ]
    },
    TargetTestnet: {
      url: process.env.TARGET_NODE_URL,
      chainId:  parseInt(process.env.TARGET_NETWORK_ID),
      accounts: [ process.env.DEPLOYER_PRIVATE_KEY ]
    }
  },
  etherscan: {
    apiKey:
        {
          ShimmerEVMTestnet: "no-api-key-required"
        },
    customChains: [
      {
        apikey: "no-api-key-required",
        network: "ShimmerEVMTestnet",
        chainId: process.env.SHIMMEREVM_CHAINID ? parseInt(process.env.SHIMMEREVM_CHAINID) : 1073,
        urls: {
          apiURL: "https://explorer.evm.testnet.shimmer.network/api",
          browserURL: "https://explorer.evm.testnet.shimmer.network/"
        }
      }
    ]
  },
  docgen: {
    pages:"files"
  }
};
