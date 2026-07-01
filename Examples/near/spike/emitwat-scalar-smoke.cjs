// U32StorageScalarProbe smoke: exercises storageScalarAssignOp (n += 5).
// Renders from Tests/EmitWatScalar.lean → build/wasm-near/emitwat-scalar.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-scalar-smoke.cjs
const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-scalar.wasm");
const decU64FromCall = (r) => { const buf = typeof r === "string" ? Buffer.from(r, "latin1") : Buffer.from(r); return Number(buf.readBigUInt64LE(0)); };
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount; const c = await root.devDeploy(B, {});
    // storage_lifecycle (call, mutates): write 7 → read n=7 → write n → n+=5 → assert result==12 → return 12.
    // No trap ⇒ storageScalarAssignOp computed +=5 correctly (assert holds).
    const r = await root.call(c, "storage_lifecycle", {});
    assert.equal(decU64FromCall(r), 12);
    console.log("PASS: storage_lifecycle -> 12 (storageScalarAssignOp += 5, assert 12 holds)");
  } catch(e){ console.error("FAIL:", (e.stack||e).split("\n").slice(0,4).join("\n")); process.exitCode=1; }
  finally { await w.tearDown(); }
})();
