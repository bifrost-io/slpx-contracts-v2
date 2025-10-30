import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Bsc, BifrostMultisig, Ethereum, Arbitrum, Optimistic, Base } from "../constants";
const deployFunction: DeployFunction = async function ({
  deployments,
  getNamedAccounts,
  network,
}: HardhatRuntimeEnvironment) {
  console.log("Running vETH deploy script");

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const name = "Bifrost Voucher ETH"
  const symbol = "vETH"
  let wethAddress = ""
  let multiSignatureAddress = ""
  switch (network.name) {
    // case Ethereum.name:
    //   wethAddress = Ethereum.WETH
    //   multiSignatureAddress = Ethereum.MultiSignature
    //   break
    // case Arbitrum.name:
    //   wethAddress = Arbitrum.WETH
    //   multiSignatureAddress = Arbitrum.MultiSignature
    //   break
    // case Optimistic.name:
    //   wethAddress = Optimistic.WETH
    //   multiSignatureAddress = Optimistic.MultiSignature
    //   break
    case Base.name:
      wethAddress = Base.WETH
      multiSignatureAddress = Base.MultiSignature
      break
    default:
      throw new Error("Network not supported");
  }

  console.log("Deployer is :", deployer);
  await deploy("VETH", {
    from: deployer,
    log: true,
    deterministicDeployment: false,
    contract: "VETH",
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            wethAddress,
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

deployFunction.tags = ["VETH"];
