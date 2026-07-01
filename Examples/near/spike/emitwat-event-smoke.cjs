const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
(async () => {
  const w = await Worker.init({});
  try {
    const root = w.rootAccount;
    const c = await root.devDeploy(path.resolve(process.argv[2]), {});
    const captured = [];
    const origLog = console.log;
    console.log = (...a) => { captured.push(a.join(" ")); };
    await root.call(c, "emitEvent", {});
    console.log = origLog;
    const text = captured.join("\n");
    origLog("CAPTURED LOGS:\n" + text);
    assert.ok(text.includes('"event":"Seen"'), "missing event key");
    assert.ok(text.includes('"value":42'), "missing value");
    assert.ok(text.includes('"ok":true'), "missing ok");
    origLog(JSON.stringify({ok:true, event:"Seen", value:42, ok_:true}));
  } finally { await w.tearDown(); }
})().catch(e => { console.error(e.stack||e); process.exit(1); });
