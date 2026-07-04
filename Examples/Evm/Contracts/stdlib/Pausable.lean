/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable Pausable emergency-stop primitive for the unified EVM entry path.
-/
import ProofForge.Contract.Builder

namespace Pausable

open ProofForge.Contract.Builder
open ProofForge.IR

namespace Spec

def paused (s : Nat) : Prop := s ≠ 0

theorem not_paused_zero : ¬ paused 0 := by simp [paused]

end Spec

def spec : ProofForge.Contract.ContractSpec :=
  build "Pausable" do
    scalarState "paused" .u64

    entryReturns "paused" .u64 do
      ret (storageScalarRead "paused")

    entry "pause" do
      letBind "p" .u64 (storageScalarRead "paused")
      assert (eq (.local "p") (u64 0)) "already paused"
      effect (storageScalarWrite "paused" (u64 1))

    entry "unpause" do
      letBind "p" .u64 (storageScalarRead "paused")
      assert (ne (.local "p") (u64 0)) "not paused"
      effect (storageScalarWrite "paused" (u64 0))

def module : ProofForge.IR.Module :=
  spec.module

end Pausable
