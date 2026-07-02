// ArrayProbe full module smoke: sumLiteral (arrayLit+arrayGet), storageLifecycle
// (storageArrayRead/Write), arrayPredicates (array equality via __pf_arr_eq).
// Rendered from Tests/EmitWatArray.lean → build/wasm-near/emitwat-array-full.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-array-full-smoke.cjs
const assert = require("node:assert/strict");
const path   = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-array-full.wasm");
const decU64View = (r) => Number(Buffer.from(r.result).readBigUInt64LE(0));
const decU64Call = (r) => { const b = typeof r === "string" ? Buffer.from(r,"latin1") : Buffer.from(r); return Number(b.readBigUInt64LE(0)); };

(async () => {
  const w = await Worker.init({});
  let ok = true;
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(B, {});
    // sum_literal (view): arrayLit [10,20,30] → 10+20+30 = 60.
    assert.equal(decU64View(await c.viewRaw("sum_literal", {})), 60);
    console.log("PASS sum_literal = 60");
    // storage_lifecycle (call): writes [7,11,13] to indexed storage, returns sum = 31.
    assert.equal(decU64Call(await root.call(c, "storage_lifecycle", {})), 31);
    console.log("PASS storage_lifecycle = 31");
    // array_predicates (view): assertEq(xs,ys) + assert(eq xs ys) + assert(ne xs zs) must not trap;
    // returns 1.
    assert.equal(decU64View(await c.viewRaw("array_predicates", {})), 1);
    console.log("PASS array_predicates = 1 (no trap: array equality holds)");
  } catch (e) {
    ok = false;
    console.error("FAIL", e);
  } finally {
    await w.tearDown();
  }
  process.exit(ok ? 0 : 1);
})();