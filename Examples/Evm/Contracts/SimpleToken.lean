/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable SimpleToken for the unified EVM entry path.
-/
import ProofForge.Contract.Builder

namespace SimpleToken

open ProofForge.Contract.Builder
open ProofForge.IR

def spec : ProofForge.Contract.ContractSpec :=
  build "SimpleToken" do
    scalarState "owner" .u64
    scalarState "totalSupply" .u64
    mapState "balances" .u64 .u64 256

    entryWithParams "init" #[("supply", .u64)] .unit do
      letBind "owner" .u64 (contextRead .userId)
      effect (storageScalarWrite "owner" (.local "owner"))
      effect (storageScalarWrite "totalSupply" (.local "supply"))
      effect (storageMapInsert "balances" (.local "owner") (.local "supply"))

    entryReturns "getOwner" .u64 do
      ret (storageScalarRead "owner")

    entryReturns "totalSupply" .u64 do
      ret (storageScalarRead "totalSupply")

    entryWithParams "balanceOf" #[("addr", .u64)] .u64 do
      ret (storageMapGet "balances" (.local "addr"))

    entryWithParams "transfer" #[("to", .u64), ("amount", .u64)] .unit do
      letBind "sender" .u64 (contextRead .userId)
      letBind "bal" .u64 (storageMapGet "balances" (.local "sender"))
      assert (ge (.local "bal") (.local "amount")) "insufficient balance"
      letBind "newBal" .u64 (sub (.local "bal") (.local "amount"))
      effect (storageMapSet "balances" (.local "sender") (.local "newBal"))
      letBind "recvBal" .u64 (storageMapGet "balances" (.local "to"))
      effect (storageMapSet "balances" (.local "to") (add (.local "recvBal") (.local "amount")))

def module : ProofForge.IR.Module :=
  spec.module

end SimpleToken
