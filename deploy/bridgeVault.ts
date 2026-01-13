import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc_Testnet, Bsc, Ethereum, Arbitrum, Optimistic, Base, Soneium, Pharos_Testnet } from "../constants";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running BridgeVault deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  let multiSignatureAddress = "";

  switch (network.name) {
    case Bsc_Testnet.name:
      multiSignatureAddress = Bsc_Testnet.MultiSignature;
      break;
    case Bsc.name:
      multiSignatureAddress = Bsc.MultiSignature;
      break;
    case Ethereum.name:
      multiSignatureAddress = Ethereum.MultiSignature;
      break;
    case Arbitrum.name:
      multiSignatureAddress = Arbitrum.MultiSignature;
      break;
    case Optimistic.name:
      multiSignatureAddress = Optimistic.MultiSignature;
      break;
    case Base.name:
      multiSignatureAddress = Base.MultiSignature;
      break;
    case Pharos_Testnet.name:
      multiSignatureAddress = Pharos_Testnet.MultiSignature;
      break;
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("BridgeVault", {
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
          ],
        },
      },
    },
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["BridgeVault"];
