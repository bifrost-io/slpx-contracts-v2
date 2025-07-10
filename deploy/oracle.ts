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

  let multiSignatureAddress = "";
  let host = "";
  let bifrostChainId = "";

  switch (network.name) {
    case Bsc_Testnet.name:
      multiSignatureAddress = Bsc_Testnet.MultiSignature;
      host = Bsc_Testnet.IsmpHost;
      bifrostChainId = BifrostPaseoDest;
      break;
    case Bsc.name:
      multiSignatureAddress = Bsc.MultiSignature;
      host = Bsc.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Ethereum.name:
      multiSignatureAddress = Ethereum.MultiSignature;
      host = Ethereum.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Arbitrum.name:
      multiSignatureAddress = Arbitrum.MultiSignature;
      host = Arbitrum.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Optimism.name:
      multiSignatureAddress = Optimism.MultiSignature;
      host = Optimism.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Base.name:
      multiSignatureAddress = Base.MultiSignature;
      host = Base.IsmpHost;
      bifrostChainId = BifrostPolakdotDest;
      break;
    case Soneium.name:
      multiSignatureAddress = Soneium.MultiSignature;
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
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            multiSignatureAddress,
            host,
            bifrostChainId
          ],
        },
      },
    },
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["Oracle"];
