# Wasm Allocators

This note separates three allocator surfaces that are easy to conflate.

## Where allocation happens

Wasm guest code can only dereference offsets inside its own linear memory.
Any allocator used by generated contract code must therefore return a wasm
linear-memory offset. A native host pointer from the runner process is not a
valid contract pointer.

That gives ProofForge three distinct cases:

| Strategy | Where it lives | Chain deployable | Current role |
|---|---|---:|---|
| `alloc.bump` | generated wasm module | yes | simplest no-free allocator |
| `alloc.bump_reset` | generated wasm module | yes | resets the bump frontier at each entrypoint |
| `alloc.minimal_malloc` | generated wasm module | yes | first-fit free-list allocator skeleton for direct WAT output |
| `alloc.external` | offline host import ABI | no on NEAR | simulator hook for allocator experiments |
| `alloc.jemalloc` / `alloc.mimalloc` | imported or wasm-linked allocator ABI | no on NEAR unless linked into the final wasm | future experiments |

The offline runner in `runtime/offline-host` is not the chain allocator. It
only supplies host imports for local execution. For imported allocator
strategies, it also implements `pf_alloc` / `pf_dealloc` by managing offsets in
the guest memory. For `alloc.minimal_malloc`, those imports are absent and the
allocation happens inside the generated wasm module.

## NEAR and `wee_alloc`

NEAR Rust SDK contracts use the Rust compiler path: Rust code plus SDK crates
compile into one wasm module, and the selected global allocator is linked into
that same module. In current `near-sdk-rs`, `wee_alloc` is an optional wasm32
dependency and the default feature set enables `wee_alloc`; the deprecated
`setup_alloc` macro documentation says allocator setup is already done by
default when that feature is enabled.

`EmitWat` does not go through Rust, so it cannot directly depend on the Rust
`wee_alloc` crate. The equivalent direct-WAT shape is `alloc.minimal_malloc`:
allocator code is emitted into the module, returns linear-memory offsets, and
uses `memory.grow` when the module needs more pages. This follows the same
placement model as NEAR's Rust path without claiming byte-for-byte parity with
the `wee_alloc` crate.

## Current `minimalMalloc`

`alloc.minimal_malloc` emits:

- `global $arr_ptr`: bump frontier for new blocks
- `global $arr_free`: head of a singly linked free list
- `func $__pf_arr_alloc(n: i64) -> i32`
- `func $__pf_arr_dealloc(p: i32, n: i64)`

Block layout:

```text
block_ptr + 0: u32 total_block_size
block_ptr + 4: u32 next_free_block
block_ptr + 8: payload returned to generated contract code
```

Allocation first scans the free list for a block large enough. If none exists,
it extends `arr_ptr`; if the new frontier exceeds the current memory size, it
uses `memory.grow`. The current version does not split or coalesce blocks.

The portable IR currently has no release/scope semantics, so generated modules
do not call `__pf_arr_dealloc` yet. This means `minimalMalloc` mostly behaves
like a growing allocator today, but the free-list path is present for the point
where IR lifetimes exist.

## What not to do

- Do not wire host-process `jemalloc` directly to `pf_alloc` for chain code.
  It would return native pointers, which wasm cannot dereference.
- Do not require `pf_alloc` / `pf_dealloc` imports for NEAR deployable output.
  NEAR does not provide those imports.
- Do not call the direct-WAT allocator `wee_alloc` unless the actual Rust crate
  is compiled and linked into the final wasm artifact.

