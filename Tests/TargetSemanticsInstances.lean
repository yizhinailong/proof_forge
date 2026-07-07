import ProofForge.Backend.Evm.Refinement
import ProofForge.Backend.Solana.Refinement
import ProofForge.Backend.WasmNear.Refinement
import ProofForge.IR.StepSemantics

/-! ## Shared TargetSemantics instance smoke

Pins that the existing EVM/Yul, Solana sBPF, and Wasm/NEAR executable trace
runners are reachable through the shared `TargetSemantics` interface.
-/

namespace ProofForge.Tests.TargetSemanticsInstances

open ProofForge.Backend.Refinement
open ProofForge.IR.StepSemantics

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

#check (fun (object : Lean.Compiler.Yul.Object) calls storage =>
  runTraceListGen_sound
    (MachineState := ProofForge.Backend.Evm.Refinement.EvmYulMachineState)
    (Call := TraceCall)
    (Obs := ObservableStep)
    ProofForge.Backend.Evm.Refinement.evmYulTargetSemantics.traceStep calls
    ({ object, storage } : ProofForge.Backend.Evm.Refinement.EvmYulMachineState))

#check (fun (program : ProofForge.Backend.Solana.SbpfInterpreter.SbpfProgram)
    (module : ProofForge.IR.Module) calls memory =>
  runTraceListGen_sound
    (MachineState := ProofForge.Backend.Solana.Refinement.SolanaSbpfMachineState)
    (Call := TraceCall)
    (Obs := ObservableStep)
    ProofForge.Backend.Solana.Refinement.solanaSbpfTargetSemantics.traceStep calls
    ({ program, module, memory } :
      ProofForge.Backend.Solana.Refinement.SolanaSbpfMachineState))

#check (fun (wasm : ProofForge.Compiler.Wasm.Module) calls state =>
  runTraceListGen_sound
    (MachineState := ProofForge.Backend.WasmNear.Refinement.WasmNearMachineState)
    (Call := TraceCall)
    (Obs := ObservableStep)
    ProofForge.Backend.WasmNear.Refinement.wasmNearTargetSemantics.traceStep calls
    ({ wasm, state } : ProofForge.Backend.WasmNear.Refinement.WasmNearMachineState))

end ProofForge.Tests.TargetSemanticsInstances

def main : IO UInt32 := do
  IO.println "target-semantics-instances-smoke: EVM/Yul, Solana sBPF, and Wasm/NEAR executable trace runners are wired through TargetSemantics"
  return 0
