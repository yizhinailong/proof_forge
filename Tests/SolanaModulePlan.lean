/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# SolanaModulePlan golden smoke

Build the Solana semantic plan for the Counter fixture and write it to a path
provided on the command line. The shell gate compares the output to the golden
copy at `Examples/Solana/Counter/golden/plan.txt`.
-/

import ProofForge.IR.Examples.Counter
import ProofForge.Backend.Solana.Plan

namespace ProofForge.Tests.SolanaModulePlan

open ProofForge.Backend.Solana.Plan

def main (args : List String) : IO UInt32 := do
  let path := match args with
    | [path] => path
    | _ => "build/solana/Counter.plan.txt"
  match buildSolanaModulePlan ProofForge.IR.Examples.Counter.module with
  | .error err =>
      IO.eprintln s!"failed to build SolanaModulePlan: {err.render}"
      return 1
  | .ok plan =>
      let rendered := plan.render
      IO.FS.writeFile path rendered
      IO.println s!"wrote SolanaModulePlan to {path}"
      return 0

end ProofForge.Tests.SolanaModulePlan

def main : List String → IO UInt32 :=
  ProofForge.Tests.SolanaModulePlan.main
