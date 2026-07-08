/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Primary-chain materialization report (EVM · Solana · Wasm-NEAR)

Product north star: authors write portable business logic; `--target` selects
one of the three primary chains and the adapter materializes native form.

This module is the **shared product vocabulary** for that step:

* EVM → contract-global storage slots + ABI/Yul
* Solana → account-data layout (+ optional extension accounts/CPI)
* Wasm-NEAR → host key/value storage + host imports

Chain-specific detail modules (e.g. `Backend.Solana.Materialize`) feed into the
same JSON shape so artifacts are comparable across targets.
-/
import ProofForge.IR.Contract
import ProofForge.Target.Registry
import ProofForge.Target.StorageBinding
import ProofForge.Target.HostBridge
import ProofForge.Backend.Solana.Extension.Types
import ProofForge.Backend.Solana.Materialize

namespace ProofForge.Target.Materialize

open ProofForge.IR
open ProofForge.Target

/-- How native layout was obtained for this build. -/
inductive Mode where
  | autoPortable
  | extensionDeclared
  deriving BEq, DecidableEq, Repr

def Mode.id : Mode → String
  | .autoPortable => "auto-portable"
  | .extensionDeclared => "extension-declared"

/-- Unified materialization summary for a primary-chain build. -/
structure Report where
  targetId : String
  targetFamily : String
  storageBinding : String
  mode : Mode
  layoutKind : String
  hostBridge? : Option String := none
  stateUnits : Nat
  entrypointCount : Nat
  note : String
  deriving Repr

private def jsonStr (s : String) : String := "\"" ++ s ++ "\""

private def jsonOptStr : Option String → String
  | none => "null"
  | some s => jsonStr s

def Report.json (r : Report) : String :=
  "{" ++
  "\"targetId\":" ++ jsonStr r.targetId ++ "," ++
  "\"targetFamily\":" ++ jsonStr r.targetFamily ++ "," ++
  "\"storageBinding\":" ++ jsonStr r.storageBinding ++ "," ++
  "\"mode\":" ++ jsonStr r.mode.id ++ "," ++
  "\"layoutKind\":" ++ jsonStr r.layoutKind ++ "," ++
  "\"hostBridge\":" ++ jsonOptStr r.hostBridge? ++ "," ++
  "\"stateUnits\":" ++ toString r.stateUnits ++ "," ++
  "\"entrypointCount\":" ++ toString r.entrypointCount ++ "," ++
  "\"note\":" ++ jsonStr r.note ++
  "}"

/-- EVM: portable state → contract-global slots. Proxy pattern is extension. -/
def forEvm (module : Module) : Report :=
  let mode :=
    match module.proxyPattern? with
    | some _ => .extensionDeclared
    | none => .autoPortable
  { targetId := "evm"
    targetFamily := "evm"
    storageBinding := StorageBinding.contractGlobal.id
    mode := mode
    layoutKind := "contract-global-slots"
    hostBridge? := none
    stateUnits := module.state.size
    entrypointCount := module.entrypoints.size
    note :=
      match mode with
      | .autoPortable =>
          "EVM storage slots and ABI synthesized from portable IR (no chain DSL authoring)"
      | .extensionDeclared =>
          "EVM layout includes declared proxy/extension metadata" }

/-- Solana: portable state → default program-owned account; extensions merge PDA/CPI. -/
def forSolana (module : Module)
    (ext : ProofForge.Backend.Solana.Extension.ProgramExtensions := {}) : Report :=
  let sol := ProofForge.Backend.Solana.Materialize.report module ext
  let mode :=
    match sol.mode with
    | .autoPortable => Mode.autoPortable
    | .extensionDeclared => Mode.extensionDeclared
  { targetId := "solana-sbpf-asm"
    targetFamily := "solana"
    storageBinding := StorageBinding.accountData.id
    mode := mode
    layoutKind := "account-data"
    hostBridge? := none
    stateUnits := sol.stateAccountCount
    entrypointCount := module.entrypoints.size
    note := sol.note }

/-- Wasm-NEAR: portable state → host KV; Promise/string pool is extension surface. -/
def forWasmNear (module : Module) : Report :=
  let hasNearExt :=
    !module.nearCrosscallStrings.isEmpty ||
    module.capabilities.any (fun c => c == .nearPromise)
  let mode := if hasNearExt then Mode.extensionDeclared else Mode.autoPortable
  { targetId := "wasm-near"
    targetFamily := "wasm-host"
    storageBinding := StorageBinding.hostKeyValue.id
    mode := mode
    layoutKind := "host-key-value"
    hostBridge? := some HostBridge.near.id
    stateUnits := module.state.size
    entrypointCount := module.entrypoints.size
    note :=
      match mode with
      | .autoPortable =>
          "NEAR host storage keys and imports synthesized from portable IR (no Promise authoring)"
      | .extensionDeclared =>
          "NEAR layout includes Promise / host-string-pool extension surface" }

/-- Dispatch by target profile for the three primary product chains. -/
def forPrimaryProfile (profile : TargetProfile) (module : Module)
    (solanaExt : ProofForge.Backend.Solana.Extension.ProgramExtensions := {}) :
    Option Report :=
  match profile.id with
  | "evm" => some (forEvm module)
  | "solana-sbpf-asm" => some (forSolana module solanaExt)
  | "wasm-near" => some (forWasmNear module)
  | _ =>
      match profile.family with
      | .evm => some (forEvm module)
      | .solana => some (forSolana module solanaExt)
      | .wasmHost =>
          -- Default Wasm-host report uses NEAR-shaped host KV notes; hostBridge
          -- is taken from the profile when present.
          let base := forWasmNear module
          some {
            base with
            targetId := profile.id
            hostBridge? := profile.hostBridge?.map (·.id)
            storageBinding := profile.storageBinding.id
          }
      | _ => none

end ProofForge.Target.Materialize
