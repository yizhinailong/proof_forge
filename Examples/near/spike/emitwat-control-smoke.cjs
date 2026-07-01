// Control-flow smoke: ConditionalProbe (if/else) + LoopProbe (boundedFor).
// Renders from Tests/EmitWatControl.lean → build/wasm-near/emitwat-{cond,loop}.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-control-smoke.cjs
const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
const B = (n) => path.resolve(__dirname, `../../../build/wasm-near/emitwat-${n}.wasm`);
const decU64 = (r) => { const b = typeof r === "string" ? Buffer.from(r,"latin1") : Buffer.from(r); return Number(b.readBigUInt64LE(0)); };
(async () => {
  const w = await Worker.init({});
  let ok = true;
  try {
    const root = w.rootAccount;
    // conditional_lifecycle (call): count=0 → if(true) count=4 → if(4<2)false else next=4+6=10, count=10 → assert 10 → return 10.
    const c = await root.devDeploy(B("cond"), {});
    assert.equal(decU64(await root.call(c, "conditional_lifecycle", {})), 10);
    console.log("PASS: conditional_lifecycle -> 10 (if/else branches, assert 10 holds)");
    // count_to_three (call): count=0 → boundedFor 0..3 (3 iters): count 0→1→2→3 → return 3.
    const l = await root.devDeploy(B("loop"), {});
    assert.equal(decU64(await root.call(l, "count_to_three", {})), 3);
    console.log("PASS: count_to_three -> 3 (boundedFor 3 iterations)");
  } catch(e){ console.error("FAIL:", (e.stack||e).split("\n").slice(0,4).join("\n")); ok=false; process.exitCode=1; }
  finally { await w.tearDown(); }
})();
