import { task } from 'hardhat/config'
import {ethers} from "hardhat";
import { BifrostMultisig } from "../constants";

// yarn hardhat multisig --network arbitrum
// yarn hardhat multisig --network base
// yarn hardhat multisig --network bsc
// yarn hardhat multisig --network ethereum
// yarn hardhat multisig --network optimistic

// yarn hardhat transferOwnership --network arbitrum

const abi = [
  "function owner() view returns (address)",
  "function transferOwnership(address newOwner) external"
]

const Contracts = [
  // {name: "DefaultProxyAdmin", address: "0xB079fA0C53c2da05eA517Ffc545Cd7E3C180a136"},
  {name: "vASTR", address: "0xf659c15AEB6E41A9edAcBbF3fAeF3902c7f3fE1b"},
  {name: "vBNC", address: "0x61c57c187557442393a96bA8e6FDfE27610832a5"},
  // {name: "vDOT", address: "0xBC33B4D48f76d17A1800aFcB730e8a6AAada7Fe5"},
  {name: "vGLMR", address: "0x0Bc2e0cab4AD1Dd1398D70bc268c0502e8A6DF24"}
]

task("multisig")
    .setAction(async (taskArg, hre) => {
      for (const contract of Contracts) {
        const multisig = await hre.ethers.getContractAt(abi, contract.address)
        const owner = await multisig.owner()
        console.log(`✅ [${contract.name}] Owner: ${owner}`)
        if (owner !== BifrostMultisig) {
           throw new Error(`✅ [${contract.name}] Owner is not Bifrost Multisig`)
        }
      }

      const txCount = await hre.ethers.provider.getTransactionCount(BifrostMultisig)
      console.log(`✅ Transaction Count: ${txCount}`)
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
