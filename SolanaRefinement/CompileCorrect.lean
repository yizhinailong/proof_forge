/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# CompileCorrect — IR → sBPF solanalib refinement sketch (Scheme 1)

Opt-in formal surface that hooks ProofForge's EmitSBPF (`SbpfAsm.lowerModule`)
into `solanalib.SBPF` for post-hoc verification. This is the Solana analogue of
`EvmRefinement/CounterRefinement.lean` for the powdr path.

## What is machine-checked today

1. **Encode well-formedness** (default path, mathlib-free):
   `BpfEncode.moduleEncodesOk` — Counter lowers to a non-empty multiple-of-8
   byte list with every byte in `0..255`.
2. **solanalib decode + verify** (this target):
   `counter_solanalib_pipeline_ok` — the encoded Counter bytecode is accepted
   by `Solanalib.SBPF.findInstr` at every PC and by `verifyInstr` (v1).
3. **Safety bridge statement** (structural, no new proof work):
   `verified_instr_step_ne_err` re-exports solanalib's Lemma 6.4
   (`step_ne_err`) so ProofForge proofs can cite it without depending on
   solanalib from the default root.

## What is *not* claimed (honest TCB)

- No full `IR.Semantics ⇝ bpfInterp` simulation for arbitrary inputs.
- No account-input / syscall host model inside solanalib's interpreter yet;
  product correctness for CPI/PDA/syscalls remains on the existing
  `SbpfInterpreter` + Mollusk/Pinocchio differential gates.
- `native_decide` is used for the pointwise Counter pipeline check (trusts
  Lean's native evaluator), matching the Tier C-diff convention in
  `docs/formal-verification.md`.

## Next steps (Scheme 1 → 2)

- Differential: run the same Counter entrypoints on `SbpfInterpreter` and a
  solanalib `bpfInterp` host bridge; pin matching `r0` / return-data.
- Lift per-entrypoint simulation via `traceSimulation_lift` once a shared
  observable projection exists.
- Scheme 2 would replace text emit with a fully verified labeled-asm pipeline
  targeting `BpfInstruction` directly (out of scope here).

See `docs/solana-sbpf-solanalib-bridge.md`.
-/

import SolanaRefinement.SolanalibAdapter
import SolanaRefinement.LabeledToSolanalib
import SolanaRefinement.HostBridge
import ProofForge.Backend.Solana.BpfEncode
import ProofForge.Backend.Solana.LabeledSbpf
import ProofForge.IR.Examples.Counter
import Solanalib.SBPF.Verifier
import Solanalib.SBPF.Interpreter

namespace ProofForge.Backend.Solana.CompileCorrect

open ProofForge.Backend.Solana.BpfEncode
open ProofForge.Backend.Solana.LabeledSbpf
open ProofForge.Backend.Solana.SolanalibAdapter
open ProofForge.Backend.Solana.LabeledToSolanalib
open ProofForge.Backend.Solana.HostBridge
open Solanalib.SBPF

/-! ### Default-path encode anchor (also buildable without solanalib) -/

theorem counter_bpf_encode_ok :
    moduleEncodesOk ProofForge.IR.Examples.Counter.module = true := by
  native_decide

/-! ### Opt-in solanalib pipeline anchors -/

theorem counter_solanalib_pipeline_ok :
    counterPipelineOk = true := by
  native_decide

/-- Re-export of solanalib Lemma 6.4 for ProofForge-facing proofs.

If `verifyInstr ins sv = true`, a single `step` on that instruction cannot
produce the malformed-instruction outcome `.err`. Full program safety still
needs the remaining verifier obligations (in-bounds jumps, register ranges)
that solanalib intentionally leaves outside `verifyInstr`. -/
theorem verified_instr_step_ne_err
    {ins : BpfInstruction} {sv : SBPFV}
    (h : verifyInstr ins sv = true) :
    ∀ (pc : U64) (rs : RegMap) (m : Mem) (ss : StackState) (fm : FuncMap)
      (gaps : Bool) (programVmAddr cur remain : U64),
      step pc ins rs m ss sv fm gaps programVmAddr cur remain ≠ .err :=
  fun pc rs m ss fm gaps programVmAddr cur remain =>
    step_ne_err (ins := ins) (sv := sv) h pc rs m ss fm gaps programVmAddr cur remain

/-! ### CompileCorrect statement shape (proof obligations, not yet discharged
universally)

The intended end-state theorem is:

```
theorem compile_correct (module : Module) (hfrag : supportedFragment module)
    (calls : List TraceCall) (hir : irRun module calls = .ok obs)
    : ∃ st, bpfInterp (lowerModuleToBpfBin module) fuel = .success … ∧
        observable st = obs
```

Today we pin the **pipeline preconditions** that any such proof will need:
encode succeeds, decode covers every slot, and every instruction verifies. -/

structure CompilePipeline where
  module : ProofForge.IR.Module
  bytes : BpfBinBytes
  bin : BpfBin
  insns : List BpfInstruction

def buildPipeline (module : ProofForge.IR.Module) : Except String CompilePipeline := do
  let bytes ← match BpfEncode.lowerModuleToBpfBin module with
    | .error e => .error e
    | .ok b => .ok b
  let bin := SolanalibAdapter.toBpfBin bytes
  let insns ← decodeAll bin
  .ok { module, bytes, bin, insns }

def pipelineOk (p : CompilePipeline) : Bool :=
  bpfBinWellFormed p.bytes &&
    !p.insns.isEmpty &&
    verifyAll p.insns .v1

theorem counter_compile_pipeline_ok :
    (match buildPipeline ProofForge.IR.Examples.Counter.module with
     | .ok p => pipelineOk p
     | .error _ => false) = true := by
  native_decide

/-! ### Scheme 2 Phase A/B anchors (still from Portable IR) -/

theorem counter_labeled_view_ok :
    moduleLabeledOk ProofForge.IR.Examples.Counter.module = true := by
  native_decide

theorem counter_direct_lift_verify_ok :
    liftVerifyOk ProofForge.IR.Examples.Counter.module = true := by
  native_decide

theorem counter_direct_lift_eq_decode :
    liftMatchesDecode ProofForge.IR.Examples.Counter.module = true := by
  native_decide

/-! ### Host bridge: Counter core-tail on solanalib step driver -/

theorem counter_core_tail_host_bridge_ok :
    counterCoreTailBridgeOk = true := by
  native_decide

end ProofForge.Backend.Solana.CompileCorrect
