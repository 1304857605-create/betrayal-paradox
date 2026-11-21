# 背叛者悖论（Betrayal Paradox）

一个多轮 commit-reveal 社会博弈游戏：**n人各押 S，赞助方配 100%，奖池 2nS。恰好 1 人背叛他通吃；2 人以上背叛赞助方通吃；5 轮全合作玩家平分。**

## 文件

| 文件 | 作用 |
|---|---|
| `contracts/BetrayalGame.sol` | 合约（已通过 solc 0.8.28 编译，runtime 约 8.4KB） |
| `out/BetrayalGame.json` | ABI + 部署 bytecode（compile.js 产出） |
| `index.html` | 前端（本地 ethers，连 MetaMask，完整交互） |
| `simulate.js` | 纯 JS 规则模拟，验证三种结局的账（`node simulate.js`） |
| `start.cmd` | 一键起本地网页 |
| `compile.js` / `abi.js` | 编译与 ABI 注入脚本 |

## 1. 部署合约（Remix，5 分钟）

1. 打开 https://remix.ethereum.org ；
2. 新建 `BetrayalGame.sol`，粘贴 `contracts/BetrayalGame.sol` 全部内容；
3. **Solidity Compiler**：选 `0.8.20` 或更高 → **Compile**（无警告最好）；
4. **Deploy & Run**：Environment = `Injected Provider - MetaMask`，确认在 **Monad Testnet**；
5. 点 **Deploy**（**无构造参数**）→ MetaMask 确认；
6. 复制 **Deployed Contracts** 里的合约地址。

> 也可以用 Foundry/Hardhat 部署；bytecode 在 `out/BetrayalGame.json`。

## 2. 启动前端

```bash
cd betrayal-game
python -m http.server 8083
# 或直接双击 start.cmd
```

浏览器打开 http://localhost:8083 （**不要双击 HTML**，MetaMask 在 file:// 下不注入）。
演示demo网址：https://funny-kheer-ab6545.netlify.app/
Monad 测试网信息：

| 项 | 值 |
|---|---|
| Chain ID | `10143` |
| RPC | `https://testnet-rpc.monad.xyz` |
| 符号 | MON |
| 浏览器 | `https://testnet.monadvision.com` |
| 水龙头 | `https://testnet.monad.xyz` |

## 3. 一局怎么玩（5 个账号）

1. 账号 A：粘贴合约地址 → 加载合约 → 连接钱包 → **创建房间**（5 / 5 / 10 / 10 / 0.01）。
2. 账号 A/B/C/D/E 各自连接、**打开房间**、**加入**（各押 0.01 MON）。
3. 任一账号 **赞助配资** 0.05 MON（= 5 × 0.01）。
4. 房主（A）**开始游戏**。
5. 每轮：
   - Commit 阶段：每人点 **合作/背叛**（只提交哈希，链上看不到选择）；
   - 到点后任一人点 **进入揭晓阶段**；
   - Reveal 阶段：每人点 **揭晓我的选择**；
   - 到点后任一人点 **结算本轮**；0 人背叛自动进入下一轮。
6. 结局：恰好 1 人背叛 → 背叛者通吃；2 人以上 → 赞助方通吃；5 轮全合作 → 平分。
