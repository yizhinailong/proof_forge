# Development Log

This log records engineering milestones for ProofForge. It is not a replacement
for Git history. Use it to understand what changed, what was validated, and what
the next engineering step is.

## Format

Each entry should include:

- date
- commit or work range
- summary
- validation run
- known limitations
- next step

## 2026-07-01

### Psy HashProbe And Experimental Target Slice

Commit: pending

Summary:

- Extended portable IR with `Hash`, four-Felt hash literals, typed `let`
  bindings, `hash`, and `hash_two_to_one` expressions.
- Extended Psy sourcegen to lower hash values through upstream Psy idioms:
  `Hash`, `[a, b, c, d]`, `hash(data)`, and `hash_two_to_one(left, right)`.
- Added `ProofForge.IR.Examples.HashProbe` with two contract methods:
  `poseidon_hash` and `poseidon_pair_hash`.
- Added CLI support:

```sh
lake env proof-forge --emit-hash-ir-psy -o build/psy/HashProbe.psy
```

- Added `Examples/Psy/HashProbe.golden.psy`.
- Added `scripts/psy/hash-smoke.sh`, which generates a temporary Dargo package,
  runs `dargo test --file`, `dargo compile`, two `dargo execute` calls,
  `dargo generate-abi`, and writes `proof-forge-artifact.json`.
- Added CI coverage for Psy golden source generation without requiring Dargo on
  GitHub Actions.

Validation run:

```sh
lake build
lake env proof-forge --emit-hash-ir-psy -o build/psy/HashProbe.psy
diff -u Examples/Psy/HashProbe.golden.psy build/psy/HashProbe.psy
PSY_HOME=/tmp/proof_forge_refs/psyup-home-test/.psy \
  DARGO=/tmp/proof_forge_refs/psyup-home-test/.psy/toolchains/psy-0.1.0/bin/dargo \
  scripts/psy/hash-smoke.sh
```

Result:

- `lake build` passed.
- Generated HashProbe source matches the checked-in golden fixture.
- `scripts/psy/hash-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- `dargo execute` returned the expected four-Felt output for `poseidon_hash`.
- `dargo execute` returned the expected four-Felt output for
  `poseidon_pair_hash`.

Known limitations:

- Hash support is deliberately narrow: fixed four-Felt `Hash` values only.
- Psy storage maps, bounded loops, and deploy JSON are still not implemented.
- EVM IR v0 explicitly rejects Hash values and hash expressions.

Next step:

- Add map/storage-map coverage from upstream `psy-compiler/tests` and
  `psy-precompiles`, then factor the repeated Dargo package generation logic.

### Psy ContextProbe Fixture And Artifact Metadata

Commit: pending

Summary:

- Extended portable IR with `context.read` effects for `userId`, `contractId`,
  and `checkpointId`.
- Extended Psy sourcegen to lower entrypoint parameters and context reads.
- Added `ProofForge.IR.Examples.ContextProbe`, the first non-Counter Psy IR
  fixture.
- Added CLI support:

```sh
lake env proof-forge --emit-context-ir-psy -o build/psy/ContextProbe.psy
```

- Added `Examples/Psy/ContextProbe.golden.psy`.
- Added `scripts/psy/context-smoke.sh`, which mirrors the Counter Dargo smoke:
  `dargo test --file`, `dargo compile`, `dargo execute`, and
  `dargo generate-abi`.
- Added `scripts/psy/write-artifact-metadata.py` and wired both Psy smoke
  scripts to emit `proof-forge-artifact.json` with hashes for source, circuit
  JSON, ABI JSON, and execute logs.

Validation run:

```sh
lake build
lake env proof-forge --emit-context-ir-psy -o build/psy/ContextProbe.psy
diff -u Examples/Psy/ContextProbe.golden.psy build/psy/ContextProbe.psy
scripts/psy/context-smoke.sh
scripts/psy/counter-smoke.sh
git diff --check
```

Result:

- `lake build` passed.
- ContextProbe emits reviewable Psy source with parameters and context reads.
- Generated ContextProbe source matches the checked-in golden fixture.
- `scripts/psy/context-smoke.sh` generated DPN JSON, ABI JSON, execute log, and
  `proof-forge-artifact.json`.
- `dargo execute` returned `result_vm: [15]` for `sum_context(2,3)`.
- `scripts/psy/counter-smoke.sh` now also emits `proof-forge-artifact.json`.

Known limitations:

- ContextProbe uses `_proof_forge_marker` storage because Dargo v0.1.0 panics on
  an empty `#[contract] #[derive(Storage)]` struct.
- The IR still lacks maps, fixed arrays, assertions, hashes, bounded loops, and
  reusable package generation.
- Dargo does not expose a `--version` flag, so metadata records the Dargo path
  and leaves the version null for now.

Next step:

- Add a curated upstream syntax regression subset from `psy-compiler/tests`,
  then expand the IR/sourcegen surface toward maps, arrays, assertions, and
  hashes.

## 2026-06-30

### Psy Counter IR Sourcegen And Smoke

Commit: pending

Summary:

- Added `ProofForge.Backend.Psy.IR`, a strict v0 source generator for the
  hand-written portable Counter IR fixture.
- Added CLI support:

```sh
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
```

- Added `Examples/Psy/Counter.golden.psy` as the reviewed source snapshot.
- Added `scripts/psy/counter-smoke.sh`, which:
  - regenerates Counter Psy source
  - compares it against the golden fixture
  - runs `dargo test --file`
  - creates a temporary Dargo package
  - runs `dargo compile --contract-name Counter --method-names initialize increment get`
  - checks the Dargo JSON artifact is non-empty
  - runs `dargo execute --contract-name Counter --method-names initialize increment increment get`
  - checks the local execution log contains `result_vm: [2]`
  - runs `dargo generate-abi --contract-name Counter --output-dir target --pretty`
  - checks the ABI JSON artifact is non-empty
- Verified `psyup install 0.1.0` as a working macOS arm64 toolchain path for
  this smoke.
- Recorded the upstream syntax/CI corpus: `psy-precompiles`, `tests`, and
  `psy-compiler`'s Makefile `build`/`ci` targets.

Validation run:

```sh
lake build
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
diff -u Examples/Psy/Counter.golden.psy build/psy/Counter.psy
psyup install 0.1.0
scripts/psy/counter-smoke.sh
```

Result:

- `lake build` passed.
- Counter IR emits reviewable Psy source.
- Generated Psy source matches the checked-in golden fixture.
- `scripts/psy/counter-smoke.sh` generated `build/psy/Counter.psy`, ran
  `dargo test --file`, ran `dargo compile`, produced
  `build/psy/dargo-counter/target/proof_forge_counter.json`, ran
  `dargo execute`, and verified `get` returned `result_vm: [2]` after two
  increments in the same local execution session.
- The same smoke generated non-empty ABI output at
  `build/psy/dargo-counter/target/Counter.json`.
- Direct `cargo install --git https://github.com/PsyProtocol/psy-compiler dargo`
  fetched `psy-compiler` but failed while Cargo updated the `psy-node`
  `psy-contracts` submodule URL.
- `psyup` v0.1.1 currently has only a Linux x86_64 release asset; macOS arm64
  was validated by pinning `psyup install 0.1.0`.

Known limitations:

- The generator supports only the current no-argument Counter IR subset:
  `u64` scalar state, scalar read/write, `add`, let-bind, and return.
- No deploy JSON, artifact metadata, or live Psy node smoke exists yet.
  `dargo execute` covers local user/contract execution, not network deployment.

Next step:

- Add `proof-forge-artifact.json` metadata to the Psy smoke, then decide
  whether CI should pin `psyup` v0.1.0 or wait for a newer macOS release asset.

### Psy/DPN SDK Skeleton

Commit: `feat: add Psy DPN SDK skeleton`

Summary:

- Added `ProofForge.Psy` as the first Lean SDK surface for the `psy-dpn` ZK
  target.
- Added primitive types and helpers:
  - `Felt`
  - `U32`
  - `Hash`
  - `ContractMetadata`
- Added context, storage, IMT map, hash, and deferred invocation externs under
  the `lean_psy_*` naming convention.
- Added a small `Examples/Psy/Counter.lean` SDK example.

Validation run:

```sh
lake build
lake env lean Examples/Psy/Counter.lean
```

Result:

- Passed.

Notes:

- The example uses `initCounter` instead of `initialize` because `initialize`
  is a Lean command keyword.

Known limitations:

- The SDK is a source-generation boundary only; no Psy backend lowers these
  externs yet.
- There is no Dargo package generation or `.psy` output yet.

Next step:

- Add a `psy-dpn` source generator for the hand-written Counter IR fixture.

### Portable IR Counter Runtime Dispatch

Commit: `824f5f8 feat: add IR counter EVM runtime smoke`

Summary:

- Added EVM selector metadata to the hand-written Counter IR fixture.
- Extended IR-to-Yul lowering to emit runtime selector dispatch for:
  - `initialize()`
  - `increment()`
  - `get()`
- Added `proof-forge --emit-counter-ir-bytecode`, which compiles Counter IR
  through runtime Yul and `solc --strict-assembly`.
- Added a dedicated Foundry smoke script for the IR Counter path:

```sh
scripts/evm/ir-counter-smoke.sh
```

Validation run:

```sh
lake build
lake env proof-forge --emit-counter-ir-yul -o build/ir/Counter.yul
lake env proof-forge --emit-counter-ir-bytecode -o build/ir/Counter.bin --yul-output build/ir/Counter.bytecode.yul
solc --strict-assembly build/ir/Counter.yul --bin
scripts/evm/ir-counter-smoke.sh
```

Result:

- `lake build` passed.
- Counter IR emits selector-dispatch Yul.
- Counter IR emits non-empty EVM bytecode.
- `solc --strict-assembly` accepts the generated runtime Yul.
- Foundry smoke passes for `initialize`/`increment`/`get` and unknown-selector
  revert behavior.

Known limitations:

- The IR fixture is still hand-written; there is no Lean-source-to-IR extractor.
- Only no-argument entrypoints are supported in the IR EVM dispatcher.

Next step:

- Promote the IR Counter path into CI once external tool gating is in place, and
  generalize the dispatcher beyond no-argument entrypoints.

### Portable IR Counter Lowering

Commit: `787d437 feat: add portable IR counter lowering`

Summary:

- Added the first target registry modules:
  - `ProofForge.Target.Capability`
  - `ProofForge.Target.Registry`
  - `ProofForge.Target.Check`
- Added the first portable contract IR:
  - `ValueType`
  - `StateDecl`
  - `Expr`
  - `Effect`
  - `Statement`
  - `Entrypoint`
  - `Module`
- Added a hand-written Counter IR fixture in `ProofForge.IR.Examples.Counter`.
- Added an EVM/Yul lowering path for the Counter-shaped IR subset.
- Added CLI smoke command:

```sh
lake env proof-forge --emit-counter-ir-yul -o build/ir/Counter.yul
```

Validation run:

```sh
lake build
lake env proof-forge --emit-counter-ir-yul -o build/ir/Counter.yul
solc --strict-assembly build/ir/Counter.yul --bin
```

Result:

- `lake build` passed.
- Counter IR lowers to Yul.
- `solc --strict-assembly` accepts the generated Yul.

Known limitations:

- The IR-generated Yul currently contains function definitions only.
- It does not yet generate EVM calldata selector dispatch.
- `solc` emits `00` for this debug object because no runtime dispatcher calls
  the generated functions yet.
- Existing `--evm-bytecode` smoke still requires Foundry `cast`; it was not
  revalidated locally because `cast` was not on `PATH`.

Next step:

- Generate an EVM dispatcher/runtime wrapper from IR entrypoints so the IR path
  can produce callable bytecode and run through Foundry smoke.

### Psy DPN Target Research

Commit: `ce5ab3e docs: add Psy DPN target research`

Summary:

- Added `psy-dpn` as a Research-stage target.
- Classified Psy as a ZK circuit source-generation target.
- Documented why the first integration path should generate `.psy` source and
  call Dargo instead of directly emitting DPN internals.
- Added `zk.circuit` and `zk.proof` capability ids.
- Added Chinese analysis for the Psy/DPN target.

Validation run:

```sh
git diff --check
```

Result:

- Documentation whitespace check passed before commit.

Known limitations:

- No Psy source generator exists yet.
- No Dargo smoke exists in this repository.

Next step:

- Reuse the portable Counter IR fixture once the IR-to-sourcegen path exists.

### Portable IR And Target Planning Docs

Commit: `9b7fce3 docs: add portable IR, capability registry, validation gates, and dev standards`

Summary:

- Added the first portable IR spec.
- Added canonical capability ids.
- Added shared Counter scenario.
- Added validation gates and development standards.
- Added implementation backlog slices for target registry, IR, metadata, EVM
  hardening, Wasm, Solana, Move, CI, and Psy.

Validation run:

```sh
git diff --check
```

Result:

- Documentation whitespace check passed before commit.

Known limitations:

- These were planning docs only; no IR code existed yet.

Next step:

- Implement the Target registry and Counter-shaped IR v0 in Lean.

### Multi-Chain Target Design

Commit: `a5555e5 docs: add multichain target design`

Summary:

- Added the first multi-chain platform RFCs and Chinese feasibility/technical
  analysis.
- Established the direction: Lean business logic plus target-specific adapters.
- Documented EVM, Solana, Wasm-family, Move-family, and cloud platform tracks.

Validation run:

```sh
git diff --check
```

Result:

- Documentation whitespace check passed before commit.

Known limitations:

- Design-only milestone.

Next step:

- Split the design into concrete target registry, IR, and validation tasks.

### EVM Baseline

Commits:

- `34b1708 Initial ProofForge EVM backend`
- `b7a5343 Add EVM examples and Foundry smoke tests`
- `a97dd21 Add CI and integrate EVM bytecode CLI`

Summary:

- Added the initial EVM SDK and Yul backend.
- Added EVM examples and Foundry smoke tests.
- Added bytecode compilation through `solc --strict-assembly`.
- Added CI around the baseline build and EVM smoke path.

Current role:

- EVM remains the first working target.
- New IR work should use EVM as the first executable backend to validate
  semantics before adding more chains.
