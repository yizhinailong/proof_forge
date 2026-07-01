// Map\u003cHash, Hash\u003e smoke: hash-keyed map set/get/has/missing via Borsh.
// Renders from Tests/EmitWatHashmap.lean → build/wasm-near/emitwat-maphash.wasm.
// Run: NODE_PATH=\u003cnear-workspaces\u003e NEAR_SANDBOX_BINARY_PATH=\u003csandbox\u003e node emitwat-hashmap-smoke.cjs
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const path  = require("node:path");
const { Worker } = require("near-workspaces");
const B = path.resolve(__dirname, "../../../build/wasm-near/emitwat-maphash.wasm");
const h = (s) => crypto.createHash("sha256").update(s).digest();  // Buffer (32 bytes)
const decBool = (r) => Buffer.from(r.result).readUInt8(0) !== 0;
const decHash = (r) => Buffer.from(r.result).toString("hex");
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount; const c = await root.devDeploy(B, {});
    const key = h("k1"), val = h("v1");
    assert.equal(decBool(await c.viewRaw("hasBalance", key)), false);            // missing -> false
    await root.call(c, "setBalanceReturn", Buffer.concat([key, val]));           // write
    assert.equal(decBool(await c.viewRaw("hasBalance", key)), true);             // present -> true
    assert.equal(decHash(await c.viewRaw("getBalance", key)), val.toString("hex")); // round-trip
    assert.equal(decHash(await c.viewRaw("getBalance", h("missing"))), "0".repeat(64)); // missing -> zero hash
    console.log("PASS: Map\u003cHash,Hash\u003e set/get/has/missing (Borsh, hash-keyed)");
  } catch(e){ console.error("FAIL:", (e.stack||e).split("\n").slice(0,4).join("\n")); process.exitCode=1; }
  finally { await w.tearDown(); }
})();
