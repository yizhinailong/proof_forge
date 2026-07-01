const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(path.resolve(process.argv[2]), {});
    // before set: defaults
    assert.equal(await c.view("getFive", {}), 0);
    assert.equal(await c.view("getMissing", {}), 0);
    assert.equal(await c.view("hasFive", {}), false);
    await root.call(c, "setHundred", {});
    assert.equal(await c.view("getFive", {}), 100);
    assert.equal(await c.view("hasFive", {}), true);
    assert.equal(await c.view("getMissing", {}), 0);   // other key still default
    console.log(JSON.stringify({ok:true, five:100, missing:0, hasFive:true}));
  } finally { await w.tearDown(); }
})().catch(e => { console.error(e.stack||e); process.exit(1); });
