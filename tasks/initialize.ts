import { task } from 'hardhat/config'
import {ethers} from "hardhat";

// yarn hardhat oracle --network bsc_testnet --address 0xF1d4797E51a4640a76769A50b57abE7479ADd3d8 --token 0x667b70d97E3fd39530c6DED23E285c04e35D36d8 --amount 1000000000000000000

task("initialize")
    .addParam('address', ``)
    .addParam('dest', ``)
    .setAction(async (taskArgs, hre) => {
      //   let signers = await hre.ethers.getSigners()
      //   let owner = signers[0]

      //   const oracle = await hre.ethers.getContractAt("Oracle", taskArgs.address)

      //   const vTokenAmount = await oracle.getVTokenAmountByToken(taskArgs.token, taskArgs.amount, 0);
      //   console.log(`✅ Message Sent [${hre.network.name}] balanceOf() to : ${vTokenAmount}`)

      //   const tokenAmount = await oracle.getTokenAmountByVToken(taskArgs.token, taskArgs.amount, 0);
      //   console.log(`✅ Message Sent [${hre.network.name}] balanceOf() to : ${tokenAmount}`)
    });
