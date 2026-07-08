import ProofForge.Backend.WasmNear.WasmExec

/-! ## Generic WasmExec smoke

Pins the chain-agnostic Wasm stack/state helper surface used by the WASM-1
proof track. This intentionally avoids NEAR host calls and contract fixtures.
-/

namespace ProofForge.Tests.WasmExec

open ProofForge.Backend.WasmNear.WasmExec

example : True := by
  have _ := @runStateSteps
  have _ := @StateStepReduction
  have _ := @StateStepReduction.of_step
  have _ := @StateStepReductionChain
  have _ := @runStateSteps_of_reductionChain
  have _ := @StateStepReductionChain.append
  have _ := @ExecutionSegment
  have _ := @runStateSteps_of_executionSegment
  have _ := @executionSegment_of_reductionChain
  have _ := @executionSegment_append
  have _ := @StateStepProvider
  have _ := @stateStepProvider_single
  have _ := @stateStepProvider_append
  have _ := @runStateSteps_post_of_provider
  have _ := @valueStack_stackPush
  have _ := @locals_stackPush
  have _ := @globals_stackPush
  have _ := @memory_stackPush
  have _ := @host_stackPush
  have _ := @stackPeek_stackPush
  have _ := @stackPop_stackPush
  have _ := @splitStackArgs_zero
  have _ := @splitStackArgs_stackPush1
  have _ := @splitStackArgs_stackPush2
  have _ := @splitStackArgs_stackPush3
  have _ := @splitStackArgs_stackPush5
  have _ := @evalPlain_unary_stackPush
  have _ := @evalPlain_binary_stackPush
  have _ := @execDrop_stackPush
  have _ := @execConst_ok
  have _ := @execLocalGet_ok
  have _ := @execLocalSet_stackPush
  have _ := @execLocalTee_stackPush
  have _ := @execGlobalGet_ok
  have _ := @execGlobalSet_stackPush
  have _ := @execLoad_stackPush
  have _ := @execStore_stackPush
  have _ := @runHostCallWith_ok
  have _ := @lookupLocal_writeLocal_same
  have _ := @lookupGlobal_writeGlobal_same
  have _ := @lookupRegister_writeRegister_same
  have _ := @lookupStorage_writeStorage_same
  have _ := @host_beginCall_input
  have _ := @host_beginCall_registers
  have _ := @host_beginCall_returnValue
  exact True.intro

theorem stack_roundtrip_sample :
    ProofForge.Backend.WasmNear.WasmInterpreter.stackPop
      (ProofForge.Backend.WasmNear.WasmInterpreter.stackPush ({} : State) 7) =
        Except.ok (7, ({} : State)) := by
  exact stackPop_stackPush ({} : State) 7

theorem local_write_sample :
    ProofForge.Backend.WasmNear.WasmInterpreter.lookupLocal?
      (ProofForge.Backend.WasmNear.WasmInterpreter.writeLocal (#[] : Locals) "x" 9)
      "x" = some 9 := by
  exact lookupLocal_writeLocal_same (#[] : Locals) "x" 9

def samplePush7 : StateStep :=
  fun state => .ok (ProofForge.Backend.WasmNear.WasmInterpreter.stackPush state 7)

def sampleSetX : StateStep :=
  fun state => ProofForge.Backend.WasmNear.WasmInterpreter.execLocalSet state "x"

theorem state_step_reduction_chain_sample :
    StateStepReductionChain [samplePush7, sampleSetX] ({} : State)
      { ({} : State) with locals :=
          ProofForge.Backend.WasmNear.WasmInterpreter.writeLocal (#[] : Locals) "x" 7 } := by
  apply StateStepReductionChain.cons
  · exact StateStepReduction.of_step rfl
  · apply StateStepReductionChain.cons
    · exact StateStepReduction.of_step <| by
        simpa [sampleSetX] using
          execLocalSet_stackPush ({} : State) "x" 7
    · exact StateStepReductionChain.nil
        { ({} : State) with locals :=
            ProofForge.Backend.WasmNear.WasmInterpreter.writeLocal (#[] : Locals) "x" 7 }

theorem run_state_steps_chain_sample :
    runStateSteps [samplePush7, sampleSetX] ({} : State) =
      .ok { ({} : State) with locals :=
          ProofForge.Backend.WasmNear.WasmInterpreter.writeLocal (#[] : Locals) "x" 7 } := by
  exact runStateSteps_of_reductionChain state_step_reduction_chain_sample

end ProofForge.Tests.WasmExec

def main : IO UInt32 := do
  IO.println "wasm-exec-smoke: generic Wasm stack/state helper lemmas checked"
  return 0
