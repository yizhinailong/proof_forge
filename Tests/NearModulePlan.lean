/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# NearModulePlan golden + dual-path parity smoke

Build the `NearModulePlan` for a named fixture and write its rendered form to a
path provided on the command line. The shell gate compares the output to the
golden copy at `Examples/WasmNear/<Fixture>/golden/plan.txt`.

Step B (RFC 0014 Phase 4) extends this with a dual-path parity check: for each
fixture, lower via the plan-driven path (`NearModulePlan.renderModuleFromPlan`)
and via the existing inline path (`EmitWat.renderModule`), and assert the two
WAT outputs are byte-identical. This proves the plan-driven lowering preserves
semantics — the same guarantee Solana Phase 2 got with its `MATCH` assertions.

Fixtures covered:
- `Counter` — scalar state (the original MVP)
-/

import ProofForge.IR.Examples.Counter
import ProofForge.Backend.WasmNear.NearModulePlan
import ProofForge.Backend.WasmNear.EmitWat

namespace ProofForge.Tests.NearModulePlan

open ProofForge.Backend.WasmNear.NearModulePlan
open ProofForge.Backend.WasmNear.EmitWat
open ProofForge.IR

/-- Resolve a fixture name to its IR module. -/
def moduleFor (name : String) : Option Module :=
  match name with
  | "Counter" => some ProofForge.IR.Examples.Counter.module
  | _ => none

/-- Dual-path parity check: lower `mod` via the plan-driven path and the
existing inline path, return `ok n` (the shared char count) if the two WAT
outputs are byte-identical, or `error msg` otherwise. -/
def parityCheck (mod : Module) : Except String Nat := do
  let plan ← match buildNearModulePlan mod with
    | .ok p => pure p
    | .error e => .error s!"plan build failed: {e.message}"
  let planWAT ← match renderModuleFromPlan mod plan with
    | .ok s => pure s
    | .error e => .error s!"plan-driven render failed: {e.message}"
  let inlineWAT ← match renderModule mod with
    | .ok s => pure s
    | .error e => .error s!"inline render failed: {e.message}"
  if planWAT != inlineWAT then
    .error s!"WAT mismatch: plan-driven ({planWAT.length} chars) != inline ({inlineWAT.length} chars)"
  else .ok planWAT.length

def main (args : List String) : IO UInt32 := do
  let fixtureName := args[0]?.getD "Counter"
  let path := args[1]?.getD (s!"build/wasm-near/{fixtureName}.plan.txt")
  let runParity := args.contains "--parity"
  if args.length > 3 then
    IO.eprintln "usage: NearModulePlan <fixture> <output-path> [--parity]"
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
      if runParity then
        match parityCheck module with
        | .error msg =>
          IO.eprintln s!"PARITY FAIL ({fixtureName}): {msg}"
          return 1
        | .ok n =>
          IO.println s!"PARITY OK ({fixtureName}): MATCH {n} chars"
      return 0

end ProofForge.Tests.NearModulePlan

def main : List String → IO UInt32 :=
  ProofForge.Tests.NearModulePlan.main