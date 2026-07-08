/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Primary-chain materialization parity (EVM · Solana · Wasm-NEAR).
-/
import Examples.Shared.Counter
import ProofForge.Backend.Solana.Extension
import ProofForge.Target.Materialize
import ProofForge.Target.Registry

open ProofForge.Target
open ProofForge.Target.Materialize

def require (cond : Bool) (msg : String) : IO Unit :=
  if cond then pure () else throw (IO.userError msg)

def main : IO Unit := do
  let counter := Examples.Shared.Counter.module

  -- EVM
  let evmR := forEvm counter
  require (evmR.targetId == "evm") "EVM targetId"
  require (evmR.storageBinding == "contract-global") "EVM storageBinding"
  require (evmR.mode == .autoPortable) "EVM auto-portable for Shared Counter"
  require (evmR.layoutKind == "contract-global-slots") "EVM layoutKind"
  require (evmR.stateUnits == 1) "EVM stateUnits"
  require (evmR.entrypointCount == 3) "EVM entrypoints initialize/increment/get"
  require evmR.hostBridge?.isNone "EVM has no host bridge"

  -- Solana
  let solR := forSolana counter {}
  require (solR.targetId == "solana-sbpf-asm") "Solana targetId"
  require (solR.storageBinding == "account-data") "Solana storageBinding"
  require (solR.mode == .autoPortable) "Solana auto-portable for Shared Counter"
  require (solR.layoutKind == "account-data") "Solana layoutKind"
  require (solR.stateUnits == 1) "Solana stateUnits"
  require solR.hostBridge?.isNone "Solana has no host bridge"

  -- Wasm-NEAR
  let nearR := forWasmNear counter
  require (nearR.targetId == "wasm-near") "NEAR targetId"
  require (nearR.storageBinding == "host-key-value") "NEAR storageBinding"
  require (nearR.mode == .autoPortable) "NEAR auto-portable for Shared Counter"
  require (nearR.layoutKind == "host-key-value") "NEAR layoutKind"
  require (nearR.stateUnits == 1) "NEAR stateUnits"
  require (nearR.hostBridge? == some "near") "NEAR hostBridge"

  -- Profile dispatch
  require ((forPrimaryProfile evm counter).isSome) "forPrimaryProfile evm"
  require ((forPrimaryProfile solanaSbpfAsm counter).isSome) "forPrimaryProfile solana"
  require ((forPrimaryProfile wasmNear counter).isSome) "forPrimaryProfile wasm-near"

  -- Same portable module → three different bindings
  require (evmR.storageBinding != solR.storageBinding) "EVM ≠ Solana binding"
  require (solR.storageBinding != nearR.storageBinding) "Solana ≠ NEAR binding"
  require (evmR.storageBinding != nearR.storageBinding) "EVM ≠ NEAR binding"

  -- JSON shape
  for r in #[evmR, solR, nearR] do
    let js := Report.json r
    require (js.contains r.targetId) s!"json targetId {r.targetId}"
    require (js.contains "auto-portable") s!"json mode for {r.targetId}"

  IO.println "primary-materialize: ok (evm + solana + wasm-near)"
