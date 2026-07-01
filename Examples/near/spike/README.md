# wasm-near EmitWat spike — hand-written reference

A minimal hand-written NEAR counter in raw WAT, used to de-risk the `EmitWat`
canonical path (portable IR → Wasm AST → WAT → `wat2wasm`) before building the
Lean lowering. See `docs/targets/wasm-near.md` (Canonical architecture) and
decision D-023.

## What it proves

A ~40-line WAT contract with **no Lean runtime, no WASI imports, no
`near-sdk`** deploys to `near-sandbox` and passes the counter scenario
(`init` → `get`==0 → `increment` → `get`==1). This confirms:

- The NEAR register-based host ABI (`env.storage_read/write`,
  `env.read_register`, `env.value_return`, `env.log_utf8`) is tractable at the
  WAT level.
- Contract methods export as `() -> ()` dispatchers; args come via the input
  register and returns via `env.value_return` (not wasm function returns).
- A scalar value stored as ASCII bytes round-trips through `value_return` as
  JSON-parseable output (`JSON.parse("0") == 0`).

## Run it

Requires `wabt` (`brew install wabt`) and the sandbox harness from the
`lean4-zig-compiler` fork (`tests/emitzig_near/near_workspaces_smoke.cjs` +
`near-sandbox` + `near-workspaces`):

```sh
wat2wasm handwritten-counter.wat -o handwritten-counter.wasm
# then point near_workspaces_smoke.cjs (scenario=counter) at the wasm
```

## Exact host signatures (from near-vm-logic / sys.zig)

```
storage_read (key_len, key_ptr, register_id) -> u64   // 0/1 found
storage_write(key_len, key_ptr, value_len, value_ptr, register_id) -> u64  // evicted len
read_register(register_id, ptr) -> void
register_len (register_id) -> u64
value_return (value_len, value_ptr) -> void
log_utf8     (len, ptr) -> void
```
