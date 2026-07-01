const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(path.resolve(process.argv[2]), {});
    // predecessor_account_id is only valid in change (call) methods, not views:
    const r = await root.call(c, "callerStable", {});
    assert.equal(Number(r), 1, "predecessor hash determinism (call)");
    assert.equal(await c.view("contractStable", {}), 1, "contract id hash determinism (view)");
    const h = await c.view("checkpoint", {});
    assert.ok(typeof h === "number" && h >= 0, `checkpoint should be a number (got ${h})`);
    console.log(JSON.stringify({ok:true, callerStable:1, contractStable:1, checkpoint:h}));
  } finally { await w.tearDown(); }
})().catch(e => { console.error(e.stack||e); process.exit(1); });
