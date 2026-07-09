/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

T3.2: Solana account auto-fill for transfer / remote / native-value intents
without Source.Solana authoring.
-/
import Examples.Shared.AuthRemoteCall
import Examples.Shared.Ownable
import Examples.Shared.RemoteCall
import Examples.Shared.RoleGatedToken
import Examples.Shared.StakingVault
import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.Materialize
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.IR.Contract

namespace ProofForge.Tests.SolanaPortableAccounts

open ProofForge.Backend.Solana.Manifest
open ProofForge.Backend.Solana.Materialize
open ProofForge.IR

def require (cond : Bool) (msg : String) : IO Unit :=
  if cond then pure () else throw (IO.userError msg)

def leading (accounts : Array AccountEntry) : IO AccountEntry :=
  match accounts[0]? with
  | some a => pure a
  | none => throw (IO.userError "empty account schema")

def hasNamed (accounts : Array AccountEntry) (name : String) : Bool :=
  accounts.any (fun a => a.name == name)

def hasSigner (accounts : Array AccountEntry) : Bool :=
  accounts.any (fun a => a.signer)

def hasProgramState (accounts : Array AccountEntry) : Bool :=
  accounts.any (fun a => a.owner == "program" && a.writable)

def mustRender (label : String) (m : Module) : IO String := do
  match ProofForge.Backend.Solana.SbpfAsm.renderModule m with
  | .ok src => pure src
  | .error e => throw (IO.userError s!"{label} SbpfAsm: {e.message}")

/-- Pure Ownable: authority non-writable (no nativeValue). -/
def testOwnableAuth : IO Unit := do
  let m := Examples.Shared.Ownable.module
  let accounts := buildModuleAccounts m {}
  let head ← leading accounts
  require head.signer "Ownable: leading account must be signer"
  require (!head.writable) "Ownable: pure auth authority stays non-writable"
  require (head.name == "authority") "Ownable: authority name"
  require (hasProgramState accounts) "Ownable: program state present"
  let src ← mustRender "Ownable" m
  require (src.contains "account.validation") "Ownable prologue"

/-- Remote-only: state + payer + callee_program (no caller). -/
def testRemoteCall : IO Unit := do
  let m := Examples.Shared.RemoteCall.module
  let accounts := buildModuleAccounts m {}
  require (hasNamed accounts "callee_program") "RemoteCall: callee_program"
  require (hasSigner accounts) "RemoteCall: fee payer / signer"
  require (hasProgramState accounts) "RemoteCall: state account"
  let src ← mustRender "RemoteCall" m
  require (src.contains "sol_invoke_signed_c") "RemoteCall CPI"
  require (src.contains "callee_program" || src.contains "executable")
    "RemoteCall validates callee"

/-- Transfer-style map debit: leading authority for caller. -/
def testRoleGatedTokenTransfer : IO Unit := do
  let m := Examples.Shared.RoleGatedToken.module
  let accounts := buildModuleAccounts m {}
  let head ← leading accounts
  require head.signer "RoleGatedToken: caller needs leading signer"
  require (hasProgramState accounts) "RoleGatedToken: state"
  let src ← mustRender "RoleGatedToken" m
  require (src.contains "account.validation") "RoleGatedToken prologue"
  let report := report m {}
  require (report.note.contains "transfer/auth" || report.note.contains "callerIdentity")
    "RoleGatedToken materialize note mentions auth autofill"

/-- Staking deposit uses nativeValue: leading signer must be writable. -/
def testStakingVaultNative : IO Unit := do
  let m := Examples.Shared.StakingVault.module
  let accounts := buildModuleAccounts m {}
  let head ← leading accounts
  require head.signer "StakingVault: leading fee payer/authority"
  require head.writable "StakingVault: nativeValue requires writable signer@0"
  require (hasProgramState accounts) "StakingVault: state"
  let src ← mustRender "StakingVault" m
  require (src.contains "solana.nativeValue" || src.contains "nativeValue" ||
      src.contains "lamports")
    "StakingVault lowers nativeValue from account[0] lamports"
  let report := report m {}
  require (report.note.contains "nativeValue")
    s!"StakingVault note should document nativeValue autofill: {report.note}"

/-- T3.2 flagship: caller + debit + remote → authority + state + callee. -/
def testAuthRemoteCall : IO Unit := do
  let m := Examples.Shared.AuthRemoteCall.module
  -- No Solana Surface: auto-portable only.
  let report := report m {}
  require (report.mode == .autoPortable)
    s!"AuthRemoteCall must be auto-portable, got {report.mode.id}"
  let accounts := buildModuleAccounts m {}
  let head ← leading accounts
  require head.signer "AuthRemoteCall: leading authority for caller"
  require (hasProgramState accounts) "AuthRemoteCall: balance state"
  require (hasNamed accounts "callee_program") "AuthRemoteCall: remote callee"
  -- Combined: no separate Source.Solana account list.
  require (accounts.size >= 3)
    s!"AuthRemoteCall expected ≥3 accounts (auth+state+callee), got {accounts.size}"
  let src ← mustRender "AuthRemoteCall" m
  require (src.contains "sol_invoke_signed_c") "AuthRemoteCall CPI"
  require (src.contains "account.validation") "AuthRemoteCall prologue"
  require (src.contains "sol_sha256") "AuthRemoteCall hashes caller pubkey"
  require (report.note.contains "remote" || report.note.contains "callee")
    s!"AuthRemoteCall note should mention remote autofill: {report.note}"

def main : IO UInt32 := do
  testOwnableAuth
  testRemoteCall
  testRoleGatedTokenTransfer
  testStakingVaultNative
  testAuthRemoteCall
  IO.println "solana-portable-accounts: ok (auth · transfer · remote · native)"
  return 0

end ProofForge.Tests.SolanaPortableAccounts

def main : IO UInt32 :=
  ProofForge.Tests.SolanaPortableAccounts.main
