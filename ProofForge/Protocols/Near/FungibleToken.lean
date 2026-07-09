/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer B — NEAR NEP-141 fungible token *peer* client

Promise/remote helpers for calling an **already-deployed** FT contract.

This is **not** `Contract.Stdlib.NearFungibleToken` (Layer C: *you* implement
NEP-141). Method names follow NEP-141 / NEP-148 / common NEP-145 surfaces.

Uses Layer A `declareRemote` so Wasm-NEAR materializes `promise_create` with
the method string in the host pool. Bind the FT account with
`--peer my_ft=token.near` at deploy time.
-/
import ProofForge.Contract.Surface

namespace ProofForge.Protocols.Near.FungibleToken

open ProofForge.Contract.Surface

/-- Catalog id for docs / diagnostics. -/
def catalogId : String := "protocols.near.fungible_token"

def methodFtTransfer : String := "ft_transfer"
def methodFtTransferCall : String := "ft_transfer_call"
def methodFtBalanceOf : String := "ft_balance_of"
def methodFtTotalSupply : String := "ft_total_supply"
def methodFtMetadata : String := "ft_metadata"
def methodStorageDeposit : String := "storage_deposit"

/-- Bound peer + method (`RemoteRef` from Layer A). -/
abbrev FtMethod := RemoteRef

/-- Register `ft_transfer` against a logical FT peer. -/
def declareFtTransfer (peerId : String) : ModuleM FtMethod :=
  declareRemote peerId methodFtTransfer

/-- Register `ft_transfer_call` against a logical FT peer. -/
def declareFtTransferCall (peerId : String) : ModuleM FtMethod :=
  declareRemote peerId methodFtTransferCall

/-- Register `ft_balance_of` against a logical FT peer. -/
def declareFtBalanceOf (peerId : String) : ModuleM FtMethod :=
  declareRemote peerId methodFtBalanceOf

/-- Register `ft_total_supply` against a logical FT peer. -/
def declareFtTotalSupply (peerId : String) : ModuleM FtMethod :=
  declareRemote peerId methodFtTotalSupply

/-- Register `ft_metadata` against a logical FT peer. -/
def declareFtMetadata (peerId : String) : ModuleM FtMethod :=
  declareRemote peerId methodFtMetadata

/-- Register `storage_deposit` (NEP-145) against a logical FT peer. -/
def declareStorageDeposit (peerId : String) : ModuleM FtMethod :=
  declareRemote peerId methodStorageDeposit

/-- Invoke a bound FT method with portable scalar args (amount, receiver idx, …).
Encoding of NEAR JSON args remains host materialize; this only names the method. -/
def call (m : FtMethod) (args : Array ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  remoteCallRef m args

end ProofForge.Protocols.Near.FungibleToken
