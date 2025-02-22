import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running Token deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deployer is :", deployer);
  await deploy("Token", {
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
            "0x3658e00f5DDb9Fa0c7e9820e8d16C3C17eaB73CA",
            "Bifrost Voucher GLMR",
            "vGLMR",
          ],
        },
      },
    },
  });
};

export default deployFunction;

deployFunction.dependencies = [""];

deployFunction.tags = ["Token"];
