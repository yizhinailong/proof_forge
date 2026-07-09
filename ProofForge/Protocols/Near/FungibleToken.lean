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

/-- Portable scalar-arg packing bound for Layer B peer calls.

Full NEP-141 JSON (`receiver_id` string, `memo`, nested objects) is **not**
produced by this client. Host materialize currently embeds scalar words into
the promise args buffer. Authors must not assume complete Borsh/JSON ABI. -/
inductive ArgPackingBound where
  /-- Only portable scalar IR words (`u64` / `bool` / handles). -/
  | portableScalarsOnly
  deriving BEq, Repr

def argPackingBound : ArgPackingBound := .portableScalarsOnly

def argPackingBoundId : String := "portable_scalars_only"

def maxPortableScalarArgs : Nat := 8

/-- Honesty gate: reject oversized scalar lists that would pretend to pack
complex NEAR JSON. Returns error text naming the bound. -/
def requireArgPackingHonest (argCount : Nat) : Except String Unit :=
  if argCount > maxPortableScalarArgs then
    .error s!"NEAR FT peer client: arg packing honesty — at most \
{maxPortableScalarArgs} portable scalar args (bound `{argPackingBoundId}`); \
got {argCount}. Full NEP-141 JSON/Borsh is not claimed by Protocols.Near.FungibleToken."
  else
    .ok ()

/-- Invoke a bound FT method with portable scalar args (amount, receiver idx, …).
Encoding of NEAR JSON args remains host materialize; this only names the method.
Does **not** pack `receiver_id : string` / memo objects — see `argPackingBound`. -/
def call (m : FtMethod) (args : Array ProofForge.IR.Expr) : ProofForge.IR.Expr :=
  remoteCallRef m args

/-- Same as `call` but fails in Lean when arg count exceeds the honesty bound
(for specs/builders that want compile-time gate). -/
def callHonest (m : FtMethod) (args : Array ProofForge.IR.Expr) : Except String ProofForge.IR.Expr :=
  match requireArgPackingHonest args.size with
  | .error e => .error e
  | .ok () => .ok (call m args)

end ProofForge.Protocols.Near.FungibleToken
