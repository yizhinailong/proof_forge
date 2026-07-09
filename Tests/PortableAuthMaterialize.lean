/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable business checks (Ownable / require*) materialize on EVM · Solana ·
NEAR · Soroban without chain DSL in source.
-/
import Examples.Shared.Ownable
import Examples.Shared.RemoteCall
import ProofForge.Backend.Evm.Plan
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.Target.HostBridge
import ProofForge.Target.Preflight
import ProofForge.Target.Registry

open ProofForge.Target
open ProofForge.Target.Preflight

def require (cond : Bool) (msg : String) : IO Unit :=
  if cond then pure () else throw (IO.userError msg)

def main : IO Unit := do
  let ownable := Examples.Shared.Ownable.module
  let remote := Examples.Shared.RemoteCall.module

  -- Source must stay free of host string-pool / Promise APIs (product path).
  require (!remote.nearCrosscallStrings.isEmpty)
    "declareRemoteUnit must populate host string pool for Wasm materialize"
  require (remote.nearCrosscallStrings[0]? == some "callee.example.near")
    "peer deployment id registered"
  require (remote.nearCrosscallStrings[1]? == some "remote_call")
    "method id registered"

  -- Ownable: business guard_owner / require* → each backend's native fail.
  match ProofForge.Backend.Evm.Plan.buildModulePlan ownable with
  | .error e => throw (IO.userError s!"EVM Ownable plan: {e.message}")
  | .ok _ => pure ()

  match ProofForge.Backend.Solana.SbpfAsm.renderModule ownable with
  | .error e => throw (IO.userError s!"Solana Ownable lower: {e.message}")
  | .ok src =>
      require (src.contains "assert" || src.contains "assert_fail" || src.contains "error_")
        "Solana Ownable should emit assert/trap materialization for business checks"

  match ProofForge.Backend.WasmNear.EmitWat.renderModule ownable with
  | .error e => throw (IO.userError s!"NEAR Ownable lower: {e.message}")
  | .ok wat =>
      -- assert without ErrorRef → `unreachable`; with ref → env.panic
      require (wat.contains "unreachable" || wat.contains "panic")
        "NEAR Ownable business checks materialize as unreachable/panic"
      require (!wat.contains "promise_create")
        "Ownable has no crosscall; no promise_create"

  match ProofForge.Backend.WasmNear.EmitWat.renderModule ownable .soroban with
  | .error e => throw (IO.userError s!"Soroban Ownable lower: {e.message}")
  | .ok wat =>
      require (wat.contains "unreachable" || wat.contains "panic")
        "Soroban Ownable reuses EmitWat assert fail for business checks"
      require (!wat.contains "promise_create")
        "Soroban Ownable must not import NEAR promise_create"
      require (!wat.contains "invoke_contract")
        "Ownable has no portable crosscall"

  -- RemoteCall on Soroban host bridge: invoke_contract, not promise.
  match ProofForge.Backend.WasmNear.EmitWat.renderModule remote .soroban with
  | .error e => throw (IO.userError s!"Soroban RemoteCall: {e.message}")
  | .ok wat =>
      require (wat.contains "invoke_contract")
        "Soroban RemoteCall → invoke_contract"
      require (!wat.contains "promise_create")
        "Soroban RemoteCall must not use promise_create"

  -- Preflight primary + Soroban ready for Ownable and RemoteCall.
  for mod in #[ownable, remote] do
    let reps := runPrimaryWithSoroban mod
    require (reps.size == 4) "primary+soroban size"
    for r in reps do
      require r.readyToMaterialize
        s!"preflight should be ready for {r.targetId} on {mod.name}: {r.note}"

  IO.println "portable-auth-materialize: ok (Ownable checks + RemoteCall declareRemote · EVM·Solana·NEAR·Soroban)"
