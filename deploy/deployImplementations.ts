import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc_Testnet, BifrostMultisig, Bsc, Ethereum, Arbitrum, Optimistic, Base, Soneium } from "../constants";
import { ethers } from "hardhat";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
  ethers,
}: HardhatRuntimeEnvironment) {
  console.log("Running Batch Contract Upgrade deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // 获取当前网络的配置
  let networkConfig;
  switch (network.name) {
    case Bsc.name:
      networkConfig = Bsc;
      break;
    case Ethereum.name:
      networkConfig = Ethereum;
      break;
    case Arbitrum.name:
      networkConfig = Arbitrum;
      break;
    case Optimistic.name:
      networkConfig = Optimistic;
      break;
    case Base.name:
      networkConfig = Base;
      break;
    default:
      throw new Error("Network not supported");
  }

  console.log("Network:", network.name);
  console.log("Deployer is:", deployer);

  const contractsToUpgrade = ["vASTR", "vBNC", "vGLMR"];
  
  for (const contractName of contractsToUpgrade) {
    console.log(`Deploying implementation for ${contractName}...`);
        const result = await deploy(`${contractName}_Implementation`, {
          from: deployer,
          log: true,
          deterministicDeployment: false,
          contract: "VToken",
    });
    console.log(`${contractName} implementation deployed to ${result.address}`);    
  }
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["deployImplementations"]; 