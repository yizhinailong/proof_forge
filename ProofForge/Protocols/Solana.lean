/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer B — Solana protocol program clients

Thin product facade over the canonical Solana CPI builders and call shapes.

**Source of truth (do not duplicate packing here):**
- Call shapes: `ProofForge.Solana.Programs`
- Entry/module builders: `ProofForge.Solana.Builders`
- sBPF dataLayout packing: `ProofForge.Backend.Solana.Extension.Cpi`

Authors / Solana-extension modules should prefer importing this facade when
they mean “call an official program”, so Layer B is discoverable next to EVM
and NEAR protocol clients.
-/
import ProofForge.Solana.Programs
import ProofForge.Solana.Builders

namespace ProofForge.Protocols.Solana

open ProofForge.Solana

/-- Catalog id for docs / diagnostics. -/
def catalogId : String := "protocols.solana"

/-- Known protocol families with CPI packing (see `isSupportedCpiDataLayout`). -/
def knownFamilies : Array String := #[
  "system",
  "spl-token",
  "associated-token",
  "memo",
  "token-2022"
]

-- Re-export the high-traffic builders so `Protocols.Solana` is a one-stop
-- import for Layer B Solana clients (implementation stays in Solana.*).

export ProofForge.Solana (
  systemProgram
  splTokenProgram
  splToken2022Program
  associatedTokenProgram
  memoProgram
  systemTransferCall
  systemCreateAccountCall
  memoCall
  splTokenTransferCheckedCall
  splTokenInitializeMintCall
  splTokenInitializeAccount3Call
  splTokenMintToCall
  splTokenBurnCall
  splTokenApproveCall
  splTokenRevokeCall
  splTokenCloseAccountCall
  splTokenSetAuthorityCall
  associatedTokenCreateCall
  systemTransfer
  invokeSystemTransfer
  systemCreateAccount
  invokeSystemCreateAccount
  memo
  invokeMemo
  splTokenTransferChecked
  invokeSplTokenTransferChecked
  splTokenInitializeMint
  invokeSplTokenInitializeMint
  splTokenInitializeAccount3
  invokeSplTokenInitializeAccount3
  splTokenMintTo
  invokeSplTokenMintTo
  splTokenBurn
  invokeSplTokenBurn
  splTokenApprove
  invokeSplTokenApprove
  splTokenRevoke
  invokeSplTokenRevoke
  splTokenCloseAccount
  invokeSplTokenCloseAccount
  splTokenSetAuthority
  invokeSplTokenSetAuthority
  associatedTokenCreate
  invokeAssociatedTokenCreate
)

end ProofForge.Protocols.Solana
