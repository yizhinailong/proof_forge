/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Smoke entry for the opt-in solanalib CompileCorrect surface.
-/

import SolanaRefinement.CompileCorrect

namespace ProofForge.Backend.Solana.CompileCorrectSmoke

open ProofForge.Backend.Solana.CompileCorrect
open ProofForge.Backend.Solana.SolanalibAdapter

#check counter_bpf_encode_ok
#check counter_solanalib_pipeline_ok
#check counter_compile_pipeline_ok
#check verified_instr_step_ne_err
#check counter_labeled_view_ok
#check counter_direct_lift_verify_ok
#check counter_direct_lift_eq_decode
#check counter_core_tail_host_bridge_ok
#check counter_full_program_host_bridge_ok
#check counter_full_program_diff_bridge_ok

end ProofForge.Backend.Solana.CompileCorrectSmoke

def main : IO UInt32 := do
  IO.println "solana-solanalib-compile-correct-smoke: Counter encode + labeled lift + core-tail + full-program host + step_ne_err re-export checked"
  pure 0
