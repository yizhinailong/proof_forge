import ProofForge.Backend.Refinement.Core
import EvmSemantics.EVM.State
import EvmSemantics.EVM.Step
import EvmSemantics.EVM.StepF
import EvmSemantics.EVM.BigStep
import EvmSemantics.EVM.Equiv

/-! Opt-in adapter surface for `powdr-labs/evm-semantics`.

This module is intentionally outside the default `ProofForge` root. Building
the `EvmRefinement` Lake target pulls powdr + mathlib and proves that the
preferred Phase 6b surface is available, while the default CLI/library build
keeps using the mathlib-free seam in `ProofForge.Backend.Evm.EvmBytecodeSemantics`.
-/

namespace ProofForge.Backend.Evm.PowdrAdapter

abbrev PowdrState := EvmSemantics.EVM.State
abbrev PowdrStep : PowdrState → PowdrState → Prop := EvmSemantics.EVM.Step
abbrev PowdrObservableStep := ProofForge.Backend.Refinement.ObservableStep

def powdrStepF (state : PowdrState) : PowdrState :=
  EvmSemantics.EVM.stepF state

theorem powdr_stepF_sound (state : PowdrState) (hRunning : ¬ state.isDone) :
    PowdrStep state (powdrStepF state) :=
  EvmSemantics.EVM.stepF_sound state hRunning

end ProofForge.Backend.Evm.PowdrAdapter
