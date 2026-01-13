import {ethers} from "hardhat";
import { task } from 'hardhat/config'
import { Pharos_Testnet } from '../constants';


task("stpros_mint")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]
        let tx;
        const vphrs = await hre.ethers.getContractAt("stPROS", Pharos_Testnet.st_PROS, owner)
        tx = await vphrs.depositWithPROS({value: "1000000000000000000"});
        tx.wait()
        console.log(`✅ Message Sent [${hre.network.name}] depositWithPROS() to : ${tx.hash}`)
    });
