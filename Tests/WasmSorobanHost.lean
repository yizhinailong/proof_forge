import ProofForge.Backend.WasmNear.CounterSorobanRefinement
import ProofForge.Backend.WasmNear.SorobanHost

/-! Soroban host dispatch + Counter refinement smoke (Phase 4 WASM host family).

This is the third WASM host adapter smoke: `runHostCall` routes `.soroban`
bridge, and the Counter universal C-proof reuses the SAME host-agnostic
`counterWasmCoreTraceStep` core as NEAR and CosmWasm. This is the
machine-checked witness for the WASM host-family thesis. -/

namespace ProofForge.Tests.WasmSorobanHost

open ProofForge.Backend.WasmNear.WasmInterpreter
open ProofForge.Backend.WasmNear.SorobanHost
open ProofForge.Backend.WasmNear.CounterSorobanRefinement
open ProofForge.Backend.WasmNear.CounterWasmRefinement

def sorobanState : WasmState :=
  { host := { bridge := .soroban, storage := #[] } }

theorem sorobanHostArity_get : sorobanHostArity "_get" = .ok 2 := rfl

theorem sorobanHostArity_put : sorobanHostArity "_put" = .ok 4 := rfl

theorem sorobanHostArity_invoke : sorobanHostArity "invoke_contract" = .ok 6 := rfl

theorem hostArity_soroban_put :
    hostArity ProofForge.Target.HostBridge.soroban "_put" = .ok 4 := rfl

theorem hostArity_soroban_invoke :
    hostArity ProofForge.Target.HostBridge.soroban "invoke_contract" = .ok 6 := rfl

theorem runSorobanHostCall_log_id :
    runSorobanHostCall "log_from_slice" #[0, 0] sorobanState = .ok sorobanState := by
  rfl

theorem runSorobanHostCall_invoke_id :
    runSorobanHostCall "invoke_contract" #[0, 0, 0, 0, 0, 0] sorobanState =
      .ok { sorobanState with valueStack := #[0] } := by
  rfl

example : True := by
  have _ := @sorobanHostArity_get
  have _ := @sorobanHostArity_put
  have _ := @sorobanHostArity_invoke
  have _ := @hostArity_soroban_put
  have _ := @hostArity_soroban_invoke
  have _ := @runSorobanHostCall_log_id
  have _ := @runSorobanHostCall_invoke_id
  have _ := @soroban_host_smoke_ok
  have _ := @counterSoroban_canonical_safe_trace_simulates
  have _ := @counterSoroban_host_put_preserves_count_storage
  have _ := @counterSoroban_trace_simulates_after_initialize
  exact True.intro

end ProofForge.Tests.WasmSorobanHost

def main : IO UInt32 := do
  IO.println "wasm-soroban-host-smoke: Soroban host dispatch + Counter universal refinement (3rd WASM host adapter) checked"
  return 0