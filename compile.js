const solc = require("solc");
const fs = require("fs");
const path = require("path");

const src = fs.readFileSync(path.join("contracts", "BetrayalGame.sol"), "utf8");
const input = {
  language: "Solidity",
  sources: { "BetrayalGame.sol": { content: src } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
  },
};
const out = JSON.parse(solc.compile(JSON.stringify(input)));
if (out.errors) {
  for (const e of out.errors) console.log(e.severity.toUpperCase() + ": " + e.formattedMessage);
}
const contract = out.contracts["BetrayalGame.sol"] && out.contracts["BetrayalGame.sol"]["BetrayalGame"];
if (!contract) {
  console.log("COMPILE FAILED");
  process.exit(1);
}
fs.mkdirSync("out", { recursive: true });
fs.writeFileSync(
  path.join("out", "BetrayalGame.json"),
  JSON.stringify({ abi: contract.abi, bytecode: contract.evm.bytecode.object }, null, 2)
);
const fns = contract.abi.filter((x) => x.type === "function");
const evs = contract.abi.filter((x) => x.type === "event");
console.log("OK functions=" + fns.length + " events=" + evs.length + " bytecodeLen=" + contract.evm.bytecode.object.length / 2);
console.log("SIGS:");
for (const f of fns) {
  const types = f.inputs.map((i) => i.type).join(",");
  console.log("  " + f.name + "(" + types + ")" + (f.stateMutability === "view" ? " [view]" : ""));
}
