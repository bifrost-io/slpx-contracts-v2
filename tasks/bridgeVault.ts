import { task } from 'hardhat/config'
import {ethers} from "hardhat";
import { Bsc } from '../constants'

// yarn hardhat bridgeVault --network bsc_testnet
// yarn hardhat bridgeVault --network bsc
// yarn hardhat bridgeVault --network arbitrum
// yarn hardhat bridgeVault --network optimistic
// yarn hardhat bridgeVault --network base
// yarn hardhat bridgeVault --network ethereum

task("bridgeVault")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]
        const bridgeVault = await hre.ethers.getContractAt("BridgeVault", Bsc.BridgeVault, owner)
        let tx = await bridgeVault.addVTokenAddress(Bsc.V_ASTR);
        tx.wait()
        console.log(`✅ Message Sent [${hre.network.name}] addVTokenAddress() to : ${tx.hash}`)
        tx = await bridgeVault.addVTokenAddress(Bsc.V_BNC);
        tx.wait()
        console.log(`✅ Message Sent [${hre.network.name}] addVTokenAddress() to : ${tx.hash}`)
        tx = await bridgeVault.addVTokenAddress(Bsc.V_GLMR);
        tx.wait()
        console.log(`✅ Message Sent [${hre.network.name}] addVTokenAddress() to : ${tx.hash}`)
    });
