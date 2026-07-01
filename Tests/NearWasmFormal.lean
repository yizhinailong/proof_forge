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

end ProofForge.Tests.NearWasmFormal

def main : IO UInt32 := do
  IO.println "near-wasm-formal: counter scalar IR semantics checked"
  return 0
