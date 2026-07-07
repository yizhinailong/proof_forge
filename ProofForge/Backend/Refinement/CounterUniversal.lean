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

def CounterStateRel (state : State) (count : Nat) : Prop :=
  state.read "count" = some (.u64 count)

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
