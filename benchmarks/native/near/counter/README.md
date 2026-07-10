# Native NEAR Counter

Hand-written near-sdk reference for `bm-counter` on `wasm-near`.

**Source of truth (already in-tree):**  
[`testkit/compare/near/counter`](../../../../testkit/compare/near/counter)

That package is the durable NEAR compare baseline used by `just near-compare`.
B1 reuses it rather than duplicating the crate.

```sh
# Host unit tests (optional):
cargo test --manifest-path testkit/compare/near/counter/Cargo.toml --features host-tests

# Full compare (ProofForge WAT vs near-sdk size/fuel):
just near-compare
```

Symlink-friendly layout for tools that expect `benchmarks/native/near/counter/src`:

| Path | Resolves to |
|------|-------------|
| `Cargo.toml` | copy pointer — use testkit path |
| `src/lib.rs` | see testkit package |

For B1 runners, set `NATIVE_NEAR_COUNTER_DIR=testkit/compare/near/counter`.
