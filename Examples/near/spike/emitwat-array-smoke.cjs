// Storage-array smoke: ArrayProbe.storage_lifecycle (storageArrayRead/Write).
// Renders from Tests/EmitWatArray.lean (emitWatStorageModule) → build/wasm-near/emitwat-array.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-array-smoke.cjs
const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-array.wasm");
const decU64 = (r) => { const b = typeof r === "string" ? Buffer.from(r,"latin1") : Buffer.from(r); return Number(b.readBigUInt64LE(0)); };
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount; const c = await root.devDeploy(B, {});
    // storage_lifecycle (call): values[0]=7, [1]=11, [2]=13 → return 7+11+13 = 31.
    assert.equal(decU64(await root.call(c, "storage_lifecycle", {})), 31);
    console.log("PASS: storage_lifecycle -> 31 (storageArrayRead/Write, indexed storage)");
  } catch(e){ console.error("FAIL:", (e.stack||e).split("\n").slice(0,4).join("\n")); process.exitCode=1; }
  finally { await w.tearDown(); }
})();
