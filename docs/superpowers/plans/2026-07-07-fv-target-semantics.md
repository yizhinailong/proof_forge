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
P1 (shared interface) ─┬─→ S1 → S2 → S3 → S4 → S5   (Solana C-diff)
                       └─→ W1 → W2 → W3 → W4 → W5   (WASM C-diff)
P2 (trace induction, landed generically in IR/StepSemantics.lean) ─┬─→ S6 (Solana C-proof)
                                                                   └─→ W6 (WASM C-proof)
```

Start with **P1** (unblocks both lanes) or **W1** (pure docs, zero code risk).

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
  provides `executableSimulationTraceOk_sound`, which converts a concrete paired-step
  executable check into Lean evidence of matching observable arrays plus final relation.
- **S6 / W6 — refinement lemmas:** per-entrypoint simulation
  `R s s' → R (stepIR …) (runTarget …)`, then apply `traceSimulation_lift` to get
  whole-trace equality by induction over the call list. The shared lift is landed, and
  both real target runners now have the first Counter paired-step soundness checks:
  `counter_sbpf_trace_simulation_sound_checked` and
  `counter_wasm_trace_simulation_sound_checked`. The remaining target-specific work is
  to replace these fixed-trace paired checks with real per-entrypoint simulation lemmas
  for the sBPF and Wasm interpreters.
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
