/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable Ownable access-control primitive for the unified EVM entry path.
-/
import ProofForge.Contract.Builder

namespace Ownable

open ProofForge.Contract.Builder
open ProofForge.IR

namespace Spec

structure State where
  owner : Nat

def initialized (s : State) : Prop := s.owner ≠ 0

def isOwner (s : State) (caller : Nat) : Prop := caller = s.owner

theorem isOwner_refl (s : State) : isOwner s s.owner := by rfl

end Spec

def spec : ProofForge.Contract.ContractSpec :=
  build "Ownable" do
    scalarState "owner" .u64

    entry "init" do
      letBind "current" .u64 (storageScalarRead "owner")
      assert (eq (.local "current") (u64 0)) "already initialized"
      letBind "sender" .u64 (contextRead .userId)
      effect (storageScalarWrite "owner" (.local "sender"))

    entryReturns "owner" .u64 do
      ret (storageScalarRead "owner")

    entryWithParams "transferOwnership" #[("newOwner", .u64)] .unit do
      letBind "sender" .u64 (contextRead .userId)
      letBind "current" .u64 (storageScalarRead "owner")
      assert (eq (.local "sender") (.local "current")) "not owner"
      assert (ne (.local "newOwner") (u64 0)) "zero address"
      effect (storageScalarWrite "owner" (.local "newOwner"))

    entry "renounceOwnership" do
      letBind "sender" .u64 (contextRead .userId)
      letBind "current" .u64 (storageScalarRead "owner")
      assert (eq (.local "sender") (.local "current")) "not owner"
      effect (storageScalarWrite "owner" (u64 0))

def module : ProofForge.IR.Module :=
  spec.module

end Ownable
