/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# NearModulePlan golden smoke

Build the `NearModulePlan` for a named fixture and write its rendered form to a
path provided on the command line. The shell gate compares the output to the
golden copy at `Examples/WasmNear/<Fixture>/golden/plan.txt`.

This is the Step A type-only stub smoke (RFC 0014 Phase 4). The plan is built but
**not** wired into `EmitWat.lowerModule`; it only verifies the plan can be built
deterministically and rendered as a stable text artifact.

Fixtures covered:
- `Counter` — scalar state (the original MVP)
-/

import ProofForge.IR.Examples.Counter
import ProofForge.Backend.WasmNear.NearModulePlan

namespace ProofForge.Tests.NearModulePlan

open ProofForge.Backend.WasmNear.NearModulePlan
open ProofForge.IR

/-- Resolve a fixture name to its IR module. -/
def moduleFor (name : String) : Option Module :=
  match name with
  | "Counter" => some ProofForge.IR.Examples.Counter.module
  | _ => none

def main (args : List String) : IO UInt32 := do
  let fixtureName := args[0]?.getD "Counter"
  let path := args[1]?.getD (s!"build/wasm-near/{fixtureName}.plan.txt")
  if args.length > 2 then
    IO.eprintln "usage: NearModulePlan <fixture> <output-path>"
    return 2
  match moduleFor fixtureName with
  | none =>
    IO.eprintln s!"unknown fixture: {fixtureName}"
    return 2
  | some module =>
    match buildNearModulePlan module with
    | .error err =>
      IO.eprintln s!"failed to build NearModulePlan for {fixtureName}: {err.message}"
      return 1
    | .ok plan =>
      let rendered := plan.render
      IO.FS.writeFile path rendered
      IO.println s!"wrote NearModulePlan ({fixtureName}) to {path}"
      return 0

end ProofForge.Tests.NearModulePlan

def main : List String → IO UInt32 :=
  ProofForge.Tests.NearModulePlan.main