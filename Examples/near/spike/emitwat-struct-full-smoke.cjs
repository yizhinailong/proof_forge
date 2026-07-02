// StructProbe full module smoke: localSum (structLit+field) + storageLifecycle
// (storageScalarWrite struct + storageStructFieldRead/Write).
// storageLifecycle: current={x:7,y:11}, then y:=19 → return x+y = 7+19 = 26.
// Rendered from Tests/EmitWatStruct.lean → build/wasm-near/emitwat-struct-full.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-struct-full-smoke.cjs
const assert = require("node:assert/strict");
const path   = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-struct-full.wasm");
const decU64View = (r) => Number(Buffer.from(r.result).readBigUInt64LE(0));
const decU64Call = (r) => { const b = typeof r === "string" ? Buffer.from(r,"latin1") : Buffer.from(r); return Number(b.readBigUInt64LE(0)); };

(async () => {
  const w = await Worker.init({});
  let ok = true;
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(B, {});
    // local_sum (view): Point{10,20}.x + .y = 30.
    assert.equal(decU64View(await c.viewRaw("local_sum", {})), 30);
    console.log("PASS local_sum = 30 (structLit + field offset load)");
    // storage_lifecycle (call): write Point{7,11}, set y:=19, return x+y = 7+19 = 26.
    assert.equal(decU64Call(await root.call(c, "storage_lifecycle", {})), 26);
    console.log("PASS storage_lifecycle = 26 (struct storage write + field read/write)");
  } catch (e) {
    ok = false;
    console.error("FAIL", (e.stack||e).toString().split("\n").slice(0,4).join("\n"));
  } finally {
    await w.tearDown();
  }
  process.exit(ok ? 0 : 1);
})();