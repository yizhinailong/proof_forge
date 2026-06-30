# Psy DPN ZK Target

Status: **Experimental**

Canonical target id: `psy-dpn`

Reference repository: `https://github.com/PsyProtocol/psy-compiler`

Research snapshot: `mainnet-beta`, commit `24f5ec9`.

Experimental scope: ProofForge can generate reviewable `.psy` source for a
restricted portable IR subset and validate that source with Dargo for Counter,
ContextProbe, HashProbe, MapProbe, AssertProbe, and LoopProbe fixtures. The
target is not production-ready and does not yet cover arrays, structs, deploy
JSON, live Psy node/prover deployment, or broad Lean-to-IR extraction.

## Summary

Psy is a ZK-oriented contract target, not an EVM/Wasm/Solana/Move variant. The
public compiler repository defines the `.psy` language, parser, semantic
checker, interpreter/lowering flow, ABI generation, Dargo CLI, browser/Node
Wasm bindings, and precompiled contract examples.

The important distinction for ProofForge is that Psy compiles contract methods
to DPN circuit function definitions. The target artifact is closer to a ZK VM
circuit artifact than to EVM bytecode or a Wasm module.

Initial ProofForge integration should therefore treat Psy as a **ZK circuit
source-generation target**:

```text
Lean portable contract
  -> Lean checks and proofs
  -> Psy-compatible portable IR subset
  -> generated .psy package
  -> dargo compile
  -> DPNFunctionCircuitDefinition JSON + ABI
  -> Psy deploy/test tooling
```

Do not start by directly emitting Psy DPN internals. The public repo does not
expose a stable Yul-like textual intermediate language.

## Why This Is A New Target Family

Existing target families in ProofForge are:

- direct compiler target: EVM through Yul and `solc`
- Wasm host targets: NEAR and CosmWasm
- binary toolchain targets: Solana sBPF
- source codegen targets: Move packages

Psy is different:

- contract execution is circuit/proof oriented
- the compiler output is a set of circuit function definitions
- the deployable object is Psy-specific contract code/deploy JSON
- storage and call semantics are not EVM slot storage
- the usable public integration boundary is `.psy` source plus Dargo tooling

This should become a fifth family:

```text
ZK circuit sourcegen: Portable IR -> target source -> circuit artifact
```

## Toolchain Shape

Observed public tooling:

| Component | Role |
|---|---|
| `.psy` language | Target source language for contracts and tests |
| `dargo compile` | Compiles a Psy package to `Vec<DPNFunctionCircuitDefinition>` JSON |
| `dargo execute` | Runs compiled circuits in a local user/contract execution session |
| `dargo test` | Runs compiler/interpreter tests for Psy source |
| `dargo generate-abi` | Generates ABI JSON from parsed/typechecked contracts |
| `psy-wasm` | Browser/Node wrapper around the compiler and in-memory VM demo |
| `gen_deploy_json` example | Converts compiled function JSON into Psy genesis deploy JSON |

The first ProofForge adapter should shell out to `dargo` rather than embedding
Psy Rust crates. Embedding is possible later, but the compiler workspace depends
on `psy-node` crates through SSH git dependencies, so a CLI boundary is more
practical for early spikes and CI.

## Upstream Syntax And CI Corpus

The best grammar and idiom corpus is the upstream `psy-compiler` repository:

| Source | What to learn |
|---|---|
| `psy-precompiles/*/src/main.psy` | Production-style contract storage, events, fixed arrays, maps, hashing, cross-contract refs, and ABI method sets |
| `psy-precompiles/*/Dargo.toml` | Package layout and local dependency structure |
| `tests/*.psy` | Small syntax and semantic probes for storage refs, context functions, maps, traits, arrays, loops, hashes, and assertions |
| `Makefile` `ci` target | Official local test matrix for `dargo test`, `dargo compile`, and `dargo execute` |
| `Makefile` precompile targets | Method lists for compiling and ABI-generating shipped contracts |

Important Makefile signals:

```make
export DARGO_STD_PATH := $(PWD)/psy-std/std.psy

build:
	@RUSTFLAGS="-A warnings" cargo build --profile ${PROFILE} -p psy-precompiles
	@RUSTFLAGS="-A warnings" cargo build --profile ${PROFILE} --bin dargo --bin psy-lsp-server

DARGO_CLI_COMPILE = RUST_LOG=$(LOG_LEVEL) ./target/${PROFILE}/dargo compile --program-dir tests --debug --entry-path
DARGO_CLI_EXECUTE = RUST_LOG=${LOG_LEVEL} ./target/${PROFILE}/dargo execute --program-dir tests --debug --entry-path
DARGO_CLI_TEST    = RUST_LOG=${LOG_LEVEL} ./target/${PROFILE}/dargo test --file
```

For ProofForge this gives two source-aligned validation styles:

1. Package smoke, matching precompiled contracts:

```sh
cd build/psy/dargo-counter
dargo compile --contract-name Counter --method-names initialize increment get
dargo execute --contract-name Counter --method-names initialize increment increment get
dargo generate-abi --contract-name Counter --output-dir target --pretty
```

2. Syntax corpus smoke, matching upstream `tests`:

```sh
dargo test --file path/to/test.psy
dargo --program-dir tests execute --debug --entry-path ctx_test.psy --parameters 2,3
```

The current ProofForge smoke uses the package style because it mirrors the
eventual generated artifact layout. A future syntax-regression gate should copy
or vendor a curated subset of upstream tests and run them with the second style
against the exact `dargo` version used in CI.

## SDK Surface

The first Lean SDK module is `ProofForge.Psy` with namespace `Lean.Psy`.

It provides:

- primitive aliases for `Felt`, `U32`, and `Hash`
- context helpers such as user id, contract id, checkpoint id, and checkpoint
  roots
- raw state hash accessors
- fixed slot and fixed-capacity map wrappers
- hash intrinsics
- deferred invocation intrinsics

The SDK is intentionally a source-generation boundary. Its `lean_psy_*` externs
do not have a native runtime implementation; the future `psy-dpn` backend should
recognize these names and lower them to `.psy` source constructs or reject them
with capability diagnostics.

## Yul-Like IR Assessment

Psy currently has several intermediate layers, but none are equivalent to Yul
for ProofForge's purposes.

| Layer | Public? | Stable integration boundary? | Notes |
|---|---:|---:|---|
| `.psy` source | Yes | Yes | Best first target for source generation |
| `psy-ast` / checked AST | Yes | Maybe | Useful for understanding syntax and ABI, but tied to Psy compiler internals |
| `QExecContext` / DPN ops | Partly | No | Symbolic execution/circuit lowering layer; core types come from `psy-node` |
| `DPNFunctionCircuitDefinition` JSON | Yes | Artifact, not IR | Good output artifact, too target-specific and opaque for ProofForge IR |
| ABI / contract code JSON | Yes | Output metadata | Useful for deployment and cloud metadata |

Conclusion: **there is no Yul-equivalent public IR to target today**.
ProofForge should use its own portable contract IR as the stable middle layer,
then generate `.psy` source.

## Proposed Target Profile

```text
id: psy-dpn
family: zkCircuitSourcegen
artifactKind: psyCircuitJson
stage: Experimental
primaryInput: ProofForge portable IR subset
primaryOutput: target/contract.json containing DPNFunctionCircuitDefinition[]
sideOutputs:
  - generated .psy source package
  - generated Dargo.toml
  - ABI JSON
  - proof-forge-artifact.json
  - optional Psy deploy JSON
```

Required external tools:

- Rust toolchain compatible with the Psy compiler workspace
- `dargo`, preferably installed from `psyup`
- optional `wasm-pack` only if using `psy-wasm`
- optional Psy node/prover tooling for deployment-level tests

`cargo install --git https://github.com/PsyProtocol/psy-compiler dargo` is the
upstream Dargo install path, but it may pull `psy-node` and its submodules
during Cargo dependency resolution. On this machine it failed on the
`psy-contracts` submodule URL inside `psy-node`.

`psyup` is the more practical local toolchain path. It installs a released
toolchain tarball, symlinks `dargo`, and writes `DARGO_STD_PATH` to the bundled
`psy-std`.

```sh
curl -fsSL https://raw.githubusercontent.com/QEDProtocol/psyup/main/install.sh | bash
```

Observed release caveat: `psyup` v0.1.1 currently publishes Linux x86_64 only.
For macOS arm64, v0.1.0 includes
`psy-toolchain-v0.1.0-aarch64-apple-darwin.tar.gz` and has been validated with
the Counter smoke:

```sh
psyup install 0.1.0
scripts/psy/counter-smoke.sh
```

## Portable IR Subset

The first `psy-dpn` subset should be stricter than the EVM subset.

Allowed first:

- `Felt`, `Bool`, `U32`
- fixed-size arrays
- concrete structs
- first-order functions
- entrypoint parameters over supported scalar/fixed-size types
- bounded `if` / `while` patterns that the Psy compiler accepts
- assertions
- hash operations represented through `crypto.hash`
- context reads such as user id, contract id, and checkpoint id
- persistent scalar state
- fixed-capacity maps where represented in Psy storage
- explicit contract methods

Rejected first:

- arbitrary Lean runtime objects
- closures and higher-order runtime values
- unbounded recursion
- dynamic heap-heavy data structures
- target-native operations not represented as capabilities
- direct emission of DPN internals
- automatic translation of arbitrary EVM storage layouts

The target should fail before source generation when an unsupported IR node or
capability appears.

The design philosophy docs reinforce the same boundary: Psy is ZK-native and
uses symbolic execution. Variables become circuit wires, operations become
gates, control flow is flattened, bounded loops are unrolled, and function calls
are inlined by default. The first Psy lowering should therefore prefer static
Felt/Bool/U32 values, fixed-size arrays, bounded loops, explicit storage
effects, and small helper functions over dynamic runtime-like constructs.

## Capability Mapping

Initial mapping:

| Portable capability | Psy direction |
|---|---|
| `storage.scalar` | generated `#[derive(Storage)]` field or explicit state access |
| `storage.map` | fixed-capacity map/storage pattern where supported by Psy |
| `caller.sender` | Psy user/context functions such as user id |
| `events.emit` | target-specific event/log story to research |
| `crosscall.invoke` | `invoke_sync` / `invoke_deferred` where valid |
| `env.block` | checkpoint/block-like context reads where valid |
| `control.bounded_loop` | static Psy `for i in 0u32..Nu32` loops |
| `crypto.hash` | Psy hash intrinsics/prelude |
| `assertions.check` | Psy `assert(...)` and `assert_eq(...)` statements in generated methods |
| `zk.circuit` | every contract method lowers to a circuit definition |
| `zk.proof` | proof/deploy/test integration track; not a generic runtime effect |

The ZK capabilities are target-family capabilities. They should not leak into
portable business logic unless the user explicitly writes a proof-oriented
contract.

## Generated Package Sketch

Current Counter spike output layout:

```text
build/psy/
  Counter.psy
  dargo-counter/
    Dargo.toml
    src/main.psy
    target/proof_forge_counter.json
    target/Counter.json
    target/counter-execute.log
    target/proof-forge-artifact.json
```

Example generated shape:

```text
#[contract]
#[derive(Storage)]
pub struct Counter {
    pub count: Felt,
}

impl CounterRef {
    #[contract_method]
    pub fn initialize() {
        let c = CounterRef::new(ContractMetadata::current());
        c.count = 0;
    }

    #[contract_method]
    pub fn increment() {
        let c = CounterRef::new(ContractMetadata::current());
        let n: Felt = c.count.get();
        c.count = n + 1;
    }

    #[contract_method]
    pub fn get() -> Felt {
        let c = CounterRef::new(ContractMetadata::current());
        return c.count.get();
    }
}
```

This is intentionally source-like and reviewable. The current implementation is
`ProofForge.Backend.Psy.IR.renderModule`, exposed through:

```sh
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
```

The checked-in golden source is `Examples/Psy/Counter.golden.psy`.

Current ContextProbe spike output layout:

```text
build/psy/
  ContextProbe.psy
  dargo-context/
    Dargo.toml
    src/main.psy
    target/proof_forge_context.json
    target/ContextProbe.json
    target/context-execute.log
    target/proof-forge-artifact.json
```

`ContextProbe` is the first non-Counter fixture. It follows upstream
`tests/ctx_test.psy` by lowering entrypoint parameters plus
`get_user_id()`, `get_contract_id()`, and `get_checkpoint_id()` into Psy
source. The contract includes a `_proof_forge_marker` storage field because
Dargo v0.1.0 panics on an empty `#[contract] #[derive(Storage)]` struct.

Current HashProbe output layout:

```text
build/psy/
  HashProbe.psy
  dargo-hash/
    Dargo.toml
    src/main.psy
    target/proof_forge_hash.json
    target/HashProbe.json
    target/hash-execute.log
    target/proof-forge-artifact.json
```

`HashProbe` follows upstream `tests/hash_test.psy` and
`tests/hash_two_to_one_test.psy`. The portable IR now has a `Hash` value type,
four-Felt hash literals, typed `let` bindings, `hash`, and `hash_two_to_one`
expressions. Psy sourcegen lowers those nodes to `Hash`, `[a, b, c, d]`,
`hash(data)`, and `hash_two_to_one(left, right)`.

Current MapProbe output layout:

```text
build/psy/
  MapProbe.psy
  dargo-map/
    Dargo.toml
    src/main.psy
    target/proof_forge_map.json
    target/MapProbe.json
    target/map-execute.log
    target/proof-forge-artifact.json
```

`MapProbe` follows upstream `tests/map_test.psy`,
`tests/map_chain_insert_set_get_test.psy`, and
`tests/map_adjacent_fields_preserve_test.psy`. The portable IR now has
fixed-capacity map state and map effects for `contains`, `get`, `insert`, and
`set`. Psy sourcegen lowers the supported storage shape to
`Map<Hash, Hash, Nu32>` and emits `c.map.contains(key)`, `c.map.get(key)`,
`c.map.insert(key, value)`, and `c.map.set(key, value)`. The current Psy v0
lowerer deliberately accepts only `Map<Hash, Hash, N>` and rejects other map
key/value shapes with an explicit diagnostic.

Current AssertProbe output layout:

```text
build/psy/
  AssertProbe.psy
  dargo-assert/
    Dargo.toml
    src/main.psy
    target/proof_forge_assert.json
    target/AssertProbe.json
    target/assert-execute.log
    target/proof-forge-artifact.json
```

`AssertProbe` follows upstream precompile and test idioms that use
`assert(condition, "message")` and `assert_eq(left, right, "message")`. The
portable IR now has statement-level assertion nodes, and Psy sourcegen lowers
them into contract method bodies rather than only generated tests.

Current LoopProbe output layout:

```text
build/psy/
  LoopProbe.psy
  dargo-loop/
    Dargo.toml
    src/main.psy
    target/proof_forge_loop.json
    target/LoopProbe.json
    target/loop-execute.log
    target/proof-forge-artifact.json
```

`LoopProbe` follows upstream Psy loop idioms such as
`for _i in 0u32..3u32`. The portable IR now has a static `boundedFor`
statement node, and Psy sourcegen lowers it to a bounded `for` block while EVM
IR v0 rejects it explicitly.

## Smoke Test Strategy

Experimental smoke does not require a live Psy network.

Preferred first smoke:

1. Generate `.psy` source.
2. Compare it against `Examples/Psy/Counter.golden.psy`.
3. Run `dargo test --file build/psy/Counter.psy`.
4. Generate a temporary Dargo package.
5. Run `dargo compile --contract-name Counter --method-names initialize increment get`.
6. Verify `target/proof_forge_counter.json` is non-empty.
7. Run `dargo execute --contract-name Counter --method-names initialize increment increment get`.
8. Verify the execution log contains `result_vm: [2]`.
9. Run `dargo generate-abi --contract-name Counter --output-dir target --pretty`.
10. Verify `target/Counter.json` is non-empty.
11. Emit `target/proof-forge-artifact.json` with source, circuit JSON, ABI, and
    execute-log hashes.

This has been run locally with `psyup install 0.1.0` on macOS arm64. The smoke
produced `build/psy/dargo-counter/target/proof_forge_counter.json` and
`build/psy/dargo-counter/target/counter-execute.log`, plus ABI output at
`build/psy/dargo-counter/target/Counter.json` and metadata at
`build/psy/dargo-counter/target/proof-forge-artifact.json`.

The same validation shape is implemented for `ContextProbe`:

```sh
scripts/psy/context-smoke.sh
```

It verifies `result_vm: [15]` for `sum_context(2,3)` under Dargo's local
execution session and emits `build/psy/dargo-context/target/proof-forge-artifact.json`.

The same validation shape is also implemented for `HashProbe`:

```sh
scripts/psy/hash-smoke.sh
```

It verifies both upstream hash idioms under Dargo local execution:

- `poseidon_hash`: `result_vm: [16490263548047147048, 1812405431586978162, 16859324901997577793, 7123796541406703579]`
- `poseidon_pair_hash`: `result_vm: [15064728126975588673, 10314245681893968020, 11300930272442645327, 2830815762300183090]`

The script emits and validates
`build/psy/dargo-hash/target/proof-forge-artifact.json`.

The same validation shape is also implemented for `MapProbe`:

```sh
scripts/psy/map-smoke.sh
```

It verifies fixed-capacity Psy map storage under Dargo local execution:

- `map_lifecycle`: `result_vm: [55, 66, 77, 88]`

The script emits and validates
`build/psy/dargo-map/target/proof-forge-artifact.json`.

The same validation shape is also implemented for `AssertProbe`:

```sh
scripts/psy/assert-smoke.sh
```

It verifies IR-level assertions under Dargo local execution:

- `checked_sum(5,7)`: `result_vm: [12]`

The script emits and validates
`build/psy/dargo-assert/target/proof-forge-artifact.json`.

The same validation shape is also implemented for `LoopProbe`:

```sh
scripts/psy/loop-smoke.sh
```

It verifies static bounded-loop lowering under Dargo local execution:

- `count_to_three`: `result_vm: [3]`

The script emits and validates
`build/psy/dargo-loop/target/proof-forge-artifact.json`.

All Psy smoke scripts run
`scripts/psy/validate-artifact-metadata.py` after metadata generation. The
validator checks schema version, target id, target family, artifact kind,
fixture id, non-empty capabilities, artifact paths, byte sizes, SHA-256 hashes,
validation flags, and expected execution results inside the execute log.

Observed behavior: `dargo execute` compiles the workspace, creates a local
session with a registered user and deployed contract, then executes the method
sequence against the same session. This is not a live network, but it is closer
to an Ethereum-style local execution smoke than a pure compiler check.

Second smoke:

1. Compare high-level Counter behavior with the EVM shared scenario.
2. Add bounded-loop, array, and struct coverage from `psy-compiler/tests` and
   `psy-precompiles`.

Deployment smoke:

1. Convert `DPNFunctionCircuitDefinition[]` to deploy JSON with Psy tooling.
2. Run against a local Psy node/prover stack when the toolchain is available.

## Implementation Plan

### Phase A: Documentation and Target Registry

- Add `psy-dpn` to target registry docs.
- Add artifact kind `psyCircuitJson`.
- Add ZK circuit sourcegen target family.
- Record `dargo` as the required external tool.

### Phase B: Source Generator Spike

- Done: generate one Counter `.psy` file from a hand-built portable IR fixture.
- Done: add a golden Psy source fixture.
- Done: add `scripts/psy/counter-smoke.sh` to generate `Dargo.toml`, call
  `dargo test --file`, call `dargo compile`, verify the JSON artifact, call
  `dargo execute`, assert the local execution result, and call
  `dargo generate-abi`.
- Done: add `ContextProbe` as the first non-Counter Psy fixture with parameter
  lowering and context reads.
- Done: add `scripts/psy/context-smoke.sh` with the same Dargo validation shape.
- Done: add `HashProbe` with `Hash`, typed `let` bindings, `hash`, and
  `hash_two_to_one` lowering aligned with upstream Psy tests.
- Done: add `scripts/psy/hash-smoke.sh` with the same Dargo validation shape.
- Done: emit `proof-forge-artifact.json` metadata from all Psy smoke scripts.
- Done: validate Psy artifact metadata and record used capabilities from the
  smoke scripts.
- Done: add `MapProbe` with fixed-capacity `Map<Hash, Hash, N>` storage and
  `contains`, `get`, `insert`, and `set` lowering aligned with upstream Psy
  map tests.
- Done: add `scripts/psy/map-smoke.sh` with the same Dargo validation shape.
- Done: add `AssertProbe` with IR-level `assert` and `assert_eq` statements
  aligned with upstream Psy assertion idioms.
- Done: add `scripts/psy/assert-smoke.sh` with the same Dargo validation shape.
- Done: add `LoopProbe` with static `boundedFor` lowering aligned with upstream
  Psy fixed `for` loop idioms.
- Done: add `scripts/psy/loop-smoke.sh` with the same Dargo validation shape.
- Done: validate the Dargo portion with the `psyup` v0.1.0 macOS arm64
  toolchain.
- Remaining: add array and struct coverage from the upstream syntax corpus.

### Phase C: Metadata and Scenario Parity

- Compare the Psy Counter behavior with the EVM shared Counter scenario.
- Decide whether `psy-wasm` adds useful in-memory coverage beyond
  `dargo execute`.
- Add a target-specific Counter acceptance note.

### Phase D: Deployment Research

- Use Psy deploy JSON conversion.
- Document local node/prover setup.
- Decide whether ProofForge should own deployment or only artifact production.

## Open Questions

- Should CI use the `psyup` release tarball, and should we pin v0.1.0 until the
  latest release publishes macOS artifacts?
- Which Psy storage patterns correspond to portable `storage.map` without
  semantic surprises?
- What is the exact artifact schema for contract code versus circuit
  definitions versus deploy JSON?
- Should `Felt` become a first-class portable type, or remain target-specific?
- Can ProofForge expose privacy/ZK capabilities without making ordinary
  multi-chain contracts harder to write?
- What is the smallest useful local Psy node/prover deployment smoke beyond
  Dargo's in-memory execution session?

## First Acceptance Criteria

- `psy-dpn` is listed as Experimental in target notes.
- The target profile draft includes artifact kind, required tools, and smoke
  steps.
- Generated Counter, ContextProbe, and HashProbe `.psy` packages compile with
  `dargo compile` on a machine with the Psy toolchain.
- Generated MapProbe `.psy` package compiles with `dargo compile` on a machine
  with the Psy toolchain.
- Generated AssertProbe `.psy` package compiles with `dargo compile` on a
  machine with the Psy toolchain.
- Generated LoopProbe `.psy` package compiles with `dargo compile` on a machine
  with the Psy toolchain.
- Dargo execution proves the expected Counter lifecycle, context-read result,
  deterministic hash outputs, map lifecycle output, and assertion-protected
  checked sum output, plus the bounded loop count result.
- Artifact metadata records:
  - target id `psy-dpn`
  - target family and artifact kind
  - generated `.psy` source
  - DPN circuit JSON artifact
  - ABI artifact if generated
  - Psy compiler/Dargo version or commit
  - used capabilities
- Artifact metadata is machine-validated against the generated artifact files
  and expected Dargo execution result.
