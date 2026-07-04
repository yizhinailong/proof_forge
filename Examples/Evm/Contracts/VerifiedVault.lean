/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable VerifiedVault for the unified EVM entry path. Source-level financial
proofs remain in `VerifiedVault.Spec`; codegen uses portable IR only.
-/
import ProofForge.Contract.Builder

namespace VerifiedVault

open ProofForge.Contract.Builder
open ProofForge.IR

namespace Spec

structure State where
  reserves : Nat
  shares   : Nat

def solvent (s : State) : Prop := s.reserves = s.shares

def empty : State := { reserves := 0, shares := 0 }

def deposit? (s : State) (amount : Nat) : Option State :=
  some { reserves := s.reserves + amount, shares := s.shares + amount }

def withdraw? (s : State) (amount : Nat) : Option State :=
  if amount ≤ s.reserves ∧ amount ≤ s.shares then
    some { reserves := s.reserves - amount, shares := s.shares - amount }
  else none

def canWithdraw (s : State) (amount : Nat) : Bool :=
  amount ≤ s.reserves ∧ amount ≤ s.shares

theorem empty_solvent : solvent empty := by rfl

theorem deposit_preserves_solvent {s next : State} {amount : Nat}
    (h : solvent s) (hn : deposit? s amount = some next) : solvent next := by
  unfold deposit? at hn
  simp at hn
  rw [← hn]
  show s.reserves + amount = s.shares + amount
  rw [h]

theorem withdraw_preserves_solvent {s next : State} {amount : Nat}
    (h : solvent s) (hn : withdraw? s amount = some next) : solvent next := by
  unfold withdraw? at hn
  by_cases w : amount ≤ s.reserves ∧ amount ≤ s.shares
  · simp [w] at hn
    rw [← hn]; show s.reserves - amount = s.shares - amount; rw [h]
  · simp [w] at hn

theorem deposit_increases_shares {s next : State} {amount : Nat}
    (hn : deposit? s amount = some next) : next.shares = s.shares + amount := by
  unfold deposit? at hn; simp at hn; rw [← hn]

theorem withdraw_decreases_reserves {s next : State} {amount : Nat}
    (hn : withdraw? s amount = some next) : next.reserves = s.reserves - amount := by
  unfold withdraw? at hn
  by_cases w : amount ≤ s.reserves ∧ amount ≤ s.shares
  · simp [w] at hn; rw [← hn]
  · simp [w] at hn

end Spec

def spec : ProofForge.Contract.ContractSpec :=
  build "VerifiedVault" do
    scalarState "owner" .u64
    scalarState "initialized" .u64
    scalarState "reserves" .u64
    scalarState "totalShares" .u64
    mapState "balances" .u64 .u64 256
    scalarState "reentrancyLock" .u64

    entry "init" do
      letBind "flag" .u64 (storageScalarRead "initialized")
      assert (eq (.local "flag") (u64 0)) "already initialized"
      letBind "owner" .u64 (contextRead .userId)
      effect (storageScalarWrite "owner" (.local "owner"))
      effect (storageScalarWrite "initialized" (u64 1))
      effect (storageScalarWrite "reserves" (u64 0))
      effect (storageScalarWrite "totalShares" (u64 0))

    entry "deposit" do
      letBind "flag" .u64 (storageScalarRead "initialized")
      assert (ne (.local "flag") (u64 0)) "not initialized"
      letBind "depositor" .u64 (contextRead .userId)
      letBind "amount" .u64 .nativeValue
      assert (ne (.local "amount") (u64 0)) "zero deposit"
      letBind "reserves" .u64 (storageScalarRead "reserves")
      letBind "shares" .u64 (storageScalarRead "totalShares")
      effect (storageScalarWrite "reserves" (add (.local "reserves") (.local "amount")))
      effect (storageScalarWrite "totalShares" (add (.local "shares") (.local "amount")))
      letBind "bal" .u64 (storageMapGet "balances" (.local "depositor"))
      effect (storageMapSet "balances" (.local "depositor") (add (.local "bal") (.local "amount")))

    entryWithParams "withdraw" #[("amount", .u64)] .unit do
      letBind "flag" .u64 (storageScalarRead "initialized")
      assert (ne (.local "flag") (u64 0)) "not initialized"
      letBind "lock" .u64 (storageScalarRead "reentrancyLock")
      assert (eq (.local "lock") (u64 0)) "reentrant"
      effect (storageScalarWrite "reentrancyLock" (u64 1))
      letBind "withdrawer" .u64 (contextRead .userId)
      letBind "bal" .u64 (storageMapGet "balances" (.local "withdrawer"))
      assert (le (.local "amount") (.local "bal")) "insufficient balance"
      letBind "reserves" .u64 (storageScalarRead "reserves")
      letBind "shares" .u64 (storageScalarRead "totalShares")
      assert (le (.local "amount") (.local "reserves")) "insufficient reserves"
      assert (le (.local "amount") (.local "shares")) "insufficient shares"
      effect (storageScalarWrite "reserves" (sub (.local "reserves") (.local "amount")))
      effect (storageScalarWrite "totalShares" (sub (.local "shares") (.local "amount")))
      effect (storageMapSet "balances" (.local "withdrawer") (sub (.local "bal") (.local "amount")))
      letBind "_sent" .u64 (.crosscallInvokeValueTyped (.local "withdrawer") (u64 0) (.local "amount") #[] .u64)
      effect (storageScalarWrite "reentrancyLock" (u64 0))

    entryReturns "reserves" .u64 do
      ret (storageScalarRead "reserves")

    entryReturns "totalShares" .u64 do
      ret (storageScalarRead "totalShares")

    entryWithParams "balanceOf" #[("depositor", .u64)] .u64 do
      ret (storageMapGet "balances" (.local "depositor"))

    entryReturns "getOwner" .u64 do
      ret (storageScalarRead "owner")

def module : ProofForge.IR.Module :=
  spec.module

end VerifiedVault
