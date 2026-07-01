# Wasm Family Targets

The Wasm family includes NEAR, CosmWasm, Stellar/Soroban, Internet Computer
canisters, and later Polkadot/ink-style contracts. They share an executable
format, but not a contract ABI. ProofForge should share only the parts that are
genuinely common.

## Common Shape

The canonical Wasm-family backend is **`EmitWat`**, modeled on the in-repo
`EmitYul` EVM backend. `EmitYul` already proves that Lean's LCNF can be
lowered to a target while intercepting `lean_evm_*` externs, using a minimal
in-target object model (boxed scalars, bump allocator, refcount elided, no GC)
that is safe because EVM calls are atomic with per-call memory. Wasm contract
calls share exactly those properties (state persists via host storage; linear
memory is fresh per invocation), so the same trick applies — and crucially it
**avoids porting the full Lean runtime to Wasm**, which is the documented
blocker for the older `EmitZig` plan ([D-027](../decisions.md)).

```text
Lean contract (ProofForge.<Chain> externs)
  -> Lean compiler LCNF
  -> EmitWat            (shared: LCNF -> WAT text, object model, extern interception)
  -> WAT module
  -> wat2wasm / wabt    (shared toolchain)
  -> Wasm artifact
  -> per-chain host bridge (the ONLY chain-specific runtime code)
  -> target-specific validation
```

**Shared layer (write once for the whole family):**

- `EmitWat`: LCNF → WAT text lowering, mirroring `ProofForge/Compiler/LCNF/EmitYul.lean`.
- Lean object model in linear memory: boxing convention, bump allocator,
  refcount elision — ported from the `EmitYul` design.
- WAT module scaffolding: memory, type section, function/import/export tables,
  and the `wat2wasm` invocation + artifact metadata.

**Per-chain layer (the only thing that differs between NEAR / CosmWasm / Soroban / ICP):**

- `ProofForge.<Chain>` extern module: `@[extern "lean_<chain>_*"]`
  declarations for that chain's on-chain operations (storage, crypto, context,
  logs, cross-calls).
- Host-import mapping: which Wasm imports those externs lower to
  (NEAR `env.storage_*`, CosmWasm `db.read`/`db.write`, Soroban host functions, …).
- **ABI serialization** of arguments and return values (NEAR JSON/Borsh,
  CosmWasm JSON, …) — the messiest per-chain concern and the main spike risk.
- Exported entrypoint names + deployment packaging.

The shared/per-chain split is the whole point: tooling is identical across the
family, only the host bridge and ABI differ.

## Legacy paths

- **`EmitZig`** (prior canonical plan): `Lean → EmitZig → Zig → host bridge →
  Wasm`. Superseded by `EmitWat` because it requires porting the full Lean
  runtime to Wasm (libuv/threads/GC), which is the documented blocker. The
  useful lessons — `@[extern]` chain surface, host-bridge object conversion,
  method-export metadata, WASI stripping — carry over to `EmitWat`.
- **Rust / CDK sourcegen** (e.g. NEAR `near-sdk-rs`): `Portable IR → Rust
  package → cargo wasm32`. Retained only as a **frozen v0 stopgap** to validate
  chain semantics; not to be expanded. See [Wasm-NEAR target](wasm-near.md).

## NEAR

See [Wasm-NEAR target](wasm-near.md) for the full implementation design.

- **Canonical path:** `ProofForge.Near (@[extern lean_near_*]) → LCNF →
  EmitWat → WAT → wat2wasm → Wasm`, with a NEAR host bridge lowering
  `lean_near_*` to `env.storage_*` / `env.sha256` / `env.predecessor_account_id`
  / `env.block_height` / `env.log` imports.
- **Frozen v0 stopgap (in-repo, compiles):** Rust `near-sdk-rs` sourcegen via
  `ProofForge/Backend/WasmNear/IR.lean`. Validates NEAR semantics now; not
  expanded. Key risk for the canonical path: NEAR argument (de)serialization
  (JSON/Borsh), which the EVM backend does not face (EVM uses calldata).

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

Under `EmitWat` the Lean runtime is **not** ported wholesale; instead
`EmitWat` lowers only the object-model primitives needed (alloc, tag,
refcount-as-no-op) into Wasm linear memory, exactly as `EmitYul` does for EVM.
The remaining target concerns are still real and selected per target:

- threads — none (single-threaded, atomic per call)
- POSIX filesystem — none
- process environment — none
- libuv — none
- native GMP — none (bignum handled by the lowering/object model)
- chain-agnostic force-linking of host bridges — none

| Option | NEAR | CosmWasm | Stellar/Soroban | ICP canister |
|---|---|---|---|---|
| Object allocator | shared `EmitWat` bump allocator (per-call linear memory) | shared | shared | shared |
| Bignum / Hash | shared `EmitWat` lowering (multi-limb in linear memory) | shared | shared | shared |
| Host bridge | `near` (`env.*`) | `cosmwasm` (`db.*`) | `stellar-soroban` | `icp-canister` |
| Args ABI | JSON / Borsh | JSON | Soroban XDR / native | Candid |
| Validation | NEAR VM/MVP checks | `cosmwasm-check` | Stellar CLI or sandbox | Local replica, PocketIC, or ICP CLI |

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

- **[NEAR spike gate]** Can NEAR argument (de)serialization (JSON/Borsh) be
  lowered cleanly under `EmitWat`? This is the highest-risk unknown and must be
  de-risked before scaling the lowering.
- Should `EmitWat` emit WAT text (→ `wat2wasm`) or Wasm binary directly? WAT
  text is the default (mirrors `EmitYul` → Yul text → `solc`); binary is a
  later optimization to drop the `wabt` dependency.
- How much of the `EmitYul` object model (boxing, allocator, closure dispatch)
  can be lifted verbatim into a shared `EmitWat` object model?
- Should CosmWasm compile through `wasm32-freestanding` or a WASI route with
  import stripping?
- Should schema generation (CosmWasm JSON schema, Soroban spec, ICP `.did`)
  come from Lean types or a separate manifest?
- Should Soroban / ICP start as native Rust/Motoko package sourcegen before a
  direct `EmitWat` host bridge?
