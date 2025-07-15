import { task } from 'hardhat/config'
import {ethers} from "hardhat";
import { BifrostPolakdotDest, BifrostMultisig, Bsc } from '../constants'

// yarn hardhat initialize --network bsc
// yarn hardhat initialize --network arbitrum
// yarn hardhat initialize --network optimistic
// yarn hardhat initialize --network base
// yarn hardhat initialize --network ethereum

task("initialize")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]
        let tx;

        for (const vTokenAddress of [Bsc.V_BNC, Bsc.V_GLMR]) {
          console.log(`===============================================`, vTokenAddress)
          const vToken = await hre.ethers.getContractAt("VToken", vTokenAddress, owner)
          tx = await vToken.setOracle(Bsc.Oracle);
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
          console.log(`===============================================`)
        }
    });
