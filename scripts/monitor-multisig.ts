import { ethers } from "ethers";
import * as dotenv from "dotenv";
import { BifrostMultisig } from "../constants";
import * as fs from "fs";
dotenv.config();

const CONTRACTS = [
  { name: "DefaultProxyAdmin", address: "0xB079fA0C53c2da05eA517Ffc545Cd7E3C180a136" },
  { name: "vASTR", address: "0xf659c15AEB6E41A9edAcBbF3fAeF3902c7f3fE1b" },
  { name: "vBNC", address: "0x61c57c187557442393a96bA8e6FDfE27610832a5" },
  { name: "vDOT", address: "0xBC33B4D48f76d17A1800aFcB730e8a6AAada7Fe5" },
  { name: "vGLMR", address: "0x0Bc2e0cab4AD1Dd1398D70bc268c0502e8A6DF24" },
  { name: "Oracle", address: "0x5b631863dF1B20AFb2715ee1F1381D6Dc1Dd065d" },
  { name: "BridgeVault", address: "0x32c7D417a8B28A99B7993436eADC3De175a277E0" },
];

const NETWORKS = [
  { name: "arbitrum", rpc: process.env.ARB_URL },
  { name: "base", rpc: process.env.BASE_URL },
  { name: "bsc", rpc: process.env.BSC_URL },
  { name: "ethereum", rpc: process.env.ETHEREUM_URL },
  { name: "optimistic", rpc: process.env.OP_URL },
];

const ABI = [
  "function owner() view returns (address)"
];

function log(msg: string) {
  const line = `[${new Date().toLocaleString("zh-CN", { timeZone: "Asia/Shanghai" })}] ${msg}`;
  console.log(line);
  fs.appendFileSync(__dirname + "/monitor-multisig.log", line + "\n");
}

async function sendSlackAlert(
  errors: {network: string, contractName: string, contractAddress: string, realOwner: string}[],
  networkName: string
) {
  const webhook = process.env.SLACK_WEBHOOK_URL;
  const mentionRaw = process.env.SLACK_MENTION_USERS || "";
  const mention = mentionRaw
    .split(",")
    .map(id => id.trim())
    .filter(Boolean)
    .map(id => `<@${id}>`)
    .join(" ");
  if (!webhook) return;

  const timestamp = new Date().toLocaleString("zh-CN", { timeZone: "Asia/Shanghai" });

  const explorer = EXPLORER_PREFIX[networkName] || "";
  const errorLines = errors.map(err => {
    const ownerLink = explorer ? `<${explorer}${err.realOwner}|${err.realOwner}>` : `\`${err.realOwner}\``;
    const expectLink = explorer ? `<${explorer}${BifrostMultisig}|${BifrostMultisig}>` : `\`${BifrostMultisig}\``;
    return `*合约:* ${err.contractName}\n*合约地址:* \`${err.contractAddress}\`\n*当前Owner:* ${ownerLink}\n*期望Owner:* ${expectLink}`;
  });

  const msg = {
    text: `🚨 多签Owner异常 ${networkName}`,
    blocks: [
      { type: "header", text: { type: "plain_text", text: `🚨 多签Owner异常 - ${networkName}` } },
      {
        type: "section",
        text: { type: "mrkdwn", text: `*请关注：* ${mention}\n\n${errorLines.join("\n\n")}` }
      },
      {
        type: "context",
        elements: [{ type: "mrkdwn", text: `⏰ 检查时间: ${timestamp}` }]
      }
    ]
  };

  let success = false;
  for (let i = 1; i <= 3; i++) {
    log(`Slack告警第${i}次尝试发送...`);
    try {
      const resp = await fetch(webhook, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(msg)
      });
      if (resp.ok) {
        log("Slack告警发送成功！");
        success = true;
        break;
      } else {
        log(`Slack告警发送失败: ${resp.status} ${resp.statusText}`);
        
        const body = await resp.text();
        log(`Slack告警响应体: ${body}`);

        log(`Slack告警debug: network=${networkName}`);
        log(`异常合约数量: ${errors.length}`);
        log(`explorer: ${EXPLORER_PREFIX[networkName] || "无"}`);
        log(`errorLines.length: ${errorLines.length}`);
        log(`拼接text长度: ${errorLines.join("\n\n").length}`);
      }
    } catch (e: any) {
      log(`Slack告警发送异常: ${e.message || e}`);
    }
    if (i < 3) await new Promise(r => setTimeout(r, 1000 * i));
  }
  if (!success) log("Slack告警最终发送失败！");
}

async function main() {
  for (const net of NETWORKS) {
    if (!net.rpc) {
      log(`跳过 ${net.name}，未配置RPC`);
      continue;
    }
    const provider = new ethers.providers.JsonRpcProvider(net.rpc);
    const errors: {network: string, contractName: string, contractAddress: string, realOwner: string}[] = [];
    for (const c of CONTRACTS) {
      try {
        const contract = new ethers.Contract(c.address, ABI, provider);
        const owner = await contract.owner();
        if (owner.toLowerCase() !== BifrostMultisig.toLowerCase()) {
          log(`❌ [${net.name}] ${c.name} owner异常: ${owner}`);
          errors.push({ network: net.name, contractName: c.name, contractAddress: c.address, realOwner: owner });
        } else {
          log(`✅ [${net.name}] ${c.name} owner正常`);
        }
      } catch (e: any) {
        log(`⚠️  [${net.name}] ${c.name} 检查失败: ${e}`);
      }
    }
    if (errors.length > 0) {
      await sendSlackAlert(errors, net.name);
    }
  }
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});

const EXPLORER_PREFIX: Record<string, string> = {
  arbitrum: "https://arbiscan.io/address/",
  base: "https://basescan.org/address/",
  bsc: "https://bscscan.com/address/",
  ethereum: "https://etherscan.io/address/",
  optimistic: "https://optimistic.etherscan.io/address/"
};