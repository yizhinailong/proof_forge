// Allocator external strategy smoke: sumLiteral with host-provided pf_alloc.
// The NEAR runtime does not export pf_alloc, so we instantiate the wasm directly in
// Node and inject a bump-allocator pf_alloc plus stubs for the NEAR host imports
// (sum_literal only touches input/read_register/value_return/pf_alloc; the rest are
// present-but-uncalled, so stubs are fine). Result is read from RET_BUF (8192) in
// linear memory, where __pf_return_u64 stored the Borsh u64.
const assert = require("node:assert/strict");
const fs   = require("node:fs");
const path = require("node:path");
const B   = fs.readFileSync(path.resolve(__dirname, "../../../build/wasm-near/emitwat-alloc-external.wasm"));
const RET_BUF = 8192, HEAP_BASE = 60000;
(async () => {
  let bumpPtr = HEAP_BASE;
  const env = {
    pf_alloc: (n) => { const p = bumpPtr; bumpPtr += Number(n); return p >>> 0; },
    pf_dealloc: () => {},   // reuse-capable dealloc; IR has no free sites yet, so never called
    input: () => 0,                        // no input bytes
    read_register: () => {},               // no input data to copy
    register_len: () => 0,
    value_return: () => {},                // result already written to RET_BUF
    log_utf8: () => {},
    storage_read: () => 0, storage_write: () => 0,
    sha256: () => {}, block_index: () => 0,
    current_account_id: () => {}, predecessor_account_id: () => {},
  };
  const { instance } = await WebAssembly.instantiate(B, { env });
  const mem = instance.exports.memory;
  instance.exports.sum_literal();
  const v = Number(new DataView(mem.buffer).getBigUint64(RET_BUF, true));
  try {
    assert.equal(v, 60);
    // second call: the injected bump allocator persists; correctness unaffected.
    instance.exports.sum_literal();
    const v2 = Number(new DataView(mem.buffer).getBigUint64(RET_BUF, true));
    assert.equal(v2, 60);
    console.log("PASS sum_literal = 60 x2 (external: host-provided pf_alloc bump, via injected import)");
    process.exit(0);
  } catch (e) { console.error("FAIL", e); process.exit(1); }
})();