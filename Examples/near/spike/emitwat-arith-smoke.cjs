// U32ArithmeticProbe smoke via EmitWat: exercises .pow (17^2=289) plus the
// full u32 arithmetic surface (add/sub/mul/div/mod/assignOp/cast/assertEq).
// Renders from Tests/EmitWatArith.lean → build/wasm-near/emitwat-arith.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-arith-smoke.cjs
const assert = require("node:assert/strict");
const path  = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-arith.wasm");
const decU64 = (r) => Number(Buffer.from(r.result).readBigUInt64LE(0));
// Borsh: two u32 params, little-endian, packed (4 + 4 bytes).
const enc = (a, b) => { const u = new Uint8Array(8); new DataView(u.buffer).setUint32(0, a, true); new DataView(u.buffer).setUint32(4, b, true); return Buffer.from(u); };
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount; const c = await root.devDeploy(B, {});
    // u32_arithmetic(a=2, b=3): every assertEq holds (incl. pow 17^2=289),
    // returns cast(bb=true) u64 = 1. A wrong a/b traps inside assertEq.
    assert.equal(decU64(await c.viewRaw("u32_arithmetic", enc(2, 3))), 1);
    console.log("PASS: u32_arithmetic(2,3) -> 1 (pow + arithmetic surface, no trap)");
  } catch(e){ console.error("FAIL:", (e.stack||e).split("\n").slice(0,4).join("\n")); process.exitCode=1; }
  finally { await w.tearDown(); }
})();
