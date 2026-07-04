/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable Pausable emergency-stop primitive authored with `contract_source`.
-/
import ProofForge.Contract.Source

namespace Pausable

open ProofForge.Contract.Source

namespace Spec

def paused (s : Nat) : Prop := s ≠ 0

theorem not_paused_zero : ¬ paused 0 := by simp [paused]

end Spec

contract_source Pausable do
  state «paused» : .u64

  query «paused» returns(.u64) do
    return «paused»;

  entry pause do
    guard_not_paused «paused»;
    «paused» := u64 1;

  entry unpause do
    guard_paused «paused»;
    «paused» := u64 0;

end Pausable
