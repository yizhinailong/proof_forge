/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Phase B.3: portable crosscall materialization on primary chains.
-/
import ProofForge.IR.Examples.CrosscallProbe
import ProofForge.IR.Examples.NearCrosscallProbe
import Examples.Shared.RemoteCall
import ProofForge.Backend.Evm.Plan
import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.PortableCrosscall
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.Backend.WasmNear.PortableCrosscall
import ProofForge.Backend.CosmWasm.EmitWat
import ProofForge.Backend.Psy.IR
import ProofForge.Target.CrosscallMaterialize
import ProofForge.Target.Registry

open ProofForge.Target
open ProofForge.Target.CrosscallMaterialize
open ProofForge.Backend.Solana.PortableCrosscall
open ProofForge.Backend.Solana.Manifest
open ProofForge.Backend.WasmNear.PortableCrosscall

def require (cond : Bool) (msg : String) : IO Unit :=
  if cond then pure () else throw (IO.userError msg)

def main : IO Unit := do
  let probe := ProofForge.IR.Examples.CrosscallProbe.module
  let nearProbe := ProofForge.IR.Examples.NearCrosscallProbe.module

  -- EVM: portable crosscall plan builds (CALL materialization).
  match ProofForge.Backend.Evm.Plan.buildModulePlan probe with
  | .error e => throw (IO.userError s!"EVM plan for CrosscallProbe failed: {e.message}")
  | .ok _ => pure ()
  require ((forProfile evm).nativeForm == NativeForm.evmCall) "EVM native form"

  -- Solana: portable scalar subset → CPI materialization (not EVM STATIC/DELEGATE/create).
  let solProbe := ProofForge.IR.Examples.CrosscallProbe.solanaPortableModule
  require (moduleHasPortableCrosscall solProbe) "solanaPortableModule has portable sites"
  let sites := collectSites solProbe
  require (sites.size > 0) "expected crosscall sites"
  match ProofForge.Target.resolveModule solanaSbpfAsm solProbe with
  | .error e => throw (IO.userError s!"Solana should accept portable crosscall.invoke: {e.render}")
  | .ok _ => pure ()
  let modAccounts := buildModuleAccounts solProbe {}
  require (modAccounts.any (fun a => a.name == "callee_program"))
    "Solana materialization should add callee_program for portable crosscall"
  match ProofForge.Backend.Solana.SbpfAsm.renderModule solProbe with
  | .error e => throw (IO.userError s!"Solana lower solanaPortableModule failed: {e.message}")
  | .ok src =>
      require (src.contains "portable crosscall") "asm should mark CPI materialization"
      require (src.contains "sol_invoke_signed_c") "asm packs real sol_invoke_signed_c"
      require (src.contains "AccountMeta") "asm packs account metas"
      require (src.contains "AccountInfo") "asm packs account infos"
      require (src.contains "sol_get_return_data") "asm decodes return data"
      require (src.contains "error_cpi") "asm traps CPI failures"

  -- NEAR: portable invoke → promise_create; full fixture still works.
  require ((forProfile wasmNear).nativeForm == NativeForm.nearPromise) "NEAR form"
  let nearPortable := ProofForge.IR.Examples.NearCrosscallProbe.portableModule
  require (moduleUsesPortableInvoke nearPortable) "portable NEAR uses crosscall.invoke"
  require (!moduleUsesPromiseExtension nearPortable) "portable NEAR has no promise constructors"
  match ProofForge.Backend.WasmNear.EmitWat.renderModule nearPortable with
  | .error e => throw (IO.userError s!"NEAR EmitWat portableModule failed: {e.message}")
  | .ok wat =>
      require (wat.contains "promise_create") "NEAR materializes promise_create"
  match ProofForge.Backend.WasmNear.EmitWat.renderModule nearProbe with
  | .error e => throw (IO.userError s!"NEAR EmitWat full NearCrosscallProbe failed: {e.message}")
  | .ok wat =>
      require (wat.contains "promise_create") "full fixture promise_create"
      require (wat.contains "promise_then") "extension path materializes promise_then"
  -- Honest reject when nearCrosscallStrings is empty (no silent EVM CALL).
  let bareNear : ProofForge.IR.Module := {
    name := "BareNearCrosscall"
    state := nearProbe.state
    entrypoints := #[ProofForge.IR.Examples.NearCrosscallProbe.callRemote]
  }
  match ProofForge.Backend.WasmNear.EmitWat.renderModule bareNear with
  | .ok _ => throw (IO.userError "NEAR bare crosscall without nearCrosscallStrings must fail")
  | .error e =>
      require (e.message.contains "nearCrosscallStrings" || e.message.contains "promise")
        s!"expected nearCrosscallStrings / promise diagnostic, got: {e.message}"

  -- Solana: EVM-only STATICCALL is rejected (not silently remapped to CPI).
  let staticOnly : ProofForge.IR.Module := {
    name := "StaticOnly"
    state := probe.state
    entrypoints := #[ProofForge.IR.Examples.CrosscallProbe.callRemoteStatic]
  }
  match ProofForge.Backend.Solana.SbpfAsm.renderModule staticOnly with
  | .ok _ => throw (IO.userError "Solana must reject STATICCALL")
  | .error e =>
      require (e.message.contains "STATICCALL" || e.message.contains "EVM-only")
        s!"expected STATICCALL reject, got: {e.message}"

  -- CosmWasm Counter spike: honest capability reject for portable crosscall.
  require ((forProfile wasmCosmWasm).nativeForm == NativeForm.cosmWasmMsg) "CosmWasm form"
  match ProofForge.Backend.CosmWasm.EmitWat.checkCapabilities solProbe with
  | .ok _ => throw (IO.userError "CosmWasm spike must reject crosscall.invoke capability")
  | .error e =>
      require (e.message.contains "not supported" || e.message.contains "crosscall")
        s!"expected CosmWasm capability reject, got: {e.message}"

  -- Psy: untyped U64 crosscall accepted; typed/create rejected.
  require ((forProfile psyDpn).nativeForm == NativeForm.zkCircuitCall) "Psy form"
  let psyMod := ProofForge.IR.Examples.CrosscallProbe.psyModule
  match ProofForge.Backend.Psy.IR.buildModule psyMod with
  | .error e => throw (IO.userError s!"Psy should accept untyped crosscall.invoke: {e.message}")
  | .ok _ => pure ()
  match ProofForge.Backend.Psy.IR.buildModule staticOnly with
  | .ok _ => throw (IO.userError "Psy must reject STATICCALL-shaped crosscall")
  | .error e =>
      require (e.message.contains "static" || e.message.contains "not supported" ||
          e.message.contains "U64")
        s!"expected Psy static reject, got: {e.message}"

  require ((forProfile aleoLeo).nativeForm == NativeForm.zkCircuitCall) "Aleo form"
  require ((forProfile solanaSbpfAsm).nativeForm == NativeForm.solanaCpi) "Solana form"
  require ((forProfile moveAptos).nativeForm == NativeForm.moveCall) "Aptos form"
  require ((forProfile moveSui).nativeForm == NativeForm.moveCall) "Sui form"

  -- Shared portable RemoteCall (contract_source + remoteCall) multi-target.
  let shared := Examples.Shared.RemoteCall.module
  require (moduleHasPortableCrosscall shared) "Shared.RemoteCall has portable crosscall"
  match ProofForge.Backend.Evm.Plan.buildModulePlan shared with
  | .error e => throw (IO.userError s!"EVM plan Shared.RemoteCall failed: {e.message}")
  | .ok _ => pure ()
  match ProofForge.Target.resolveModule solanaSbpfAsm shared with
  | .error e => throw (IO.userError s!"Solana resolve Shared.RemoteCall: {e.render}")
  | .ok _ => pure ()
  match ProofForge.Backend.Solana.SbpfAsm.renderModule shared with
  | .error e => throw (IO.userError s!"Solana lower Shared.RemoteCall: {e.message}")
  | .ok src =>
      require (src.contains "sol_invoke_signed_c") "Shared.RemoteCall Solana CPI"
      require (src.contains "sol_get_return_data") "Shared.RemoteCall return-data"
  -- NEAR needs string-pool metadata for account/method names; use portable IR probe.
  match ProofForge.Backend.WasmNear.EmitWat.renderModule nearPortable with
  | .error e => throw (IO.userError s!"NEAR portable path for multi-target failed: {e.message}")
  | .ok wat => require (wat.contains "promise_create") "NEAR multi-target promise_create"

  IO.println "crosscall-materialize: ok (evm·solana·near + shared RemoteCall + honest secondary)"
