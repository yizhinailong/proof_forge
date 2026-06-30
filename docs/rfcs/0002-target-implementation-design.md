# RFC 0002: Target implementation design

Status: Draft

Date: 2026-06-30

## Summary

RFC 0001 defines the product direction. This RFC defines the first engineering
shape for implementing that direction.

ProofForge should not use one backend strategy for every chain. It should split
targets into implementation families:

- Direct compiler targets: ProofForge owns most lowering logic, as with the
  current EVM/Yul backend.
- Wasm host targets: ProofForge emits a Wasm module plus chain-specific host
  ABI adapters, as with NEAR and CosmWasm.
- Binary toolchain targets: ProofForge emits an intermediate object/bitcode and
  calls a chain-specific packager/linker, as with Solana sBPF.
- Source codegen targets: ProofForge emits target source packages, as with Sui
  Move and Aptos Move.

This keeps the portable contract model stable while allowing each chain family
to keep its native ABI, storage model, tooling, and tests.

## Design Goals

- Keep Lean as the user-facing language for business logic, types, and proofs.
- Keep target differences explicit through capabilities and target manifests.
- Integrate with mature target-native tools before replacing them.
- Make every build produce machine-readable artifact metadata.
- Make every supported target earn support through at least one local smoke
  test and one capability matrix entry.

Non-goal: arbitrary Lean code should not be expected to compile to every
target. The supported subset will be determined by the portable contract IR and
the selected target's capability profile.

## Proposed Repository Shape

The current repository can evolve toward this layout:

```text
ProofForge/
  Target.lean
  Target/
    Capability.lean
    Artifact.lean
    Registry.lean
  IR/
    Contract.lean
    Type.lean
    Effect.lean
    Manifest.lean
  Backend/
    Evm.lean
    Wasm/
      Near.lean
      CosmWasm.lean
    Solana/
      SbfLinker.lean
      SolanaZig.lean
    Move/
      Sui.lean
      Aptos.lean
runtime/
  zig/
    lean_rt/
    host/
      near/
      cosmwasm/
      solana/
tools/
  zigc-near
  zigc-cosmwasm
  zigc-solana-sbpf
scripts/
  evm/
  near/
  cosmwasm/
  solana/
  move/
Examples/
  Evm/
  Near/
  CosmWasm/
  Solana/
  Move/
```

This is not a required one-shot refactor. It is a direction for staged work.
The existing EVM implementation can remain where it is until `Target` and `IR`
modules exist.

## Target Profile

Every target should be described by a `TargetProfile`.

Conceptually:

```lean
inductive TargetFamily where
  | evm
  | wasm
  | solana
  | move

inductive ArtifactKind where
  | evmBytecode
  | wasm
  | solanaElf
  | movePackage

structure TargetProfile where
  id : String
  family : TargetFamily
  artifactKind : ArtifactKind
  capabilities : CapabilitySet
  buildSteps : Array BuildStep
  smokeTests : Array SmokeTest
```

Initial target ids:

| Target id | Family | Artifact | Status |
|---|---|---|---|
| `evm` | EVM | Runtime bytecode | Implemented baseline |
| `wasm-near` | Wasm host | NEAR-compatible Wasm | Researched in Lean fork |
| `wasm-cosmwasm` | Wasm host | CosmWasm Wasm | New implementation track |
| `solana-sbpf-linker` | Solana | Solana sBPF ELF `.so` | New preferred research track |
| `solana-zig-fork` | Solana | Solana sBPF ELF `.so` | Fallback/reference track |
| `move-sui` | Move | Sui Move package | Research/codegen track |
| `move-aptos` | Move | Aptos Move package | Research/codegen track |

## Capability Matrix

The compiler should use a target capability matrix before lowering. If a
contract uses a capability that the target cannot represent, the build should
fail with a precise diagnostic.

| Capability | EVM | NEAR | CosmWasm | Solana | Sui | Aptos |
|---|---|---|---|---|---|---|
| Persistent scalar state | Slot storage | Host KV | Host KV | Account data | Object fields | Account resources |
| Caller/sender | `msg.sender` | predecessor/signer | `MessageInfo.sender` | signer account | `TxContext.sender` | `signer` |
| Native value received | `msg.value` | attached deposit | funds in message info | lamport accounts | coin objects | coin resources |
| Events/logs | EVM logs | logs/events | events/attributes | logs/events | events | events |
| Cross-contract call | call/staticcall | promises | submessages | CPI | module calls/transactions | module calls |
| State account/object selection | implicit contract | implicit contract | implicit contract | explicit accounts | explicit objects | account resources |
| Dynamic map storage | mapping/keccak slot | KV prefixes | KV prefixes | account-owned data or PDAs | dynamic fields/tables | table resources |
| Contract deployment package | bytecode | Wasm | Wasm | ELF `.so` | Move package | Move package |

This matrix is intentionally semantic. Backends can implement the same
capability through very different mechanics.

## Artifact Metadata

Every build should emit `proof-forge-artifact.json` next to the target output.

Initial schema:

```json
{
  "schemaVersion": 1,
  "package": "counter",
  "target": "wasm-cosmwasm",
  "source": {
    "entryFile": "Examples/CosmWasm/Counter.lean",
    "module": "Counter"
  },
  "proofs": {
    "checked": true,
    "warnings": []
  },
  "capabilities": [
    "storage.scalar",
    "caller.sender",
    "events"
  ],
  "artifacts": [
    {
      "kind": "wasm",
      "path": "build/cosmwasm/counter.wasm",
      "sha256": "..."
    }
  ],
  "toolchain": {
    "proofForge": "0.1.0",
    "lean": "4.3.0",
    "zig": "0.15.2",
    "external": {
      "cosmwasm-check": "..."
    }
  },
  "targetMetadata": {}
}
```

The cloud platform can later store exactly this metadata, plus deployment
addresses, transaction hashes, and test reports.

## CLI Shape

The current CLI supports EVM bytecode directly:

```sh
lake env proof-forge --evm-bytecode -o build/evm/Counter.bin \
  Examples/Evm/Contracts/Counter.lean
```

The target-oriented CLI should eventually expose:

```sh
proof-forge build --target evm --out build/evm Examples/Evm/Contracts/Counter.lean
proof-forge build --target wasm-near --out build/near Examples/Near/Counter.lean
proof-forge build --target wasm-cosmwasm --out build/cosmwasm Examples/CosmWasm/Counter.lean
proof-forge build --target solana-sbpf-linker --out build/solana Examples/Solana/Counter.lean
proof-forge build --target move-sui --out build/sui Examples/Move/Counter.lean
proof-forge test --target evm
proof-forge test --target solana-sbpf-linker
```

Near-term implementation can keep target scripts under `scripts/<target>/`
while the CLI is being generalized.

## EVM Target

Current pipeline:

```text
Lean contract
  -> Lean frontend / LCNF
  -> EmitYul
  -> Yul
  -> solc --strict-assembly
  -> runtime bytecode
  -> Foundry smoke
```

Implementation notes:

- Keep `ProofForge.Evm` as the first concrete capability SDK.
- Keep `.evm-methods` as target metadata until a unified manifest exists.
- Add artifact metadata around the existing bytecode path.
- Add golden Yul snapshots for simple examples before major IR refactors.

## NEAR Target

The Lean fork already demonstrates the desired Wasm-host pattern:

```text
Lean contract
  -> EmitZig
  -> generated Zig contract module
  -> NEAR Zig runtime + host bridge
  -> wasm32-wasi or wasm32-freestanding Wasm
  -> strip/stub incompatible WASI imports if needed
  -> NEAR-compatible Wasm
```

Key pieces observed in the fork:

- `Lean.Near`: Lean SDK with `@[extern "lean_near_*"]` functions.
- `host/near/lean_near.zig`: bridge from Lean objects to NEAR host imports.
- `tools/zigc-near`: wrapper that generates method exports and links runtime.
- `near-strip-wasi-imports.cjs`: removes WASI imports and checks MVP Wasm
  compatibility.

Implementation improvements needed for ProofForge:

- Move `lean_near_*` extern declarations out of core EmitZig runtime externs.
- Make host bridge selection target-driven instead of "all Wasm means NEAR".
- Move method export metadata into a generic target manifest.
- Keep NEAR as the first reference for Wasm-host runtime shape.

## CosmWasm Target

CosmWasm should share the Wasm-host family with NEAR, but it needs a separate
adapter. Wasm is the artifact format; the contract ABI is different.

Expected pipeline:

```text
Lean contract
  -> EmitZig
  -> generated Zig contract module
  -> CosmWasm Zig runtime + host bridge
  -> wasm32-freestanding or wasm32-unknown-style Wasm
  -> cosmwasm-check
  -> cw-multi-test or wasmd smoke
```

Required exports:

- `interface_version_8`
- `allocate`
- `deallocate`
- `instantiate`
- `execute`
- `query`
- optional later: `migrate`, `reply`, `sudo`, `ibc_*`

The entrypoint adapter should use the CosmWasm region-pointer ABI. The first
implementation should keep messages JSON-backed to avoid adding a full schema
compiler before the backend exists.

Lean SDK sketch:

```lean
namespace CosmWasm

structure Env where
  blockHeight : UInt64
  blockTimeNanos : UInt64
  contractAddress : String

structure MessageInfo where
  sender : String
  fundsJson : String

opaque storageRead : String -> IO (Option String)
opaque storageWrite : String -> String -> IO Unit
opaque storageRemove : String -> IO Unit
opaque valueReturn : String -> IO Unit
opaque logAttribute : String -> String -> IO Unit
opaque queryChain : String -> IO String

end CosmWasm
```

Zig bridge sketch:

```zig
export fn instantiate(env: u32, info: u32, msg: u32) callconv(.c) u32 {
    return runLeanEntrypoint(.instantiate, env, info, msg);
}

export fn execute(env: u32, info: u32, msg: u32) callconv(.c) u32 {
    return runLeanEntrypoint(.execute, env, info, msg);
}

export fn query(env: u32, msg: u32) callconv(.c) u32 {
    return runLeanQuery(env, msg);
}
```

First smoke test:

- Counter contract with `instantiate`, `execute({"increment":{}})`, and
  `query({"get_count":{}})`.
- Build Wasm.
- Run `cosmwasm-check`.
- Run a local Rust or CLI-based smoke that calls instantiate/execute/query.

## Solana Target

Solana should have two implementation profiles.

### Preferred track: `solana-sbpf-linker`

The `zignocchio` project shows a useful no-fork flow:

```text
Zig source
  -> zig build-lib -target bpfel-freestanding -femit-llvm-bc=entrypoint.bc
  -> sbpf-linker --cpu v2 --export entrypoint -o program.so entrypoint.bc
  -> solana-test-validator or Mollusk smoke
```

This matches the "intermediate artifact plus target packager" pattern used by
EVM/Solang-style flows.

ProofForge pipeline:

```text
Lean contract
  -> EmitZig
  -> generated Zig contract module
  -> generated solana_contract_root.zig
  -> zig build-lib -target bpfel-freestanding -femit-llvm-bc
  -> sbpf-linker
  -> Solana ELF `.so`
  -> smoke test
```

Required Solana adapter pieces:

- `Lean.Solana`: account, instruction data, signer, PDA, CPI, log, return data.
- `lean_solana_*` bridge functions in Zig.
- `solana_contract_root.zig`: exports the single `entrypoint(input) -> u64`.
- Instruction dispatch metadata, replacing NEAR-style method exports.
- Explicit account schemas for each entrypoint.

Solana method manifest sketch:

```toml
[[instruction]]
name = "increment"
tag = 1
handler = "l_Counter_increment"
accounts = [
  { name = "payer", signer = true, writable = true },
  { name = "counter", signer = false, writable = true, owner = "program" }
]
```

Root adapter sketch:

```zig
export fn entrypoint(input: [*]u8) callconv(.c) u64 {
    var ctx = solana.deserialize(input);
    lean_rt.lean_initialize_runtime_module();
    return dispatchLeanInstruction(&ctx);
}
```

Testing strategy:

- Fast deterministic program tests: Mollusk where possible.
- Deployment-style smoke: `solana-test-validator --bpf-program`.
- First contract: no CPI, one PDA/account state.
- Second contract: CPI to System Program.
- Third contract: SPL Token CPI.

### Fallback/reference track: `solana-zig-fork`

The `solana-sdk-mono` project shows another route:

```text
Zig source
  -> solana-zig target .sbf/.solana
  -> dynamic library `.so`
  -> Mollusk tests
```

This route is useful because the SDK already models accounts, CPI, typed
accounts, events, and program tests in a mature way. It should remain a
reference even if ProofForge chooses `sbpf-linker` first.

## Move Targets

Move targets should not try to compile the full Lean runtime. The first
implementation should generate Move source packages from a restricted portable
IR.

Shared Move restrictions:

- First-order functions only.
- No closures or higher-order runtime values.
- No arbitrary Lean heap objects at runtime.
- Data types must map to Move structs/enums or generated variants.
- Effects must be target capabilities, not arbitrary IO.
- Proofs stay in Lean and are checked before Move code generation.

### Sui

Sui uses an object-centric Move model. Persistent state should map to objects
with `UID`.

Pipeline:

```text
Lean portable contract
  -> Portable IR
  -> Sui Move package
  -> sui move build
  -> sui move test
  -> optional localnet/testnet publish
```

Sui mapping:

| Portable concept | Sui mapping |
|---|---|
| Contract state | Object struct with `id: UID` |
| Caller | `TxContext.sender(ctx)` |
| Entry method | `public entry fun` |
| Native value | `Coin<T>` objects |
| Events | `sui::event::emit` |
| Dynamic map | `table`, dynamic fields, or explicit child objects |

First Sui POC:

- Counter object with `init`, `increment`, `get`.
- Generate `Move.toml` and `sources/counter.move`.
- Add Move unit tests.

### Aptos

Aptos uses a module/resource model closer to account-scoped storage.

Pipeline:

```text
Lean portable contract
  -> Portable IR
  -> Aptos Move package
  -> aptos move compile
  -> aptos move test
  -> optional localnet/testnet publish
```

Aptos mapping:

| Portable concept | Aptos mapping |
|---|---|
| Contract state | `struct State has key` under an account |
| Caller | `&signer` |
| Entry method | `public entry fun` |
| Native value | `aptos_coin` / fungible asset APIs |
| Events | event module APIs |
| Dynamic map | table resources |

First Aptos POC:

- Account-owned counter resource.
- `initialize(account: &signer)`
- `increment(account: &signer)`
- `get(addr: address): u64`

## Implementation Phases

### Phase 1: Target registry and metadata

- Add target ids and capability sets.
- Add artifact metadata schema.
- Add docs and CLI shape.
- Keep current EVM command working.

### Phase 2: EVM metadata hardening

- Emit `proof-forge-artifact.json` for EVM builds.
- Add target id to generated metadata.
- Add golden output tests for core EVM examples.

### Phase 3: Wasm-host extraction

- Port NEAR runtime lessons into ProofForge docs and structure.
- Design target-selectable runtime bridge modules.
- Add `wasm-cosmwasm` spike with `allocate/deallocate` and one entrypoint.

### Phase 4: Solana sBPF smoke

- Add `zigc-solana-sbpf` spike using `bpfel-freestanding` and `sbpf-linker`.
- Generate a minimal `entrypoint`.
- Verify whether the Lean Zig runtime can link under sBPF constraints.
- If it fails, define a restricted Solana runtime subset before expanding SDK.

### Phase 5: Move sourcegen POC

- Define a restricted Move-compatible IR subset.
- Generate Sui counter package.
- Generate Aptos counter package.
- Compare which Move target should be promoted first.

## Open Engineering Risks

- Lean runtime on sBPF may be too large or use unsupported sections.
- Full Lean heap/object model may be too expensive for Solana compute budgets.
- CosmWasm may require a tighter no-WASI runtime than NEAR's first path.
- Move codegen requires a real ownership/resource model, not string templates.
- A portable IR that is too close to EVM will fail on Solana and Move.
- A portable IR that is too generic will become unusable for real contracts.

## Immediate Next Decisions

- Choose whether target registry work should land before the CosmWasm spike.
- Choose `solana-sbpf-linker` as the primary Solana path or keep both paths
  active until the first Lean runtime smoke.
- Decide whether Move POC starts with Sui or Aptos. Aptos is likely simpler for
  storage; Sui is strategically important because its object model is more
  different and tests the abstraction harder.

## Research References

- EVM baseline in this repository: `ProofForge.Compiler.LCNF.EmitYul`,
  `ProofForge.Evm`, `scripts/evm/foundry-smoke.sh`.
- NEAR reference in local Lean fork:
  `/Users/davirian/dev/active/lean4-zig-compiler/src/Lean/Near.lean`,
  `tools/zigc-near`, and `src/runtime/zig/host/near`.
- Solana fork-target reference:
  `https://github.com/DaviRain-Su/solana-sdk-mono.git`.
- Solana stock-Zig reference:
  `https://github.com/vitorpy/zignocchio`.
- sbpf-linker:
  `https://github.com/blueshift-gg/sbpf-linker`.
- CosmWasm docs:
  `https://cosmwasm.cosmos.network/`.
- Sui Move docs:
  `https://docs.sui.io/concepts/sui-move-concepts`.
- Aptos Move docs:
  `https://aptos.dev/network/blockchain/move`.
