/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable ERC-20 token for the unified EVM entry path.
-/
import ProofForge.Contract.Builder

namespace ERC20

open ProofForge.Contract.Builder
open ProofForge.IR

namespace Spec

theorem transfer_conserves_supply {srcBal dstBal amount : Nat}
    (h_src : amount ≤ srcBal)
    : (srcBal - amount) + (dstBal + amount) = srcBal + dstBal := by
  omega

theorem spend_allowance_bounded {current allowance : Nat}
    (h : current ≤ allowance)
    : allowance - current ≤ allowance := by omega

theorem mint_increases_supply {supply : Nat} {amount : Nat}
    : supply + amount ≥ supply := by omega

theorem burn_decreases_supply {supply amount : Nat}
    (h : amount ≤ supply)
    : supply - amount ≤ supply := by omega

end Spec

def allowancePath (owner spender : Expr) : Array StoragePathSegment :=
  #[.mapKey owner, .mapKey spender]

def spec : ProofForge.Contract.ContractSpec :=
  build "ERC20" do
    scalarState "totalSupply" .u64
    mapState "balances" .u64 .u64 256
    mapState "allowances" .u64 .u64 256

    entryReturns "totalSupply" .u64 do
      ret (storageScalarRead "totalSupply")

    entryWithParams "balanceOf" #[("account", .u64)] .u64 do
      ret (storageMapGet "balances" (.local "account"))

    entryWithParams "transfer" #[("to", .u64), ("amount", .u64)] .unit do
      letBind "sender" .u64 (contextRead .userId)
      assert (ne (.local "to") (u64 0)) "zero recipient"
      letBind "srcBal" .u64 (storageMapGet "balances" (.local "sender"))
      assert (ge (.local "srcBal") (.local "amount")) "insufficient balance"
      effect (storageMapSet "balances" (.local "sender") (sub (.local "srcBal") (.local "amount")))
      letBind "dstBal" .u64 (storageMapGet "balances" (.local "to"))
      effect (storageMapSet "balances" (.local "to") (add (.local "dstBal") (.local "amount")))

    entryWithParams "allowance" #[("owner", .u64), ("spender", .u64)] .u64 do
      ret (.effect (.storagePathRead "allowances" (allowancePath (.local "owner") (.local "spender"))))

    entryWithParams "approve" #[("spender", .u64), ("amount", .u64)] .unit do
      letBind "owner" .u64 (contextRead .userId)
      assert (ne (.local "spender") (u64 0)) "zero spender"
      effect (.storagePathWrite "allowances" (allowancePath (.local "owner") (.local "spender")) (.local "amount"))

    entryWithParams "transferFrom" #[("src", .u64), ("dst", .u64), ("amount", .u64)] .unit do
      letBind "spender" .u64 (contextRead .userId)
      letBind "current" .u64 (.effect (.storagePathRead "allowances" (allowancePath (.local "src") (.local "spender"))))
      assert (ge (.local "current") (.local "amount")) "insufficient allowance"
      effect (.storagePathWrite "allowances" (allowancePath (.local "src") (.local "spender")) (sub (.local "current") (.local "amount")))
      letBind "srcBal" .u64 (storageMapGet "balances" (.local "src"))
      assert (ge (.local "srcBal") (.local "amount")) "insufficient balance"
      effect (storageMapSet "balances" (.local "src") (sub (.local "srcBal") (.local "amount")))
      letBind "dstBal" .u64 (storageMapGet "balances" (.local "dst"))
      effect (storageMapSet "balances" (.local "dst") (add (.local "dstBal") (.local "amount")))

    entryWithParams "mint" #[("account", .u64), ("amount", .u64)] .unit do
      assert (ne (.local "account") (u64 0)) "zero account"
      letBind "ts" .u64 (storageScalarRead "totalSupply")
      effect (storageScalarWrite "totalSupply" (add (.local "ts") (.local "amount")))
      letBind "bal" .u64 (storageMapGet "balances" (.local "account"))
      effect (storageMapSet "balances" (.local "account") (add (.local "bal") (.local "amount")))

    entryWithParams "burn" #[("account", .u64), ("amount", .u64)] .unit do
      assert (ne (.local "account") (u64 0)) "zero account"
      letBind "bal" .u64 (storageMapGet "balances" (.local "account"))
      assert (ge (.local "bal") (.local "amount")) "insufficient balance"
      effect (storageMapSet "balances" (.local "account") (sub (.local "bal") (.local "amount")))
      letBind "ts" .u64 (storageScalarRead "totalSupply")
      effect (storageScalarWrite "totalSupply" (sub (.local "ts") (.local "amount")))

def module : ProofForge.IR.Module :=
  spec.module

end ERC20
