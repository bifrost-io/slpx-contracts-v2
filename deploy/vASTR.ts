import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc, BifrostMultisig, Ethereum, Arbitrum, Optimistic, Base } from "../constants";
const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vASTR deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = "Bifrost Voucher ASTR"
  const symbol = "vASTR"
  let astrAddress = ""
  let multiSignatureAddress = ""
  switch (network.name) {
    case Bsc.name:
      astrAddress = Bsc.ASTR
      multiSignatureAddress = Bsc.MultiSignature
      break
    case Ethereum.name:
      astrAddress = Ethereum.ASTR
      multiSignatureAddress = Ethereum.MultiSignature
      break
    case Arbitrum.name:
      astrAddress = Arbitrum.ASTR
      multiSignatureAddress = Arbitrum.MultiSignature
      break
    case Optimistic.name:
      astrAddress = Optimistic.ASTR
      multiSignatureAddress = Optimistic.MultiSignature
      break
    case Base.name:
      astrAddress = Base.ASTR
      multiSignatureAddress = Base.MultiSignature
      break
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("vASTR", {
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
            astrAddress,
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

deployFunction.tags = ["vASTR"];
