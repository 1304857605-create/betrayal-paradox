# 背叛者悖论（Betrayal Paradox）· 任务分发

> 5 轮 commit-reveal 社会博弈游戏 · Monad Blitz@广州 · 2026-11-21  
> 提交截止 18:30，Demo 19:00。现在 13:35，剩余约 5 小时。

## 0. 规则定稿（先全员对齐，别再改）

- **N=5 人**，每人交押金 `S`；**赞助方再配 100%**，即再出 `N*S`。
- **奖池 = 2*N*S**（5 人 × S + 赞助 5S = **10S**）。
- 共 **5 轮**，每轮：
  - **Commit 阶段 30 秒**：提交 `hash(choice, salt, address, roomId, round)`；
  - **Reveal 阶段 30 秒**：提交 `choice` + `salt`，合约校验；
  - 结算。
- 选择：`COOPERATE = 0`，`BETRAY = 1`。
- 结算（**一局一个奖池，不按轮分池**）：
  - **0 人背叛**：奖池滚入下一轮；5 轮都 0 人背叛 → 5 名玩家平分奖池（每人 2S，净赚 S）。
  - **恰好 1 人背叛**：该玩家拿走全部奖池（10S），**游戏立即结束**。
  - **2 人及以上背叛**：**全部奖池归赞助方**，游戏立即结束；玩家押金不退。
- 未 reveal 的玩家：本轮视为弃权，押金留在奖池；最终平分时只分给每轮都 reveal 的玩家。
- 演示参数可调：`commitSecs=10, revealSecs=10`；若每轮都合作，5 轮约 100 秒；一旦有人背叛，立即结束。
- **注意**：你写的“2S”如果指“总奖池 2S”，那 5 人每人只能交 0.2S；下面按 **10S** 写，公式可改。

## 1. 分工（3 人默认；2 人/1 人见文末）

| 角色 | 负责 | 交付物 | 截止 |
|---|---|---|---|
| **A 合约/链上** | `BetrayalGame.sol`、赞助配资、部署、单测、合约地址 | 合约 + 部署记录 + 3 个结果用例 | **15:30** |
| **B 前端/交互** | 大厅、房间、赞助方/奖池、倒计时、commit/reveal、结算 | 可连钱包的页面 | **16:30** |
| **C 产品/测试/演示** | 规则文案、5 账号测试、录屏、项目提交材料 | 测试记录 + 90 秒视频 + 提交文案 | 18:00 |
| **全员** | 16:30–17:30 联调；17:30–18:15 彩排 | 三种结果都能演 | 18:15 |

## 2. 合约接口（A 按这个写，B 按这个接）

```solidity
// 状态
struct Room {
    address host;
    uint256 stake;
    uint8 maxPlayers;
    uint8 rounds;          // 5
    uint64 commitSecs;     // 30（演示 10）
    uint64 revealSecs;     // 30（演示 10）
    uint8 currentRound;    // 1..5
    uint8 phase;           // 0 lobby, 1 commit, 2 reveal, 3 settled, 4 ended
    uint64 phaseDeadline;
    uint256 pot;
    address[] players;
    bool[] revealed;
}

// 写
function createRoom(uint8 maxPlayers, uint8 rounds, uint64 commitSecs, uint64 revealSecs, uint256 stake);
function joinRoom(uint256 roomId) payable;          // 必须 msg.value == stake
function sponsorRoom(uint256 roomId) payable;       // 赞助方配资，必须 msg.value == 已加入人数 * stake
function startGame(uint256 roomId);                 // 赞助到位、人数满，才能开始
function commit(uint256 roomId, bytes32 commitment);
function reveal(uint256 roomId, uint8 choice, bytes32 salt);
function settleRound(uint256 roomId);               // 任何人，reveal 截止后
function nextRound(uint256 roomId);                 // 任何人，0 人背叛时进入下一轮
function claim(uint256 roomId);                     // 结束后领奖

// 读
function getRoom(uint256 roomId) view returns (...);
function getPlayers(uint256 roomId) view returns (address[] memory);
function getScore(uint256 roomId, address player) view returns (uint256);
function commitmentOf(uint256 roomId, uint8 round, address player) view returns (bytes32);
```

**哈希**：`keccak256(abi.encodePacked(choice, salt, msg.sender, roomId, round))`。  
**事件**：`RoomCreated, Joined, GameStarted, Committed, Revealed, RoundSettled, GameEnded`。  
**安全**：防重复 commit/reveal；phase 检查；只有玩家可操作；结算用 pull-over-push（先记账，claim 提现），避免转账失败卡死。

## 3. 前端页面（B 按这个做）

1. **大厅**：创建房间（人数/押金/轮数/倒计时）、房间列表、加入；
2. **房间**：玩家列表、奖池、轮次、阶段倒计时、我的余额/战绩；
3. **Commit**：选“合作/背叛” → 本地生成随机 salt → 算 hash → 发交易；显示“已提交（隐藏）”；
4. **Reveal**：提交 choice + salt；显示“已揭晓”；
5. **结算**：显示本轮谁背叛、谁赢、奖池变化；
6. **结束**：5 轮总收益、冠军、claim 按钮。

技术栈建议：纯 HTML + ethers v6 CDN（最快）或 Next.js；不要上后端，链上就是后端。

## 4. 验收标准（16:00 联调时逐条过）

- [ ] 3 个账号能创建/加入同一房间；
- [ ] 合约能开始游戏，进入第 1 轮 commit；
- [ ] 3 人都能 commit，界面不泄露选择；
- [ ] 3 人都能 reveal，合约校验通过；
- [ ] 结算正确：1 人背叛 → 背叛者拿走 10S；2 人以上背叛 → **赞助方拿走 10S**；0 人背叛 → 滚入下一轮；
- [ ] 5 轮全合作能走完，5 人平分 10S，能 claim；
- [ ] 赞助方配资未到位时不能 start；
- [ ] 错误路径：重复 commit、错误 salt、超时 reveal 都有提示/拒绝。

## 5. 演示脚本（90 秒）

**现场只演一局**（10s commit / 10s reveal，5 人）：

1. 5 个账号加入，每人 0.01 MON；赞助方配资 0.05 MON；奖池 **0.10 MON**；
2. 第 1 轮：A 背叛，B–E 合作 → A 拿走 0.10 MON，**游戏立即结束**（观众：“啊？”）；
3. 收尾：“只要一个人背叛，他通吃；如果两个以上背叛，赞助方拿走全部；五轮都合作，五个人平分。”

**另外两种结果用提前录好的 15 秒片段/截图**：

- 2 人背叛 → 赞助方拿走 10S；
- 5 轮全合作 → 5 人各拿 2S（净赚 S）。

**讲 Why Monad**：5 轮 × 3–6 人 × commit+reveal = 几分钟内几十笔交易；低费用 + 快速确认让节奏不拖。诚实补一句：“核心是需要一个所有人都信得过的裁判。”

## 6. 提交材料（C 负责，18:00 前）

- 项目名：**背叛者悖论（Betrayal Paradox）**
- 一句话：5 轮秘密投票，恰好一个背叛者通吃；多人背叛全输。
- Demo 链接、GitHub、合约地址、至少 1 张截图；
- 90 秒视频（3 账号一局，含 1 人背叛、2 人背叛、全合作三种结果）。

## 7. 2 人 / 1 人怎么办

- **2 人**：A 合约 + B 前端；C 的测试/演示由两人轮流做；16:30 前必须跑通一局。
- **1 人**：先合约（1.5h）→ 最简前端（2h）→ 3 个浏览器账号自测（1h）→ 录屏/提交（1h）；前端砍到只剩“加入/commit/reveal/结算”四个按钮。

## 8. 保命方案

- 16:30 合约还没部署：砍成“最后 10 秒才能背叛 + 20% 税”的单轮版；
- 17:30 前端还连不上：改用 Remix 直接调合约 + 录屏，页面只做展示；
- 18:00 还没跑通：提交现有代码 + 规则说明 + 录屏，别空着。
