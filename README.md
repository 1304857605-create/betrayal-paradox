# 背叛者悖论（Betrayal Paradox）

> Monad Blitz@广州 · 2026-11-21 · 提交截止 18:30 · Demo 19:00

一个 5 轮 commit-reveal 社会博弈游戏：**5 人各押 S，赞助方配 100%，奖池 10S。恰好 1 人背叛他通吃；2 人以上背叛赞助方通吃；5 轮全合作玩家平分。**

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

**同一浏览器切换 MetaMask 账号**后刷新页面即可操作不同玩家；本机会记住每个账号的选择和盐（`localStorage`）。

## 4. 演示脚本（90 秒）

> 5 个账号，每人押 0.01 MON，赞助方配 0.05，奖池 0.10 MON。  
> 第 1 轮：A 背叛，B–E 合作 → A 拿走 0.10，游戏结束。  
> 收尾：“一个人背叛他通吃；两个以上背叛赞助方通吃；五轮全合作五个人平分。链上只认哈希，揭晓后改不了。”

另两种结果用提前录好的片段/截图：2 人背叛 → 赞助方通吃；5 轮全合作 → 每人赚 0.01。

## 5. 提交材料

- 项目名：**背叛者悖论（Betrayal Paradox）**
- 一句话：5 轮秘密投票，恰好一个背叛者通吃；多人背叛全输给赞助方。
- GitHub、Demo 链接、合约地址、至少 1 张截图、90 秒视频。

## 6. 诚实边界（答辩会被问）

- 这是**测试网 demo**，合约未审计，只适用 EOA 账户（直接转账）；
- 结算用 push 转账，不适合恶意合约账户；产品化要改成 pull（先记账、再 claim）；
- 赞助方靠玩家背叛赚钱，观感偏“庄家”；若用于校园/品牌，建议声明“赢走的钱捐公益/滚入下一场”；
- Why Monad：5 轮 × 多人 × commit+reveal 是几分钟内几十笔交易，低费用 + 快速确认让节奏不拖；核心是“需要一个所有人都信得过的裁判”。
