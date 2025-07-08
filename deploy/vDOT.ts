import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc, Ethereum, Arbitrum, Optimism, Base } from "../constants";
const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vDOT deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = "Polkadot"
  const symbol = "DOT"
  let dotAddress = ""
  let multiSignatureAddress = ""
  switch (network.name) {
    case Bsc.name:
      dotAddress = Bsc.DOT
      multiSignatureAddress = Bsc.MultiSignature
      break
    case Ethereum.name:
      dotAddress = Ethereum.DOT
      multiSignatureAddress = Ethereum.MultiSignature
      break
    case Arbitrum.name:
      dotAddress = Arbitrum.DOT
      multiSignatureAddress = Arbitrum.MultiSignature
      break
    case Optimism.name:
      dotAddress = Optimism.DOT
      multiSignatureAddress = Optimism.MultiSignature
      break
    case Base.name:
      dotAddress = Base.DOT
      multiSignatureAddress = Base.MultiSignature
      break
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("vDOT", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    contract: "VToken",
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            dotAddress,
            multiSignatureAddress,
            name,
            symbol,
          ],
        },
      },
    },
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["vDOT"];
