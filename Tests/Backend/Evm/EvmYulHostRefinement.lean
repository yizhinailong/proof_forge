import ProofForge.Backend.Evm.YulHostRefinement

/-! ## EVM Yul-host IR paired simulation smoke (mathlib-free) -/

namespace ProofForge.Tests.EvmYulHostRefinement

open ProofForge.Backend.Evm.YulHostRefinement

#check counter_yul_trace_simulation_ok
#check counter_yul_trace_simulation_sound_checked
#check counter_yul_counter_call_trace_ok
#check counter_yul_counter_call_trace_sound_checked
#check value_vault_yul_trace_simulation_ok
#check value_vault_yul_trace_simulation_sound_checked
#check value_vault_yul_executable_still_ok
#check counter_yul_executable_still_ok

end ProofForge.Tests.EvmYulHostRefinement

def main : IO UInt32 := do
  IO.println "evm-yul-host-refinement-smoke: Counter IR↔Yul paired simulation + ValueVault lockstep + executable traces checked"
  return 0
