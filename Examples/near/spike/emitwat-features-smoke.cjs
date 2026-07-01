const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
const wasmPath = process.argv[2];
(async () => {
  const worker = await Worker.init({});
  try {
    const root = worker.rootAccount;
    const c = await root.devDeploy(path.resolve(wasmPath), {});
    await root.call(c, "init", {});
    assert.equal(await c.view("getN", {}), 0);
    assert.equal(await c.view("getFlag", {}), false);
    await root.call(c, "bump", {});   // n=5
    assert.equal(await c.view("getN", {}), 5);
    assert.equal(await c.view("getFlag", {}), false);  // 5>10 false
    await root.call(c, "bump", {});   // n=10
    assert.equal(await c.view("getN", {}), 10);
    assert.equal(await c.view("getFlag", {}), false);  // 10>10 false
    await root.call(c, "bump", {});   // n=15
    assert.equal(await c.view("getN", {}), 15);
    assert.equal(await c.view("getFlag", {}), true);   // 15>10 true
    console.log(JSON.stringify({ok:true, n:15, flag:true}));
  } finally { await worker.tearDown(); }
})().catch(e => { console.error(e.stack||e); process.exit(1); });
