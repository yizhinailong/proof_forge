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

end ProofForge.Tests.CounterUniversalRefinement

def main : IO UInt32 := do
  IO.println "counter-universal-refinement-smoke: per-entrypoint simulation and all-call-list Counter trace induction checked"
  return 0
