const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(path.resolve(process.argv[2]), {});
    await root.call(c, "setHash", {});
    assert.equal(await c.view("checkStored", {}), 1, "stored hash roundtrip");
    assert.equal(await c.view("checkDeterminism", {}), 1, "sha256 determinism");
    assert.equal(await c.view("checkTwoToOne", {}), 1, "hash_two_to_one determinism");
    console.log(JSON.stringify({ok:true, stored:1, determinism:1, twoToOne:1}));
  } finally { await w.tearDown(); }
})().catch(e => { console.error(e.stack||e); process.exit(1); });
