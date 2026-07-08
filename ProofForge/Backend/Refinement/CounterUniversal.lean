import ProofForge.Backend.Refinement.Core
import ProofForge.IR.CounterSemantics
import ProofForge.IR.StepSemantics

namespace ProofForge.Backend.Refinement.CounterUniversal

open ProofForge.IR
open ProofForge.IR.Semantics
open ProofForge.IR.CounterSemantics
open ProofForge.IR.StepSemantics
open ProofForge.Backend.Refinement

/-! ## Universal Counter refinement skeleton

This module is the first narrow C-proof-shaped step after totalizing the
Counter IR fragment. It proves a reusable trace simulation theorem over every
Counter call list from any related IR/target state.

The target model here is deliberately tiny: a Counter machine state is the
single storage word `count`. This does not claim EVM/Yul or sBPF bytecode
coverage; later target modules can replace `targetStep` with a real target
Lean semantics while keeping the same per-entrypoint simulation + trace
induction shape.
-/

inductive CounterCall where
  | initialize
  | increment
  | get
  deriving Repr, DecidableEq

def CounterCall.entrypoint : CounterCall → Entrypoint
  | .initialize => ProofForge.IR.Examples.Counter.initializeEntrypoint
  | .increment => ProofForge.IR.Examples.Counter.increment
  | .get => ProofForge.IR.Examples.Counter.get

def counterObservableReturn (call : CounterCall) (value? : Option Value) :
    Except String ObservableReturn :=
  match call, value? with
  | .initialize, none => .ok .none
  | .increment, none => .ok .none
  | .get, some (.u64 value) => .ok (.u64 value)
  | .initialize, some _ => .error "Counter.initialize returned an unexpected value"
  | .increment, some _ => .error "Counter.increment returned an unexpected value"
  | .get, none => .error "Counter.get returned no value"
  | .get, some _ => .error "Counter.get returned a non-u64 value"

def irStep (state : State) (call : CounterCall) :
    Except String (State × ObservableReturn) := do
  let (nextState, value?) ← runCounterEntrypoint state call.entrypoint
  let observable ← counterObservableReturn call value?
  .ok (nextState, observable)

def targetStep (count : Nat) : CounterCall → Nat × ObservableReturn
  | .initialize => (0, .none)
  | .increment => (count + 1, .none)
  | .get => (count, .u64 count)

def targetRunTraceList : List CounterCall → Nat → Nat × Array ObservableReturn
  | [], count => (count, #[])
  | call :: rest, count =>
      let (nextCount, observable) := targetStep count call
      let (finalCount, observables) := targetRunTraceList rest nextCount
      (finalCount, #[observable] ++ observables)

def targetTraceStep (count : Nat) (call : CounterCall) :
    Except String (Nat × ObservableReturn) :=
  let (nextCount, observable) := targetStep count call
  .ok (nextCount, observable)

theorem targetRunTraceList_eq_runTraceListGen (calls : List CounterCall) (count : Nat) :
    .ok (targetRunTraceList calls count) =
      ProofForge.IR.StepSemantics.runTraceListGen targetTraceStep calls count := by
  induction calls generalizing count with
  | nil =>
      rfl
  | cons call rest ih =>
      let next := targetStep count call
      have hstep : targetTraceStep count call = .ok (next.1, next.2) := by
        simp [targetTraceStep, next]
      have hrest :
          ProofForge.IR.StepSemantics.runTraceListGen targetTraceStep rest next.1 =
            .ok (targetRunTraceList rest next.1) :=
        (ih next.1).symm
      have hrun := ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
        targetTraceStep call rest count next.1 next.2
        (targetRunTraceList rest next.1).1 (targetRunTraceList rest next.1).2
        hstep hrest
      simpa [targetRunTraceList, next] using hrun.symm

def CounterStateRel (state : State) (count : Nat) : Prop :=
  state.read "count" = some (.u64 count)

def counterModelTargetSemantics : TargetSemantics := {
  id := "counter-model"
  supportedFragments := #[.counter]
  fragmentAccepts := isCounterModule
  lowerableAccepts := isCounterModule
  MachineState := Nat
  Call := CounterCall
  Obs := ObservableReturn
  traceStep := targetTraceStep
  runTrace := fun calls count => .ok (targetRunTraceList calls count)
  runTrace_eq_traceStep := targetRunTraceList_eq_runTraceListGen
  executableTraceOk := fun obligation => FormalFragment.counter.acceptsModule obligation.module
  -- FV-9.1: the real generic simulation relation for the counter-model target.
  irStateRel := fun irState count => CounterStateRel irState count
  -- The counter-model has no count before `initialize` runs (IR `State.empty`
  -- has no `count` key), so there is no related initial machine state; the
  -- relation base-case applies only post-initialize, which the trace proofs
  -- establish.
  initialMachineState := fun _ => none
  initialRelHolds := by intros m ms h; cases h
}

theorem lookup_insert_same (name : String) (value : Value) (bindings : Bindings) :
    lookup name (ProofForge.IR.Semantics.insert name value bindings) = some value := by
  induction bindings with
  | nil =>
      simp [ProofForge.IR.Semantics.insert, lookup]
  | cons binding rest ih =>
      rcases binding with ⟨key, oldValue⟩
      by_cases hkey : key == name
      · simp [ProofForge.IR.Semantics.insert, lookup, hkey]
      · simp [ProofForge.IR.Semantics.insert, lookup, hkey, ih]

theorem counter_state_rel_write_count (state : State) (count : Nat) :
    CounterStateRel (state.write "count" (.u64 count)) count := by
  simp [CounterStateRel, State.read, State.write, lookup_insert_same]

theorem counter_initialize_simulates (state : State) (count : Nat) :
    ∃ nextState nextCount observable,
      irStep state .initialize = .ok (nextState, observable) ∧
      targetStep count .initialize = (nextCount, observable) ∧
      CounterStateRel nextState nextCount := by
  refine ⟨state.write "count" (.u64 0), 0, .none, ?_, rfl, ?_⟩
  · rw [irStep, CounterCall.entrypoint, initialize_total_ok]
    rfl
  · exact counter_state_rel_write_count state 0

theorem counter_get_simulates {state : State} {count : Nat}
    (h : CounterStateRel state count) :
    ∃ nextState nextCount observable,
      irStep state .get = .ok (nextState, observable) ∧
      targetStep count .get = (nextCount, observable) ∧
      CounterStateRel nextState nextCount := by
  refine ⟨state, count, .u64 count, ?_, rfl, h⟩
  rw [irStep, CounterCall.entrypoint, get_total_ok_of_count h]
  rfl

theorem counter_increment_simulates {state : State} {count : Nat}
    (h : CounterStateRel state count) :
    ∃ nextState nextCount observable,
      irStep state .increment = .ok (nextState, observable) ∧
      targetStep count .increment = (nextCount, observable) ∧
      CounterStateRel nextState nextCount := by
  refine ⟨state.write "count" (.u64 (count + 1)), count + 1, .none, ?_, rfl, ?_⟩
  · rw [irStep, CounterCall.entrypoint, increment_total_ok_of_count h]
    rfl
  · exact counter_state_rel_write_count state (count + 1)

theorem counter_step_simulates (call : CounterCall)
    {state : State} {count : Nat} (h : CounterStateRel state count) :
    ∃ nextState nextCount observable,
      irStep state call = .ok (nextState, observable) ∧
      targetStep count call = (nextCount, observable) ∧
      CounterStateRel nextState nextCount := by
  cases call
  · exact counter_initialize_simulates state count
  · exact counter_increment_simulates h
  · exact counter_get_simulates h

theorem counter_step_simulates_traceStep (call : CounterCall)
    {state : State} {count : Nat} (h : CounterStateRel state count) :
    ∃ nextState nextCount observable,
      irStep state call = .ok (nextState, observable) ∧
      targetTraceStep count call = .ok (nextCount, observable) ∧
      CounterStateRel nextState nextCount := by
  obtain ⟨nextState, nextCount, observable, hirStep, htargetStep, hrelNext⟩ :=
    counter_step_simulates call h
  refine ⟨nextState, nextCount, observable, hirStep, ?_, hrelNext⟩
  rw [targetTraceStep, htargetStep]

/-! ### FV-9.2c: per-entrypoint preservation consumes `TargetSemantics.irStateRel`

These restate the counter-model preservation theorems through the generic
`TargetSemantics.irStateRel` field (FV-9.1), demonstrating that the
simulation-relation premise of `traceSimulation_lift` is dischargeable via
the field. FV-9.3's ∀-contract induction will use exactly this shape:
`step_simulates` quantified over `irStateRel`.
-/

theorem counter_step_simulates_via_irStateRel (call : CounterCall)
    {state : State} {count : Nat}
    (h : counterModelTargetSemantics.irStateRel state count) :
    ∃ nextState nextCount observable,
      irStep state call = .ok (nextState, observable) ∧
      targetTraceStep count call = .ok (nextCount, observable) ∧
      counterModelTargetSemantics.irStateRel nextState nextCount := by
  -- `irStateRel` is `CounterStateRel` (FV-9.1), so this is exactly
  -- `counter_step_simulates_traceStep`.
  rw [show counterModelTargetSemantics.irStateRel = CounterStateRel from rfl] at *
  exact counter_step_simulates_traceStep call h

/-! ### FV-9.3: the ∀-call-list fragment-refines theorem for the counter-model

This is the FV-9.3 deliverable for the counter-model target: the
`<target>_fragment_refines` theorem, stated and proved by specializing
`traceSimulation_lift_via_irStateRel` (the FV-9.1-field-consuming wrapper) to
`counterModelTargetSemantics` and discharging the per-call `step_simulates`
premise with FV-9.2c's `counter_step_simulates_via_irStateRel`.

**Honest scope:** this is ∀-calls-list (the universal-over-inputs half) for
the fixed counter-model target, with the relation fixed to the FV-9.1 field.
The full ∀-module theorem (quantifying over every fragment module, not just
the counter shape) is the broader FV-9.3/FV-9.4 work: it needs the
per-constructor preservation lemmas for every constructor the fragment admits
(FV-9.2 widening) so the structural induction over IR program structure can
discharge each case. This theorem is the end-to-end witness that the
FV-9.0 substrate + FV-9.1 field + FV-9.2 preservation + traceSimulation_lift
chain composes; the counter-model is the first target where it's closed.
-/

theorem counterModel_fragment_refines (calls : List CounterCall)
    {state : State} {count : Nat}
    (hrel : counterModelTargetSemantics.irStateRel state count) :
    ∃ finalIr finalMs observables,
      runTraceListGen irStep calls state = .ok (finalIr, observables) ∧
      runTraceListGen counterModelTargetSemantics.traceStep calls count =
        .ok (finalMs, observables) ∧
      counterModelTargetSemantics.irStateRel finalIr finalMs ∧
      IRTraceMatches irStep state calls observables ∧
      IRTraceMatches counterModelTargetSemantics.traceStep count calls observables := by
  exact traceSimulation_lift_via_irStateRel counterModelTargetSemantics irStep
    (fun call irState ms h =>
      counter_step_simulates_via_irStateRel call h)
    calls hrel

theorem counter_trace_simulates_all_related_via_framework (calls : List CounterCall)
    {state : State} {count : Nat} (h : CounterStateRel state count) :
    ∃ finalState finalCount observables,
      runTraceListGen irStep calls state = .ok (finalState, observables) ∧
      runTraceListGen targetTraceStep calls count = .ok (finalCount, observables) ∧
      CounterStateRel finalState finalCount ∧
      IRTraceMatches irStep state calls observables ∧
      IRTraceMatches targetTraceStep count calls observables :=
  traceSimulation_lift irStep targetTraceStep CounterStateRel
    (fun call {irState} {targetState} hrel =>
      counter_step_simulates_traceStep (state := irState) (count := targetState) call hrel)
    calls h

theorem counter_trace_simulates_all_related (calls : List CounterCall)
    {state : State} {count : Nat} (h : CounterStateRel state count) :
    ∃ finalState finalCount observables,
      runTraceListGen irStep calls state = .ok (finalState, observables) ∧
      targetRunTraceList calls count = (finalCount, observables) ∧
      CounterStateRel finalState finalCount ∧
      IRTraceMatches irStep state calls observables := by
  induction calls generalizing state count with
  | nil =>
      refine ⟨state, count, #[], rfl, rfl, h, IRTraceMatches.nil⟩
  | cons call rest ih =>
      obtain ⟨nextState, nextCount, observable, hirStep, htargetStep, hrelNext⟩ :=
        counter_step_simulates call h
      obtain ⟨finalState, finalCount, restObservables, hirRest, htargetRest,
        hrelFinal, htraceRest⟩ := ih hrelNext
      refine ⟨finalState, finalCount, #[observable] ++ restObservables, ?_, ?_,
        hrelFinal, IRTraceMatches.cons hirStep htraceRest⟩
      · exact runTraceListGen_cons_ok irStep call rest state nextState observable
          finalState restObservables hirStep hirRest
      · simp [targetRunTraceList, htargetStep, htargetRest]

theorem counter_trace_simulates_after_initialize (calls : List CounterCall)
    (state : State) (count : Nat) :
    ∃ finalState finalCount observables,
      runTraceListGen irStep (.initialize :: calls) state =
        .ok (finalState, observables) ∧
      targetRunTraceList (.initialize :: calls) count =
        (finalCount, observables) ∧
      CounterStateRel finalState finalCount ∧
      IRTraceMatches irStep state (.initialize :: calls) observables := by
  obtain ⟨nextState, nextCount, observable, hirStep, htargetStep, hrelNext⟩ :=
    counter_initialize_simulates state count
  obtain ⟨finalState, finalCount, restObservables, hirRest, htargetRest,
    hrelFinal, htraceRest⟩ := counter_trace_simulates_all_related calls hrelNext
  refine ⟨finalState, finalCount, #[observable] ++ restObservables, ?_, ?_,
    hrelFinal, IRTraceMatches.cons hirStep htraceRest⟩
  · exact runTraceListGen_cons_ok irStep .initialize calls state nextState observable
      finalState restObservables hirStep hirRest
  · simp [targetRunTraceList, htargetStep, htargetRest]

end ProofForge.Backend.Refinement.CounterUniversal
