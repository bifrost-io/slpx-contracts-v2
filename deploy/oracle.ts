import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc_Testnet, Bsc, Ethereum, Arbitrum, Optimism, Base, Soneium, BifrostPaseoDest, BifrostPolakdotDest } from "../constants";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running Oracle deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let host = "";
  let bifrostChainId = "";

  switch (network.name) {
    case Bsc_Testnet.name:
      host = Bsc_Testnet.IsmpHost;
      bifrostChainId = BifrostPaseoDest;
      break;
    case Bsc.name:
      host = Bsc.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Ethereum.name:
      host = Ethereum.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Arbitrum.name:
      host = Arbitrum.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Optimism.name:
      host = Optimism.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Base.name:
      host = Base.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Soneium.name:
      host = Soneium.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("Oracle", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    args: [
      host,
      bifrostChainId
    ]
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["Oracle"];
