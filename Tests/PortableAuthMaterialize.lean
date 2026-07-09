/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable business checks (Ownable / require*) materialize on EVM · Solana ·
NEAR · Soroban without chain DSL in source.
-/
import Examples.Shared.Ownable
import Examples.Shared.RemoteCall
import ProofForge.Backend.Evm.Plan
import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.Target.HostBridge
import ProofForge.Target.PeerMap
import ProofForge.Target.Preflight
import ProofForge.Target.Registry

open ProofForge.Target
open ProofForge.Target.Preflight
open ProofForge.Backend.Solana.Manifest

def require (cond : Bool) (msg : String) : IO Unit :=
  if cond then pure () else throw (IO.userError msg)

def main : IO Unit := do
  let ownable := Examples.Shared.Ownable.module
  let remote := Examples.Shared.RemoteCall.module

  -- C.6: Shared holds logical peers; deploy PeerMap rewrites host ids.
  require (!remote.nearCrosscallStrings.isEmpty)
    "declareRemoteUnit must populate host string pool for Wasm materialize"
  require (remote.nearCrosscallStrings[0]? == some "peer.callee")
    "logical peer id in Shared (not chain account)"
  require (remote.nearCrosscallStrings[1]? == some "remote_call")
    "method id registered"
  let deployed := PeerMap.applyToModule remote PeerMap.nearDemo
  require (deployed.nearCrosscallStrings[0]? == some "callee.example.near")
    "PeerMap.nearDemo rewrites peer.callee → callee.example.near"
  require (deployed.nearCrosscallStrings[1]? == some "remote_call")
    "unmapped method id stays as declared"

  -- Ownable: business guard_owner / require* → each backend's native fail.
  match ProofForge.Backend.Evm.Plan.buildModulePlan ownable with
  | .error e => throw (IO.userError s!"EVM Ownable plan: {e.message}")
  | .ok _ => pure ()

  -- C.3: portable Ownable synthesizes leading `authority` signer so userId
  -- is the tx authority, not the program state account.
  let ownableAccounts := buildModuleAccounts ownable {}
  require (ownableAccounts.any (fun a => a.name == "authority" && a.signer))
    "Ownable Solana schema must synthesize authority signer for caller"
  require (
      match ownableAccounts[0]? with
      | some a => a.signer
      | none => false)
    "authority/signer must lead account list so context.userId is correct"
  require (ownableAccounts.any (fun a => a.name == "owner" && a.owner == "program"))
    "Ownable state account remains program-owned data"

  match ProofForge.Backend.Solana.SbpfAsm.renderModule ownable with
  | .error e => throw (IO.userError s!"Solana Ownable lower: {e.message}")
  | .ok src =>
      require (src.contains "assert" || src.contains "assert_fail" || src.contains "error_")
        "Solana Ownable should emit assert/trap materialization for business checks"
      require (src.contains "account.validation[0:authority]: signer=true" ||
          src.contains "signer=true")
        "Solana Ownable prologue validates authority signer"
      require (src.contains "control.assert" || src.contains "assert_eq" ||
          src.contains "assert_fail")
        "guard_owner materializes as control.assert"

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
      -- C.8: scalar storage on Soroban host names, not NEAR storage_*.
      require (wat.contains "_get" || wat.contains "_put")
        "Soroban Ownable storage should import/call _get/_put"
      require (!wat.contains "storage_read" && !wat.contains "storage_write")
        "Soroban Ownable must not import NEAR storage_read/write"
      -- C.9: caller-using entrypoints emit require_auth_for_args prologue.
      require (wat.contains "require_auth_for_args")
        "Soroban Ownable with caller should emit require_auth_for_args"

  -- RemoteCall on Soroban host bridge: invoke_contract, not promise.
  match ProofForge.Backend.WasmNear.EmitWat.renderModule remote .soroban with
  | .error e => throw (IO.userError s!"Soroban RemoteCall: {e.message}")
  | .ok wat =>
      require (wat.contains "invoke_contract")
        "Soroban RemoteCall → invoke_contract"
      require (!wat.contains "promise_create")
        "Soroban RemoteCall must not use promise_create"
      require (wat.contains "peer.callee")
        "Soroban WAT keeps logical peer without PeerMap"
  -- Deploy map applied at emit: host account appears in pool data.
  match ProofForge.Backend.WasmNear.EmitWat.renderModule remote .near PeerMap.nearDemo with
  | .error e => throw (IO.userError s!"NEAR RemoteCall with PeerMap: {e.message}")
  | .ok wat =>
      require (wat.contains "promise_create") "NEAR still promise_create"
      require (wat.contains "callee.example.near")
        "PeerMap.nearDemo embeds host account in WAT"
      require (!wat.contains "peer.callee")
        "logical peer should be rewritten after PeerMap"

  -- Preflight primary + Soroban ready for Ownable and RemoteCall.
  for mod in #[ownable, remote] do
    let reps := runPrimaryWithSoroban mod
    require (reps.size == 4) "primary+soroban size"
    for r in reps do
      require r.readyToMaterialize
        s!"preflight should be ready for {r.targetId} on {mod.name}: {r.note}"

  IO.println "portable-auth-materialize: ok (Ownable checks + RemoteCall declareRemote · EVM·Solana·NEAR·Soroban)"
