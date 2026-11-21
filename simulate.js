// 背叛者悖论 · 纯 JS 规则模拟（不连链，验证三种结局的账是否对得上）
// 运行：node simulate.js（金额全部按 wei 整数算，避免浮点误差）
const N = 5;
const S = 10000000000000000n; // 每人押金 0.01 MON = 1e16 wei
const SPONSOR = S * BigInt(N); // 赞助配资 100%
const POT = S * BigInt(N) + SPONSOR; // 10S = 1e17 wei
const toMON = (w) => (Number(w) / 1e18).toFixed(4);

function runGame(rounds, betrayPlan, forfeitIdx = null) {
  let pot = POT;
  const net = Array(N).fill(0n);
  const forfeited = Array(N).fill(false);
  let sponsorNet = -SPONSOR;
  for (let r = 1; r <= rounds; r++) {
    const betrayers = betrayPlan[r] || [];
    if (forfeitIdx !== null && r === 1) forfeited[forfeitIdx] = true;
    if (betrayers.length === 0) {
      if (r === rounds) {
        const elig = [];
        for (let i = 0; i < N; i++) if (!forfeited[i]) elig.push(i);
        const per = pot / BigInt(elig.length);
        for (const i of elig) net[i] += per;
        const rem = pot - per * BigInt(elig.length);
        return { outcome: "split", per, rem, net, sponsorNet };
      }
      continue;
    } else if (betrayers.length === 1) {
      net[betrayers[0]] += pot;
      return { outcome: "one-betrayer", winner: betrayers[0], net, sponsorNet };
    } else {
      sponsorNet += pot;
      return { outcome: "sponsor-wins", net, sponsorNet };
    }
  }
  return { outcome: "?", net, sponsorNet };
}

function show(name, result) {
  console.log("\n=== " + name + " ===");
  if (result.outcome === "one-betrayer") {
    console.log("结局：恰好 1 人背叛 → 背叛者通吃");
    console.log("背叛者 #" + result.winner + " 净收益 = " + toMON(result.net[result.winner] - S) + " MON（拿回奖池，扣除自己押金）");
  } else if (result.outcome === "sponsor-wins") {
    console.log("结局：2 人以上背叛 → 赞助方通吃");
    console.log("赞助方净收益 = " + toMON(result.sponsorNet) + " MON");
  } else {
    console.log("结局：5 轮全合作 → 玩家平分");
    console.log("每人分到 = " + toMON(result.per) + " MON，净赚 = " + toMON(result.per - S) + " MON，余数 " + result.rem + " wei 给 0 号玩家");
    console.log("赞助方净收益 = " + toMON(result.sponsorNet) + " MON");
  }
  let playerSum = 0n;
  for (const n of result.net) playerSum += n;
  playerSum -= S * BigInt(N);
  console.log("玩家净收益合计 = " + toMON(playerSum) + " MON；赞助方 = " + toMON(result.sponsorNet) + "；两者相加（应为 0，零和）：" + toMON(playerSum + result.sponsorNet));
}

show("场景 A：第 1 轮恰好 1 人背叛（#1 背叛，其余合作）", runGame(5, { 1: [1] }));
show("场景 B：第 1 轮 2 人背叛（#1、#2 背叛）", runGame(5, { 1: [1, 2] }));
show("场景 C：5 轮全合作", runGame(5, {}));
show("场景 D：前 4 轮全合作，第 5 轮 #0 背叛", runGame(5, { 5: [0] }));
show("场景 E：5 轮全合作但有 1 人第 1 轮弃权", runGame(5, {}, 4));

console.log("\n结论：");
console.log("A：唯一背叛者赚 9S，其他 4 人各亏 S，赞助方亏 5S。");
console.log("B：2 人背叛 → 赞助方赚 5S，5 名玩家各亏 S。");
console.log("C：全员合作 → 每人赚 S，赞助方亏 5S。");
console.log("D：前 4 轮没人背叛 → 第 5 轮一个人背叛照样通吃。");
console.log("E：弃权者分不到钱（押金留在奖池里分给别人）。");
