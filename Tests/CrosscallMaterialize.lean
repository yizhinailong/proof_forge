/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Phase B.3: portable crosscall materialization on primary chains.
-/
import ProofForge.IR.Examples.CrosscallProbe
import ProofForge.IR.Examples.NearCrosscallProbe
import ProofForge.Backend.Evm.Plan
import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.PortableCrosscall
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.Target.CrosscallMaterialize
import ProofForge.Target.Registry

open ProofForge.Target
open ProofForge.Target.CrosscallMaterialize
open ProofForge.Backend.Solana.PortableCrosscall
open ProofForge.Backend.Solana.Manifest

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
      require (src.contains "error_cpi") "asm traps CPI failures"

  -- NEAR: string-pool Promise path for NearCrosscallProbe.
  require ((forProfile wasmNear).nativeForm == NativeForm.nearPromise) "NEAR form"
  match ProofForge.Backend.WasmNear.EmitWat.renderModule nearProbe with
  | .error e => throw (IO.userError s!"NEAR EmitWat NearCrosscallProbe failed: {e.message}")
  | .ok wat =>
      require (wat.contains "promise_create") "NEAR materializes promise_create"
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

  -- CosmWasm / Psy / Aleo forms are declared (honest mapping).
  require ((forProfile wasmCosmWasm).nativeForm == NativeForm.cosmWasmMsg) "CosmWasm form"
  require ((forProfile psyDpn).nativeForm == NativeForm.zkCircuitCall) "Psy form"
  require ((forProfile aleoLeo).nativeForm == NativeForm.zkCircuitCall) "Aleo form"
  require ((forProfile solanaSbpfAsm).nativeForm == NativeForm.solanaCpi) "Solana form"

  IO.println "crosscall-materialize: ok (evm plan + solana CPI mat + near promise)"
