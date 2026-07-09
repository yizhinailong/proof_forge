/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable Ownable + Pausable composition: only the owner may pause/unpause.

Standalone `Pausable` leaves pause/unpause unauthenticated so hosts can compose
auth separately; this module is the product path that matches OpenZeppelin-style
`onlyOwner` pause control without chain DSL.
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Stdlib.OwnablePausable

open ProofForge.Contract.Source

def «owner» : ScalarRef :=
  ProofForge.Contract.Surface.slot "owner" .u64

def «paused» : ScalarRef :=
  ProofForge.Contract.Surface.slot "paused" .u64

contract_source OwnablePausable do
  use ProofForge.Contract.Surface.scalar «owner»
  use ProofForge.Contract.Surface.scalar «paused»

  query «owner» returns(.u64) do
    return «owner»;

  query «paused» returns(.u64) do
    return «paused»;

  entry init do
    do ProofForge.Contract.Surface.requireZero «owner» "already initialized";
    «owner» := caller;

  entry pause do
    guard_owner «owner»;
    guard_not_paused «paused»;
    «paused» := u64 1;

  entry unpause do
    guard_owner «owner»;
    guard_paused «paused»;
    «paused» := u64 0;

  entry renounceOwnership do
    guard_owner «owner»;
    «owner» := u64 0;

end ProofForge.Contract.Stdlib.OwnablePausable
