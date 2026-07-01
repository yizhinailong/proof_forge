# Wasm Family Targets

The Wasm family includes NEAR, CosmWasm, Stellar/Soroban, Internet Computer
canisters, later Polkadot/ink-style contracts, and Cloudflare Workers. They
share an executable format, but not a contract ABI. Cloudflare Workers is not a
blockchain, but it uses the same Wasm-host backend pattern: a generated Wasm
module plus a target-specific host bridge. ProofForge should share only the
parts that are genuinely common. See [Cloudflare Workers target](cloudflare-workers.md)
for the off-chain reinterpretation of capabilities.

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

## Stellar/Soroban

Stellar smart contracts are also Wasm artifacts, but Soroban has its own SDK,
host environment, storage lifecycle, authorization model, deployment flow, and
CLI tooling.

Candidate target id: `wasm-stellar-soroban`.

Current native path:

```text
Rust + soroban-sdk
  -> stellar contract build
  -> wasm32v1-none Wasm
  -> stellar contract deploy / invoke
```

Target-specific concerns:

- build flow uses Rust and Stellar CLI rather than `cosmwasm-check`;
- storage distinguishes instance, persistent, and temporary entries, with TTL
  and archival behavior;
- authorization is explicit and address-based through `require_auth`-style
  calls, not just a sender read;
- contract accounts can implement custom authorization;
- contract interface/spec metadata is part of the developer workflow;
- deployment separates Wasm upload/install from contract instantiation.

The first ProofForge spike may generate or wrap a native Soroban package before
attempting a direct Lean-to-Wasm host bridge. See
[Stellar Soroban target](stellar-soroban.md).

## Internet Computer Canisters

Internet Computer canisters are Wasm modules plus persistent canister state and
Candid interfaces. They have their own message model, lifecycle, cycles
accounting, stable memory, and management canister APIs.

Candidate target id: `wasm-icp-canister`.

Current native paths:

```text
Motoko or Rust CDK
  -> Wasm canister module
  -> Candid .did interface
  -> local replica / PocketIC / ICP CLI validation
```

Target-specific concerns:

- update, query, and composite query methods have different semantics;
- Candid service metadata is part of the public contract interface;
- caller and canister identities are principals;
- persistent state may rely on canister memory, stable memory, or
  CDK-managed stable structures;
- inter-canister calls are asynchronous message flows;
- cycles are the resource-accounting unit, not ordinary native value;
- deployment and upgrades go through canister lifecycle and management canister
  APIs.

The first ProofForge spike may generate or wrap a native Motoko/Rust CDK
canister before attempting a direct Lean-to-Wasm host bridge. See
[Internet Computer target](internet-computer.md).

## Runtime Profile

The Wasm runtime profile should avoid:

- threads
- POSIX filesystem
- process environment
- libuv
- native GMP
- target-agnostic force-linking of chain hosts

Runtime options should be selected by target:

|| Option | NEAR | CosmWasm | Stellar/Soroban | ICP canister | Cloudflare Workers |
|---|---|---|---|---|---|---|
|| Allocator | bump or Wasm-safe allocator | CosmWasm allocator ABI | Soroban-compatible Wasm allocation path | Canister-compatible Wasm allocation path | bump or Wasm-safe allocator |
|| MPZ | Zig bigint or restricted arithmetic | Zig bigint or restricted arithmetic | Zig bigint or restricted arithmetic | Zig bigint or restricted arithmetic | Zig bigint or restricted arithmetic |
|| Host bridge | `near` | `cosmwasm` | `stellar-soroban` | `icp-canister` | `cloudflare-workers` |
|| Validation | NEAR VM/MVP checks | `cosmwasm-check` | Stellar CLI or sandbox | Local replica, PocketIC, or ICP CLI | `wrangler dev` / Miniflare |

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
- Should Soroban start as native Rust/Soroban package sourcegen before a direct
  Lean-to-Wasm host bridge?
- Should ICP start as native Motoko/Rust CDK package sourcegen before a direct
  Lean-to-Wasm canister bridge?
