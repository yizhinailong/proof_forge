import ProofForge.Backend.Refinement.CounterUniversal
import ProofForge.IR.Examples.Counter

/-! ## SupportedFragment smoke

Pins the proof-fragment boundary used by the universal Counter refinement
track: the `counter-model` target semantics accepts only the canonical Counter
fragment and rejects modules outside that proved scope.
-/

namespace ProofForge.Tests.SupportedFragment

open ProofForge.Backend.Refinement
open ProofForge.Backend.Refinement.CounterUniversal

def checkedCounterModule : ProofForge.IR.Module :=
  { ProofForge.IR.Examples.Counter.module with overflowChecked := true }

def renamedCounterModule : ProofForge.IR.Module :=
  { ProofForge.IR.Examples.Counter.module with name := "CounterRenamed" }

theorem counter_model_declares_counter_fragment :
    counterModelTargetSemantics.supportsProofFragment .counter = true := by
  native_decide

theorem counter_model_supports_canonical_counter :
    counterModelTargetSemantics.supportedFragment
      ProofForge.IR.Examples.Counter.module = true := by
  native_decide

theorem counter_model_rejects_checked_counter :
    counterModelTargetSemantics.supportedFragment checkedCounterModule = false := by
  native_decide

theorem counter_model_rejects_renamed_counter :
    counterModelTargetSemantics.supportedFragment renamedCounterModule = false := by
  native_decide

theorem require_supported_fragment_accepts_counter :
    (match counterModelTargetSemantics.requireSupportedFragment
        ProofForge.IR.Examples.Counter.module with
     | .ok _ => true
     | .error _ => false) = true := by
  native_decide

theorem require_supported_fragment_rejects_checked_counter :
    (match counterModelTargetSemantics.requireSupportedFragment checkedCounterModule with
     | .ok _ => false
     | .error _ => true) = true := by
  native_decide

end ProofForge.Tests.SupportedFragment

def main : IO UInt32 := do
  IO.println "supported-fragment-smoke: Counter proof fragment accepts canonical Counter and rejects fragment-outside modules"
  return 0
