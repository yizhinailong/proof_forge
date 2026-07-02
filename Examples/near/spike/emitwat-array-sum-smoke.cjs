// ArrayProbe.emitWatSumModule smoke: verifies arrayLit + arrayGet lowering.
// sumLiteral builds xs = [10,20,30] via __pf_arr_lit_u64_3 and returns xs[0]+xs[1]+xs[2] = 60.
// Rendered from Tests/EmitWatArray.lean → build/wasm-near/emitwat-array-sum.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-array-sum-smoke.cjs
const assert = require("node:assert/strict");
const path   = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-array-sum.wasm");

const decU64 = (r) => Buffer.from(r.result).readBigUInt64LE(0);

(async () => {
  const w = await Worker.init({});
  let ok = true;
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(B, {});
    // sum_literal (view): arrayLit [10,20,30] → 10+20+30 = 60, returned as Borsh u64 (LE 8 bytes).
    assert.equal(decU64(await c.viewRaw("sum_literal", {})), 60n);
    console.log("PASS sum_literal = 60");
    // sum again: allocator is bump (per-call contract instance is fresh, but within one instance
    // a second call advances arr_ptr). 60 + ... still 60. Verify idempotent.
    assert.equal(decU64(await c.viewRaw("sum_literal", {})), 60n);
    console.log("PASS sum_literal (2nd call, bump alloc) = 60");
  } catch (e) {
    ok = false;
    console.error("FAIL", e);
  } finally {
    await w.tearDown();
  }
  process.exit(ok ? 0 : 1);
})();