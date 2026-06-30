> **Note:** public validation command changes must update
> [validation-gates.md](validation-gates.md) in the same change.

# Implementation Backlog

This backlog turns the multi-chain design into reviewable engineering slices.
It is intentionally scoped to local compiler, artifact, and smoke-test work.
The cloud platform should wait until at least two materially different targets
are working locally.

Related docs:

- [Design decisions](decisions.md)
- [Portable Contract IR](portable-ir.md)
- [Capability registry](capability-registry.md)
- [Shared scenario: Counter](shared-scenario.md)
- [RFC 0002](rfcs/0002-target-implementation-design.md)
- [Target notes](targets/README.md)
- [Validation gates](validation-gates.md)

## Workstream 1: Target Registry

Goal: make target selection explicit before adding more backends.

Tasks:

- Add target ids: `evm`, `wasm-near`, `wasm-cosmwasm`,
  `solana-sbpf-linker`, `solana-zig-fork`, `move-sui`, `move-aptos`,
  `psy-dpn`.
- Define target family, artifact kind, required tools, and capability set
  (see [capability-registry.md](capability-registry.md)).
- Add a target lookup function for CLI and scripts.
- Add diagnostics for unknown targets and unsupported capabilities.

Acceptance criteria:

- `evm` can be represented as a target profile without changing current EVM
  behavior.
- A target profile can declare external tool requirements.
- Unsupported capability errors include target id, capability id, and source
  location when available.

## Workstream 1.5: Portable IR and Shared Scenario

Goal: define the contract IR and Counter scenario before non-EVM spikes.

Tasks:

- Implement IR node types per [portable-ir.md](portable-ir.md).
- Express Counter per [shared-scenario.md](shared-scenario.md).
- Lower Counter IR to EVM (directly or via EmitYul adapter).
- Wire capability checker to [capability-registry.md](capability-registry.md).

Acceptance criteria:

- Counter module is representable in IR without EVM opcodes in the IR layer.
- EVM build from IR matches existing Counter behavior.
- At least one unsupported capability is rejected with a clear diagnostic.
- IR version appears in artifact metadata when emitted.

## Workstream 2: Artifact Metadata

See [validation-gates.md](validation-gates.md) for current and planned validation commands.

Goal: every build should produce a machine-readable result that can later feed
CI and the cloud platform.

Tasks:

- Add a `proof-forge-artifact.json` schema.
- Emit metadata for EVM bytecode builds.
- Include source module, target id, artifact path, SHA-256, tool versions, and
  proof/check status.
- Keep schema versioned from day one.

Acceptance criteria:

- EVM bytecode build writes bytecode and metadata next to each other.
- Metadata can be parsed independently by CI scripts.
- Missing optional tools are represented as warnings, not malformed metadata.

## Workstream 3: EVM Baseline Hardening

See [validation-gates.md](validation-gates.md) for current and planned validation commands.

Goal: keep EVM stable while the target model is introduced.

Tasks:

- Keep `proof-forge --evm-bytecode` working.
- Add golden Yul outputs for simple examples.
- Add metadata emission around current `solc --strict-assembly` flow.
- Keep Foundry smoke as the mature EVM smoke test.

Acceptance criteria:

- `lake build` passes.
- `scripts/evm/build-examples.sh` succeeds on a machine with `solc`.
- `scripts/evm/foundry-smoke.sh` succeeds on a machine with Foundry.
- The generated metadata points to the bytecode artifact and records `target:
  evm`.

## Workstream 4: Wasm Host Runtime Split

Goal: make Wasm host adapters target-driven instead of assuming every Wasm
contract is NEAR.

Tasks:

- Move chain extern declarations out of generic EmitZig runtime externs.
- Add a target-selected host bridge list.
- Keep NEAR bridge as the reference implementation.
- Add a CosmWasm bridge skeleton with allocator and region ABI.

Acceptance criteria:

- A Wasm build can select NEAR or CosmWasm bridge explicitly.
- Generic Wasm runtime does not force-link NEAR host functions.
- `wasm-near` and `wasm-cosmwasm` can have different required exports.

## Workstream 5: CosmWasm Spike

Goal: prove that ProofForge can target another Wasm host besides NEAR.

Tasks:

- Add `Lean.CosmWasm` SDK skeleton (see [wasm-family.md](targets/wasm-family.md)).
- Add `zigc-cosmwasm` wrapper.
- Add `cosmwasm_contract_root.zig`.
- Export `interface_version_8`, `allocate`, `deallocate`, `instantiate`,
  `execute`, and `query`.
- Add Counter example using JSON-backed messages.
- Add `cosmwasm-check` smoke.

Acceptance criteria:

- Counter Wasm passes `cosmwasm-check`.
- `instantiate`, `execute`, and `query` are present in exports.
- The smoke test can increment and query counter state.

## Workstream 6: Solana sBPF-Linker Spike

Goal: validate the no-fork Solana pipeline before adopting a forked compiler.

Tasks:

- Add `zigc-solana-sbpf` wrapper around `zig build-lib
  -target bpfel-freestanding -femit-llvm-bc`.
- Call `sbpf-linker --cpu v2 --export entrypoint`.
- Add `solana_contract_root.zig` with one exported `entrypoint`.
- Add minimal syscall/log bridge.
- Add explicit instruction manifest format (see [solana-sbf.md](targets/solana-sbf.md)).
- Add Counter account example.

Acceptance criteria:

- A minimal generated `entrypoint.bc` is produced by stock Zig.
- `sbpf-linker` produces a `.so`.
- The `.so` runs in either Mollusk or `solana-test-validator`.
- The spike records whether the Lean Zig runtime can link under sBPF
  constraints.

## Workstream 7: Solana Runtime Decision

Goal: decide whether ProofForge can use full Lean runtime on Solana or needs a
restricted runtime subset. **Runs after Workstream 6 produces spike data.**

Questions:

- Does the full Lean Zig runtime link under `bpfel-freestanding`?
- Does the resulting ELF pass Solana loader constraints?
- Is the artifact size acceptable?
- Is 4KB stack pressure manageable?
- Are heap allocation and reference counting feasible inside Solana compute
  budgets?

Decision outcomes:

- Use full Lean Zig runtime for Solana.
- Use restricted Lean runtime subset for Solana.
- Generate direct Zig for a portable IR subset without the full Lean runtime.
- Fall back to the `solana-zig` fork while keeping `sbpf-linker` open.

Record the outcome in [decisions.md](decisions.md).

## Workstream 8: Move Source Generation POC (Aptos first)

Goal: avoid pretending Move is another Lean runtime target.

Tasks:

- Define a Move-compatible subset of the portable IR.
- Generate one **Aptos** Move counter package (Sui follows in a separate slice).
- Run `aptos move compile/test`.
- Document verifier restrictions that must feed back into IR design.

Acceptance criteria:

- Generated Aptos Move source compiles.
- Generated package has tests.
- Unsupported Lean constructs fail before codegen.
- Follow-up Sui object POC is documented as a separate milestone.

## Workstream 9: CI Expansion

See [validation-gates.md](validation-gates.md) for current and planned validation commands.

Goal: keep CI useful without requiring every external chain tool on day one.

Tasks:

- Keep `lake build` as always-on CI.
- Add EVM smoke only when `solc` and Foundry are available.
- Add optional jobs for CosmWasm, Solana, and Move with clear tool checks.
- Add artifact metadata validation as a tool-independent job.

Acceptance criteria:

- Base CI does not fail because optional chain tools are missing.
- Target-specific CI jobs fail loudly when their toolchain is present but the
  target build fails.
- Metadata schema validation runs without chain tools.

## Workstream 10: Psy DPN ZK Target Spike

Goal: validate a ZK circuit sourcegen target without coupling ProofForge to Psy
compiler internals.

Tasks:

- Done: generate one Counter `.psy` source file from a portable IR fixture.
- Done: add a temporary Dargo package generator in `scripts/psy/counter-smoke.sh`.
- Done: document `dargo test --file` as the first local smoke runner.
- Done: run `dargo compile` with the `psyup` v0.1.0 macOS arm64 toolchain and
  capture DPN circuit JSON.
- Done: run `dargo execute` as a local user/contract session and assert the
  Counter result after two increments.
- Done: call `dargo generate-abi` and capture non-empty ABI JSON.
- Done: emit `proof-forge-artifact.json` with target id `psy-dpn` for Psy smoke
  artifacts.
- Done: add ContextProbe as a non-Counter fixture for parameter lowering and
  context reads.
- Done: add HashProbe for `Hash`, typed hash let-bindings, `hash`, and
  `hash_two_to_one`, aligned with upstream Psy hash tests.
- Done: validate Psy artifact metadata, including hashes, byte sizes,
  capabilities, validation flags, and expected execution results.
- Done: add map/storage-map, assertions, bounded-loop, array, struct,
  aggregate ABI, nested aggregate, storage nested aggregate, U32 arithmetic,
  and bitwise coverage from the upstream `psy-compiler/tests` and
  `psy-precompiles` corpus.
- Done: add U32/Hash limb packing coverage for local arrays and ABI parameters
  from the upstream `psy-precompiles` corpus.
- Done: emit and validate ProofForge deploy manifests for all Dargo-backed Psy
  smoke compile outputs.
- Done: add map storage path coverage for `Map<Hash, Hash, N>` with Dargo
  compile/execute validation.
- Done: add expression-position `storageMapSet` lowering and MapProbe coverage
  for upstream map edge semantics where `set` and repeated `insert` return the
  previous `Hash` value.
- Done: add storage-reference compound assignment coverage for scalar storage
  and generic storage paths with Dargo compile/execute validation.
- Done: add native U32 scalar storage coverage using Psy `pub value: u32`
  storage plus scalar `+=` assignment, with Dargo compile/execute validation.
- Done: add native Bool scalar storage coverage using Psy `pub flag: bool`
  storage plus `bool as Felt` return casts, with Dargo compile/execute
  validation.
- Done: add U32 storage array coverage using Felt-backed storage plus explicit
  U32 read/write casts, with Dargo compile/execute validation.
- Done: add a Psy IR coverage manifest gate so every portable IR constructor
  must be classified as lowered, validated, unsupported, or structural for the
  Psy backend.
- Done: factor Dargo smoke package generation into a shared writer so every
  Psy smoke creates the same `src/main.psy` and `Dargo.toml` layout before
  metadata validation.
- Done: reject EVM-style entrypoint selectors in the Psy backend instead of
  silently dropping selector metadata that Dargo/Psy ABI does not use.
- Done: validate Psy identifiers and duplicate declarations before source
  generation so invalid names do not fall through to Dargo parser/typechecker
  failures.
- Done: add a generic generated test fallback for valid Psy IR modules that do
  not have fixture-specific assertions, backed by `GenericEntrypointProbe`,
  golden source, Dargo compile/execute validation, ABI generation, deploy
  manifest generation, and artifact metadata validation.
- Convert the deploy manifest path to upstream compressed genesis deploy JSON
  once the Psy tooling exposes a stable boundary, then exercise a local
  node/prover deployment smoke.
- Record Dargo/Psy compiler version or commit once the toolchain exposes a
  stable value.

Acceptance criteria:

- Generated `.psy` source is readable and checked into a golden fixture or
  snapshot.
- `dargo compile` produces a non-empty JSON artifact on a machine with the Psy
  toolchain.
- `dargo execute` returns `result_vm: [2]` for the Counter lifecycle.
- `dargo execute` returns `result_vm: [15]` for ContextProbe's
  `sum_context(2,3)` lifecycle.
- `dargo execute` returns deterministic four-Felt outputs for HashProbe's
  `poseidon_hash` and `poseidon_pair_hash` entrypoints.
- `dargo generate-abi` produces a non-empty ABI JSON artifact.
- `dargo execute` returns `result_vm: [42]` for the generic non-whitelisted
  `GenericEntrypointProbe`.
- Artifact metadata records target id, fixture id, used capabilities, artifact
  paths, hashes, byte sizes, Dargo package source copy, Dargo package manifest,
  and validation status.
- Artifact metadata is machine-validated by the Psy smoke scripts.
- Artifact metadata records Dargo/Psy compiler version or commit once available.
- Unsupported non-circuit-friendly IR nodes fail before source generation.
- CI either pins a known-good `psyup` release or skips this gate clearly when a
  matching toolchain tarball is unavailable.

## Workstream 11: Kaspa Toccata Research Target

Goal: decide whether and how ProofForge should support Kaspa's Toccata
programmability stack without pretending it is an EVM, account-state, or generic
ZK circuit target.

Tasks:

- Done: add a docs-first target note for candidate id `kaspa-toccata`.
- Classify the target as UTXO covenant/based-app research, not
  `zk-circuit-sourcegen`.
- Review candidate capabilities for UTXO state, covenant lineage, transaction
  v1, user lanes, compute budgets, and inline proof verification.
- Decide whether the first spike should generate Silverscript or only produce a
  target manifest around hand-authored covenant source.
- Define a tiny L1 covenant Counter-like scenario with successor-output
  validation.
- Define the minimal artifact metadata shape for covenant source, transaction v1
  manifest, covenant lineage manifest, and optional proof verifier manifest.
- Defer based-app support until the L1 covenant artifact shape is clear.

Acceptance criteria:

- `docs/targets/kaspa-toccata.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish inline ZK verification from `psy-dpn`-style circuit
  source generation.

## Workstream 12: Stellar Soroban Research Target

Goal: decide whether and how ProofForge should support Stellar smart contracts
without treating all Wasm contract chains as one target.

Tasks:

- Done: add a docs-first target note for candidate id `wasm-stellar-soroban`.
- Classify Soroban as a Wasm-host candidate, not a generic Wasm artifact target.
- Decide whether the first spike should generate a native Rust/Soroban package
  or wait for a direct Lean-to-Wasm host bridge.
- Review candidate capabilities for address authorization, contract-account
  authorization, storage TTL, contract spec metadata, and Stellar assets.
- Define a tiny Counter-like scenario that exercises storage and event output.
- Define artifact metadata for Wasm, contract spec, deployment manifest,
  toolchain versions, and validation result.
- Identify the local smoke command set: `stellar contract build`, sandbox or
  testnet deploy, and invoke.

Acceptance criteria:

- `docs/targets/stellar-soroban.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Soroban from NEAR and CosmWasm despite all three using
  Wasm artifacts.

## Workstream 13: Internet Computer Research Target

Goal: decide whether and how ProofForge should support Internet Computer
canisters without treating every Wasm artifact as the same contract target.

Tasks:

- Done: add a docs-first target note for candidate id `wasm-icp-canister`.
- Classify ICP canisters as a Wasm-host candidate, not a generic Wasm artifact
  target.
- Decide whether the first spike should generate a native Motoko/Rust CDK
  package or wait for a direct Lean-to-Wasm canister bridge.
- Review candidate capabilities for Candid, update/query method modes, stable
  memory, orthogonal persistence, principals, cycles, async inter-canister
  calls, canister lifecycle, certified data, and management canister APIs.
- Define a tiny Counter-like scenario with one update method and one query
  method.
- Define artifact metadata for Wasm, Candid, canister manifest, stable-state or
  upgrade policy, toolchain versions, and validation result.
- Identify the local smoke command set: local replica, PocketIC, or ICP CLI
  canister install/call flow.

Acceptance criteria:

- `docs/targets/internet-computer.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish ICP canisters from NEAR, CosmWasm, and Soroban despite
  all using Wasm artifacts.

## Workstream 14: TON TVM Research Target

Goal: decide whether and how ProofForge should support TON smart contracts
without pretending TVM contracts are EVM, Wasm-host, Move, or ZK targets.

Tasks:

- Done: add a docs-first target note for candidate id `ton-tvm`.
- Classify TON as a TVM/Tolk sourcegen candidate.
- Decide whether the first spike should generate Tolk source/package artifacts
  or wait for a lower-level TVM/cell IR.
- Review candidate capabilities for cells, TL-B metadata, inbound messages,
  outbound messages, get methods, action lists, `StateInit`, account status,
  TVM gas, and jetton/token integration.
- Define a tiny Counter-like scenario with one internal message and one get
  method.
- Define artifact metadata for source, TVM/BOC output, interface metadata,
  initial state, message/action schema, toolchain versions, and validation
  result.
- Identify the local smoke command set: Acton/Tolk compile and local test or
  emulator validation.

Acceptance criteria:

- `docs/targets/ton-tvm.md` records the target classification and non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish TON TVM from Wasm-host, EVM, Move, and ZK targets.

## Workstream 15: Bitcoin Cash CashScript Research Target

Goal: decide whether and how ProofForge should support Bitcoin Cash smart
contracts without pretending UTXO spend paths are stateful contract method calls.

Tasks:

- Done: add a docs-first target note for candidate id `bch-cashscript`.
- Classify BCH/CashScript as a UTXO script/covenant sourcegen candidate.
- Decide whether the first spike should generate CashScript source/package
  artifacts before any lower-level BCH Script path.
- Review candidate capabilities for UTXO state, P2SH scripts, unlockers,
  transaction introspection, covenants, local state, CashTokens, timelocks,
  signature checks, CashScript artifacts, and transaction-builder validation.
- Define a tiny UTXO spend scenario with at least one contract function and a
  transaction-builder smoke.
- Define artifact metadata for `.cash` source, cashc artifact JSON, bytecode,
  constructor/unlocker manifest, transaction scenario, toolchain versions, and
  validation result.
- Identify the local smoke command set: `cashc`, CashScript SDK,
  `MockNetworkProvider`, and optional chipnet/node-backed validation.

Acceptance criteria:

- `docs/targets/bitcoin-cash-cashscript.md` records the target classification
  and non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish BCH/CashScript from EVM, Wasm-host, Move, generic
  Bitcoin, and Kaspa/Toccata targets.

## Workstream 16: Algorand AVM Research Target

Goal: decide whether and how ProofForge should support Algorand smart contracts
without pretending AVM applications are EVM, Wasm-host, Move, Solana, TVM,
UTXO, or ZK circuit targets.

Tasks:

- Done: add a docs-first target note for candidate id `algorand-avm`.
- Classify Algorand as an AVM/TEAL source or package-generation candidate.
- Decide whether the first spike should generate Algorand Python or Algorand
  TypeScript package artifacts before any direct TEAL emitter path.
- Review candidate capabilities for stateful applications, LogicSig programs,
  ARC-4 ABI/app specs, global/local/box storage, transaction groups, resource
  references, inner transactions, Algorand Standard Assets, AVM budget, and
  AlgoKit/Puya artifacts.
- Define a tiny stateful Counter-like application with one update method, one
  read/query path, explicit storage schema, and localnet or simulator-backed
  validation.
- Define artifact metadata for source, approval bytecode, clear-state bytecode,
  optional LogicSig bytecode, ABI/app spec, storage schema, resource references,
  toolchain versions, and validation result.
- Identify the local smoke command set: AlgoKit/Puya compile plus LocalNet or
  simulator-backed create/call/query validation.

Acceptance criteria:

- `docs/targets/algorand-avm.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Algorand AVM from Wasm-host, EVM, Move, Solana, TVM,
  UTXO, and ZK targets.

## Workstream 17: Cardano Plutus/Aiken Research Target

Goal: decide whether and how ProofForge should support Cardano smart contracts
without pretending eUTXO validators are stateful method-call contracts.

Tasks:

- Done: add a docs-first target note for candidate id `cardano-plutus-aiken`.
- Classify Cardano as an eUTXO validator sourcegen candidate.
- Decide whether the first spike should generate Aiken source before any direct
  Plutus/UPLC path.
- Review candidate capabilities for eUTXO state, validator roles, datum,
  redeemer, script context, validity ranges, transaction balancing, native
  tokens, execution units, and Plutus blueprints.
- Define a tiny Counter-like eUTXO state-machine scenario with successor-output
  validation.
- Define artifact metadata for Aiken source, UPLC/Plutus validators, blueprint,
  datum/redeemer schemas, transaction scenario, execution units, toolchain
  versions, and validation result.
- Identify the local smoke command set: Aiken compile/test plus emulator,
  SDK-backed transaction, or cardano-node-backed validation.

Acceptance criteria:

- `docs/targets/cardano-plutus-aiken.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Cardano from EVM, Wasm-host, Move, Solana, TVM, AVM,
  generic Bitcoin, BCH/CashScript, and Kaspa/Toccata targets.

## Workstream 18: Tezos Michelson/LIGO Research Target

Goal: decide whether and how ProofForge should support Tezos smart contracts
without hiding Michelson operation-list semantics behind generic contract calls.

Tasks:

- Done: add a docs-first target note for candidate id `tezos-michelson-ligo`.
- Classify Tezos as a Michelson source/artifact target with LIGO as the first
  sourcegen path.
- Review candidate capabilities for Michelson code, entrypoints, typed
  Micheline storage, `big_map`, operation lists, views, events, tickets,
  Sapling, delegation, gas/storage burn, and LIGO artifacts.
- Define a tiny Counter-like contract with one entrypoint, one view, typed
  storage, and a local test or sandbox validation flow.
- Define artifact metadata for LIGO source, Michelson output, parameter/storage
  schema, operation list, view/event manifest, toolchain versions, and
  validation result.
- Identify the local smoke command set: LIGO compile/test plus Octez sandbox or
  equivalent Tezos local validation.

Acceptance criteria:

- `docs/targets/tezos-michelson-ligo.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Tezos from EVM, Wasm-host, Move, Solana, TVM, AVM, UTXO,
  and ZK targets.

## Workstream 19: Starknet Cairo Research Target

Goal: decide whether and how ProofForge should support Starknet smart contracts
without treating Cairo chain contracts as generic ZK circuits.

Tasks:

- Done: add a docs-first target note for candidate id `starknet-cairo`.
- Classify Starknet as a Cairo/Sierra/CASM sourcegen candidate.
- Review candidate capabilities for Cairo source, Sierra, CASM, class
  declaration, class hash, Starknet ABI, storage, account abstraction, syscalls,
  L1/L2 messaging, Starknet fee/resource constraints, and Starknet Foundry
  validation.
- Define a tiny Counter-like contract with storage, an increment external
  function, a read function, and one event.
- Define artifact metadata for Cairo source, Sierra/CASM artifacts, ABI,
  selector/class-hash metadata, deployment manifest, toolchain versions, and
  validation result.
- Identify the local smoke command set: Scarb build plus `snforge` or
  devnet-backed tests.

Acceptance criteria:

- `docs/targets/starknet-cairo.md` records the target classification and
  non-goals.
- Capability candidates remain documented but are not added to
  `ProofForge.Target.Capability` until reviewed.
- The first spike has a reproducible local validation command or a documented
  external-tool blocker.
- The docs distinguish Starknet from EVM, Wasm-host, Move, Solana, TVM, AVM,
  UTXO, and `psy-dpn`-style ZK circuit targets.

## Suggested Order

1. Target registry (Workstream 1).
2. Portable IR + shared Counter scenario (Workstream 1.5).
3. EVM artifact metadata (Workstreams 2–3).
4. Wasm runtime split (Workstream 4).
5. **Parallel:** CosmWasm spike (Workstream 5) and Solana sbpf-linker spike
   (Workstream 6).
6. Solana runtime decision (Workstream 7 — after spike data).
7. Move Aptos POC (Workstream 8).
8. Psy DPN sourcegen spike (Workstream 10) once the IR fixture exists.
9. Kaspa Toccata research target review (Workstream 11) before any registry
   changes.
10. Stellar Soroban research target review (Workstream 12) before any registry
    changes.
11. Internet Computer research target review (Workstream 13) before any registry
    changes.
12. Algorand AVM research target review (Workstream 16) before any registry
    changes.
13. Cardano Plutus/Aiken research target review (Workstream 17) before any
    registry changes.
14. Tezos Michelson/LIGO research target review (Workstream 18) before any
    registry changes.
15. Starknet Cairo research target review (Workstream 19) before any registry
    changes.
16. TON TVM research target review (Workstream 14) before any registry changes.
17. Bitcoin Cash CashScript research target review (Workstream 15) before any
    registry changes.
18. CI target matrix (Workstream 9).
19. Cloud platform design refresh (prerequisite: two+ targets at Experimental
   stage; see [decisions.md](decisions.md)).
