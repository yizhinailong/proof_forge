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

/-- Opt-in EVM bytecode state: the real powdr state. -/
abbrev State := EvmSemantics.EVM.State

/-- Opt-in relational EVM step: the real powdr `Step`. -/
abbrev Step : State → State → Prop := EvmSemantics.EVM.Step

abbrev ObservableStep := ProofForge.Backend.Refinement.ObservableStep

/-- Raw powdr total executable step. It is identity-like on done states. -/
def rawStepF (state : State) : State :=
  EvmSemantics.EVM.stepF state

/-- Seam-compatible executable step.

The default mathlib-free seam uses `Except String State`, while powdr exposes a
total `State → State` plus a soundness theorem that requires the source state
not to be done. This wrapper turns accidental calls on done states into an
adapter error, so any successful result carries the precondition needed for
powdr's `stepF_sound`. -/
def stepF (state : State) : Except String State :=
  if state.isDone then
    .error "powdr stepF called on a done EVM state"
  else
    .ok (rawStepF state)

/-- Compatibility alias for single opcode-granular execution. -/
def step (state : State) : State :=
  rawStepF state

def isHalted (state : State) : Bool :=
  state.isDone

/-- Fuel-bounded powdr bytecode driver.

Observable projection is still a Phase 6c task, so this driver preserves the
same `Array ObservableStep` shape as the mathlib-free seam but returns no
observable steps yet. The important E2 fact is that state stepping is now the
real powdr executable step in the opt-in target. -/
def runBytecode : State → Nat → Except String (State × Array ObservableStep)
  | state, 0 => .ok (state, #[])
  | state, fuel + 1 =>
      if isHalted state then
        .ok (state, #[])
      else do
        let next ← stepF state
        let (finalState, observations) ← runBytecode next fuel
        .ok (finalState, observations)

theorem raw_stepF_sound (state : State) (hRunning : ¬ state.isDone) :
    Step state (rawStepF state) :=
  EvmSemantics.EVM.stepF_sound state hRunning

/-- Soundness of the seam-compatible executable step wrapper. -/
theorem stepF_sound {state next : State} (h : stepF state = .ok next) :
    Step state next := by
  unfold stepF at h
  by_cases hDone : state.isDone
  · simp [hDone] at h
  · simp [hDone] at h
    cases h
    exact raw_stepF_sound state hDone

theorem runBytecode_zero (state : State) :
    runBytecode state 0 = .ok (state, (#[] : Array ObservableStep)) := rfl

abbrev PowdrState := State
abbrev PowdrStep : PowdrState → PowdrState → Prop := Step
abbrev PowdrObservableStep := ObservableStep

def powdrStepF (state : PowdrState) : PowdrState :=
  rawStepF state

theorem powdr_stepF_sound (state : PowdrState) (hRunning : ¬ state.isDone) :
    PowdrStep state (powdrStepF state) :=
  raw_stepF_sound state hRunning

end ProofForge.Backend.Evm.PowdrAdapter
