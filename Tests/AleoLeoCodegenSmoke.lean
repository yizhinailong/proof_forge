import ProofForge.Backend.Aleo.IR
import ProofForge.IR.Examples.Counter
import ProofForge.Target.Registry

/-! Aleo/Leo codegen + registry smoke (Phase 4 ZK lane, Road 1 sourcegen).

This is the Lean-side gate for the `aleo-leo` registry target. It checks:

1. `aleo-leo` is a registered target profile (in `Target.Registry.all` /
   `knownIds`), so `proof-forge --list-targets` exposes it.
2. The portable IR `Counter` fixture lowers to a Leo program without error
   (`ProofForge.Backend.Aleo.IR.renderModule`).
3. The lowered output contains the expected Leo structure markers for the
   Road 1 Counter spike: `program counter.aleo`, a `mapping count`, an
   `@noupgrade constructor`, `fn initialize`, `fn increment`, `fn get`, and
   `Final` blocks.

The heavier end-to-end gate (`leo build` + `leo test` + artifact metadata)
lives in `scripts/aleo/counter-smoke.sh` and the GitHub CI `aleo-smoke` job;
this Lean gate is the in-repo codegen witness that runs in `just check`
without needing the external `leo` CLI. -/

namespace ProofForge.Tests.AleoLeoCodegenSmoke

open ProofForge.Backend.Aleo.IR
open ProofForge.Target
open ProofForge.IR.Examples.Counter

theorem aleo_leo_in_registry : Target.all.any (fun p => p.id == "aleo-leo") = true := by
  native_decide

theorem aleo_leo_in_known_ids : Target.knownIds.contains "aleo-leo" = true := by
  native_decide

/-- The Counter fixture lowers to a Leo program without error. -/
def counterLowersOk : Bool :=
  match renderModule module with
  | .ok _ => true
  | .error _ => false

theorem counter_lowers_ok : counterLowersOk = true := by
  native_decide

/-- The lowered Leo source contains the Road 1 Counter spike structure markers. -/
def counterLeoHasMarkers : Bool :=
  match renderModule module with
  | .ok s =>
      s.contains "program counter.aleo" &&
      s.contains "mapping count" &&
      s.contains "@noupgrade" &&
      s.contains "constructor" &&
      s.contains "fn initialize" &&
      s.contains "fn increment" &&
      s.contains "fn get" &&
      s.contains "Final"
  | .error _ => false

theorem counter_leo_has_markers : counterLeoHasMarkers = true := by
  native_decide

example : True := by
  have _ := @aleo_leo_in_registry
  have _ := @aleo_leo_in_known_ids
  have _ := @counter_lowers_ok
  have _ := @counter_leo_has_markers
  exact True.intro

end ProofForge.Tests.AleoLeoCodegenSmoke

def main : IO UInt32 := do
  IO.println "aleo-leo-codegen-smoke: aleo-leo registry entry + Counter Leo codegen + structure markers checked"
  return 0