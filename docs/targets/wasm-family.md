# Wasm Family Targets

The Wasm family includes NEAR, CosmWasm, and later Polkadot/ink-style
contracts. They share an executable format, but not a contract ABI. ProofForge
should share only the parts that are genuinely common.

## Common Shape

```text
Lean contract
  -> EmitZig
  -> generated Zig module
  -> target-selected Lean Zig runtime
  -> target host bridge
  -> Wasm artifact
  -> target-specific validation
```

Common work:

- Lean-to-Zig code generation.
- Lean runtime compiled for Wasm.
- Single-threaded runtime profile.
- Wasm-safe allocator strategy.
- No POSIX/libuv assumptions.
- Artifact metadata.

Target-specific work:

- Exported function names and signatures.
- Host imports.
- Storage ABI.
- Event/log ABI.
- Cross-contract call model.
- Validation tooling.
- Deployment packaging.

## NEAR

The local Lean fork already proves the NEAR shape:

```text
Lean.Near
  -> EmitZig
  -> tools/zigc-near
  -> near_contract_root.zig
  -> host/near/lean_near.zig
  -> NEAR-compatible Wasm
```

Key lessons:

- The Lean SDK can expose chain operations through `@[extern]`.
- The Zig host bridge should convert Lean objects into target host calls.
- Method exports can be generated from sidecar metadata.
- WASI imports may need stripping or stubbing for the target VM.
- NEAR's storage model is implicit contract KV storage.

Design cleanup before porting:

- Do not keep `lean_near_*` declarations in generic EmitZig extern lists.
- Do not force-link NEAR host code for every Wasm target.
- Move method metadata into the unified target manifest.

## CosmWasm

CosmWasm is also Wasm, but its ABI is message-oriented.

Expected exports:

- `interface_version_8`
- `allocate`
- `deallocate`
- `instantiate`
- `execute`
- `query`
- later: `migrate`, `reply`, `sudo`, `ibc_channel_open`,
  `ibc_channel_connect`, `ibc_channel_close`, `ibc_packet_receive`,
  `ibc_packet_ack`, `ibc_packet_timeout`

Expected imports include storage, address, crypto, debug, and chain query host
functions. Exact imports should be taken from the supported CosmWasm VM version
when implementation starts.

First adapter behavior:

- Keep messages as JSON strings.
- Return JSON responses.
- Represent events as attributes.
- Use string-keyed storage first.
- Add typed schema generation later.

## Runtime Profile

The Wasm runtime profile should avoid:

- threads
- POSIX filesystem
- process environment
- libuv
- native GMP
- target-agnostic force-linking of chain hosts

Runtime options should be selected by target:

| Option | NEAR | CosmWasm |
|---|---|---|
| Allocator | bump or Wasm-safe allocator | CosmWasm allocator ABI |
| MPZ | Zig bigint or restricted arithmetic | Zig bigint or restricted arithmetic |
| Host bridge | `near` | `cosmwasm` |
| Validation | NEAR VM/MVP checks | `cosmwasm-check` |

## CosmWasm Counter Spike

Minimal Lean surface:

```lean
namespace CosmWasm

opaque inputJson : IO String
opaque storageRead : String -> IO (Option String)
opaque storageWrite : String -> String -> IO Unit
opaque storageRemove : String -> IO Unit
opaque returnJson : String -> IO Unit
opaque logAttribute : String -> String -> IO Unit
opaque queryChain : String -> IO String

end CosmWasm
```

Expected user contract shape:

```lean
def instantiate : CosmWasm.Entrypoint := do
  CosmWasm.storageWrite "count" "0"
  CosmWasm.returnJson "{\"ok\":true}"

def execute : CosmWasm.Entrypoint := do
  let msg <- CosmWasm.inputJson
  if msg == "{\"increment\":{}}" then
    ...

def query : CosmWasm.Entrypoint := do
  ...
```

Acceptance criteria:

- Wasm exports all required functions.
- `cosmwasm-check` accepts the artifact.
- Counter can instantiate, increment, and query.
- Artifact metadata records `target: wasm-cosmwasm`.

## Open Questions

- Should CosmWasm compile through `wasm32-freestanding` or a WASI route with
  import stripping?
- How much of the Lean runtime can be kept before artifact size becomes a
  practical issue?
- Should schema generation come from Lean types or a separate manifest?
- Should NEAR and CosmWasm share a generic Wasm memory allocator layer?
