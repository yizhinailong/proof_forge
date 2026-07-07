# FV Target-Semantics Task Plan — Solana sBPF + WASM Executable Trace

> **For agentic workers.** Recommended sub-skill: `superpowers:subagent-driven-development`
> — dispatch one fresh subagent per task, review between tasks. Every task below is
> self-contained and states, in order:
> **① Read first** (orientation) · **② Context to load** (files the agent must open) ·
> **③ Do** (the work) · **Acceptance** (how to know it's done) · **Depends on**.
>
> Rationale and the wider portfolio live in
> [docs/zh/execution-plan-2026-07.md](../../zh/execution-plan-2026-07.md) §7.
> This file is the executable task queue only.

## Background (all agents read once)

Build **in-Lean executable semantics** for two target VMs and check them against the
portable IR reference semantics (`ProofForge/IR/Semantics.lean`). This moves
`solana-sbpf-asm` and `wasm-near` from weak/external checks to **in-Lean differential
trace checks (Tier C-diff)**, then toward **refinement theorems (Tier C-proof)**. Tiers:
[docs/formal-verification.md](../../formal-verification.md).

**Both targets are the SAME shape** — machine state → `step` → fuel-bounded `run` →
simulation relation `R : IR.State ↔ MachineState` → `observe` → differential obligation
(`native_decide`) → refinement lemma (`induction`). Build the shared interface once
(**Task P1**), then instantiate per target. Do NOT build two bespoke interpreters.

**Key scheduling fact:** the C-diff obligations use `native_decide` (pointwise
evaluation), so they need only Task P1 — **not** the IR induction (P2). Tasks S1–S3 and
W1–W5 are therefore doable now; the C-proof tasks (S6/W6) are a later layer on P2.

**Non-goals (stay in external differential gates, do NOT model in Lean):**
Solana CPI / PDA derivation / account-validation prologue → Mollusk/Surfpool.
NEAR Promise / async / cross-contract → `runtime/offline-host` + wasmtime.

**Import vs self-build — do NOT over-scope the self-built targets.** The EVM lane and the
Solana/WASM lanes differ in one fundamental way:

- **EVM = import (do not write EVM semantics).** A Lean 4 EVM semantics already exists —
  `powdr-labs/evm-semantics` (Lean `v4.31.0`, toolchain-compatible; relational `Step` plus
  an executable `stepF`). Add it as an **opt-in lake dependency** and refine the IR against
  its relational `Step`. See
  [tier-c-proof-feasibility.md §2](../../tier-c-proof-feasibility.md).
- **Solana / WASM = self-build, but ONLY the fragment.** No off-the-shelf Lean semantics
  exists, so you write the interpreter (S1 / W2) — but **self-build ≠ reimplement the whole
  VM**. Model ONLY the instruction + host subset the lowering emits (ALU, storage,
  control-flow). The full VM (Solana CPI/PDA/syscalls/account-model; NEAR Promise/async)
  stays OUT, in the external gate (Non-goals above). It is a small, auditable fragment
  interpreter, not a chain runtime.

**Two-hop trust for self-built targets — the external differential gate stays forever.**
- Import (EVM): powdr's `Step` is conformance-tested against `ethereum/tests`, so "Lean
  model ≈ real EVM" is powdr's job; you prove ONE hop: IR ⟷ powdr `Step`.
- Self-build (Solana/WASM): you prove IR ⟷ your interpreter (pure Lean, no mathlib). But
  "your interpreter ≈ the real VM" is a SECOND hop that is **not** proven in Lean — it is
  checked by the external differential gate (Mollusk/Surfpool for sBPF, wasmtime /
  offline-host for Wasm). **Never delete or weaken that gate for a self-built target**; it
  is the only thing that catches a hand-written interpreter diverging from the real runtime.

Whether import or self-build, both plug into the SAME `TargetSemantics` interface (P1):
a relational `Step` (for the C-proof induction) + an executable `step` / `stepF` (for the
C-diff `native_decide`). Adopt powdr's dual relational+executable shape for the self-built
interpreters too.

## Task graph

```text
P1 (shared interface, LANDED) ──→ E1 (LANDED) → E2 (LANDED) → E3   (EVM C-proof via powdr — REFERENCE, do first)
                               ├→ S1 → S2 → S3 → S4 → S5   (Solana C-diff)
                               └→ W1 → W2 → W3 → W4 → W5   (WASM C-diff)
P2 (trace induction, landed generically) ─┬─→ S6 (Solana C-proof, copies E3)
                                          └─→ W6 (WASM C-proof, copies E3)
```

**EVM is the reference lane — do E1–E3 first.** EVM *imports* an external Lean semantics
(`powdr-labs/evm-semantics`), so its C-proof lands fastest and gives Solana/WASM a worked
template: S6/W6 copy E3's shape, swapping powdr's `Step` for the self-built
`SbpfInterpreter` / `WasmInterpreter` `Step`. **Already LANDED** (commits `4c4ec279`…`2fd6e9f6`):
P1 shared interface, the generic trace induction, and the EVM seam switched to powdr's
`State`/`Step`/`stepF` shape (`173b9d4f`, builds mathlib-free), plus E1's opt-in
`EvmRefinement` target pinned to powdr/mathlib and E2's real powdr-backed wrapper
surface. Remaining EVM work is E3.
(For the self-built lanes, start with **S1** or **W1**.)

---

## Task P1 — Shared `TargetSemantics` interface

- **① Read first:** `docs/formal-verification.md` (the three tiers, so you don't
  over-claim); this file's Background.
- **② Context to load:** the three copied obligation types —
  `ProofForge/Backend/Solana/Refinement.lean:38-57`,
  `ProofForge/Backend/WasmNear/Refinement/Core.lean:23-40`,
  `ProofForge/Backend/Evm/Refinement.lean:30-61`.
- **③ Do:** create `ProofForge/Backend/Refinement/Core.lean` holding ONE shared
  `ObservableReturn` / `ObservableStep` / `TraceObligation`, plus a `TargetSemantics`
  abstraction (a structure/class with: a `MachineState` type, `step`, fuel-bounded
  `run`, `observe : MachineState → ObservableReturn`, and an `executableTraceOk`
  differential runner). Migrate EVM/Solana/NEAR Refinement to import the shared types.
  Keep every existing theorem's truth value unchanged.
- **Acceptance:** `lake build` green; existing Refinement theorems still `#check`;
  `just check` passes; the three local `ObservableReturn` copies are gone.
- **Depends on:** none.

---

## EVM lane (E1–E3) — REFERENCE, do first (import `powdr-labs/evm-semantics`)

> EVM does NOT self-build semantics — it **imports** `powdr-labs/evm-semantics` (Lean
> `v4.31.0`, toolchain-compatible; relational `Step` + executable `stepF`). Facts +
> rationale: [tier-c-proof-feasibility.md §2](../../tier-c-proof-feasibility.md),
> [phase-6b-integration-blockers.md](../../phase-6b-integration-blockers.md). The seam
> `ProofForge/Backend/Evm/EvmBytecodeSemantics.lean` already mirrors powdr's
> `State`/`Step`/`stepF` and builds mathlib-free (commit `173b9d4f`). E1–E3 wire the real
> dependency and prove the first IR↔EVM refinement — the template S6/W6 then copy.

## Task E1 — Opt-in lake target for `powdr-labs/evm-semantics` + mathlib (LANDED)

- **① Read first:** `docs/phase-6b-integration-blockers.md` §(b) `require` syntax + §(d)
  resolution path #0 + "Recommended next action"; `docs/tier-c-proof-feasibility.md` §2.
- **② Context to load:** `lakefile.lean` (currently mathlib-free — verified); the seam
  docstring in `ProofForge/Backend/Evm/EvmBytecodeSemantics.lean` (lists the required
  `EvmSemantics.EVM.*` imports).
- **③ Do:** add a **separate opt-in lake target** (a distinct `lean_lib`, e.g.
  `EvmRefinement`, **not** in the default target graph) that `require`s
  `powdr-labs/evm-semantics` pinned to a **literal commit SHA** (+ transitive
  `mathlib @ v4.31.0`). Run `lake update` in a **network** environment; capture the pinned
  commit into `lake-manifest.json`. The default `lake build` / `just check` MUST stay
  mathlib-free and green.
- **Landed:** `lakefile.lean` pins powdr
  `ae13dbc506158f9d0c7e05634636b17e2bccf850`; `lake-manifest.json` records
  mathlib `fabf563a7c95a166b8d7b6efca11c8b4dc9d911f`; `EvmRefinement/PowdrAdapter.lean`
  imports powdr's `State`, `Step`, `StepF`, `BigStep`, and `Equiv` modules and wraps
  `EvmSemantics.EVM.stepF_sound`.
- **Acceptance:** default `lake build` unchanged (mathlib-free, green); the opt-in
  `EvmRefinement` target resolves and builds powdr + mathlib in a network env; the pinned
  commit is recorded in `lake-manifest.json`.
- **Depends on:** none — **but needs network + a long mathlib build.** This is the one
  heavy, environment-dependent task; run it where network and build time exist.

## Task E2 — Replace the EVM seam stubs with real powdr imports (LANDED)

- **② Context to load:** `ProofForge/Backend/Evm/EvmBytecodeSemantics.lean` (stub
  `State`/`Step`/`stepF`/`runBytecode` + the docstring import list: `EvmSemantics.EVM.State`
  / `Step` / `BigStep` / `StepF`).
- **③ Do:** under the opt-in target only, replace the stub bodies with imports from
  `EvmSemantics.EVM.*`, keeping the public surface and all `Refinement.lean` callers
  unchanged. Keep the mathlib-free stub as the default-build fallback (gate the real import
  behind the opt-in target so the default build never pulls mathlib).
- **Landed:** `EvmRefinement/PowdrAdapter.lean` now exposes real powdr-backed
  `State`, `Step`, `stepF : State → Except String State`, `step`, `isHalted`, and
  `runBytecode`. The `stepF` wrapper turns done-state calls into adapter errors, so
  `stepF_sound` can recover powdr's `¬ state.isDone` precondition and prove the real
  `EvmSemantics.EVM.Step`.
- **Acceptance:** opt-in target type-checks against the real powdr `State`/`Step`/`stepF`;
  default build still mathlib-free + green; no `Refinement.lean` theorem statement changes.
- **Depends on:** E1.

## Task E3 — First real IR↔EVM refinement (Counter, against powdr's `Step`)

- **① Read first:** `ProofForge/Backend/Refinement/CounterUniversal.lean` (the proof shape:
  per-entrypoint simulation + generic trace induction, currently against a toy `targetStep`);
  `docs/tier-c-proof-feasibility.md` §3 (the target-obligation shape).
- **② Context to load:** `CounterUniversal.lean` (`targetStep` / `counterModelTargetSemantics`
  — the toy to replace for EVM); the real powdr `Step` (from E2); the EVM storage layout
  (`ProofForge/Backend/Evm/Plan/Storage.lean`, for the `R` relation);
  `ProofForge/Backend/Evm/Refinement.lean`.
- **③ Do:** instantiate a `TargetSemantics` for EVM whose `Step` is powdr's relational
  `Step` over the compiled Counter; define `R : IR.State ↔ EvmSemantics.EVM.State` (IR
  `count` binding ↔ the storage slot from the EVM plan's layout); prove per-entrypoint
  simulation (`initialize`/`get`/`increment`) against powdr's `Step`; lift to the **universal**
  trace theorem via the already-landed generic induction. This is Phase 6c — the first
  universal (`∀` call list) **IR↔EVM-bytecode** refinement. Also confirm whether powdr
  exposes a **Yul-level** relation; if not, document the Yul→bytecode (`solc`) step as an
  explicit trust boundary (the §2 granularity caveat).
- **Progress:** `EvmRefinement/CounterRefinement.lean` now starts the E3 relation layer:
  it proves the ProofForge EVM layout maps Counter `count` to scalar slot 0, defines the
  IR `count` ↔ powdr `AccountMap`/`Storage` relation over the generated EVM
  packed U64 slot shape: `count` occupies the high 64 bits and the low 192 bits
  are padding/other-packed-field space, with `count < 2^64`. This corrected the
  earlier raw-`UInt256.ofNat count` relation, and later corrected the too-strong
  canonical whole-word equality relation, neither of which matches the compiled
  runtime's `get`/write behavior. It also defines selector calldata plus
  `prepareCounterCall`, a runtime-bytecode-parameterized powdr frame setup for Counter
  calls, and proves that preparation preserves `CounterStorageRel`. It also embeds the
  current CLI-generated Counter runtime bytecode as `counterCompiledRuntimeCode`, proves
  its size and selector offsets, exposes `counterCompiledPowdrConfig`, and adds the
  opt-in `just evm-powdr-counter-runtime` drift gate. The compiled-runtime path also
  exposes `counterCompiledPowdrTargetSemantics` and
  `counterCompiledPowdr_trace_simulates_after_initialize_from_obligations`, so the next
  proof obligation is specialized to the real Counter runtime witness. The module also
  defines `counterBaseEvmState` and native executable smokes for `initialize`, `get`, and
  `initialize; increment; get`; those are C-diff witnesses over powdr's executable driver,
  not substitutes for the pending relational per-entrypoint proof. The concrete compiled
  target's `executableTraceOk` now consumes Counter `TraceObligation`s through the
  compiled runtime and proves the initialize-get-increment-get trace with
  `counterCompiledPowdr_executable_trace_ok`. Prepared calls now normalize a fresh
  top-level EVM frame (gas/header/fork/caller/pc/stack/halt) while preserving storage, so
  the relation is not accidentally blocked by stale halted frames or zero-gas defaults.
  Packed-storage smokes show `get` reads packed `7` as `7`, `get` also reads a
  padded high-bit `7` as `7`, `initialize; get` returns `0` from a padded slot,
  and `increment; get` reaches `8`. It now exposes
  `counterPowdrTraceStep` / `counterPowdrTargetSemantics`, which run prepared Counter
  calls through powdr `runBytecode`, project EVM results to Counter observables, and prove
  successful trace steps are backed by powdr `Steps` with the stated observable projection;
  compiled-runtime C-diff is green, while the relational per-entrypoint obligations still
  need to be discharged. It also defines explicit
  `CounterPowdrEntrypointObligations` for `initialize`/`increment`/`get` and proves
  `counterPowdr_trace_simulates_from_obligations`: those three powdr bytecode obligations
  are sufficient to obtain the universal Counter trace simulation through the shared
  induction. `initialize` is now modeled as the relation-establishing entrypoint, so
  `counterPowdr_trace_simulates_after_initialize_from_obligations` proves universal
  `initialize :: calls` traces from arbitrary IR/EVM starting states once the same three
  per-entrypoint obligations hold.
  The newly explicit `count < 2^64` side condition is the next proof boundary: an
  unbounded IR `u64` Nat increment at `2^64 - 1` will not match the compiled EVM runtime
  unless the supported fragment/input predicate excludes overflow or the IR Counter
  semantics is changed to the same checked/wrapping behavior. That boundary is now
  represented in Lean by `counterTraceSafeFromCount` /
  `counterTraceSafeAfterInitialize`, with native checks for the normal
  initialize-get-increment-get trace and for the unsafe max-u64 increment case.
  The per-entrypoint obligation surface now has a safe variant:
  `CounterStepSafe`, `CounterPowdrSafeEntrypointObligations`, and
  `counterPowdr_safe_step_simulates_from_obligations` thread the bounded
  `increment` precondition into the EVM step proof instead of leaving overflow
  as an implicit side condition. `counterPowdr_safe_trace_simulates_from_obligations`
  and `counterPowdr_safe_trace_simulates_after_initialize_from_obligations` then
  lift that safe side condition through the universal trace induction, with a
  compiled-runtime specialization exposed by
  `counterCompiledPowdr_safe_trace_simulates_after_initialize_from_obligations`.
  `CounterTraceSafeAtState` and
  `counterCompiledPowdr_safe_trace_simulates_from_state_safe_obligations` expose
  the same boundary as a state/input predicate, which is the shape needed for a
  later SupportedFragment gate. `CounterPowdrEvmPostconditions` and
  `counterPowdrSafeEntrypointObligationsOfPostconditions` further isolate the
  remaining powdr work: prove the compiled runtime's EVM-only storage
  postconditions for `initialize`/safe `increment`/`get`, and the safe
  per-entrypoint obligations follow. That surface is now split once more into
  prepared-frame obligations:
  `CounterPowdrPreparedEvmPostconditions` proves the bytecode facts on states
  already produced by `prepareCounterCall`, and
  `counterPowdrEvmPostconditionsOfPrepared` bridges those facts back to the
  arbitrary pre-state wrapper used by `counterPowdrTraceStep`. For initialize,
  `counterInitializeStorageWord` models the compiled body as "clear the high
  64-bit count field, preserve low 192-bit padding", and
  `counterPreparedInitializePostconditionOfStorageModel` turns that storage
  model into the prepared-frame initialize postcondition.
  `CounterPowdrPreparedStorageModels` now names that exact prepared-frame
  storage-model surface and `counterCompiledPowdr_safe_trace_simulates_*_prepared_storage_models`
  connect it directly to the compiled-runtime safe universal trace theorems.
  The SSTORE-side storage projection lemma
  `counterStorageValue_accountMap_set_storage_same` is also available for the
  eventual opcode case proof, and
  `counterInitializeStorageValue_of_sstore_stackMemFlow_ok` proves that a
  successful powdr `SSTORE` helper step with the initialize model value on top
  of the stack writes exactly that model into Counter slot 0.
  `counterStack_of_initialize_sload_and_or_ok` composes the powdr `SLOAD`,
  `AND`, and `OR` helper steps and proves the value presented to SSTORE is
  `lor (land oldWord mask) setValue`, matching the initialize-body shape.
  `counterInitializeSetValue_eq_zero`, `counterInitializeLowMask_eq`,
  `counterInitializeBodyWriteWord_eq_storageWord`, and
  `counterInitializeBodyWriteWord_rel_zero` now prove the concrete initialize
  body expression clears the high 64-bit count field while preserving the low
  192-bit padding, exactly matching `counterInitializeStorageWord`.
  `counterStack_of_initialize_sload_and_or_storageWord_ok` specializes the
  SLOAD/AND/OR helper sequence to those concrete constants and returns the
  storage model value on top of the stack.
  `counterStack_of_initialize_prefix_to_sload_ok` now proves the initialize-body
  prefix (`PUSH0`, `PUSH1`, `DUP1`, `SHL`, `SUB`, `NOT`) constructs the exact
  `counterCountSlot :: counterInitializeLowMask :: counterInitializeSetValue`
  stack consumed by SLOAD.
  `counterStorageValue_of_initialize_sload_and_or_push_sstore_ok` stitches
  SLOAD/AND/OR through the final `PUSH0; SSTORE` and proves the resulting state
  writes the initialize storage model into Counter slot 0.
  `counterStorageValue_of_initialize_body_helpers_ok` now composes the complete
  initialize-body helper sequence from the prefix through SSTORE and proves it
  writes `counterInitializeStorageWord`.
  `counterCompiledRuntimeCode_decodes_initialize_first_push0`,
  `counterPreparedInitializeFirstPush0_decoded`, and
  `counterStack_of_stepFE_push0_ok` start the dispatcher-to-helper bridge by
  proving the compiled initialize body's first post-`JUMPDEST` opcode decodes
  as `PUSH0` and that top-level `stepFE` has the same stack effect as the
  helper. The bridge now also has `stepFE` stack-effect lemmas for `PUSH1`,
  `DUP1`, `SHL`, `SUB`, and `NOT`, plus compiled-runtime decode facts for the
  initialize prefix opcodes through the mask-building `NOT`.
  `counterCompiledStateAt`, the `counterPreparedInitialize*_decoded` lemmas,
  and `counterCompiledRuntimeCode_decodes_initialize_sload_slot_push0` extend
  those decode facts to prepared-like states through the final slot `PUSH0`;
  `counterStack_of_initialize_prefix_stepFE_to_sload_ok` now composes the
  top-level `stepFE` prefix path and proves it reaches the exact stack consumed
  by `SLOAD`. The bridge also now covers the initialize tail:
  `counterStack_of_stepFE_stackMemFlow_sload_ok`,
  `counterStack_of_stepFE_compBit_and_ok`,
  `counterStack_of_stepFE_compBit_or_ok`,
  `counterStorageValue_of_stepFE_stackMemFlow_sstore_ok`,
  `counterStack_of_stepFE_stackMemFlow_sstore_ok`, tail decode facts through
  `SSTORE`, `counterStorageValue_of_initialize_tail_stepFE_ok`, and
  `counterStack_of_initialize_tail_stepFE_ok` prove the top-level `stepFE`
  SLOAD/AND/OR/PUSH0/SSTORE sequence writes the initialize storage model value
  and preserves the return-address/selector stack tail needed by the final
  return path. The initialize trampoline is bridged too:
  `counterCompiledRuntimeCode_decodes_initialize_trampoline_*`,
  `counterPreparedInitializeTrampoline*_decoded`,
  `counterState_of_stepFE_stackMemFlow_jumpdest_ok`,
  `counterState_of_stepFE_stackMemFlow_jump_ok`,
  `counterState_of_initialize_trampoline_stepFE_to_body_ok`, and
  `counterState_of_initialize_body_jumpdest_stepFE_to_first_opcode_ok` prove the
  top-level `stepFE` trampoline lands at the initialize body and then advances
  to the first body opcode while preserving the return address stack shape.
  The initialize selector dispatcher is now pinned at the bytecode/prepared-state
  layer too: `counterCompiledRuntimeCode_decodes_dispatcher_*` facts cover
  offsets 0, 1, 2, 4, 5, 6, 11, 12, and 14 (`PUSH0; CALLDATALOAD; PUSH1 224;
  SHR; DUP1; PUSH4 initialize-selector; EQ; PUSH1 trampoline; JUMPI`),
  `counterPreparedDispatcher*_decoded` lifts those facts to
  `counterCompiledStateAt`, and
  `counterState_of_dispatcher_first_push0_stepFE_to_calldataload_ok` proves the
  first top-level dispatcher `stepFE` advances from PC 0 to the `CALLDATALOAD`
  opcode with selector offset 0 on the stack. The dispatcher bridge now also
  has `counterState_of_stepFE_env_calldataload_ok`,
  `counterState_of_stepFE_compBit_shr_ok`, and
  `counterState_of_stepFE_compBit_eq_ok` generic state lemmas, a taken-branch
  `counterState_of_stepFE_stackMemFlow_jumpi_taken_ok`, concrete initialize
  calldata selector facts, and the path theorems
  `counterState_of_dispatcher_calldataload_stepFE_to_shift_push_ok`,
  `counterState_of_dispatcher_selector_shift_push_stepFE_to_shr_ok`, and
  `counterState_of_dispatcher_selector_shr_stepFE_to_dup_ok`. The tail is
  bridged too:
  `counterState_of_dispatcher_selector_dup_stepFE_to_selector_push_ok`,
  `counterState_of_dispatcher_initialize_selector_push_stepFE_to_eq_ok`,
  `counterState_of_dispatcher_initialize_eq_stepFE_to_trampoline_push_ok`,
  `counterState_of_dispatcher_trampoline_push_stepFE_to_jumpi_ok`, and
  `counterState_of_dispatcher_initialize_jumpi_stepFE_to_trampoline_ok` prove
  the concrete initialize dispatcher reaches the initialize trampoline
  `JUMPDEST` with the selector left on the stack.
  `counterState_of_dispatcher_trampoline_stepFE_to_initialize_first_opcode_ok`
  now composes the dispatcher path, trampoline path, and initialize-body
  `JUMPDEST`, reaching the first initialize body opcode with the return address
  and selector stack shape preserved.
  `counterStorageValue_of_initialize_body_stepFE_from_first_opcode_ok` composes
  the first initialize body opcode through the prefix and SLOAD/AND/OR/PUSH0/SSTORE
  tail, proving the concrete `stepFE` body writes `counterInitializeStorageWord`
  relative to the SLOAD-state storage word. Its companion
  `counterStack_of_initialize_body_stepFE_from_first_opcode_ok` proves the same
  body path preserves the return-address/selector stack tail for the final
  return path.
  `counterCompiledPreparedInitialize_entry_facts` records the compiled prepared
  initialize frame's PC0/code/fork, empty stack, initialize calldata, and
  contract address facts needed to instantiate the composed path from a real
  `CounterPreparedCall`.
  The final return segment is now bridged at `stepFE` level:
  `counterCompiledRuntimeCode_decodes_initialize_body_return_jump`,
  `counterCompiledRuntimeCode_valid_initialize_return_jumpdest`, the
  `counterCompiledRuntimeCode_decodes_initialize_return*` facts,
  `counterPreparedInitializeReturn*_decoded`,
  `counterState_of_stepFE_system_return_empty_ok`, and
  `counterState_of_initialize_return_stepFE_to_returned_empty_ok` cover the body
  final `JUMP` plus `JUMPDEST; PUSH0; DUP1; RETURN` and prove the resulting
  frame halts with `Returned ByteArray.empty` while preserving Counter storage.
  `counterInitializeObservable_of_returned_empty` maps that result to the
  Counter `initialize` observable `.none`.
  `counterInitializeReturn_preserves_storage_model_stepFE_ok` packages those
  facts as the final return-path bridge: once the body has established the
  initialize storage model at the return jump, the halted frame keeps that model
  and exposes the `.none` observable.
  `EvmRefinement/PowdrAdapter.lean` also proves `runBytecode_steps`: every successful
  fuel-bounded executable run is backed by powdr's relational `Steps` closure.
  The adapter now has `runBytecode_halted_succ` and `runBytecode_step_succ`,
  and `CounterRefinement.lean` adds
  `counterPowdrAdapter_stepF_of_stepFE_ok` plus
  `counterRunBytecode_stepFE_succ`, so the composed `stepFE` path can be fed
  into the prepared-frame `runBytecode` driver one opcode at a time.
  `counterRunBytecode_initialize_return_segment_ok` applies that bridge to the
  final return segment, proving 5 fuel steps from the body return jump reach the
  halted return frame. `counterRunBytecode_initialize_body_and_return_ok`
  composes the body path with that return segment: from the first initialize
  body opcode, 22 fuel steps reach the halted frame, preserve the initialize
  storage model, and expose the `.none` observable.
  `counterStack_of_initialize_tail_stepFE_to_sstore_ok` and
  `counterStack_of_initialize_body_stepFE_to_sstore_ok` now expose the
  pre-SSTORE stack shape consumed by
  `counterCompiledStateAt_of_initialize_sstore_stepFE_ok`, so the 22-fuel body
  bridge derives the body-return-jump `counterCompiledStateAt` fact internally
  instead of carrying it as an explicit premise.
  `counterRunBytecode_initialize_dispatcher_body_and_return_ok` now prepends
  the initialize selector dispatcher plus trampoline path to that body+return
  bridge, proving a 36-fuel `runBytecode` path from PC0 to the halted `.none`
  result while preserving the initialize storage model. The next slice should
  lift that exact 36-step path through the compiled config's 5000-fuel
  `counterPowdrPreparedTraceStep` and instantiate the prepared-frame initialize
  storage model. The pinned
  powdr tree has no Yul-level semantics module, so ProofForge's Yul→bytecode `solc` hop
  remains an explicit trust boundary. The remaining E3 work is to discharge those
  prepared-frame storage models against the concrete runtime by connecting the
  composed dispatcher/trampoline/body `stepFE` path to the prepared-frame
  `counterPowdrPreparedTraceStep` result and instantiating the prepared-frame
  initialize storage model.
- **Acceptance:** a universally-quantified refinement theorem (IR Counter ⟷ powdr EVM
  `Step`, by `induction`, **not** `native_decide`) type-checks under the opt-in target;
  `docs/formal-verification.md` EVM Tier C-proof row updated from aspirational/blocked to
  "Counter refinement against powdr (opt-in)".
- **Depends on:** E1, E2, P1 (landed), generic trace induction (landed).

**Then Solana/WASM copy E3.** S6/W6 mirror E3's per-entrypoint-simulation + induction shape,
swapping powdr's `Step` for the self-built `SbpfInterpreter` / `WasmInterpreter` `Step` — no
external dependency, but the external differential gate stays (Background "Two-hop trust").

## Task S1 — sBPF interpreter (state + step)

- **① Read first:** `docs/solana-sbpf-executable-trace.md` — the FULL design (machine
  state, opcode subset, dispatch, observable projection, phasing). Follow it exactly.
- **② Context to load:** `ProofForge/Backend/Solana/Asm.lean`
  (`Reg`/`Imm`/`MemOff`/`Opcode`/`Inst`/`AstNode` + the `Opcode.isLoad/isStore/...`
  helpers); `ProofForge/Backend/Solana/SbpfAsm.lean` (`lowerModule : Module → Except _
  (Array AstNode)` — its output is what you interpret).
- **③ Do:** create `ProofForge/Backend/Solana/SbpfInterpreter.lean`. Define `SbpfState`
  (regs, stack, entryR0, pc). Build a label table + `equDecl` symbol table by a pre-pass
  over the `AstNode` array. Implement `step` for the Counter opcode subset
  (`mov64/add64/sub64/mul64/lsh64`, `lddw`, `ldxdw`, `stxdw`, `ja/jeq/exit`, and a
  storage read/write **syscall stub** only). Implement a **fuel-bounded** `run` (total;
  over-budget = interpreter error, not a hang). Uncovered syscalls/opcodes = error.
- **Acceptance:** a `#check`-only smoke that the interpreter runs the lowered Counter
  entrypoints to `exit` with no error.
- **Depends on:** P1 (for `ObservableReturn`).

## Task S2 — sBPF differential obligation

- **② Context to load:** the interpreter from S1;
  `ProofForge/Backend/Solana/Refinement.lean` (`counterTraceObligation`,
  `ObservableReturn`).
- **③ Do:** add `TraceObligation.sbpfExecutableTraceOk` (run interpreter over
  `lowerModule` output, project `observe`, compare to `expected`) and
  `theorem counter_sbpf_executable_trace_ok := by native_decide`. **Delete the
  bare-substring branch** in `hasEntrypointDispatch` (`Refinement.lean:119-123`) — the
  executable check supersedes it. Update the `solana-sbpf-asm` Tier C-diff row in
  `docs/formal-verification.md` from "artifact-surface only" to "executable-trace
  (Counter subset)".
- **Acceptance:** `just solana-light` runs the new theorem locally with no
  `sbpf`/`surfpool`; `just check` green.
- **Depends on:** S1, P1.

## Task S3 — sBPF simulation relation `R`

- **② Context to load:** `ProofForge/Backend/Solana/StateLayout.lean`
  (`computeInputLayout`, `AccountInputLayout`, account-data offsets);
  `ProofForge/IR/Semantics.lean` (`State`).
- **③ Do:** define `R : IR.State ↔ SbpfState` mapping the IR scalar binding to the U64
  at the account-data offset given by `StateLayout` (Slice A: one U64 scalar). State
  pointwise theorems that `R` holds on the Counter scenario after `initialize` and after
  `increment` (`native_decide` is fine — this is C-diff, not C-proof).
- **Acceptance:** `R`-holds theorems for the Counter scenario `#check` and pass.
- **Depends on:** S1.

## Task W1 — WASM executable-trace design note (docs only)

- **① Read first:** `docs/solana-sbpf-executable-trace.md` (you are mirroring it);
  `ProofForge/Backend/WasmNear/Refinement/Core.lean` (existing `WasmTraceOp` extraction +
  offline-host obligations); `runtime/offline-host/src/main.rs` (the EXTERNAL semantics
  you will reproduce in-Lean).
- **② Context to load:** `ProofForge/Compiler/Wasm/AST.lean`;
  `ProofForge/Backend/WasmNear/Layout.lean`; `ProofForge/Target/HostBridge.lean`.
- **③ Do:** write `docs/wasm-executable-trace.md` mirroring the Solana note: scope the
  Wasm stack-machine subset (value stack, locals, linear memory), the abstract host model
  (HostBridge functions over an abstract host state), the `R` bridge via `Layout.lean`,
  the phasing (Counter → ValueVault → maps), and the non-goals (Promise/async →
  offline-host). Pure docs, no code.
- **Acceptance:** reviewed note; same section structure as the Solana note; registered in
  `docs/INDEX.md` and (if in the i18n manifest) a zh mirror plan noted.
- **Depends on:** none.

## Task W2 — Wasm interpreter (state + step)

- **① Read first:** `docs/wasm-executable-trace.md` (W1).
- **② Context to load:** `ProofForge/Compiler/Wasm/AST.lean` (`WasmInsn`/`WasmBlock`/
  `WasmFunc`); `ProofForge/Backend/WasmNear/Refinement/Core.lean` (`WasmTraceOp`,
  `wasmInsnTraceOps` — reuse as the instruction enumeration); `ProofForge/Backend/
  WasmNear/EmitWat.lean` (what is actually emitted for Counter).
- **③ Do:** create `ProofForge/Backend/WasmNear/WasmInterpreter.lean`. `WasmState` (value
  stack, locals, linear-memory bytes, abstract host state). `step`/`eval` over the emitted
  subset (`i64.const/add/sub/mul`, `local.get/set/tee`, `i64.load/store`,
  `block/loop/br/br_if/if/call/return`). Fuel-bounded.
- **Acceptance:** `#check` smoke that the interpreter runs the emitted Counter functions.
- **Depends on:** P1, W1.

## Task W3 — Wasm host model (HostBridge-parameterized)

- **② Context to load:** `ProofForge/Target/HostBridge.lean` (`requiredImports`,
  `hostFunctions`); `runtime/offline-host/src/main.rs` (reference behavior);
  `ProofForge/Backend/WasmNear/Layout.lean`.
- **③ Do:** model the HostBridge host functions (`storage_read`/`storage_write`,
  `value_return`, register ABI, `signer_account_id`, `attached_deposit`) as pure
  transitions over the abstract host state. **Parameterize by `HostBridge`** so
  CosmWasm/Soroban reuse it later (this is the FV counterpart of the W0 EmitWat
  unification in execution-plan §2.2).
- **Acceptance:** host calls in the Counter trace resolve against the model; a
  storage read-after-write returns the written value.
- **Depends on:** W2.

## Task W4 — WASM differential obligation

- **③ Do:** add `wasmExecutableTraceOk` + `native_decide` theorem, running the
  interpreter **in-Lean** (so this check no longer relies on the external Rust
  offline-host). Update the `wasm-near` Tier C-diff row in `docs/formal-verification.md`.
- **Acceptance:** the NEAR Lean gate runs the new theorem in-Lean; `just check` green.
- **Depends on:** W2, W3, P1.

## Task W5 — Wasm simulation relation `R`

- **② Context to load:** `ProofForge/Backend/WasmNear/Layout.lean` (Borsh key derivation).
- **③ Do:** define `R : IR.State ↔ Wasm host storage`; state pointwise theorems it holds
  on the Counter scenario after each entrypoint.
- **Acceptance:** `R`-holds theorems `#check` and pass.
- **Depends on:** W2, W3.

## Later tasks — C-proof layer (after P2) and deeper slices

These are lower-priority; they build on the C-diff tasks above.

- **P2 — trace induction:** landed in `ProofForge/IR/StepSemantics.lean`
  (`IRTraceMatches`, `runTraceListGen_sound`, proven by induction) and generalized over
  arbitrary target machine states. `ProofForge/Backend/Refinement/Core.lean` now also
  provides `traceSimulation_lift`, the reusable S6/W6 induction lemma: if every atomic
  IR/target call preserves `R` and emits the same observable, then the whole call list
  emits the same observable array. `CounterUniversal.lean` instantiates this as
  `counter_trace_simulates_all_related_via_framework`. The same core module now also
  provides `executableStepSimulationOk_sound` and `executableSimulationTraceOk_sound`,
  which convert concrete paired-step executable checks into Lean evidence for one
  entrypoint or a concrete call list.
- **S6 / W6 — refinement lemmas:** per-entrypoint simulation
  `R s s' → R (stepIR …) (runTarget …)`, then apply `traceSimulation_lift` to get
  whole-trace equality by induction over the call list. The shared lift is landed, and
  both real target runners now have Counter entrypoint-level paired-step soundness checks
  for the concrete `initialize`/`get`/`increment` prefixes, plus whole-trace checks:
  `counter_sbpf_trace_simulation_sound_checked` and
  `counter_wasm_trace_simulation_sound_checked`. The remaining target-specific work is
  to replace these pointwise entrypoint checks with universally quantified
  per-entrypoint simulation lemmas for the sBPF and Wasm interpreters.
  Depends on P1 + P2 + (S3 / W5).
- **S4 / S5 — Solana deeper slices:** ValueVault multiple scalar slots (S4), then
  maps/arrays by porting the IR storage-slot model to sBPF scratch memory (S5).
- **WASM deeper slices:** ValueVault, then maps — mirror S4/S5 using `Layout.lean`.

---

## How to hand a task to a subagent (answers "①去看什么 / ②给它看什么 / ③让它做什么")

For each task, give the subagent exactly its three fields:
1. **① Read first** → the orientation docs (so it understands the tier framing and the
   design note before touching code).
2. **② Context to load** → the concrete files (with line ranges) it must open.
3. **③ Do + Acceptance** → the imperative work and the pass condition (a `just` recipe or
   a `lake env lean --run Tests/…` line).

Dispatch one subagent per task via `superpowers:subagent-driven-development`; review the
diff between tasks. **First moves:** `P1` (unblocks both C-diff lanes) or `W1` (pure docs).
