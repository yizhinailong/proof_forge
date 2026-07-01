const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
const u64 = (n) => { const b = new Uint8Array(8); const v = new DataView(b.buffer); v.setBigUint64(0, BigInt(n), true); return b; };
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(path.resolve(process.argv[2]), {});
    await root.call(c, "setN", u64(42));
    assert.equal(await c.view("getN", {}), 42, "setN(42)");
    await root.call(c, "setN", u64(1000));
    assert.equal(await c.view("getN", {}), 1000, "setN(1000)");
    const sum = new Uint8Array(16); sum.set(u64(10), 0); sum.set(u64(32), 8);
    await root.call(c, "setSum", sum);
    assert.equal(await c.view("getN", {}), 42, "setSum(10,32)");
    console.log(JSON.stringify({ok:true, single:42, multi:42}));
  } finally { await w.tearDown(); }
})().catch(e => { console.error(e.stack||e); process.exit(1); });
