/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Layer B — NEAR NEP-141 *peer* client (fixture)

Calls an **already-deployed** FT via promise/remote method names.
Not Layer C (`Stdlib.NearFungibleToken` / `FungibleToken.lean` — those *are*
the FT contract).

Product index: `docs/protocols-layer.md` · `ProofForge.Protocols.Near.FungibleToken`.

```text
  pay(amount)           → ft_transfer
  pay_with_callback(…)  → ft_transfer_call
  query_balance(…)      → ft_balance_of
```

Bind the peer at deploy: `--peer my_ft=token.near`.
-/
import ProofForge.Contract.Builder
import ProofForge.Protocols.Near.FungibleToken

namespace Examples.Backend.WasmNear.FtPeerClient

open ProofForge.Contract.Builder
open ProofForge.Protocols.Near.FungibleToken

def spec : ProofForge.Contract.ContractSpec :=
  build "NearFtPeerClient" do
    scalarState "last_amount" .u64
    let ftTransfer ← declareFtTransfer "my_ft"
    let ftTransferCall ← declareFtTransferCall "my_ft"
    let ftBalance ← declareFtBalanceOf "my_ft"
    let ftSupply ← declareFtTotalSupply "my_ft"

    entryWithParams "pay" #[("amount", .u64)] .unit do
      letBind "_p" .u64 (call ftTransfer #[localVar "amount"])
      effect (storageScalarWrite "last_amount" (localVar "amount"))

    entryWithParams "pay_with_callback" #[("amount", .u64), ("msg_tag", .u64)] .unit do
      letBind "_p" .u64 (call ftTransferCall #[localVar "amount", localVar "msg_tag"])
      effect (storageScalarWrite "last_amount" (localVar "amount"))

    entryWithParams "query_balance" #[("account_tag", .u64)] .u64 do
      ret (call ftBalance #[localVar "account_tag"])

    entryReturns "query_supply" .u64 do
      ret (call ftSupply #[])

def module : ProofForge.IR.Module :=
  spec.module

end Examples.Backend.WasmNear.FtPeerClient
