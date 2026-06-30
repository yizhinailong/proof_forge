# Psy DPN ZK Target

Status: **Research**

Canonical target id: `psy-dpn`

Reference repository: `https://github.com/PsyProtocol/psy-compiler`

Research snapshot: `mainnet-beta`, commit `24f5ec9`.

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
stage: Research
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
- bounded `if` / `while` patterns that the Psy compiler accepts
- assertions
- hash operations represented through `crypto.hash`
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
| `crypto.hash` | Psy hash intrinsics/prelude |
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

## Smoke Test Strategy

Research-stage smoke should not require a live Psy network.

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

This has been run locally with `psyup install 0.1.0` on macOS arm64. The smoke
produced `build/psy/dargo-counter/target/proof_forge_counter.json` and
`build/psy/dargo-counter/target/counter-execute.log`, plus ABI output at
`build/psy/dargo-counter/target/Counter.json`.

Observed behavior: `dargo execute` compiles the workspace, creates a local
session with a registered user and deployed contract, then executes the method
sequence against the same session. This is not a live network, but it is closer
to an Ethereum-style local execution smoke than a pure compiler check.

Second smoke:

1. Record tool versions and artifact hashes in `proof-forge-artifact.json`.
2. Compare high-level Counter behavior with the EVM shared scenario.

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
- Done: validate the Dargo portion with the `psyup` v0.1.0 macOS arm64
  toolchain.
- Remaining: emit `proof-forge-artifact.json`.

### Phase C: Metadata and Scenario Parity

- Emit `proof-forge-artifact.json` with Dargo version, source hash, circuit JSON
  hash, ABI hash, and execution log hash.
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
- Should local deployment require a full Psy node, or is in-memory execution
  sufficient for Experimental stage?

## First Acceptance Criteria

- `psy-dpn` is listed as Research in target notes.
- The target profile draft includes artifact kind, required tools, and smoke
  steps.
- A generated Counter `.psy` package compiles with `dargo compile` on a machine
  with the Psy toolchain.
- Artifact metadata records:
  - target id `psy-dpn`
  - generated `.psy` source
  - DPN circuit JSON artifact
  - ABI artifact if generated
  - Psy compiler/Dargo version or commit
  - used capabilities
