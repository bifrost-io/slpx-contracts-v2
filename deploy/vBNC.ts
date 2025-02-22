import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vBNC deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deployer is :", deployer);
  await deploy("vBNC", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            "0xf877500C6ff3cf8305245bCb3Cf1c5A6B7287aEF",
            "0x8Ce84E9Fa0101D317D8956D73610ad3e0E219d41",
          ],
        },
      },
    },
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["vBNC"];
