# Phase 6b — EVM semantics target switch and integration blockers

Status: **preferred target switched to `powdr-labs/evm-semantics`; opt-in target and wrapper landed, default mathlib-free seam remains stubbed by design.**
Date: 2026-07-07.
RFC: RFC 0014 Phase 6b (Path 5b — Tier C-proof).
Roadmap: `docs/tier-c-proof-feasibility.md` §5 Phase 6b.

## Goal (recap)

Bring in a conformance-tested EVM bytecode semantics as an opt-in `lake`
dependency, replacing/augmenting the in-tree pseudo-Yul `Evm.YulSemantics`
that `Evm.Refinement.lean` currently uses. The preferred external dependency is
now [`powdr-labs/evm-semantics`](https://github.com/powdr-labs/evm-semantics):
a Lean 4 EVM semantics pinned to ProofForge's Lean toolchain (`v4.31.0`) and
structured around relational `Step` / `Eval` plus executable `stepF`.
It is a STANDALONE semantics, not a refinement framework — the simulation
obligation is ProofForge's (that is Phase 6c).

## (a) Toolchain comparison

| | Lean toolchain | mathlib | Notes |
|---|---|---|---|
| **ProofForge** | `leanprover/lean4:v4.31.0` | none | Pinned by `lean-toolchain`. Existing 378-job build green. |
| **powdr-labs/evm-semantics** | `leanprover/lean4:v4.31.0` | `mathlib4 @ v4.31.0` | Toolchain-compatible preferred target; pull behind an opt-in lake target so the default build stays mathlib-free. |
| **EVMYulLean** | `leanprover/lean4:v4.22.0` | `require mathlib from git "https://github.com/leanprover-community/mathlib4.git"@"v4.22.0"` | Pinned by its `lean-toolchain` and `lakefile.lean`. mathlib v4.22.0 is tightly coupled to the v4.22.0 toolchain. |

A lake workspace uses **one** `lean-toolchain`. The two pinned toolchains
differ by 9 minor versions (`v4.22.0` vs `v4.31.0`).

## (b) The exact `require` syntax now used

The opt-in EVM-refinement target now pins `powdr-labs/evm-semantics` to a
literal commit SHA for reproducibility:

```lean
require evm_semantics from git
  "https://github.com/powdr-labs/evm-semantics.git"@"ae13dbc506158f9d0c7e05634636b17e2bccf850"
```

`lake-manifest.json` records the transitive `mathlib` pin
`fabf563a7c95a166b8d7b6efca11c8b4dc9d911f` (`v4.31.0`). The new
`EvmRefinement` Lake target imports powdr; the default `proof-forge` target
does not.

The old `EVMYulLean` fallback syntax, **only if its toolchain aligns**, would be:

```lean
require evmyul from git
  "https://github.com/leonardoalt/EVMYulLean.git"@"<commit-sha>"
```

The `<commit-sha>` should be the tip of `main` at the time of unblocking,
captured into `lake-manifest.json` by `lake update`. (A `main`-branch pin
is explicitly avoided for reproducibility — `EVMYulLean` publishes no
tags, so a literal commit SHA is required.)

EVMYulLean's own `lakefile.lean` additionally:

- `require mathlib from git ... @"v4.22.0"` (transitive dep, toolchain-coupled).
- Builds a C FFI (`extern_lib libleanffi`) by cloning two external C repos
  (`amosnier/sha-2`, `brainhub/SHA3IUF`) and compiling `EvmYul/FFI/ffi.c`.
- Its `extern_lib` target opportunistically populates the `EthereumTests`
  git submodule via `git submodule update --init EthereumTests` from the
  package directory. This is the heavy submodule the task says NOT to pull
  in the default build (CI-only).

## (c) Integration outcome

**TARGET SWITCHED, OPT-IN DEPENDENCY WIRED.** The `EVMYulLean` integration was
blocked by the pinned toolchain mismatch below. The preferred route is now
powdr, which removes the toolchain blocker but still pulls mathlib. The
dependency is present in `lakefile.lean` and `lake-manifest.json`, but it is
only imported by the separate opt-in `EvmRefinement` target. The default
`proof-forge` target remains free of powdr/mathlib imports.

## (d) The precise blocker + resolution path

### Historical blocker: `EVMYulLean` Lean toolchain + mathlib version mismatch

- ProofForge: `leanprover/lean4:v4.31.0`, no mathlib.
- EVMYulLean: `leanprover/lean4:v4.22.0` + `mathlib4 @ v4.22.0`.

A single lake workspace cannot simultaneously satisfy both toolchain
pins. mathlib v4.22.0 will not compile under lean v4.31.0 (mathlib is
tightly coupled to a specific Lean toolchain version; the mathlib team
cuts a `v4.X.0` tag per Lean release). Downgrading ProofForge to v4.22.0
would break the existing 378-job build (and the task explicitly forbids
forcing a downgrade/upgrade).

### Secondary considerations (not the primary blocker)

- EVMYulLean builds C FFI by cloning two external C repos (`sha-2`,
  `SHA3IUF`) and compiling them; this needs a C compiler and network
  access at build time. Manageable in CI, but an extra moving part.
- EVMYulLean's `extern_lib` target populates the `EthereumTests` submodule
  (heavy; CI-only per the task). This is avoidable by not building the
  `conform` test driver, but the `extern_lib` still runs the submodule
  init in the default `lake build` of EVMYulLean — a downstream consumer
  building `EvmYul` would trigger it unless the target graph is trimmed.

### Resolution path (in order of preference)

0. **Switch the refinement target to `powdr-labs/evm-semantics` (resolves the
   EVMYulLean blocker now).** As of 2026-07, [`powdr-labs/evm-semantics`](https://github.com/powdr-labs/evm-semantics)
   is a Lean 4 EVM semantics pinned to `leanprover/lean4:v4.31.0` + `mathlib @
   v4.31.0` — the **same toolchain as ProofForge** — so there is no version
   mismatch to wait on. It is relationally structured (Prop-valued `Step`/`Eval`
   plus an executable `stepF`), which fits the Phase 6c simulation proof better
   than EVMYulLean's executable `step`. Cost: it pulls `mathlib` (ProofForge has
   none today) — isolate it behind an **opt-in lake target** for the
   EVM-refinement modules so the core build stays mathlib-free. It is a draft
   ("not for production"), so pin a specific commit; its `Step` relation joins
   the TCB. This is now the **preferred** path; the EVMYulLean options below are
   fallbacks. The local seam now mirrors powdr's `State` / `Step` / `stepF`
   shape. See [tier-c-proof-feasibility.md §2](tier-c-proof-feasibility.md).

1. **Wait for EVMYulLean to update its toolchain pin to a Lean version
   compatible with ProofForge's (≥ v4.31.0) and cut a matching mathlib
   tag.** This is the cleanest path: no ProofForge churn, no vendoring.
   Track upstream: https://github.com/leonardoalt/EVMYulLean. When the
   `lean-toolchain` there reads `leanprover/lean4:v4.31.0` (or later) and
   `lakefile.lean` requires `mathlib @ v4.31.0` (or later), add the
   `require` entry above and run `lake update` in an environment with
   network access.

2. **Align toolchains intentionally.** If ProofForge independently decides
   to downgrade/pin to v4.22.0 (unlikely — it would regress the 378-job
   build and the broader ecosystem), or if EVMYulLean lands on a
   ProofForge-compatible toolchain, the `require` entry in §(b) becomes
   droppable as-is. This is a coordinated upstream+downstream decision,
   not a Phase 6b unilateral change.

3. **Vendor an adapter against a frozen EVMYulLean commit, build it in a
   separate lake workspace pinned to v4.22.0, and surface a thin extracted
   interface (e.g. via an `irreducible` definition or a `cc`-free wrapper)
   that ProofForge imports.** This is the heaviest path and is only worth
   it if (1) and (2) are blocked long-term. It is research-grade; defer.

### Recommended next action

Use the opt-in powdr wrapper plus the landed Counter storage relation to prove
the Counter per-entrypoint simulation against powdr `Step`. The pinned powdr
tree exposes bytecode semantics but no Yul-level relation, so keep the
Yul→bytecode `solc` step as an explicit trust boundary.

## (e) Files changed (Phase 6b, blocked-seam deliverable)

- `ProofForge/Backend/Evm/EvmBytecodeSemantics.lean` (new/updated) — the
  default-build, mathlib-free adapter seam with the public surface (`State`,
  `Step`, `stepF`, `step`, `runBytecode`) aligned to the powdr target shape
  and `Refinement.ObservableStep`. Its stub body is intentional fallback
  surface; real powdr imports live in the opt-in `EvmRefinement` target.
- `docs/phase-6b-integration-blockers.md` (new/updated — this file).
- `docs/tier-c-proof-feasibility.md` (modified) — Phase 6b section marked
  as powdr-target wired, with the EVMYulLean blocker retained as historical
  context/fallback.
- `docs/rfcs/0014-unified-semantic-lowering-contract.md` (modified) —
  Path 5b Phase 6b status updated to powdr-target wired and Phase 6b
  unblocked.
- `docs/zh/rfcs/0014-unified-semantic-lowering-contract.zh.md` (modified)
  — Path 5b Phase 6b status updated by zh translation sync.
- `lakefile.lean` — modified to add the pinned `evm_semantics` dependency and
  an opt-in `EvmRefinement` target; the default `proof-forge` target does not
  import powdr/mathlib.
- `lake-manifest.json` — records the pinned powdr/mathlib dependency graph.
- `EvmRefinement/PowdrAdapter.lean` — opt-in adapter that imports powdr's
  `State`, `Step`, `StepF`, `BigStep`, and `Equiv` modules; exposes real
  powdr-backed `State`, `Step`, `stepF`, `step`, `isHalted`, and `runBytecode`
  wrappers; and proves the wrapper `stepF_sound` using
  `EvmSemantics.EVM.stepF_sound`, plus `runBytecode_steps` from successful
  fuel-bounded execution to powdr `Steps`.
- `EvmRefinement/CounterRefinement.lean` — opt-in Counter relation layer that
  maps IR `count` to the powdr account storage word at ProofForge's EVM scalar
  slot 0 using the generated packed U64 shape: high 64 bits carry `count`, low
  192 bits are padding/other-packed-field space, and `count < 2^64`,
  embeds the current CLI-generated Counter runtime bytecode witness, proves its
  selector offsets, exposes the compiled-runtime powdr config, and specializes
  the initialize-prefixed trace theorem to that concrete runtime target. It also
  defines a high-gas top-level `counterBaseEvmState` and native executable
  smokes for the compiled runtime; those are C-diff witnesses, not the pending
  relational per-entrypoint proof. Prepared calls now normalize a fresh
  top-level EVM frame while preserving storage, so stale halted frames or
  zero-gas defaults are not accidental counterexamples. The concrete compiled
  powdr target now wires `executableTraceOk` for Counter `TraceObligation`s and
  proves the initialize-get-increment-get trace. The relation layer also exposes
  `CounterStepSafe`, `CounterPowdrSafeEntrypointObligations`, and
  `counterPowdr_safe_step_simulates_from_obligations`, so the bounded
  `increment` precondition is now part of the per-entrypoint EVM proof surface.
  The safe trace theorem also lifts this predicate through the universal
  Counter trace induction and exposes a compiled-runtime specialization.
  `CounterTraceSafeAtState` exposes the same boundary as a state/input predicate.
  `CounterPowdrEvmPostconditions` and
  `counterPowdrSafeEntrypointObligationsOfPostconditions` isolate the remaining
  proof to EVM-only storage postconditions for the compiled runtime. Padded-slot
  native smokes confirm `get` reads the high 64-bit count and `initialize; get`
  returns `0` even when the low 192 bits are nonzero.
  `CounterPowdrPreparedEvmPostconditions` and
  `counterPowdrEvmPostconditionsOfPrepared` split the hard proof into
  prepared-frame bytecode facts plus the `prepareCounterCall` bridge. The
  initialize slice now has `counterInitializeStorageWord` as the storage model
  and `counterPreparedInitializePostconditionOfStorageModel` as the bridge from
  that model to the prepared-frame postcondition. `CounterPowdrPreparedStorageModels`
  names the exact remaining prepared-frame storage-model surface, and the
  compiled `counterCompiledPowdr_safe_trace_simulates_*_prepared_storage_models`
  theorems connect that surface directly to the safe universal trace theorems.
  The SSTORE slice now has
  `counterInitializeStorageValue_of_sstore_stackMemFlow_ok`, proving that a
  successful powdr `SSTORE` helper step with the initialize model value on the
  stack writes that value into Counter slot 0. `counterStack_of_initialize_sload_and_or_ok`
  composes the powdr `SLOAD`, `AND`, and `OR` helper steps into the value
  shape that feeds that SSTORE. `counterInitializeSetValue_eq_zero`,
  `counterInitializeLowMask_eq`, `counterInitializeBodyWriteWord_eq_storageWord`,
  and `counterInitializeBodyWriteWord_rel_zero` prove that the concrete mask and
  set value produced by the initialize body exactly match
  `counterInitializeStorageWord`; `counterStack_of_initialize_sload_and_or_storageWord_ok`
  specializes the SLOAD/AND/OR helper sequence to that storage model value.
  `counterStack_of_initialize_prefix_to_sload_ok` proves the initialize-body
  prefix constructs the exact stack consumed by the SLOAD helper.
  `counterStorageValue_of_initialize_sload_and_or_push_sstore_ok` stitches
  SLOAD/AND/OR through the final `PUSH0; SSTORE` and proves the resulting state
  writes the initialize storage model into Counter slot 0.
- `scripts/evm/powdr-counter-runtime-smoke.sh` + `just evm-powdr-counter-runtime`
  — opt-in drift gate that regenerates the Counter runtime and checks it still
  matches the embedded powdr witness.
- `ProofForge/Backend/Evm/Refinement.lean` — **NOT modified** (no theorem
  touched; wiring is Phase 6c).
- `ProofForge/IR/StepSemantics.lean` — **NOT modified** (Phase 6a
  invariant preserved).

## (f) Verification

- `lake build ProofForge.Backend.Evm.EvmBytecodeSemantics` — green (the
  default mathlib-free seam compiles with no external dependency).
- `lake build proof-forge` — green; default target does not build powdr/mathlib.
- `lake build EvmRefinement` — green; builds the opt-in powdr/mathlib adapter
  target.
- `just evm-powdr-counter-runtime` — green; generated Counter runtime matches
  the embedded powdr witness.
- `counterCompiledPowdr_initialize_executable_smoke`,
  `counterCompiledPowdr_get_zero_executable_smoke`, and
  `counterCompiledPowdr_initialize_increment_get_executable_smoke` — green
  under `lake build EvmRefinement`.
- `counterCompiledPowdr_get_packed_seven_executable_smoke` and
  `counterCompiledPowdr_increment_packed_seven_executable_smoke` — green;
  confirm the relation's packed U64 storage shape matches the compiled runtime.
- `counterCompiledPowdr_executable_trace_ok` — green; the compiled-runtime
  powdr `TargetSemantics.executableTraceOk` accepts the Counter trace obligation.
- `counterPowdr_safe_step_simulates_from_obligations` — green under
  `lake build EvmRefinement`; safe per-entrypoint obligations imply the
  one-step IR/powdr Counter simulation.
- `counterCompiledPowdr_safe_trace_simulates_after_initialize_from_obligations`
  — green under `lake build EvmRefinement`; safe per-entrypoint obligations
  plus `counterTraceSafeAfterInitialize` imply the initialize-prefixed universal
  IR/powdr Counter trace simulation for the concrete compiled runtime.
- `counterCompiledPowdr_safe_trace_simulates_from_state_safe_obligations` —
  green under `lake build EvmRefinement`; `CounterTraceSafeAtState` plus the
  storage relation imply the universal IR/powdr Counter trace simulation for
  the concrete compiled runtime.
- `counterPowdrSafeEntrypointObligationsOfPostconditions` — green under
  `lake build EvmRefinement`; EVM-only storage postconditions imply the safe
  per-entrypoint obligations.
- `counterPowdrEvmPostconditionsOfPrepared` — green under
  `lake build EvmRefinement`; prepared-frame postconditions imply the ordinary
  arbitrary-pre-state postconditions used by `counterPowdrTraceStep`.
- `counterPreparedInitializePostconditionOfStorageModel` — green under
  `lake build EvmRefinement`; a powdr proof that initialize writes
  `counterInitializeStorageWord` implies the prepared-frame initialize
  postcondition.
- `counterCompiledPowdr_safe_trace_simulates_after_initialize_from_prepared_storage_models`
  and `counterCompiledPowdr_safe_trace_simulates_from_state_safe_prepared_storage_models`
  — green under `lake build EvmRefinement`; compiled prepared-frame storage
  models imply the existing safe universal IR/powdr trace theorems.
- `counterInitializeStorageValue_of_sstore_stackMemFlow_ok` — green under
  `lake build EvmRefinement`; the final SSTORE helper branch writes the
  initialize storage model into Counter slot 0 when the dispatcher/body proof
  establishes the required stack shape.
- `counterStack_of_initialize_sload_and_or_ok` — green under
  `lake build EvmRefinement`; the SLOAD/AND/OR helper sequence forms the
  storage value that is later consumed by the SSTORE proof.
- `counterInitializeBodyWriteWord_eq_storageWord` and
  `counterStack_of_initialize_sload_and_or_storageWord_ok` — green under
  `lake build EvmRefinement`; the concrete initialize mask/set-value expression
  equals the storage model consumed by the SSTORE helper proof.
- `counterStack_of_initialize_prefix_to_sload_ok` — green under
  `lake build EvmRefinement`; the concrete initialize-body prefix constructs
  `counterCountSlot :: counterInitializeLowMask :: counterInitializeSetValue`
  before SLOAD.
- `counterStorageValue_of_initialize_sload_and_or_push_sstore_ok` — green under
  `lake build EvmRefinement`; the SLOAD/AND/OR result plus final PUSH0/SSTORE
  writes the initialize storage model into Counter slot 0.
- `just evm-bytecode-semantics-smoke` — green; checks the local powdr-target
  seam without importing powdr or mathlib.

## (g) RFC/doc update summary

- `docs/tier-c-proof-feasibility.md` Phase 6b: marked as powdr-target seam,
  with the old EVMYulLean mismatch retained as historical blocker/fallback.
- RFC 0014 Path 5b Phase 6b: status updated to powdr-target wired and Phase
  6b unblocked, cross-referencing this file.

## (h) Remaining proof boundary

The Counter relation now carries `count < 2^64` plus the generated high-64-bit
packed storage shape with low 192-bit padding allowed. The next relational
proof slice must decide how Phase 6c
handles `increment` at `2^64 - 1`: either the supported input predicate excludes
overflowing traces, or the total Counter IR semantics is changed to match the
compiled EVM runtime's checked/wrapping behavior. Until that is resolved, the
compiled-runtime C-diff can stay green, but the universal relational
per-entrypoint proof is not yet complete. The boundary is represented in Lean by
`counterTraceSafeFromCount` / `counterTraceSafeAfterInitialize`, including a
green safe trace check and an explicit unsafe max-u64 increment check. The
per-entrypoint obligation surface now also carries this boundary through
`CounterStepSafe`, and the safe trace theorem carries it through universal trace
induction. `CounterTraceSafeAtState` is the current state/input predicate form;
the remaining Phase 6c work is to prove the compiled runtime's prepared-frame
EVM-only powdr storage models, starting with the dispatcher/JUMPDEST path to the
proven initialize-body helper sequence and connecting that sequence to the
prepared-frame initialize storage model.
