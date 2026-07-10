# Solana sBPF ↔ solanalib Bridge (Scheme 1 + Scheme 2 Phase A/B)

Status: **landed skeleton** (2026-07) — mathlib-free encode + labeled view +
opt-in solanalib lift/decode + CompileCorrect pipeline anchors.

**Portable IR is mandatory.** See
[portable-ir-semantics-anchor.md](portable-ir-semantics-anchor.md). This bridge
never bypasses `IR.Module` / `IR.Semantics`.

## Goal

Hook ProofForge's EmitSBPF output into
[`solana-foundation/leanprover-solanalib`](https://github.com/solana-foundation/leanprover-solanalib)
for **post-hoc** verification, without changing the product emit path
(`IR → AstNode → .s → sbpf → ELF`).

This is the Solana counterpart of the EVM `EvmRefinement` / powdr adapter:

| Lane | Default (mathlib-free) | Opt-in (external semantics) |
|------|------------------------|-----------------------------|
| EVM | `EvmBytecodeSemantics` | `EvmRefinement` → powdr `stepF` |
| Solana | `BpfEncode` + `LabeledSbpf` + `SbpfInterpreter` | `SolanaRefinement` → solanalib lift / `bpfInterp` / `verifyInstr` |

## Architecture

```
Portable IR.Module  (+ IR.Semantics — multi-chain source of truth)
   │ SbpfAsm.lowerModule
   ▼
Array AstNode  ──render──►  .s text  ──sbpf──►  ELF   (product path, unchanged)
   │
   │ LabeledSbpf.fromNodes       ← Scheme 2 Phase A (labeled register asm)
   ▼
LabeledProgram / ResolvedInst[]
   │ BpfEncode.toBpfBin          ← default path, no mathlib
   ▼
BpfBinBytes (Array Nat)
   │
   ├─ SolanalibAdapter.toBpfBin + decodeAll     ← byte path
   │
   └─ LabeledToSolanalib.liftSlots              ← Scheme 2 Phase B (direct lift)
         ▼
List BpfInstruction
   │ verifyInstr  (+ step_ne_err)
   │ bpfInterp    (host bridge still open)
   ▼
BpfState
```

## What landed

| Piece | Module | Gate |
|-------|--------|------|
| Binary encoder | `ProofForge/Backend/Solana/BpfEncode.lean` | `just solana-bpf-encode-smoke` |
| Labeled sBPF view | `ProofForge/Backend/Solana/LabeledSbpf.lean` | same |
| Unit + Counter/ValueVault encode | `Tests/Backend/Solana/SolanaBpfEncode.lean` | same |
| solanalib adapter | `SolanaRefinement/SolanalibAdapter.lean` | `just solana-solanalib-adapter` |
| Direct lift ResolvedInst→BpfInstruction | `SolanaRefinement/LabeledToSolanalib.lean` | same |
| Host bridge (Counter core-tail) | `SolanaRefinement/HostBridge.lean` | same |
| CompileCorrect sketch | `SolanaRefinement/CompileCorrect.lean` | same |
| Smoke entry | `SolanaRefinement/CompileCorrectSmoke.lean` | same |
| IR semantics anchor note | `docs/portable-ir-semantics-anchor.md` | docs |

### Encode conventions

- Instruction layout matches solanalib `findInstr` (8-byte slots; `lddw` = 16).
- Jump offsets are **relative** slot deltas `target - (pc + 1)`.
- Label PCs are remapped from ProofForge instruction indices to **slot**
  indices so `lddw` (2 slots) does not desync relative jumps.
- Stack-relative mem ops (`base = r10`) encode offset as **negative i16**
  (AST stores a positive distance; the text printer already shows `[r10-off]`).
- Syscall `call` immediates use a fixed murmur3-32 table for the covered
  fragment (`sol_set_return_data`, `sol_log_64_`, clock, …).

## Honest claims (Tier language)

Use the tiers in [formal-verification.md](formal-verification.md):

- **Tier C-diff (encode):** Counter/ValueVault lower to well-formed bytecode
  (`moduleEncodesOk`, `native_decide`).
- **Tier C-diff (labeled):** labeled view builds and matches encode
  (`moduleLabeledOk`, `labeledMatchesEncode`).
- **Tier C-diff (solanalib pipeline):** encoded Counter bytes decode under
  solanalib and pass `verifyInstr` v1 (`counter_solanalib_pipeline_ok`).
- **Tier C-diff (direct lift):** `liftResolved` instruction list equals
  `decodeAll ∘ encode` and verifies (`counter_lift_matches_decode`).
- **Tier C-diff (host bridge):** Counter core-tail programs
  (`initialize` / `increment` without account prologue or syscalls) run on a
  solanalib `step` driver with word↔byte memory bridge; success `r0` and
  `countOff` word match ProofForge core-tail finals
  (`counter_core_tail_bridge_ok`).
- **Structural re-export:** `verified_instr_step_ne_err` names solanalib
  Lemma 6.4 (`step_ne_err`) for ProofForge-facing proofs.
- **Not claimed:** full `IR.Semantics ⇝ bpfInterp` simulation on the complete
  EmitSBPF program; Solana account-input layout; syscall host
  (`sol_set_return_data`, …). Those remain on `SbpfInterpreter` +
  Mollusk/Pinocchio. Product path still emits text via EmitSBPF.

## Build / CI

```bash
# Default path (no solanalib download beyond existing deps)
just solana-bpf-encode-smoke

# Opt-in (pulls solanalib + mathlib; mirrors just evm-powdr-adapter)
just solana-solanalib-adapter
```

`solana-solanalib-adapter` is **not** on the required `just product` /
`just check` path (same policy as `evm-powdr-adapter`).

## Next work (still from Portable IR)

1. ~~Host bridge for Counter core-tail~~ ✅ (`HostBridge.lean`).
2. Extend host bridge to full EmitSBPF Counter entrypoints (account prologue +
   `sol_set_return_data` registry stubs).
3. Differential gate on full traces: `SbpfInterpreter.executableTraceOk` vs
   solanalib step driver observables.
4. Lift through `traceSimulation_lift` for the Counter supported fragment
   (IR → core-tail → solanalib).

Scheme 2 Phase C (assembler-in-Lean replacing external `sbpf`) remains
future work; product text emission is unchanged.
