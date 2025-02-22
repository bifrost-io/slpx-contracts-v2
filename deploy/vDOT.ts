import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vDOT deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deployer is :", deployer);
  await deploy("vDOT", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            "0x8d010bf9C26881788b4e6bf5Fd1bdC358c8F90b8",
            "0x8Ce84E9Fa0101D317D8956D73610ad3e0E219d41",
          ],
        },
      },
    },
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["vDOT"];
