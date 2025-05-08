import { task } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import chalk from 'chalk';
import { Contract } from 'ethers';
import fs from 'fs';

// 定义要监控的网络
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

// 定义合约类型
enum ContractType {
  ORACLE = 'Oracle',
  VTOKEN = 'VToken',
}

// 定义检查结果
interface CheckResult {
  name: string;
  value: string;
  expected?: string;
  isCorrect: boolean;
}

// 获取合约对象
async function getContract(hre: HardhatRuntimeEnvironment, network: string, contractName: string, contractType: ContractType): Promise<Contract | null> {
  try {
    const deploymentPath = `${__dirname}/../deployments/${network}/${contractName}.json`;
    if (!fs.existsSync(deploymentPath)) {
      console.log(chalk.yellow(`[${network}] ${contractName} 部署文件不存在`));
      return null;
    }
    
    const deployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
    const address = deployment.address;
    
    try {
      if (contractType === ContractType.ORACLE) {
        return await hre.ethers.getContractAt('Oracle', address);
      } else if (contractType === ContractType.VTOKEN) {
        return await hre.ethers.getContractAt('VToken', address);
      }
    } catch (error) {
      console.log(chalk.yellow(`[${network}] ${contractName} 合约构件不存在，请先编译合约`));
      return null;
    }
    return null;
  } catch (error) {
    console.log(chalk.yellow(`[${network}] ${contractName} 加载失败: ${error}`));
    return null;
  }
}

// 检查Oracle合约
async function checkOracleContract(hre: HardhatRuntimeEnvironment, network: string, contractName: string): Promise<CheckResult[]> {
  const results: CheckResult[] = [];
  
  try {
    const oracle = await getContract(hre, network, contractName, ContractType.ORACLE);
    if (!oracle) return results;
    
    // 检查所有者
    const owner = await oracle.owner();
    results.push({
      name: '所有者',
      value: owner,
      isCorrect: true, // 这里仅记录不判断正确性
    });
    
    // 检查费率
    const feeRateInfo = await oracle.feeRateInfo();
    results.push({
      name: '铸造费率',
      value: (feeRateInfo.mintFeeRate / 100).toString() + '%',
      isCorrect: true,
    });
    results.push({
      name: '赎回费率',
      value: (feeRateInfo.redeemFeeRate / 100).toString() + '%',
      isCorrect: true,
    });
    
    // 检查常量 (我们无法直接读取private常量，这里只是示例)
    // 在实际应用中，可以通过调用相关函数来间接验证常量值
    
  } catch (error) {
    console.log(chalk.red(`检查Oracle合约 ${contractName} 在 ${network} 网络上时出错: ${error}`));
  }
  
  return results;
}

// 检查VToken合约
async function checkVTokenContract(hre: HardhatRuntimeEnvironment, network: string, contractName: string): Promise<CheckResult[]> {
  const results: CheckResult[] = [];
  
  try {
    const vToken = await getContract(hre, network, contractName, ContractType.VTOKEN);
    if (!vToken) return results;
    
    // 检查所有者
    const owner = await vToken.owner();
    results.push({
      name: '所有者',
      value: owner,
      isCorrect: true,
    });
    
    // 检查是否暂停
    const paused = await vToken.paused();
    results.push({
      name: '暂停状态',
      value: paused ? '已暂停' : '运行中',
      isCorrect: true,
    });
    
    // 检查Oracle地址
    const oracle = await vToken.oracle();
    results.push({
      name: 'Oracle地址',
      value: oracle,
      isCorrect: true,
    });
    
    // 检查Dispatcher地址
    const dispatcher = await vToken.dispatcher();
    results.push({
      name: 'Dispatcher地址',
      value: dispatcher,
      isCorrect: true,
    });
    
    // 检查触发地址
    const triggerAddress = await vToken.triggerAddress();
    results.push({
      name: '触发地址',
      value: triggerAddress,
      isCorrect: true,
    });
    
    // 检查最大赎回请求数
    const maxRedeemRequestsPerUser = await vToken.maxRedeemRequestsPerUser();
    results.push({
      name: '每用户最大赎回请求数',
      value: maxRedeemRequestsPerUser.toString(),
      isCorrect: true,
    });
    
  } catch (error) {
    console.log(chalk.red(`检查VToken合约 ${contractName} 在 ${network} 网络上时出错: ${error}`));
  }
  
  return results;
}

// 校验交易权限
async function checkUpgradePermissions(hre: HardhatRuntimeEnvironment, network: string): Promise<CheckResult[]> {
  const results: CheckResult[] = [];
  
  try {
    // 获取代理管理员合约
    const deploymentPath = `${__dirname}/../deployments/${network}/DefaultProxyAdmin.json`;
    if (!fs.existsSync(deploymentPath)) {
      console.log(chalk.yellow(`代理管理员部署文件不存在: ${deploymentPath}`));
      return results;
    }
    
    const proxyAdminDeployment = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
    const proxyAdmin = await hre.ethers.getContractAt('ProxyAdmin', proxyAdminDeployment.address);
    
    // 检查代理管理员的所有者
    const owner = await proxyAdmin.owner();
    results.push({
      name: '代理管理员所有者',
      value: owner,
      isCorrect: true,
    });
    
  } catch (error) {
    console.log(chalk.yellow(`无法检查升级权限在 ${network} 网络上: ${error}`));
  }
  
  return results;
}

// 主任务函数
async function monitorContracts(taskArgs: any, hre: HardhatRuntimeEnvironment) {
  // 获取当前网络
  const currentNetwork = hre.network.name;
  
  if (taskArgs.targetnetwork && taskArgs.targetnetwork !== currentNetwork) {
    console.log(chalk.yellow(`切换到指定网络: ${taskArgs.targetnetwork}`));
    const networkConfig = hre.config.networks[taskArgs.targetnetwork] as { url: string };
    await hre.network.provider.request({
      method: "hardhat_reset",
      params: [{
        forking: {
          jsonRpcUrl: networkConfig.url,
          blockNumber: undefined
        }
      }]
    });
  }
  
  // 如果指定了特定网络，只检查该网络
  const networksToCheck = taskArgs.targetnetwork ? [taskArgs.targetnetwork] : NETWORKS;
  
  // 统计信息
  const stats = {
    totalNetworks: networksToCheck.length,
    networksWithDeployments: 0,
    networksWithoutDeployments: 0,
    contractsFound: 0,
    contractsMissing: 0,
    artifactsMissing: 0
  };
  
  for (const network of networksToCheck) {
    try {
      console.log(chalk.blue(`\n======== 检查 ${network} 网络 ========`));
      
      // 获取部署的合约列表
      let deployedContracts: string[] = [];
      try {
        // 尝试读取部署目录中的文件
        const deploymentDir = `${__dirname}/../deployments/${network}`;
        if (!fs.existsSync(deploymentDir)) {
          console.log(chalk.yellow(`[${network}] 部署目录不存在`));
          stats.networksWithoutDeployments++;
          continue;
        }
        
        deployedContracts = fs.readdirSync(deploymentDir)
          .filter((file: string) => file.endsWith('.json') && !file.includes('_Implementation') && !file.includes('_Proxy') && file !== 'DefaultProxyAdmin.json');
        
        if (deployedContracts.length > 0) {
          stats.networksWithDeployments++;
        } else {
          stats.networksWithoutDeployments++;
        }
      } catch (error) {
        console.log(chalk.yellow(`[${network}] 无法获取部署合约列表: ${error}`));
        stats.networksWithoutDeployments++;
        continue;
      }
      
      // 检查升级权限
      console.log(chalk.cyan('\n升级权限检查:'));
      try {
        const upgradeResults = await checkUpgradePermissions(hre, network);
        if (upgradeResults.length > 0) {
          upgradeResults.forEach(result => {
            console.log(`${result.name}: ${chalk.green(result.value)}`);
          });
        } else {
          console.log(chalk.yellow(`[${network}] 无法检查升级权限`));
          stats.artifactsMissing++;
        }
      } catch (error) {
        console.log(chalk.yellow(`[${network}] 升级权限检查失败: ${error}`));
        stats.artifactsMissing++;
      }
      
      // 检查每个合约
      for (const contractFile of deployedContracts) {
        const contractName = contractFile.replace('.json', '');
        
        if (contractName.startsWith('v')) {
          // 是VToken合约
          console.log(chalk.cyan(`\n检查VToken合约: ${contractName}`));
          try {
            const vTokenResults = await checkVTokenContract(hre, network, contractName);
            if (vTokenResults.length > 0) {
              vTokenResults.forEach(result => {
                console.log(`${result.name}: ${chalk.green(result.value)}`);
              });
              stats.contractsFound++;
            } else {
              console.log(chalk.yellow(`[${network}] ${contractName} 无法加载合约`));
              stats.contractsMissing++;
            }
          } catch (error) {
            console.log(chalk.yellow(`[${network}] ${contractName} 检查失败: ${error}`));
            stats.contractsMissing++;
          }
        } else if (contractName === 'Oracle') {
          // 是Oracle合约
          console.log(chalk.cyan(`\n检查Oracle合约: ${contractName}`));
          try {
            const oracleResults = await checkOracleContract(hre, network, contractName);
            if (oracleResults.length > 0) {
              oracleResults.forEach(result => {
                console.log(`${result.name}: ${chalk.green(result.value)}`);
              });
              stats.contractsFound++;
            } else {
              console.log(chalk.yellow(`[${network}] ${contractName} 无法加载合约`));
              stats.contractsMissing++;
            }
          } catch (error) {
            console.log(chalk.yellow(`[${network}] ${contractName} 检查失败: ${error}`));
            stats.contractsMissing++;
          }
        }
      }
    } catch (error) {
      console.log(chalk.red(`[${network}] 网络检查失败: ${error}`));
    }
  }
  
  // 打印统计信息
  console.log(chalk.blue('\n======== 检查统计 ========'));
  console.log(`总网络数: ${stats.totalNetworks}`);
  console.log(`有部署目录的网络数: ${stats.networksWithDeployments}`);
  console.log(`无部署目录的网络数: ${stats.networksWithoutDeployments}`);
  console.log(`成功加载的合约数: ${stats.contractsFound}`);
  console.log(`无法加载的合约数: ${stats.contractsMissing}`);
  console.log(`缺少构件的合约数: ${stats.artifactsMissing}`);
  
  // 提供建议
  if (stats.artifactsMissing > 0) {
    console.log(chalk.yellow('\n建议:'));
    console.log('1. 运行 npx hardhat compile 编译合约');
    console.log('2. 确保所有合约的ABI文件都存在');
  }
  
  if (stats.contractsMissing > 0) {
    console.log(chalk.yellow('\n注意:'));
    console.log('部分合约无法加载，可能是因为:');
    console.log('1. 合约未部署');
    console.log('2. 部署文件格式不正确');
    console.log('3. 合约地址无效');
  }
}

task('monitor', '监控合约的权限、所有者和配置')
  .addOptionalParam('targetnetwork', '指定要监控的网络，如果不指定则监控所有支持的网络')
  .setAction(monitorContracts); 