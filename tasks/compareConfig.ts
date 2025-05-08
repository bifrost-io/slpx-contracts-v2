import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import chalk from 'chalk';
import { Contract } from 'ethers';
import fs from 'fs';

// 定义要对比的网络
const NETWORKS = [
  'ethereum',
  'optimistic',
  'arbitrum',
  'bsc',
  'base',
  'astar',
  'moonbeam',
  'moonriver',
];

// 定义合约信息结构
interface ContractInfo {
  network: string;
  contractName: string;
  settings: {[key: string]: any};
}

// 获取合约对象
async function getContract(hre: HardhatRuntimeEnvironment, network: string, contractName: string): Promise<Contract | null> {
  try {
    const deploymentPath = `${__dirname}/../deployments/${network}/${contractName}.json`;
    if (!fs.existsSync(deploymentPath)) {
      console.log(chalk.yellow(`部署文件不存在: ${deploymentPath}`));
      return null;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
    const address = deployment.address;
    
    if (contractName.startsWith('v')) {
      return await hre.ethers.getContractAt('VToken', address);
    } else if (contractName === 'Oracle') {
      return await hre.ethers.getContractAt('Oracle', address);
    }
    return null;
  } catch (error) {
    console.log(chalk.yellow(`无法加载合约: ${contractName} 在 ${network} 网络上`));
    return null;
  }
}

// 获取Oracle合约配置
async function getOracleConfig(hre: HardhatRuntimeEnvironment, network: string, contractName: string): Promise<ContractInfo | null> {
  try {
    const oracle = await getContract(hre, network, contractName);
    if (!oracle) return null;
    
    const feeRateInfo = await oracle.feeRateInfo();
    const owner = await oracle.owner();
    
    return {
      network,
      contractName,
      settings: {
        owner,
        mintFeeRate: feeRateInfo.mintFeeRate.toString(),
        redeemFeeRate: feeRateInfo.redeemFeeRate.toString(),
      }
    };
  } catch (error) {
    console.log(chalk.red(`获取Oracle合约 ${contractName} 配置在 ${network} 网络上出错: ${error}`));
    return null;
  }
}

// 获取VToken合约配置
async function getVTokenConfig(hre: HardhatRuntimeEnvironment, network: string, contractName: string): Promise<ContractInfo | null> {
  try {
    const vToken = await getContract(hre, network, contractName);
    if (!vToken) return null;
    
    const owner = await vToken.owner();
    const oracle = await vToken.oracle();
    const dispatcher = await vToken.dispatcher();
    const triggerAddress = await vToken.triggerAddress();
    const maxRedeemRequestsPerUser = await vToken.maxRedeemRequestsPerUser();
    const paused = await vToken.paused();
    
    return {
      network,
      contractName,
      settings: {
        owner,
        oracle,
        dispatcher,
        triggerAddress,
        maxRedeemRequestsPerUser: maxRedeemRequestsPerUser.toString(),
        paused,
      }
    };
  } catch (error) {
    console.log(chalk.red(`获取VToken合约 ${contractName} 配置在 ${network} 网络上出错: ${error}`));
    return null;
  }
}

// 比较多个网络上相同合约的配置
function compareContractConfigs(contractInfos: ContractInfo[]) {
  if (contractInfos.length <= 1) {
    console.log(chalk.yellow(`只有一个网络的配置数据，无法进行比较`));
    return;
  }
  
  const reference = contractInfos[0];
  const refNetwork = reference.network;
  const refSettings = reference.settings;
  
  console.log(chalk.cyan(`\n对比 ${reference.contractName} 合约在不同网络上的配置:`));
  console.log(chalk.blue(`以 ${refNetwork} 网络为参考`));
  
  // 输出参考设置
  console.log(chalk.cyan(`\n${refNetwork} 网络配置:`));
  for (const [key, value] of Object.entries(refSettings)) {
    console.log(`${key}: ${chalk.green(value)}`);
  }
  
  // 对比其他网络
  for (let i = 1; i < contractInfos.length; i++) {
    const current = contractInfos[i];
    console.log(chalk.cyan(`\n${current.network} 网络配置:`));
    
    for (const [key, refValue] of Object.entries(refSettings)) {
      const currentValue = current.settings[key];
      
      // 比较配置
      if (currentValue === undefined) {
        console.log(`${key}: ${chalk.red('缺失')}`);
      } else if (currentValue.toString() === refValue.toString()) {
        console.log(`${key}: ${chalk.green(currentValue)} (与参考一致)`);
      } else {
        console.log(`${key}: ${chalk.yellow(currentValue)} (与参考不一致, 参考值: ${refValue})`);
      }
    }
    
    // 检查额外配置
    for (const [key, value] of Object.entries(current.settings)) {
      if (refSettings[key] === undefined) {
        console.log(`${key}: ${chalk.blue(value)} (参考配置中不存在)`);
      }
    }
  }
}

// 主任务函数
async function compareNetworks(taskArgs: any, hre: HardhatRuntimeEnvironment) {
  const currentNetwork = hre.network.name;
  
  // 确定要比较的合约
  const targetContract = taskArgs.contract;
  const referenceNetwork = taskArgs.reference || NETWORKS[0];
  const networksToCompare = taskArgs.targetnetworks ? taskArgs.targetnetworks.split(',') : NETWORKS;
  
  console.log(chalk.blue(`开始比较 ${targetContract} 在不同网络上的配置...`));
  console.log(chalk.blue(`参考网络: ${referenceNetwork}`));
  console.log(chalk.blue(`比较网络: ${networksToCompare.join(', ')}`));
  
  // 收集每个网络的合约配置
  const contractInfos: ContractInfo[] = [];
  
  // 确保参考网络是第一个
  const sortedNetworks = [referenceNetwork, ...networksToCompare.filter((n: string) => n !== referenceNetwork)];
  
  for (const network of sortedNetworks) {
    try {
      let contractInfo: ContractInfo | null = null;
      
      if (targetContract.startsWith('v')) {
        contractInfo = await getVTokenConfig(hre, network, targetContract);
      } else if (targetContract === 'Oracle') {
        contractInfo = await getOracleConfig(hre, network, targetContract);
      } else {
        console.log(chalk.red(`不支持的合约类型: ${targetContract}`));
        continue;
      }
      
      if (contractInfo) {
        contractInfos.push(contractInfo);
      }
    } catch (error) {
      console.log(chalk.red(`获取 ${network} 网络上的 ${targetContract} 配置时出错: ${error}`));
    }
  }
  
  // 比较配置
  compareContractConfigs(contractInfos);
}

task('compare', '比较不同网络上相同合约的配置')
  .addParam('contract', '要比较的合约名称，例如 "Oracle" 或 "vDOT"')
  .addOptionalParam('reference', '作为参考的网络名称')
  .addOptionalParam('targetnetworks', '要比较的网络列表，使用逗号分隔')
  .setAction(compareNetworks); 