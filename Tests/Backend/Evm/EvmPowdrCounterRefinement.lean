import EvmRefinement.CounterRefinement

/-! ## EVM powdr Counter bytecode refinement smoke (opt-in, mathlib)

Pins the opt-in powdr EVM bytecode lane for Counter:
- compiled Counter bytecode runs through powdr `stepF`/`runBytecode` and
  produces the expected observables;
- the same `TraceObligation` passes both the IR reference trace and the
  powdr bytecode trace (delivery-boundary pin);
- the universal fragment refinement theorem covers all Counter-shaped modules.

This test imports `EvmRefinement` and therefore pulls powdr + mathlib; it is
intentionally not on the default `lake build` path.
-/

namespace ProofForge.Tests.EvmPowdrCounterRefinement

open ProofForge.Backend.Evm.CounterRefinement

#check counterCompiledPowdr_executable_trace_ok
#check counterCompiledPowdr_ir_and_target_trace_match
#check counterCompiledPowdr_initialize_executable_smoke
#check counterCompiledPowdr_get_zero_executable_smoke
#check counterCompiledPowdr_initialize_increment_get_executable_smoke
#check evmCompiledPowdr_fragment_refines_all

end ProofForge.Tests.EvmPowdrCounterRefinement

def main : IO UInt32 := do
  IO.println "evm-powdr-counter-refinement-smoke: Counter IR↔powdr bytecode delivery boundary pinned"
  return 0
