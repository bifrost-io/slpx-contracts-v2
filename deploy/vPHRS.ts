import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Pharos_Testnet } from "../constants";
const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vPHRS deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = "Bifrost Voucher PHRS"
  const symbol = "vPHRS"
  let multiSignatureAddress = ""
  let wphrsAddress = ""
  switch (network.name) {
    case Pharos_Testnet.name:
      wphrsAddress = Pharos_Testnet.W_PHRS
      multiSignatureAddress = Pharos_Testnet.MultiSignature
      break
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("VPHRS", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    contract: "VPHRS",
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            wphrsAddress,
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

deployFunction.tags = ["VPHRS"];
