// MapProbe.emitWatPathModule smoke: storagePathRead/Write with a single mapKey segment.
// pathLifecycle writes balances[key] = value (hash4(77,88,99,111)) and reads it back.
// Rendered from Tests/EmitWatPath.lean → build/wasm-near/emitwat-path.wasm.
// Run: NODE_PATH=<near-workspaces> NEAR_SANDBOX_BINARY_PATH=<sandbox> node emitwat-path-smoke.cjs
const assert = require("node:assert/strict");
const path   = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-path.wasm");
// hash4(a,b,c,d) packs 4 u64-LE limbs into 32 bytes, mirroring __pf_hash_make.
const hash4 = (a,b,c,d) => { const buf = Buffer.alloc(32);
  buf.writeBigUInt64LE(BigInt(a),0); buf.writeBigUInt64LE(BigInt(b),8);
  buf.writeBigUInt64LE(BigInt(c),16); buf.writeBigUInt64LE(BigInt(d),24); return buf; };
const decHash = (r) => Buffer.from(typeof r === "string" ? Buffer.from(r,"latin1") : r).toString("hex");

(async () => {
  const w = await Worker.init({});
  let ok = true;
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(B, {});
    // path_lifecycle (call, mutates): balances[hash4(2002..)] := hash4(77,88,99,111), read back.
    assert.equal(decHash(await root.call(c, "path_lifecycle", {})), hash4(77,88,99,111).toString("hex"));
    console.log("PASS path_lifecycle = hash4(77,88,99,111) (storagePathWrite + storagePathRead via mapKey segment)");
  } catch (e) {
    ok = false;
    console.error("FAIL", (e.stack||e).toString().split("\n").slice(0,4).join("\n"));
  } finally {
    await w.tearDown();
  }
  process.exit(ok ? 0 : 1);
})();