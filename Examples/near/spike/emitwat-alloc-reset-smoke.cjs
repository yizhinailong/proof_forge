// Allocator bumpReset strategy smoke: sumLiteral with entrypoint-boundary arr_ptr reset.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-alloc-reset-smoke.cjs
const assert = require("node:assert/strict");
const path   = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-alloc-reset.wasm");
const decU64 = (r) => Number(Buffer.from(r.result).readBigUInt64LE(0));
(async () => {
  const w = await Worker.init({});
  let ok = true;
  try {
    const root = w.rootAccount; const c = await root.devDeploy(B, {});
    // reset happens each call; correctness unaffected.
    assert.equal(decU64(await c.viewRaw("sum_literal", {})), 60);
    assert.equal(decU64(await c.viewRaw("sum_literal", {})), 60);
    assert.equal(decU64(await c.viewRaw("sum_literal", {})), 60);
    console.log("PASS sum_literal = 60 x3 (bumpReset: per-call reset, no accumulation)");
  } catch (e) { ok = false; console.error("FAIL", e); } finally { await w.tearDown(); }
  process.exit(ok ? 0 : 1);
})();
