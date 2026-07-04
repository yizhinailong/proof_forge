/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Reusable reentrancy lock mixin for `contract_source` composition.
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Stdlib.ReentrancyGuard

open ProofForge.Contract.Source

def lock : ScalarRef :=
  ProofForge.Contract.Surface.slot "lock" .u64

contract_mixin ReentrancyGuardMixin do
  use ProofForge.Contract.Surface.scalar lock

  entry acquire do
    do ProofForge.Contract.Surface.acquireLock lock;

  entry release do
    do ProofForge.Contract.Surface.releaseLock lock;

  query locked returns(.u64) do
    return lock;

contract_source ReentrancyGuard do
  use mixin

end ProofForge.Contract.Stdlib.ReentrancyGuard
