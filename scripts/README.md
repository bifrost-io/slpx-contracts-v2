# monitor-multisig.ts 简要说明

## 作用

- 定时批量检查多链（arbitrum, base, bsc, ethereum, optimistic）下多个合约的 owner 权限
- 如果 owner 与 BifrostMultisig 不符，自动发送 Slack 告警并 @ 指定人员
- 日志会输出到控制台和 scripts/monitor-multisig.log

## 依赖

- Node.js 18+
- ethers
- dotenv

安装依赖：
```bash
npm install ethers dotenv
```

## 环境变量（.env）

```env
SLACK_WEBHOOK_URL=你的slack webhook
SLACK_MENTION_USERS=Uxxxxxxx,Uyyyyyyy
ARB_URL=xxx
BASE_URL=xxx
BSC_URL=xxx
ETHEREUM_URL=xxx
OP_URL=xxx
```

## 用法

```bash
npx ts-node scripts/monitor-multisig.ts
```

## crontab 示例

每两小时15分自动检查：
```bash
15 */2 * * * cd /path/to/your/project && npx ts-node scripts/monitor-multisig.ts >> scripts/monitor-multisig.log 2>&1
```

## 说明
- Slack @用户请用逗号分隔的用户ID（如 Uxxxxxx,Uyyyyyy）
- 日志和告警均带时间戳
- 告警消息 owner/期望owner 可直接点击跳转区块浏览器
