# Wasm-NEAR Target (Rust `near-sdk-rs` Sourcegen)

**Target id:** `wasm-near`
**Family:** Wasm host
**Stage:** Spike (in progress — CLI emit modes, IR lowering, package generation)
**Backend pattern:** Portable IR → Rust `near-sdk-rs` package → `cargo build --target wasm32-unknown-unknown` → NEAR-compatible Wasm

## Two Paths

The canonical future path (from the local Lean fork) is:

```text
Lean.Near → EmitZig → tools/zigc-near → host/near/lean_near.zig → Wasm
```

The EmitZig fork and Zig host bridge sources are not present in this repository.
The current in-repo v0 path uses Rust source generation as a fallback:

```text
Portable IR → near-sdk-rs package (Cargo.toml, src/lib.rs) → cargo wasm32 → Wasm
```

This validates NEAR semantics now and preserves the Zig host-bridge path for
restoration later. See [D-018](../decisions.md).

## Capability Profile

Defined in `ProofForge/Target/Registry.lean` (`def wasmNear`):

| Capability | Supported | Notes |
|---|---|---|
| `storage.scalar` | Yes | u32, u64, bool, hash → Rust struct fields |
| `storage.map` | Yes | Map<U64, …> and Map<Hash, …> → raw `env::storage_read`/`env::storage_write` |
| `caller.sender` | Yes | `env::predecessor_account_id()` |
| `value.native` | Yes (capability) | Attached deposit capability declared; expression inspection not supported in v0 |
| `events.emit` | Yes | `near_sdk::log!` with deterministic JSON |
| `env.block` | Yes | `env::block_height()` |
| `crypto.hash` | Yes | `env::sha256`-based hash helpers |
| `assertions.check` | Yes | Lowered to Rust `assert!`/`assert_eq!` |
| `account.explicit` | Yes | `env::current_account_id()` |
| `crosscall.invoke` | No | Not supported in sourcegen v0 |
| `storage.array` | No | Rejected by capability check |
| `control.conditional` | No | Rejected by capability check |
| `control.bounded_loop` | No | Rejected by capability check |
| `data.fixed_array` | No | Rejected by capability check |
| `data.struct` | No | Rejected by capability check |

## Deviations from Original Plan

The implementation diverged from the original plan in several places, all
documented in [D-019](../decisions.md):

1. **Map keys widened to Hash.** The plan specified only `Map<U64, …>`, but
   `MapProbe` uses `Map<Hash, Hash, 128>`. The implementation supports both U64
   and Hash keys with separate `__pf_map_key_u64`/`__pf_map_key_hash` helpers.

2. **`.assertions` and `.accountExplicit` added.** The plan's capability list
   omitted these, but `MapProbe` uses `assertEq` and `ContextProbe` uses
   `contractId`. Both are now in the profile and lowered.

3. **`.crosscallInvoke` removed.** As planned, not supported in v0 sourcegen.

4. **`assert`/`assertEq` lowered.** Since `.assertions` is in the profile,
   these lower to Rust `assert!`/`assert_eq!` macros rather than being rejected.

5. **`ifElse`/`boundedFor` rejected.** Not in the capability profile.

6. **`nativeValue` expression rejected.** Despite `.valueNative` being in the
   profile (for the capability declaration), the expression for inspecting
   attached deposit is not supported in v0.

## Generated Package Structure

`renderPackage` produces a `NearPackage` with these files:

- `Cargo.toml` — package name sanitized from module name, dependencies on
  `near-sdk = "5"`, `borsh = "1"`, `serde = "1"`, `serde_json = "1"`
- `src/lib.rs` — `#[near(contract_state)]` struct, `Default` impl,
  `#[near] impl` block with entrypoints, and conditional helper functions

### Scalar State

Scalar state fields become Rust struct fields with `BorshDeserialize`/`BorshSerialize`:

| IR type | Rust type | Default |
|---|---|---|
| `u32` | `u32` | `0u32` |
| `u64` | `u64` | `0u64` |
| `bool` | `bool` | `false` |
| `hash` | `[u64; 4]` | `[0u64, 0u64, 0u64, 0u64]` |

### Map State

Map state uses raw NEAR KV storage through `env::storage_read`,
`env::storage_write`, and `env::storage_has_key`. Key helpers are emitted per
key type used:

- `__pf_map_key_u64(prefix, key)` — for `Map<U64, …>`
- `__pf_map_key_hash(prefix, key)` — for `Map<Hash, …>`

Codec helpers are emitted only for value types actually used by the module:
`__pf_encode_u64`/`__pf_decode_u64`, `__pf_encode_bool`/`__pf_decode_bool`,
`__pf_encode_hash`/`__pf_decode_hash`.

Map set helpers (`__pf_map_set_u64`, `__pf_map_set_bool`, `__pf_map_set_hash`)
return the previous value, matching existing Psy/EVM map semantics.

### Context Fields

| IR context field | Rust lowering |
|---|---|
| `userId` | `__pf_account_id_hash_u64(&env::predecessor_account_id())` |
| `contractId` | `__pf_account_id_hash_u64(&env::current_account_id())` |
| `checkpointId` | `env::block_height()` |

The `__pf_account_id_hash_u64` helper is emitted when either `.userId` or
`.contractId` is used.

### Hash Helpers

Emitted when `.cryptoHash` is used:

- `__pf_hash(value: [u64; 4]) -> [u64; 4]` — single-value SHA-256
- `__pf_hash_two_to_one(left: [u64; 4], right: [u64; 4]) -> [u64; 4]` — two-to-one SHA-256

### Events

`eventEmit` lowers to `near_sdk::log!` with deterministic JSON. v0 supports
`U32`, `U64`, `Bool`, and `Hash` event fields.

## CLI Modes

```
proof-forge --emit-counter-ir-wasm-near -o build/wasm-near/Counter
proof-forge --emit-context-ir-wasm-near -o build/wasm-near/ContextProbe
proof-forge --emit-hash-ir-wasm-near -o build/wasm-near/HashProbe
proof-forge --emit-map-ir-wasm-near -o build/wasm-near/MapProbe
```

`-o` is required for wasm-near modes and is interpreted as a package output
directory (not a single file). Existing EVM/Psy `-o` behavior is unchanged.

## Implementation Files

| File | Purpose |
|---|---|
| `ProofForge/Backend/WasmNear.lean` | Umbrella module |
| `ProofForge/Backend/WasmNear/IR.lean` | Core lowering: validation, type inference, Rust source generation (~57KB) |
| `ProofForge/Target/Registry.lean` | `wasmNear` profile with tools and capabilities |
| `ProofForge/Cli.lean` | `EmitMode` constructors, parse cases, `writeNearPackage`, compile functions |

## Required Tools

- `rustup` + `cargo` + `wasm32-unknown-unknown` target
- `near-cli` (for deployment validation; not required for source generation or cargo build)

## Verification

```sh
# Build the compiler
lake build

# Generate a Counter package
lake env proof-forge --emit-counter-ir-wasm-near -o build/wasm-near/Counter

# Build the Wasm artifact
cd build/wasm-near/Counter && cargo build --target wasm32-unknown-unknown --release

# Run diagnostics
lake env lean --run Tests/WasmNearDiagnostics.lean
```

## Open Questions

- Should the Zig host-bridge path be restored before expanding capability
  coverage beyond the current subset?
- Should `nativeValue` expression inspection be added as a dedicated IR context
  field for attached deposit?
- Should map storage use `near_sdk::collections::LookupMap` instead of raw
  `env::storage_read`/`env::storage_write` for better NEAR SDK integration?
