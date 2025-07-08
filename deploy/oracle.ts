import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc_Testnet, Bsc, Ethereum, Arbitrum, Optimism, Base, Soneium } from "../constants";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running Oracle deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let host = "";

  switch (network.name) {
    case Bsc_Testnet.name:
      host = Bsc_Testnet.IsmpHost;
      break;
    case Bsc.name:
      host = Bsc.IsmpHost;
      break;
    case Ethereum.name:
      host = Ethereum.IsmpHost;
      break;
    case Arbitrum.name:
      host = Arbitrum.IsmpHost;
      break;
    case Optimism.name:
      host = Optimism.IsmpHost;
      break;
    case Base.name:
      host = Base.IsmpHost;
      break;
    case Soneium.name:
      host = Soneium.IsmpHost;
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
    ]
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["Oracle"];
