# Phase 6b — EVM semantics target switch and integration blockers

Status: **preferred target switched to `powdr-labs/evm-semantics`; opt-in target and wrapper landed, default seam still stubbed.**
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

- `ProofForge/Backend/Evm/EvmBytecodeSemantics.lean` (new/updated) — stub
  adapter with the public surface (`State`, `Step`, `stepF`, `step`,
  `runBytecode`) aligned to the powdr target shape and
  `Refinement.ObservableStep`, `sorry`-free stub theorems (`stepF_sound`,
  `step_noop`, `runBytecode_empty`), and a module docstring recording the
  target switch.
  Compiles with NO external dependency (imports only
  `ProofForge.Backend.Evm.Refinement`).
- `docs/phase-6b-integration-blockers.md` (new/updated — this file).
- `docs/tier-c-proof-feasibility.md` (modified) — Phase 6b section marked
  "blocked — seam only (2026-07-07)" with a one-paragraph note.
- `docs/rfcs/0014-unified-semantic-lowering-contract.md` (modified) —
  Path 5b Phase 6b status updated to "blocked — seam only".
- `docs/zh/rfcs/0014-unified-semantic-lowering-contract.zh.md` (modified)
  — Path 5b Phase 6b status updated (zh translation sync).
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
  slot 0, embeds the current CLI-generated Counter runtime bytecode witness,
  proves its selector offsets, exposes the compiled-runtime powdr config, and
  specializes the initialize-prefixed trace theorem to that concrete runtime
  target. It also defines a high-gas top-level `counterBaseEvmState` and native
  executable smokes for the compiled runtime; those are C-diff witnesses, not
  the pending relational per-entrypoint proof.
- `scripts/evm/powdr-counter-runtime-smoke.sh` + `just evm-powdr-counter-runtime`
  — opt-in drift gate that regenerates the Counter runtime and checks it still
  matches the embedded powdr witness.
- `ProofForge/Backend/Evm/Refinement.lean` — **NOT modified** (no theorem
  touched; wiring is Phase 6c).
- `ProofForge/IR/StepSemantics.lean` — **NOT modified** (Phase 6a
  invariant preserved).

## (f) Verification

- `lake build ProofForge.Backend.Evm.EvmBytecodeSemantics` — green (the
  stub module compiles with no external dependency; only imports
  `ProofForge.Backend.Evm.Refinement` which already builds).
- `lake build proof-forge` — green; default target does not build powdr/mathlib.
- `lake build EvmRefinement` — green; builds the opt-in powdr/mathlib adapter
  target.
- `just evm-powdr-counter-runtime` — green; generated Counter runtime matches
  the embedded powdr witness.
- `counterCompiledPowdr_initialize_executable_smoke`,
  `counterCompiledPowdr_get_zero_executable_smoke`, and
  `counterCompiledPowdr_initialize_increment_get_executable_smoke` — green
  under `lake build EvmRefinement`.
- `just evm-bytecode-semantics-smoke` — green; checks the local powdr-target
  seam without importing powdr or mathlib.

## (g) RFC/doc update summary

- `docs/tier-c-proof-feasibility.md` Phase 6b: marked as powdr-target seam,
  with the old EVMYulLean mismatch retained as historical blocker/fallback.
- RFC 0014 Path 5b Phase 6b: status updated to the powdr target switch and
  opt-in mathlib isolation plan, cross-referencing this file.
