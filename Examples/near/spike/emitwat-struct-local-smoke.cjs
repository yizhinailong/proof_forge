// StructProbe.emitWatLocalSumModule smoke: structLit + field lowering.
// localSum builds Point{x=10,y=20} via __pf_struct_lit_Point and returns p.x + p.y = 30.
// Rendered from Tests/EmitWatStruct.lean → build/wasm-near/emitwat-struct-local.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-struct-local-smoke.cjs
const assert = require("node:assert/strict");
const path   = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-struct-local.wasm");
const decU64 = (r) => Number(Buffer.from(r.result).readBigUInt64LE(0));

(async () => {
  const w = await Worker.init({});
  let ok = true;
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(B, {});
    // local_sum (view): Point{10,20}.x + .y = 30, returned as Borsh u64.
    assert.equal(decU64(await c.viewRaw("local_sum", {})), 30);
    console.log("PASS local_sum = 30 (structLit + field offset load)");
  } catch (e) {
    ok = false;
    console.error("FAIL", e);
  } finally {
    await w.tearDown();
  }
  process.exit(ok ? 0 : 1);
})();