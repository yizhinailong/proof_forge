# ProofForge Offline Wasm Host

This crate is a local wasmtime runner for `EmitWat` output. It loads a `.wat` or
`.wasm` module, injects the NEAR-style host imports used by `EmitWat`, and runs
one or more exported entrypoints in the same instance. It is not part of the
chain artifact.

The allocator boundary is intentional: `pf_alloc(n) -> i32` returns an offset in
the guest wasm linear memory. It never returns a native host pointer. The current
host implementation manages that linear memory with a bump allocator plus a
reserved free-list path for future `pf_dealloc` call sites.

`alloc.jemalloc` currently selects the same `pf_alloc` / `pf_dealloc` import ABI
as `alloc.external`. A real jemalloc experiment must compile/link jemalloc into
wasm so it allocates from the same linear memory; host-process jemalloc cannot be
used directly by guest wasm.

`alloc.minimal_malloc` is different: `EmitWat` emits allocator code into the
module itself. The offline host does not provide `pf_alloc` for that path; it
only provides the NEAR-style environment imports. See
`docs/targets/wasm-allocators.md` for the strategy split.

## Usage

Generate allocator WAT fixtures:

```sh
lake env lean --run Tests/EmitWatAlloc.lean
```

Run the jemalloc-shaped fixture through wasmtime:

```sh
cargo run --manifest-path runtime/offline-host/Cargo.toml -- \
  run build/wasm-near/emitwat-alloc-jemalloc.wat sum_literal --repeat 2
```

Run the wasm-internal `minimalMalloc` fixture:

```sh
cargo run --manifest-path runtime/offline-host/Cargo.toml -- \
  run build/wasm-near/emitwat-alloc-minimal.wat sum_literal --repeat 2
```

Compile WAT to wasm with wabt and run the binary path:

```sh
wat2wasm build/wasm-near/emitwat-alloc-jemalloc.wat \
  -o build/wasm-near/emitwat-alloc-jemalloc.wasm
cargo run --manifest-path runtime/offline-host/Cargo.toml -- \
  run build/wasm-near/emitwat-alloc-jemalloc.wasm sum_literal --repeat 2
```

Multiple exports can be listed to exercise one module instance with shared host
storage:

```sh
cargo run --manifest-path runtime/offline-host/Cargo.toml -- \
  run build/wasm-near/emitwat-features.wat init bump bump getN getFlag
```
