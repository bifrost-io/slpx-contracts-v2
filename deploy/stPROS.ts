import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Pharos_Testnet } from "../constants";
const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running stPROS deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = "Faroo Staked PROS"
  const symbol = "stPROS"
  let multiSignatureAddress = ""
  let wprosAddress = ""
  switch (network.name) {
    case Pharos_Testnet.name:
      wprosAddress = Pharos_Testnet.W_PROS
      multiSignatureAddress = Pharos_Testnet.MultiSignature
      break
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("stPROS", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    contract: "stPROS",
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            wprosAddress,
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

deployFunction.tags = ["stPROS"];
