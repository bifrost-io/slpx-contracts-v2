import fs from "fs";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import * as dotenv from "dotenv";
import "./tasks";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  paths: {
    sources: "./contracts", // Use ./src rather than ./contracts as Hardhat expects
    cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
  },
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    manta: {
      url: "https://pacific-rpc.manta.network/http",
      chainId: 169,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    ethereum: {
      url: "https://ethereum-rpc.publicnode.com",
      chainId: 1,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    }, 
    optimistic: {
      url: "https://optimism-rpc.publicnode.com",
      chainId: 10,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    arbitrum: {
      url: "https://arbitrum-one.public.blastapi.io",
      chainId: 42161,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    bsc: {
      url: "https://bsc-mainnet.public.blastapi.io",
      chainId: 56,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    base: {
      url: "https://mainnet.base.org",
      chainId: 8453,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    base_testnet: {
      url: "https://sepolia.base.org",
      chainId: 84532,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    soneium: {
      url: "https://rpc.soneium.org",
      chainId: 1868,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    astar: {
      url: "https://evm.astar.network",
      chainId: 592,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    moonbeam: {
      url: "https://rpc.api.moonbeam.network",
      chainId: 1284,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    moonriver: {
      url: "https://moonriver.unitedbloc.com:2000",
      chainId: 1285,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    base_local: {
      url: "http://localhost:8545",
      chainId: 8453,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    base_testnet_local: {
      url: "http://localhost:8545",
      chainId: 84532,
      accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      moonbeam:
          process.env.MOONBEAM_API_KEY !== undefined
              ? process.env.MOONBEAM_API_KEY
              : "",
      base_testnet:
          process.env.BASE_TESTNET_API_KEY !== undefined
              ? process.env.BASE_TESTNET_API_KEY
              : "",
      mainnet:
          process.env.ETHEREUM_API_KEY !== undefined
              ? process.env.ETHEREUM_API_KEY
              : "",      
      optimisticEthereum:
          process.env.OP_API_KEY !== undefined
              ? process.env.OP_API_KEY
              : "",  
      arbitrumOne:
          process.env.ARB_API_KEY !== undefined
              ? process.env.ARB_API_KEY
              : "", 
      bsc:
          process.env.BSC_API_KEY !== undefined
              ? process.env.BSC_API_KEY
              : "",      
      base:
          process.env.BASE_API_KEY !== undefined
              ? process.env.BASE_API_KEY
              : "",
      moonriver:
          process.env.MOONRIVER_API_KEY !== undefined
              ? process.env.MOONRIVER_API_KEY
              : "",
      astar:
          process.env.ASTAR_API_KEY !== undefined
              ? process.env.ASTAR_API_KEY
              : "",
      soneium:
          process.env.SONEIUM_API_KEY !== undefined
              ? process.env.SONEIUM_API_KEY
              : "",
      moonbaseAlpha: "INSERT_MOONSCAN_API_KEY", // Moonbeam Moonscan API Key
    },
    customChains: [
      {
        network: "astar",
        chainId: 592,
        urls: {
          apiURL: "https://astar.blockscout.com/api",
          browserURL: "https://astar.blockscout.com"
        }
      },
      {
        network: "soneium",
        chainId: 1868,
        urls: {
          apiURL: "https://soneium.blockscout.com/api",
          browserURL: "https://soneium.blockscout.com"
        }
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      },
      {
        network: "base_testnet",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      }
    ]
  },

};

export default config;
