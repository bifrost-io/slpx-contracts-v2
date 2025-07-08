import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc, Ethereum, Arbitrum, Optimism, Base, Bsc_Testnet } from "../constants";
const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vBNC deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = "Bifrost Voucher BNC"
  const symbol = "vBNC"
  let bncAddress = ""
  let multiSignatureAddress = ""
  switch (network.name) {
    case Bsc_Testnet.name:
      bncAddress = Bsc_Testnet.BNC
      multiSignatureAddress = Bsc_Testnet.MultiSignature
      break
    case Bsc.name:
      bncAddress = Bsc.BNC
      multiSignatureAddress = Bsc.MultiSignature
      break
    case Ethereum.name:
      bncAddress = Ethereum.BNC
      multiSignatureAddress = Ethereum.MultiSignature
      break
    case Arbitrum.name:
      bncAddress = Arbitrum.BNC
      multiSignatureAddress = Arbitrum.MultiSignature
      break
    case Optimism.name:
      bncAddress = Optimism.BNC
      multiSignatureAddress = Optimism.MultiSignature
      break
    case Base.name:
      bncAddress = Base.BNC
      multiSignatureAddress = Base.MultiSignature
      break
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("vBNC", {
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
            bncAddress,
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

deployFunction.tags = ["vBNC"];
