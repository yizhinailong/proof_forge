/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable **hash-width** Ownable mixin — owner stored as `.hash`, checks use
`callerHash` / `requireOwnerHash`.

Product path for identity-heavy chains (NEAR account ids; Solana full-pubkey
digest). **Not** multi-target with EVM yet (`userIdHash` unsupported on EVM);
use `Stdlib.Ownable` (u64 handle) for EVM·Solana·NEAR triad, or this mixin
when targeting wasm-near / Solana hash identity.
-/
import ProofForge.Contract.Source

namespace ProofForge.Contract.Stdlib.OwnableHash

open ProofForge.Contract.Source

def «owner» : ScalarRef :=
  ProofForge.Contract.Surface.slot "owner" .hash

contract_mixin OwnableHashMixin do
  use ProofForge.Contract.Surface.scalar «owner»

  query «owner» returns(.hash) do
    return «owner»;

  -- Note: no `transferOwnership (newOwner : .hash)` — Solana IR v0 cannot take
  -- Hash entrypoint params. Renounce + re-init patterns, or NEAR-only extension
  -- mixins, cover transfer for now.
  entry renounceOwnership do
    do ProofForge.Contract.Surface.requireOwnerHash «owner»;
    «owner» := ProofForge.Contract.Surface.hash4 0 0 0 0;

contract_source OwnableHash do
  use mixin
  entry init do
    do ProofForge.Contract.Surface.assertCondition
      (ProofForge.Contract.Surface.eq
        (ProofForge.Contract.Surface.read «owner»)
        (ProofForge.Contract.Surface.hash4 0 0 0 0))
      "already initialized";
    «owner» := callerHash;

end ProofForge.Contract.Stdlib.OwnableHash
