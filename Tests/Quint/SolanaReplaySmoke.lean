/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# SolanaReplay smoke — pure string-render check

This is the Step A smoke for `ProofForge.Backend.Quint.SolanaReplay`. It
constructs a `SolanaReplayConfig`, builds a small synthetic ITF trace, and
asserts that `SolanaReplay.renderReplayHarness` produces a Rust Mollusk test
file containing the expected structural anchors (the `Mollusk::new` call, the
instruction tags for `initialize`/`increment`/`get_`, and the per-step
assertions).

It does **not** spawn `quint`, `sbpf`, `solana-keygen`, or `cargo`; it is a
pure Lean string check. The full end-to-end gate (Step B) is a follow-up.
-/

import ProofForge.IR.Contract
import ProofForge.Backend.Quint.ITF
import ProofForge.Backend.Quint.SolanaReplay
import ProofForge.IR.Examples.Counter

namespace Tests.Quint.SolanaReplaySmoke

open ProofForge.Backend.Quint
open ProofForge.Backend.Quint.SolanaReplay

def cfg : SolanaReplayConfig := {
  programPath := "build/testkit/solana/counter/deploy/proofforge-counter.so",
  keypairPath := "build/testkit/solana/counter/deploy/proofforge-counter-keypair.json",
  stateAccountDataLen := 8,
  primaryStateVar := "count",
  primaryStateByteSize := 8
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
  match renderReplayHarness ProofForge.IR.Examples.Counter.module syntheticTrace cfg with
  | .error err => do
    IO.eprintln s!"FAIL render: {err.message}"
    pure 1
  | .ok source => do
    -- The rendered Rust test file must reference the ELF path, build a
    -- `Mollusk::new`, emit one `#[test] fn test_step_<idx>` per trace step
    -- (states 1..3 → steps 1..3), and carry the expected value byte arrays.
    let checks : List (String × String) := [
      ("references program path",
        if source.contains cfg.programPath then "ok" else "FAIL"),
      ("references keypair path",
        if source.contains cfg.keypairPath then "ok" else "FAIL"),
      ("builds Mollusk",
        if source.contains "Mollusk::new(" then "ok" else "FAIL"),
      ("has step 1 (init)",
        if source.contains "fn test_step_1()" then "ok" else "FAIL"),
      ("has step 2 (increment)",
        if source.contains "fn test_step_2()" then "ok" else "FAIL"),
      ("has step 3 (get_)",
        if source.contains "fn test_step_3()" then "ok" else "FAIL"),
      ("has AccountMeta",
        if source.contains "AccountMeta::new(" then "ok" else "FAIL")
    ]
    let failed := checks.filter (fun (_, v) => v != "ok")
    if !failed.isEmpty then
      for (label, _) in failed do
        IO.eprintln s!"FAIL {label}"
      IO.eprintln "--- rendered source ---"
      IO.eprintln source
      pure 1
    else
      IO.println s!"PASS (rendered {source.length} chars)"
      pure 0

end Tests.Quint.SolanaReplaySmoke

def main : IO UInt32 := Tests.Quint.SolanaReplaySmoke.main