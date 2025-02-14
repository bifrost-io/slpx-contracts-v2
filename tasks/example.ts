import { task } from 'hardhat/config'

task("example", "Example task")
    .setAction(async (taskArgs, hre) => {
        console.log("Example task")
    });