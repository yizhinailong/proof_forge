import ProofForge.Backend.WasmNear.Refinement
import ProofForge.IR.Semantics
import ProofForge.IR.Ownership
import ProofForge.IR.Examples.ArrayProbe

namespace ProofForge.Tests.NearWasmFormal

theorem release_then_sum_ownership_ok :
    ProofForge.IR.Ownership.checkEntrypointOk
      ProofForge.IR.Examples.ArrayProbe.releaseThenSum = true := by
  native_decide

#check ProofForge.IR.Semantics.counter_trace_gets_one
#check ProofForge.IR.Semantics.counter_exports_match_near_entrypoints
#check ProofForge.Tests.NearWasmFormal.release_then_sum_ownership_ok
#check ProofForge.Backend.WasmNear.Refinement.counter_ir_observable_trace_ok
#check ProofForge.Backend.WasmNear.Refinement.counter_emitwat_exports_trace_entrypoints

end ProofForge.Tests.NearWasmFormal

def main : IO UInt32 := do
  IO.println "near-wasm-formal: counter scalar IR semantics checked"
  return 0
