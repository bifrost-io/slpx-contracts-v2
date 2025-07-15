import { task } from 'hardhat/config'
import {ethers} from "hardhat";
import { BifrostPolakdotDest, BifrostMultisig, Bsc } from '../constants'

// yarn hardhat initialize --network bsc

task("initialize")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        if (hre.network.name === "bsc") {
          const vToken = await hre.ethers.getContractAt("VToken", Bsc.V_GLMR, owner)
          let tx = await vToken.setOracle(Bsc.Oracle);
          tx.wait()
          console.log(`✅ Message Sent [${hre.network.name}] setOracle() to : ${tx.hash}`)

          tx = await vToken.setBridgeVault(Bsc.BridgeVault);
          tx.wait()
          console.log(`✅ Message Sent [${hre.network.name}] setBridgeVault() to : ${tx.hash}`)

          tx = await vToken.setTokenGateway(Bsc.TokenGateway);
          tx.wait()
          console.log(`✅ Message Sent [${hre.network.name}] setTokenGateway() to : ${tx.hash}`)

          tx = await vToken.setBifrostDest(BifrostPolakdotDest);
          tx.wait()
          console.log(`✅ Message Sent [${hre.network.name}] setBifrostDest() to : ${tx.hash}`)
          tx = await vToken.setMaxWithdrawCount(5);
          tx.wait()
          console.log(`✅ Message Sent [${hre.network.name}] setMaxWithdrawCount() to : ${tx.hash}`)

          await vToken.transferOwnership(BifrostMultisig);
          tx.wait()
          console.log(`✅ Message Sent [${hre.network.name}] transferOwnership() to : ${tx.hash}`)
        }
    });
