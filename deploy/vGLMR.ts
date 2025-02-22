import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vGLMR deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deployer is :", deployer);
  await deploy("vGLMR", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            "0xF83455EBd661eB4f414aD3BF252a62b08C3f990C",
            "0x8Ce84E9Fa0101D317D8956D73610ad3e0E219d41",
          ],
        },
      },
    },
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["vGLMR"];
