/// Standalone Node smoke test for the Counter Wasm guest.
/// This does not go through Wrangler/Miniflare; it directly wires the host
/// imports and calls the guest `fetch` export to verify the protocol.

const fs = require('fs');
const path = require('path');

const wasmBytes = fs.readFileSync(path.join(__dirname, 'build', 'counter.wasm'));

async function main() {
  const kv = new Map();
  const textEncoder = new TextEncoder();
  const textDecoder = new TextDecoder();

  let instance;

  function mem() {
    return instance.exports.memory;
  }

  const imports = {
    env: {
      kv_get: (keyPtr, keyLen) => {
        const key = textDecoder.decode(new Uint8Array(mem().buffer, keyPtr, keyLen));
        const value = kv.get(key);
        if (value === undefined) return 0;
        const valueBytes = textEncoder.encode(value + '\0');
        const valuePtr = instance.exports.malloc(valueBytes.length);
        new Uint8Array(mem().buffer).set(valueBytes, valuePtr);
        return valuePtr;
      },
      kv_put: (keyPtr, keyLen, valuePtr, valueLen) => {
        const key = textDecoder.decode(new Uint8Array(mem().buffer, keyPtr, keyLen));
        const value = textDecoder.decode(new Uint8Array(mem().buffer, valuePtr, valueLen));
        kv.set(key, value);
      },
      console_log: (msgPtr, msgLen) => {
        const msg = textDecoder.decode(new Uint8Array(mem().buffer, msgPtr, msgLen));
        console.log('[guest]', msg);
      },
    },
  };

  instance = (await WebAssembly.instantiate(wasmBytes, imports)).instance;

  function callFetch(method) {
    const reqBytes = textEncoder.encode(method + '\n');
    const reqPtr = instance.exports.malloc(reqBytes.length);
    new Uint8Array(mem().buffer).set(reqBytes, reqPtr);
    const respPtr = instance.exports.fetch(reqPtr, reqBytes.length);
    const bytes = new Uint8Array(mem().buffer);
    let end = respPtr;
    while (bytes[end] !== 0) end += 1;
    return textDecoder.decode(bytes.subarray(respPtr, end));
  }

  console.log('initialize:', callFetch('initialize'));
  console.log('get:', callFetch('get'));
  console.log('increment:', callFetch('increment'));
  console.log('increment:', callFetch('increment'));
  console.log('get:', callFetch('get'));

  if (callFetch('get') !== 'OK\n2') {
    throw new Error('unexpected final count');
  }
  console.log('smoke test passed');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
