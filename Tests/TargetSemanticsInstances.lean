import ProofForge.Backend.Evm.Refinement
import ProofForge.Backend.Solana.Refinement
import ProofForge.Backend.WasmNear.Refinement

/-! ## Shared TargetSemantics instance smoke

Pins that the existing EVM/Yul, Solana sBPF, and Wasm/NEAR executable trace
runners are reachable through the shared `TargetSemantics` interface.
-/

namespace ProofForge.Tests.TargetSemanticsInstances

#check ProofForge.Backend.Evm.Refinement.evmYulTargetSemantics
#check ProofForge.Backend.Solana.Refinement.solanaSbpfTargetSemantics
#check ProofForge.Backend.WasmNear.Refinement.wasmNearTargetSemantics

theorem evm_counter_target_semantics_trace_ok :
    ProofForge.Backend.Evm.Refinement.evmYulTargetSemantics.executableTraceOk
      ProofForge.Backend.Evm.Refinement.counterTraceObligation = true := by
  native_decide

theorem solana_counter_target_semantics_trace_ok :
    ProofForge.Backend.Solana.Refinement.solanaSbpfTargetSemantics.executableTraceOk
      ProofForge.Backend.Solana.Refinement.counterTraceObligation = true := by
  native_decide

theorem wasm_counter_target_semantics_trace_ok :
    ProofForge.Backend.WasmNear.Refinement.wasmNearTargetSemantics.executableTraceOk
      ProofForge.Backend.WasmNear.Refinement.counterTraceObligation = true := by
  native_decide

end ProofForge.Tests.TargetSemanticsInstances

def main : IO UInt32 := do
  IO.println "target-semantics-instances-smoke: EVM/Yul, Solana sBPF, and Wasm/NEAR executable trace runners are wired through TargetSemantics"
  return 0
