const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
const wasmPath = process.argv[2];
function num(v){ return typeof v==="bigint"?Number(v): typeof v==="string"?Number(v): Buffer.isBuffer(v)?Number(v.toString("utf8")):Number(v); }
(async () => {
  const worker = await Worker.init({});
  try {
    const root = worker.rootAccount;
    const c = await root.devDeploy(path.resolve(wasmPath), {});
    await root.call(c, "initialize", {});
    const a = await c.view("get", {});
    assert.equal(num(a), 0, `after init, get should be 0 (got ${num(a)})`);
    await root.call(c, "increment", {});
    const b = await c.view("get", {});
    assert.equal(num(b), 1, `after increment, get should be 1 (got ${num(b)})`);
    console.log(JSON.stringify({ok:true, afterInit:num(a), afterIncrement:num(b)}));
  } finally { await worker.tearDown(); }
})().catch(e => { console.error(e.stack||e); process.exit(1); });
