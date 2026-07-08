import ProofForge.Backend.Refinement.CounterUniversal

/-! ## Universal Counter refinement smoke

Checks the first all-call-list Counter simulation layer: per-entrypoint
simulation lemmas plus the inductive trace theorem over arbitrary Counter call
lists from related states, and init-prefixed traces from arbitrary IR states.
-/

namespace ProofForge.Tests.CounterUniversalRefinement

open ProofForge.Backend.Refinement.CounterUniversal

#check counter_initialize_simulates
#check counter_get_simulates
#check counter_increment_simulates
#check counter_step_simulates
#check counter_step_simulates_traceStep
#check counter_trace_simulates_all_related_via_framework
#check counter_trace_simulates_all_related
#check counter_trace_simulates_after_initialize

def sampleCalls : List CounterCall := [
  .get,
  .increment,
  .get
]

theorem sample_initialized_trace_simulates (state : ProofForge.IR.Semantics.State)
    (count : Nat) :
    ∃ finalState finalCount observables,
      ProofForge.IR.StepSemantics.runTraceListGen irStep (.initialize :: sampleCalls) state =
        .ok (finalState, observables) ∧
      targetRunTraceList (.initialize :: sampleCalls) count =
        (finalCount, observables) ∧
      CounterStateRel finalState finalCount ∧
      ProofForge.IR.StepSemantics.IRTraceMatches irStep state
        (.initialize :: sampleCalls) observables :=
  counter_trace_simulates_after_initialize sampleCalls state count

theorem sample_related_trace_simulates_via_framework
    {state : ProofForge.IR.Semantics.State} {count : Nat}
    (h : CounterStateRel state count) :
    ∃ finalState finalCount observables,
      ProofForge.IR.StepSemantics.runTraceListGen irStep sampleCalls state =
        .ok (finalState, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen targetTraceStep sampleCalls count =
        .ok (finalCount, observables) ∧
      CounterStateRel finalState finalCount ∧
      ProofForge.IR.StepSemantics.IRTraceMatches irStep state sampleCalls observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches targetTraceStep count sampleCalls observables :=
  counter_trace_simulates_all_related_via_framework sampleCalls h

/-! ## FV-9.3: `<target>_fragment_refines` via `TargetSemantics.irStateRel`

The counter-model target's ∀-call-list fragment-refines theorem, proved by
specializing `traceSimulation_lift_via_irStateRel` (the FV-9.1-field-consuming
wrapper) and discharging per-call `step_simulates` with FV-9.2c. This is the
end-to-end witness that the FV-9.0 substrate + FV-9.1 field + FV-9.2
preservation + traceSimulation_lift chain composes. -/

#check counterModel_fragment_refines

theorem sample_related_trace_fragment_refines_via_field
    {state : ProofForge.IR.Semantics.State} {count : Nat}
    (h : counterModelTargetSemantics.irStateRel state count) :
    ∃ finalIr finalMs observables,
      ProofForge.IR.StepSemantics.runTraceListGen irStep sampleCalls state =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen
        counterModelTargetSemantics.traceStep sampleCalls count =
        .ok (finalMs, observables) ∧
      counterModelTargetSemantics.irStateRel finalIr finalMs ∧
      ProofForge.IR.StepSemantics.IRTraceMatches irStep state sampleCalls observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        counterModelTargetSemantics.traceStep count sampleCalls observables :=
  counterModel_fragment_refines sampleCalls h

end ProofForge.Tests.CounterUniversalRefinement

def main : IO UInt32 := do
  IO.println "counter-universal-refinement-smoke: per-entrypoint simulation, generic trace-simulation lift, all-call-list Counter trace induction, and FV-9.3 counterModel_fragment_refines via irStateRel checked"
  return 0
