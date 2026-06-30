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

- Generate one Counter `.psy` package from a portable IR fixture.
- Generate `Dargo.toml`.
- Call `dargo compile` and capture DPN circuit JSON.
- Call `dargo generate-abi` when available.
- Emit `proof-forge-artifact.json` with target id `psy-dpn`.
- Document whether `dargo execute`, `dargo test`, or `psy-wasm` is the best
  local smoke runner.

Acceptance criteria:

- Generated `.psy` source is readable and checked into a golden fixture or
  snapshot.
- `dargo compile` produces a non-empty JSON artifact on a machine with the Psy
  toolchain.
- Artifact metadata records Dargo/Psy compiler version or commit.
- Unsupported non-circuit-friendly IR nodes fail before source generation.

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
9. CI target matrix (Workstream 9).
10. Cloud platform design refresh (prerequisite: two+ targets at Experimental
   stage; see [decisions.md](decisions.md)).
