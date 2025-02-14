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
  },
  etherscan: {
    apiKey: {
      moonbeam:
          process.env.MOONBEAM_API_KEY !== undefined
              ? process.env.MOONBEAM_API_KEY
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
      }
    ]
  },

};

export default config;
