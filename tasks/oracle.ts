import { task } from 'hardhat/config'
import {ethers} from "hardhat";

// yarn hardhat oracle --network bsc_testnet --address 0xF1d4797E51a4640a76769A50b57abE7479ADd3d8 --token 0x667b70d97E3fd39530c6DED23E285c04e35D36d8 --amount 1000000000000000000
// yarn hardhat oracleSetFeeRate --network bsc --address 0x5b631863dF1B20AFb2715ee1F1381D6Dc1Dd065d  --mint-fee-rate 0 --redeem-fee-rate 10
// yarn hardhat oracleSetFeeRate --network arbitrum --address 0x5b631863dF1B20AFb2715ee1F1381D6Dc1Dd065d  --mint-fee-rate 0 --redeem-fee-rate 10
// yarn hardhat oracleSetFeeRate --network optimistic --address 0x5b631863dF1B20AFb2715ee1F1381D6Dc1Dd065d  --mint-fee-rate 0 --redeem-fee-rate 10
// yarn hardhat oracleSetFeeRate --network base --address 0x5b631863dF1B20AFb2715ee1F1381D6Dc1Dd065d  --mint-fee-rate 0 --redeem-fee-rate 10
// yarn hardhat oracleSetFeeRate --network ethereum --address 0x5b631863dF1B20AFb2715ee1F1381D6Dc1Dd065d  --mint-fee-rate 0 --redeem-fee-rate 10

task("oracle")
    .addParam('address', ``)
    .addParam('token', ``)
    .addParam('amount', ``)
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        const oracle = await hre.ethers.getContractAt("Oracle", taskArgs.address)

        const vTokenAmount = await oracle.getVTokenAmountByToken(taskArgs.token, taskArgs.amount, 0);
        console.log(`✅ Message Sent [${hre.network.name}] balanceOf() to : ${vTokenAmount}`)

        const tokenAmount = await oracle.getTokenAmountByVToken(taskArgs.token, taskArgs.amount, 0);
        console.log(`✅ Message Sent [${hre.network.name}] balanceOf() to : ${tokenAmount}`)
    });

task("oracleSetFeeRate")
    .addParam('address', ``)
    .addParam('mintFeeRate', ``)
    .addParam('redeemFeeRate', ``)
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        const oracle = await hre.ethers.getContractAt("Oracle", taskArgs.address)

        const tx = await oracle.setFeeRate(taskArgs.mintFeeRate, taskArgs.redeemFeeRate, {
            from: owner.address,
        })
        console.log(`✅ Message Sent [${hre.network.name}] setFeeRate() to : ${tx.hash}`)
    });
