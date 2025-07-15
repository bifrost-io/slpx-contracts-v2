import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc, Ethereum, Arbitrum, Optimistic, Base } from "../constants";
const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vGLMR deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = "Bifrost Voucher GLMR"
  const symbol = "vGLMR"
  let glmrAddress = ""
  let multiSignatureAddress = ""
  switch (network.name) {
    case Bsc.name:
      glmrAddress = Bsc.GLMR
      multiSignatureAddress = Bsc.MultiSignature
      break
    case Ethereum.name:
      glmrAddress = Ethereum.GLMR
      multiSignatureAddress = Ethereum.MultiSignature
      break
    case Arbitrum.name:
      glmrAddress = Arbitrum.GLMR
      multiSignatureAddress = Arbitrum.MultiSignature
      break
    case Optimistic.name:
      glmrAddress = Optimistic.GLMR
      multiSignatureAddress = Optimistic.MultiSignature
      break
    case Base.name:
      glmrAddress = Base.GLMR
      multiSignatureAddress = Base.MultiSignature
      break
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("vGLMR", {
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
            glmrAddress,
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

deployFunction.tags = ["vGLMR"];
