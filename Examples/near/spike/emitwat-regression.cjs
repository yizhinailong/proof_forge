const assert = require("node:assert/strict");
const path = require("node:path");
const { Worker } = require("near-workspaces");
const u64 = (n) => { const b = new Uint8Array(8); new DataView(b.buffer).setBigUint64(0, BigInt(n), true); return b; };
const dec = (r, w) => { const b = Buffer.from(r.result); return w==="u64"?Number(b.readBigUInt64LE(0)):w==="u32"?b.readUInt32LE(0):b.readUInt8(0)!==0; };
const B = "/Users/davirian/orca/workspaces/proof_forge/lookdown/build/wasm-near/emitwat-";
async function run(file, fn) {
  const w = await Worker.init({}); let ok = true;
  try { const root = w.rootAccount; const c = await root.devDeploy(B+file+".wasm", {}); await fn(root, c); }
  catch(e){ console.error(file+" FAILED:", (e.message||e).split("\n")[0]); ok=false; }
  finally { await w.tearDown(); }
  return ok;
}
(async () => {
  let pass = 0, fail = 0;
  // Counter
  if (await run("counter", async (r,c)=>{ await r.call(c,"initialize",{}); assert.equal(dec(await c.viewRaw("get"),"u64"),0); await r.call(c,"increment",{}); assert.equal(dec(await c.viewRaw("get"),"u64"),1); })) pass++; else fail++;
  // Features
  if (await run("features", async (r,c)=>{ await r.call(c,"init",{}); assert.equal(dec(await c.viewRaw("getN"),"u32"),0); assert.equal(dec(await c.viewRaw("getFlag"),"bool"),false); for(let i=0;i<3;i++) await r.call(c,"bump",{}); assert.equal(dec(await c.viewRaw("getN"),"u32"),15); assert.equal(dec(await c.viewRaw("getFlag"),"bool"),true); })) pass++; else fail++;
  // Map
  if (await run("map", async (r,c)=>{ assert.equal(dec(await c.viewRaw("getFive"),"u64"),0); assert.equal(dec(await c.viewRaw("hasFive"),"bool"),false); await r.call(c,"setHundred",{}); assert.equal(dec(await c.viewRaw("getFive"),"u64"),100); assert.equal(dec(await c.viewRaw("hasFive"),"bool"),true); assert.equal(dec(await c.viewRaw("getMissing"),"u64"),0); })) pass++; else fail++;
  // Hash
  if (await run("hash", async (r,c)=>{ await r.call(c,"setHash",{}); assert.equal(dec(await c.viewRaw("checkStored"),"u64"),1); assert.equal(dec(await c.viewRaw("checkDeterminism"),"u64"),1); assert.equal(dec(await c.viewRaw("checkTwoToOne"),"u64"),1); })) pass++; else fail++;
  // Context (callerStable is a call; assertEq traps if wrong)
  if (await run("context", async (r,c)=>{ await r.call(c,"callerStable",{}); await c.viewRaw("contractStable"); const h=dec(await c.viewRaw("checkpoint"),"u64"); assert.ok(typeof h==="number"&&h>=0); })) pass++; else fail++;
  // Params
  if (await run("params", async (r,c)=>{ await r.call(c,"setN",u64(42)); assert.equal(dec(await c.viewRaw("getN"),"u64"),42); const s=new Uint8Array(16); s.set(u64(10),0); s.set(u64(32),8); await r.call(c,"setSum",s); assert.equal(dec(await c.viewRaw("getN"),"u64"),42); })) pass++; else fail++;
  // Event
  if (await run("event", async (r,c)=>{ const cap=[]; const ol=console.log; console.log=(...a)=>cap.push(a.join(" ")); await r.call(c,"emitEvent",{}); console.log=ol; const t=cap.join("\n"); assert.ok(t.includes('"event":"Seen"')&&t.includes('"value":42')&&t.includes('"ok":true')); })) pass++; else fail++;
  console.log(`\nEmitWat Borsh regression: ${pass} passed, ${fail} failed (of 7 probes)`);
  process.exit(fail===0?0:1);
})();
