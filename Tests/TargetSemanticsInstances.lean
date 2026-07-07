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

def evmTraceStep (object : Lean.Compiler.Yul.Object)
    (storage : ProofForge.Backend.Evm.YulSemantics.WordBindings)
    (call : TraceCall) :
    Except String (ProofForge.Backend.Evm.YulSemantics.WordBindings × ObservableReturn) := do
  let (storage, step) ←
    ProofForge.Backend.Evm.Refinement.runEvmEntrypointObservable object storage call
  .ok (storage, step.returnValue)

def solanaTraceStep
    (program : ProofForge.Backend.Solana.SbpfInterpreter.SbpfProgram)
    (module : ProofForge.IR.Module)
    (memory : ProofForge.Backend.Solana.SbpfInterpreter.Memory)
    (call : TraceCall) :
    Except String (ProofForge.Backend.Solana.SbpfInterpreter.Memory × ObservableReturn) := do
  let (memory, step, _) ←
    ProofForge.Backend.Solana.SbpfInterpreter.runEntrypointState
      program module memory call
  .ok (memory, step.returnValue)

def wasmTraceStep (wasm : ProofForge.Compiler.Wasm.Module)
    (state : ProofForge.Backend.WasmNear.WasmInterpreter.WasmState)
    (call : TraceCall) :
    Except String (ProofForge.Backend.WasmNear.WasmInterpreter.WasmState × ObservableReturn) := do
  let state ← ProofForge.Backend.WasmNear.WasmInterpreter.runExport wasm state call
  let returnValue ←
    ProofForge.Backend.WasmNear.WasmInterpreter.observeEntrypoint call.entrypoint state
  .ok (state, returnValue)

#check (fun (object : Lean.Compiler.Yul.Object) calls storage =>
  runTraceListGen_sound
    (MachineState := ProofForge.Backend.Evm.YulSemantics.WordBindings)
    (Call := TraceCall)
    (Obs := ObservableReturn)
    (evmTraceStep object) calls storage)

#check (fun (program : ProofForge.Backend.Solana.SbpfInterpreter.SbpfProgram)
    (module : ProofForge.IR.Module) calls memory =>
  runTraceListGen_sound
    (MachineState := ProofForge.Backend.Solana.SbpfInterpreter.Memory)
    (Call := TraceCall)
    (Obs := ObservableReturn)
    (solanaTraceStep program module) calls memory)

#check (fun (wasm : ProofForge.Compiler.Wasm.Module) calls state =>
  runTraceListGen_sound
    (MachineState := ProofForge.Backend.WasmNear.WasmInterpreter.WasmState)
    (Call := TraceCall)
    (Obs := ObservableReturn)
    (wasmTraceStep wasm) calls state)

end ProofForge.Tests.TargetSemanticsInstances

def main : IO UInt32 := do
  IO.println "target-semantics-instances-smoke: EVM/Yul, Solana sBPF, and Wasm/NEAR executable trace runners are wired through TargetSemantics"
  return 0
