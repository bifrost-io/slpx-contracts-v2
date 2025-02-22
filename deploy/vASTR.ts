import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vASTR deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deployer is :", deployer);
  await deploy("vASTR", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            "0x44C97257Ab904A22DAfA31E75190E3AF9331E81c",
            "0x8Ce84E9Fa0101D317D8956D73610ad3e0E219d41",
          ],
        },
      },
    },
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["vASTR"];
