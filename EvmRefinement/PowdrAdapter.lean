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

theorem runBytecode_halted_succ {state : State} {fuel : Nat}
    (hHalted : isHalted state = true) :
    runBytecode state (fuel + 1) = .ok (state, #[]) := by
  simp [runBytecode, hHalted]

theorem runBytecode_step_succ {state next finalState : State}
    {observations : Array ObservableStep} {fuel : Nat}
    (hHalted : isHalted state = false)
    (hstep : stepF state = .ok next)
    (hrun : runBytecode next fuel = .ok (finalState, observations)) :
    runBytecode state (fuel + 1) = .ok (finalState, observations) := by
  simp [runBytecode, hHalted, hstep]
  change Except.bind (runBytecode next fuel)
      (fun result : State × Array ObservableStep =>
        Except.ok (result.fst, result.snd)) =
    Except.ok (finalState, observations)
  rw [hrun]
  rfl

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

/-- A successful fuel-bounded executable run is backed by powdr's relational
`Step` closure. This is the bridge future Counter entrypoint runners need to
turn executable bytecode execution into C-proof evidence. -/
theorem runBytecode_steps {fuel : Nat} :
    ∀ {state finalState : State} {observations : Array ObservableStep},
      runBytecode state fuel = .ok (finalState, observations) →
        EvmSemantics.EVM.Steps state finalState := by
  induction fuel with
  | zero =>
      intro state finalState observations hrun
      have hpair : (state, (#[] : Array ObservableStep)) = (finalState, observations) := by
        simpa [runBytecode] using hrun
      cases hpair
      exact EvmSemantics.EVM.Steps.refl state
  | succ fuel ih =>
      intro state finalState observations hrun
      by_cases hHalted : isHalted state
      · simp [runBytecode, hHalted] at hrun
        have hpair : (state, (#[] : Array ObservableStep)) = (finalState, observations) := by
          simpa using hrun
        cases hpair
        exact EvmSemantics.EVM.Steps.refl state
      · simp [runBytecode, hHalted] at hrun
        cases hstep : stepF state with
        | error message =>
            rw [hstep] at hrun
            change (Except.bind (Except.error message)
              (fun next : State =>
                Except.bind (runBytecode next fuel)
                  (fun result : State × Array ObservableStep =>
                    Except.ok (result.fst, result.snd)))) =
              Except.ok (finalState, observations) at hrun
            simp [Except.bind] at hrun
        | ok next =>
            rw [hstep] at hrun
            change (Except.bind (Except.ok next)
              (fun next : State =>
                Except.bind (runBytecode next fuel)
                  (fun result : State × Array ObservableStep =>
                    Except.ok (result.fst, result.snd)))) =
              Except.ok (finalState, observations) at hrun
            simp [Except.bind] at hrun
            have hrunNext : runBytecode next fuel = .ok (finalState, observations) := by
              cases hnext : runBytecode next fuel with
              | error message =>
                  rw [hnext] at hrun
                  simp at hrun
              | ok result =>
                  rcases result with ⟨nextFinalState, nextObservations⟩
                  rw [hnext] at hrun
                  simp at hrun
                  rcases hrun with ⟨rfl, rfl⟩
                  rfl
            exact EvmSemantics.EVM.Steps.trans (stepF_sound hstep) (ih hrunNext)

abbrev PowdrState := State
abbrev PowdrStep : PowdrState → PowdrState → Prop := Step
abbrev PowdrObservableStep := ObservableStep

def powdrStepF (state : PowdrState) : PowdrState :=
  rawStepF state

theorem powdr_stepF_sound (state : PowdrState) (hRunning : ¬ state.isDone) :
    PowdrStep state (powdrStepF state) :=
  raw_stepF_sound state hRunning

end ProofForge.Backend.Evm.PowdrAdapter
