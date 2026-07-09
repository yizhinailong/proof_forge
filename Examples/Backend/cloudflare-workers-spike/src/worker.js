/// Cloudflare Workers host bridge for the Counter Wasm spike.
///
/// This is the JavaScript side that loads the guest Wasm, wires up KV host
/// imports, and exposes the `fetch` entry point expected by Workers.
///
/// The contract between host and guest is documented in `src/counter.zig`.

import wasmModule from "../build/counter.wasm";

const COUNT_KEY = "count";
const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

function encode(str) {
  return textEncoder.encode(str);
}

function decode(bytes) {
  return textDecoder.decode(bytes);
}

export default {
  async fetch(request, env, _ctx) {
    // Per-request KV cache. Workers KV reads/writes are async, so we buffer
    // state for the synchronous guest imports and flush at the end.
    let kvCache = {};
    let kvDirty = false;

    // Warm cache from KV.
    try {
      const stored = await env.COUNTER_KV?.get(COUNT_KEY);
      if (stored !== null && stored !== undefined) {
        kvCache[COUNT_KEY] = stored;
      }
    } catch (e) {
      console.warn("KV get failed:", e);
    }

    function mem() {
      return instance.exports.memory;
    }

    const imports = {
      env: {
        kv_get: (keyPtr, keyLen) => {
          const key = decode(new Uint8Array(mem().buffer, keyPtr, keyLen));
          const value = kvCache[key];
          if (value === undefined) return 0;
          const valueBytes = encode(value + "\0");
          const valuePtr = instance.exports.malloc(valueBytes.length);
          new Uint8Array(mem().buffer).set(valueBytes, valuePtr);
          return valuePtr;
        },
        kv_put: (keyPtr, keyLen, valuePtr, valueLen) => {
          const key = decode(new Uint8Array(mem().buffer, keyPtr, keyLen));
          const value = decode(new Uint8Array(mem().buffer, valuePtr, valueLen));
          kvCache[key] = value;
          kvDirty = true;
        },
        console_log: (msgPtr, msgLen) => {
          const msg = decode(new Uint8Array(mem().buffer, msgPtr, msgLen));
          console.log("[guest]", msg);
        },
      },
    };

    // Wrangler imports .wasm files as a WebAssembly.Module, so instantiate()
    // returns the Instance directly (not a { module, instance } result object).
    const instance = await WebAssembly.instantiate(wasmModule, imports);

    // Map HTTP request to contract method.
    const url = new URL(request.url);
    let method;
    if (request.method === "POST" && url.pathname === "/initialize") {
      method = "initialize";
    } else if (request.method === "POST" && url.pathname === "/increment") {
      method = "increment";
    } else if (request.method === "GET" && url.pathname === "/count") {
      method = "get";
    } else {
      return new Response("ERR\nunknown route", { status: 404 });
    }

    // Call the guest `fetch` export.
    const reqBytes = encode(method + "\n");
    const reqPtr = instance.exports.malloc(reqBytes.length);
    new Uint8Array(mem().buffer).set(reqBytes, reqPtr);
    const respPtr = instance.exports.fetch(reqPtr, reqBytes.length);

    const bytes = new Uint8Array(mem().buffer);
    let end = respPtr;
    while (bytes[end] !== 0) end += 1;
    const resp = decode(bytes.subarray(respPtr, end));

    // Flush dirty cache back to KV.
    if (kvDirty && env.COUNTER_KV) {
      try {
        await env.COUNTER_KV.put(COUNT_KEY, kvCache[COUNT_KEY]);
      } catch (e) {
        console.error("KV put failed:", e);
      }
    }

    if (resp.startsWith("OK\n")) {
      const value = resp.slice(3);
      return new Response(value, {
        status: 200,
        headers: { "Content-Type": "text/plain" },
      });
    } else {
      return new Response(resp, { status: 500 });
    }
  },
};
