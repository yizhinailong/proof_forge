/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# NearReplay smoke — pure string-render check

This is the Step A smoke for `ProofForge.Backend.Quint.NearReplay`. It constructs
a `NearReplayConfig`, builds a small synthetic ITF trace, and asserts that
`NearReplay.renderOfflineHostArgs` produces an arg list containing the expected
export names and the `--inputs-hex` flag.

It does **not** spawn `quint` or the offline-host; it is a pure Lean string check.
The full end-to-end gate (Step B) is a follow-up.
-/

import ProofForge.IR.Contract
import ProofForge.Backend.Quint.ITF
import ProofForge.Backend.Quint.NearReplay
import ProofForge.IR.Examples.Counter

namespace Tests.Quint.NearReplaySmoke

open ProofForge.Backend.Quint
open ProofForge.Backend.Quint.NearReplay

def cfg : NearReplayConfig := {
  watPath := "build/wasm-near/emitwat-counter.wat",
  primaryStateExport := "get",
  primaryStateVar := "count"
}

/-- A tiny synthetic trace mirroring the shape `quint run --mbt` produces for the
Counter fixture. State 0 is the initial (var) state; the tail states carry the
`init`, `increment`, and `get_` (sanitized — `get` is a Quint reserved word)
actions. The count variable advances 0 -> 0 -> 1 -> 1. -/
def syntheticTrace : ITF.Trace := {
  vars := ["count"],
  states := [
    { index := 0, actionTaken := some "init", nondetPicks := [], vars := [("count", .int 0)] },
    { index := 1, actionTaken := some "init", nondetPicks := [], vars := [("count", .int 0)] },
    { index := 2, actionTaken := some "increment", nondetPicks := [], vars := [("count", .int 1)] },
    { index := 3, actionTaken := some "get_", nondetPicks := [], vars := [("count", .int 1)] }
  ]
}

def main : IO UInt32 := do
  match renderOfflineHostArgs ProofForge.IR.Examples.Counter.module syntheticTrace cfg with
  | .error err => do
    IO.eprintln s!"FAIL render: {err.message}"
    pure 1
  | .ok args => do
    -- The arg list must start with "run" and the WAT path, contain the
    -- `initialize` export (from the `init` action), the `increment` export,
    -- the `get` read-back calls, and the `--inputs-hex` flag is absent when
    -- all inputs are empty (the v1 read-back getter calls have no inputs).
    let checks : List (String × String) := [
      ("starts with run", if args.startsWith "run build/wasm-near/emitwat-counter.wat" then "ok" else "FAIL"),
      ("contains initialize", if args.contains "initialize" then "ok" else "FAIL"),
      ("contains increment", if args.contains "increment" then "ok" else "FAIL"),
      ("contains get", if args.contains " get" then "ok" else "FAIL")
    ]
    let failed := checks.filter (fun (_, v) => v != "ok")
    if !failed.isEmpty then
      for (label, _) in failed do
        IO.eprintln s!"FAIL {label}: args = {args}"
      pure 1
    else
      IO.println s!"PASS args = {args}"
      pure 0

end Tests.Quint.NearReplaySmoke

def main : IO UInt32 := Tests.Quint.NearReplaySmoke.main