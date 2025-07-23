import { task } from 'hardhat/config'
import {ethers} from "hardhat";
import { BifrostMultisig } from "../constants";

// yarn hardhat checkMultisig --network arbitrum
// yarn hardhat checkMultisig --network base
// yarn hardhat checkMultisig --network bsc
// yarn hardhat checkMultisig --network ethereum
// yarn hardhat checkMultisig --network optimistic

// yarn hardhat transferOwnership --network arbitrum

// yarn hardhat transactionCount --network arbitrum 55
// yarn hardhat transactionCount --network base 55
// yarn hardhat transactionCount --network bsc 55
// yarn hardhat transactionCount --network ethereum 55
// yarn hardhat transactionCount --network optimistic 55


const abi = [
  "function owner() view returns (address)",
  "function transferOwnership(address newOwner) external"
]

const Contracts = [
  {name: "DefaultProxyAdmin", address: "0xB079fA0C53c2da05eA517Ffc545Cd7E3C180a136"},
  {name: "vASTR", address: "0xf659c15AEB6E41A9edAcBbF3fAeF3902c7f3fE1b"},
  {name: "vBNC", address: "0x61c57c187557442393a96bA8e6FDfE27610832a5"},
  {name: "vDOT", address: "0xBC33B4D48f76d17A1800aFcB730e8a6AAada7Fe5"},
  {name: "vGLMR", address: "0x0Bc2e0cab4AD1Dd1398D70bc268c0502e8A6DF24"},
  {name: "Oracle", address: "0x5b631863dF1B20AFb2715ee1F1381D6Dc1Dd065d"},
  {name: "BridgeVault", address: "0x32c7D417a8B28A99B7993436eADC3De175a277E0"},
]

task("checkMultisig")
    .setAction(async (taskArg, hre) => {
      for (const contract of Contracts) {
        const multisig = await hre.ethers.getContractAt(abi, contract.address)
        const owner = await multisig.owner()
        console.log(`✅ [${contract.name}] Owner: ${owner}`)
        if (owner !== BifrostMultisig) {
           throw new Error(`❌ [${contract.name}] Owner is not Bifrost Multisig`)
        }
      }
});

task("transferOwnership")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let caller = signers[0]
        console.log(`✅ Caller: ${caller.address}`)
        for (const contract of Contracts) {
          const multisig = await hre.ethers.getContractAt(abi, contract.address)
          const tx = await multisig.transferOwnership(BifrostMultisig)
          await tx.wait()
          console.log(`✅ [${contract.name}] Transfer Ownership: ${tx.hash}`)
        }
});

task("transactionCount")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let caller = signers[0]
        console.log(`✅ Caller: ${caller.address}`)
        const txCount = await hre.ethers.provider.getTransactionCount('0x8Ce84E9Fa0101D317D8956D73610ad3e0E219d41')
        console.log(`✅ Transaction Count: ${txCount}`)
});
