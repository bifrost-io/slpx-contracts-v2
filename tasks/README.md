# SLPX 合约监测任务

本目录包含一系列用于监控和验证SLPX合约的Hardhat任务。这些任务可以帮助您检查部署在不同网络上的合约配置、权限和常量值，确保它们符合预期并保持一致性。

## 安装依赖

在运行这些任务之前，确保安装了所需的依赖：

```bash
npm install --save-dev @types/node chalk@4.1.2 --legacy-peer-deps --force
```

## 环境配置

1. 复制`.env.example`文件为`.env`
2. 在`.env`文件中配置：
   - RPC URLs：各网络的RPC节点地址（必需）
   - API Keys：各网络的区块浏览器API密钥（可选，仅用于合约验证）
   - 注意：监测任务不需要私钥，因为我们只是读取合约状态，不需要发送交易

## 可用任务

### 1. 监控合约配置 (`monitor`)

监控各链上所有合约的权限、所有者和配置信息。

**用法**：
```bash
npx hardhat monitor [--targetnetwork <网络名称>]
```

**参数**：
- `--targetnetwork`：(可选) 指定要监控的网络名称。如果不指定，将监控所有支持的网络。

**监控内容**：
- 升级权限检查：检查代理管理员合约的所有者
- VToken合约检查：
  - 所有者地址
  - 暂停状态
  - Oracle地址
  - Dispatcher地址
  - 触发地址
  - 每用户最大赎回请求数
- Oracle合约检查：
  - 所有者地址
  - 铸造费率
  - 赎回费率

**示例**：
```bash
# 监控所有网络上的合约
npx hardhat monitor

# 只监控以太坊主网上的合约
npx hardhat monitor --targetnetwork ethereum
```

### 2. 比较合约配置 (`compare`)

比较不同链上同一合约的配置是否一致，以便发现配置差异。

**用法**：
```bash
npx hardhat compare --contract <合约名> [--reference <参考网络>] [--targetnetworks <网络列表>]
```

**参数**：
- `--contract`：要比较的合约名称，如 "Oracle" 或 "vDOT"。
- `--reference`：(可选) 作为参考的网络名称。默认为第一个网络。
- `--targetnetworks`：(可选) 要比较的网络列表，使用逗号分隔。默认比较所有支持的网络。

**比较内容**：
- VToken合约：
  - 所有者地址
  - Oracle地址
  - Dispatcher地址
  - 触发地址
  - 最大赎回请求数
  - 暂停状态
- Oracle合约：
  - 所有者地址
  - 铸造费率
  - 赎回费率

**示例**：
```bash
# 比较所有网络上Oracle合约的配置，以ethereum为参考
npx hardhat compare --contract Oracle

# 比较特定网络上vDOT合约的配置
npx hardhat compare --contract vDOT --reference ethereum --targetnetworks optimistic,arbitrum,base
```

### 3. 验证合约常量 (`verify-constants`)

验证合约中的常量值是否符合预期，以确保关键参数设置正确。

**用法**：
```bash
npx hardhat verify-constants [--targetnetwork <网络名称>] [--targetcontract <合约名>]
```

**参数**：
- `--targetnetwork`：(可选) 指定要验证的网络名称。如果不指定，将验证所有支持的网络。
- `--targetcontract`：(可选) 指定要验证的合约名称。如果不指定，将验证所有合约。

**验证内容**：
- Oracle合约：
  - BIFROST_CHAIN_ID: "2030"
  - BIFROST_SLPX: "bif-slpx"
  - FEE_DENOMINATOR: 10000
- VToken合约：
  - BIFROST_SLPX: "bif-slpx"
  - BIFROST_CHAIN_ID: 2030

**示例**：
```bash
# 验证所有网络上所有合约的常量
npx hardhat verify-constants

# 只验证以太坊主网上的Oracle合约
npx hardhat verify-constants --targetnetwork ethereum --targetcontract Oracle
```

## 支持的网络

任务支持以下网络：
- ethereum (以太坊主网)
- optimistic (乐观)
- arbitrum (Arbitrum)
- bsc (币安智能链)
- base (Base)
- astar (Astar)
- moonbeam (Moonbeam)
- moonriver (Moonriver)

## 常见问题处理

### 1. 找不到合约部署文件
错误信息：`部署文件不存在: xxx/deployments/network/Contract.json`
解决方法：
- 确认合约是否已在该网络上部署
- 检查`deployments`目录下是否有对应网络的子目录
- 确认部署文件名称是否正确

### 2. 找不到合约构件
错误信息：`HH700: Artifact for contract "xxx" not found`
解决方法：
- 运行`npx hardhat compile`重新编译合约
- 检查`artifacts`目录是否存在并包含所需合约
- 确认合约名称拼写正确

### 3. RPC连接问题
错误信息：`Error running JSON-RPC server: xxx`
解决方法：
- 检查`.env`文件中的RPC URL配置
- 确认网络连接正常
- 尝试使用其他RPC节点

### 4. 配置不一致问题
当使用`compare`任务发现配置不一致时：
1. 记录不一致的具体参数
2. 检查是否是预期的差异
3. 如果是非预期差异，使用管理员账户更新配置

### 5. 常量验证失败
当使用`verify-constants`任务发现常量值不正确时：
1. 确认预期的常量值是否正确
2. 检查合约源代码中的常量定义
3. 如果需要更新，需要重新部署合约

## 最佳实践

1. **定期监控**：建议每天运行一次`monitor`任务，及时发现异常
2. **配置比对**：在新增网络部署后，使用`compare`任务确保配置一致
3. **常量验证**：在每次部署或升级后，使用`verify-constants`任务验证常量
4. **错误记录**：保存所有异常情况的日志，便于追踪和分析
5. **权限管理**：定期检查所有者和管理员权限，确保安全性

如果发现异常，请联系开发团队进行进一步排查和修复。 