import { VToken } from './../typechain-types/contracts/VToken';
import { task } from 'hardhat/config'
import {ethers} from "hardhat";
import { hexToU8a,u8aToHex  } from "@polkadot/util"
import { WsProvider, ApiPromise } from '@polkadot/api';

// yarn hardhat approve --erc20 0x051713fD66845a13BF23BACa008C5C22C27Ccb58 --to 0x4e1A1FdE10494d714D2620aAF7B27B878458459c --network zkatana
// yarn hardhat approve --erc20 0xEaFAF3EDA029A62bCbE8a0C9a4549ef0fEd5a400 --to 0x4e1A1FdE10494d714D2620aAF7B27B878458459c --network zkatana
// manta:
// yarn hardhat approve --erc20 0x95CeF13441Be50d20cA4558CC0a27B601aC544E5 --to 0x95A4D4b345c551A9182289F9dD7A018b7Fd0f940 --network manta

// vmanta:
// yarn hardhat approve --erc20 0x7746ef546d562b443AE4B4145541a3b1a3D75717 --to 0x95A4D4b345c551A9182289F9dD7A018b7Fd0f940 --network manta

// astr
// yarn hardhat approve --erc20 0xfffFffff00000000000000010000000000000010 --to 0x4D43d8268365616aA4573362A7a470de23f9598B --network astar

// soneium vastr
// yarn hardhat approve --erc20 0x60336f9296C79dA4294A19153eC87F8E52158e5F --to 0x9D40Ca58eF5392a8fB161AB27c7f61de5dfBF0E2 --network soneium
// soneium astr
// yarn hardhat approve --erc20 0x2CAE934a1e84F693fbb78CA5ED3B0A6893259441 --to 0x9D40Ca58eF5392a8fB161AB27c7f61de5dfBF0E2 --network soneium
// yarn hardhat balance --erc20 0xf877500C6ff3cf8305245bCb3Cf1c5A6B7287aEF  --network base_local
// yarn hardhat balance --erc20 0x667b70d97E3fd39530c6DED23E285c04e35D36d8  --network base_testnet_local
// yarn hardhat balance --erc20 0x79D6028229f2d819a1a4bb52a05Bc97F5f37D667  --network base_testnet_local


const GATEWAY_ADDRESS = "0xFcDa26cA021d5535C3059547390E6cCd8De7acA6"
const GATEWAY_ABI = [{"inputs":[{"components":[{"internalType":"uint256","name":"amount","type":"uint256"},{"internalType":"uint256","name":"relayerFee","type":"uint256"},{"internalType":"bytes32","name":"assetId","type":"bytes32"},{"internalType":"bool","name":"redeem","type":"bool"},{"internalType":"bytes32","name":"to","type":"bytes32"},{"internalType":"bytes","name":"dest","type":"bytes"},{"internalType":"uint64","name":"timeout","type":"uint64"},{"internalType":"uint256","name":"nativeCost","type":"uint256"},{"internalType":"bytes","name":"data","type":"bytes"}],"internalType":"struct TeleportParams","name":"teleportParams","type":"tuple"}],"name":"teleport","outputs":[],"stateMutability":"payable","type":"function"}]

task("balance")
    .addParam('erc20', ``)
//     .addParam('to', ``)]
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        const IERC20Instance = await hre.ethers.getContractAt("IERC20", taskArgs.erc20, owner)

        const balance = await IERC20Instance.balanceOf(owner.address);
        console.log(`✅ Message Sent [${hre.network.name}] balanceOf() to : ${balance}`)


        // Get Eth balance
        const eth_balance = await hre.ethers.provider.getBalance(owner.address)
        console.log(`✅ Owner ${owner.address} Balance: ${hre.ethers.utils.formatEther(eth_balance)}`)
    });

// yarn hardhat transfer --to 0x4597C97a43dFBb4a398E2b16AA9cE61f90d801DD --network base_local

task("teleport")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        const gateway = new hre.ethers.Contract(GATEWAY_ADDRESS, GATEWAY_ABI, owner)

        let teleportParams = {
            amount: "100000000000000000",
            relayerFee: 0,
            assetId: "0x2a4161abff7b056457562a2e82dd6f5878159be2537b90f19dd1458b40524d3f",
            redeem: true,
            to: "0x28ea206ff421d348f50e0b8e8c3ccfed4a117f7c78c04b2e7be3f2c7e8fcaa40",
            dest: "0x504f4c4b41444f542d32303330",
            timeout: 21600,
            nativeCost: hre.ethers.utils.parseEther("0.0003"),
            data: "0x"
        }
        const tx = await gateway.teleport(teleportParams, { value: hre.ethers.utils.parseEther("0.0003") })
        console.log(`✅ Message Sent [${hre.network.name}] teleport() to : ${tx.hash}`)
    });


task("teleport_with_remark")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        const gateway = new hre.ethers.Contract(GATEWAY_ADDRESS, GATEWAY_ABI, owner);

        const api = await ApiPromise.create({ provider : new WsProvider('ws://127.0.0.1:8012') });
        const remark = api.tx.system.remarkWithEvent("HelloWorld").method.toHex();

        let teleportParams = {
            amount: "5000000000000000000",
            relayerFee: 0,
            assetId: "0x2a4161abff7b056457562a2e82dd6f5878159be2537b90f19dd1458b40524d3f",
            redeem: true,
            to: "0xae431bfb8a79e7b62df50eb3cfe902ba1131258926c79eae12d704868ac64e03",
            // to: "0x6d6f646ca09b1c60e86502450000000000000000000000000000000000000000",
            // dest: "0x504f4c4b41444f542d32303330",
            dest: "0x4b5553414d412d32303330",
            timeout: 0,
            nativeCost: 0,
            data: remark
        }
        const tx = await gateway.teleport(teleportParams)
        console.log(`✅ Message Sent [${hre.network.name}] teleport() to : ${tx.hash}`)
    });


 task("teleport_with_mint")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        const gateway = new hre.ethers.Contract(GATEWAY_ADDRESS, GATEWAY_ABI, owner);

        const api = await ApiPromise.create({ provider : new WsProvider('ws://127.0.0.1:8012') });
        const remark = api.tx.system.remarkWithEvent("HelloWorld").method.toHex();
        const vtokenMint = api.tx.slpx.mint(
            { Native: 'BNC' },
            "5000000000000",
            { Astar: "0x4D43d8268365616aA4573362A7a470de23f9598B" },
            "HelloWorld",
            0
        ).method.toHex();

        console.log(vtokenMint);

        let teleportParams = {
            amount: "5000000000000000000",
            relayerFee: 0,
            assetId: "0x2a4161abff7b056457562a2e82dd6f5878159be2537b90f19dd1458b40524d3f",
            redeem: true,
            to: "0xae431bfb8a79e7b62df50eb3cfe902ba1131258926c79eae12d704868ac64e03",
            dest: "0x504f4c4b41444f542d32303330",
            timeout: 0,
            nativeCost: hre.ethers.utils.parseEther("0.0005"),
            data: vtokenMint
        }
        const tx = await gateway.teleport(teleportParams, { value: hre.ethers.utils.parseEther("0.0005") })
        console.log(`✅ Message Sent [${hre.network.name}] teleport() to : ${tx.hash}`)
    });

task("teleport_with_redeem")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        const gateway = new hre.ethers.Contract(GATEWAY_ADDRESS, GATEWAY_ABI, owner);

        const api = await ApiPromise.create({ provider : new WsProvider('ws://127.0.0.1:8012') });
        const vtokenRedeem = api.tx.slpx.redeem(
            null,
            { VToken: 'BNC' },
            "5000000000000",
            { Astar: "0x4D43d8268365616aA4573362A7a470de23f9598B" }
        ).method.toHex();

        let teleportParams = {
            amount: "5000000000000000000",
            relayerFee: 0,
            assetId: "0xcb3a56c232d1a9e5f65ed22b30c66131168a14fed9ba3eddaf56e99a32654790",
            redeem: true,
            to: "0xae431bfb8a79e7b62df50eb3cfe902ba1131258926c79eae12d704868ac64e03",
            dest: "0x504f4c4b41444f542d32303330",
            timeout: 0,
            nativeCost: hre.ethers.utils.parseEther("0.0005"),
            data: vtokenRedeem
        }
        const tx = await gateway.teleport(teleportParams, { value: hre.ethers.utils.parseEther("0.0005") })
        console.log(`✅ Message Sent [${hre.network.name}] teleport() to : ${tx.hash}`)
    });

task("teleport_with_async_mint")
    .setAction(async (taskArgs, hre) => {
        let signers = await hre.ethers.getSigners()
        let owner = signers[0]

        const gateway = new hre.ethers.Contract(GATEWAY_ADDRESS, GATEWAY_ABI, owner);

        let data = hre.ethers.utils.defaultAbiCoder.encode(['uint32', 'uint256'], [
            8453,
            "9000000000000000000"
        ]);

        console.log(data);

        let teleportParams = {
            amount: "5000000000000000000",
            relayerFee: 0,
            assetId: "0x2a4161abff7b056457562a2e82dd6f5878159be2537b90f19dd1458b40524d3f",
            redeem: true,
            to: "0x6d6f646ca09b1c60e86502450000000000000000000000000000000000000000",
            dest: "0x504f4c4b41444f542d32303330",
            timeout: 0,
            nativeCost: hre.ethers.utils.parseEther("0.0005"),
            data
        }
        const tx = await gateway.teleport(teleportParams, { value: hre.ethers.utils.parseEther("0.0005") })
        console.log(`✅ Message Sent [${hre.network.name}] teleport() to : ${tx.hash}`)
    });

    // npx hardhat setBalance --account 0x4597C97a43dFBb4a398E2b16AA9cE61f90d801DD --balance 1000000000000000000