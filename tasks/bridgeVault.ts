import { task } from 'hardhat/config'
import {ethers} from "hardhat";
import { Bsc } from '../constants'

// yarn hardhat bridgeVault --network bsc_testnet
// yarn hardhat bridgeVault --network bsc

task("bridgeVault")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]
        if (hre.network.name === "bsc") {
            const bridgeVault = await hre.ethers.getContractAt("BridgeVault", Bsc.BridgeVault, owner)
            let tx = await bridgeVault.addVTokenAddress(Bsc.V_ASTR);
            tx.wait()
            console.log(`✅ Message Sent [${hre.network.name}] addVTokenAddress() to : ${tx}`)
            tx = await bridgeVault.addVTokenAddress(Bsc.V_BNC);
            tx.wait()
            console.log(`✅ Message Sent [${hre.network.name}] addVTokenAddress() to : ${tx}`)
            tx = await bridgeVault.addVTokenAddress(Bsc.V_GLMR);
            tx.wait()
            console.log(`✅ Message Sent [${hre.network.name}] addVTokenAddress() to : ${tx}`)
        }
    });
