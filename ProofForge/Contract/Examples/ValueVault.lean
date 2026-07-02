import ProofForge.Contract.Builder

namespace ProofForge.Contract.Examples.ValueVault

open ProofForge.Contract.Builder

def spec : ContractSpec :=
  build "ValueVault" do
    scalarState "balance" .u64
    scalarState "released" .u64
    scalarState "fees" .u64
    scalarState "last_value" .u64
    scalarState "last_checkpoint" .u64
    scalarState "operations" .u64

    entrySelectorWithParams "initialize" "00000001" #[("initial", .u64)] .unit do
      letBind "checkpoint" .u64 (contextRead .checkpointId)
      effect (storageScalarWrite "balance" (localVar "initial"))
      effect (storageScalarWrite "released" (u64 0))
      effect (storageScalarWrite "fees" (u64 0))
      effect (storageScalarWrite "last_value" (localVar "initial"))
      effect (storageScalarWrite "last_checkpoint" (localVar "checkpoint"))
      effect (storageScalarWrite "operations" (u64 1))
      effect (eventEmit "VaultInitialized" #[
        ("initial", localVar "initial"),
        ("checkpoint", localVar "checkpoint")
      ])

    entrySelectorWithParams "deposit" "00000002" #[("amount", .u64)] .unit do
      letBind "current" .u64 (storageScalarRead "balance")
      letBind "next" .u64 (add (localVar "current") (localVar "amount"))
      letBind "ops" .u64 (storageScalarRead "operations")
      letBind "next_ops" .u64 (add (localVar "ops") (u64 1))
      effect (storageScalarWrite "balance" (localVar "next"))
      effect (storageScalarWrite "last_value" (localVar "amount"))
      effect (storageScalarWrite "operations" (localVar "next_ops"))
      effect (eventEmit "ValueDeposited" #[
        ("amount", localVar "amount"),
        ("balance", localVar "next"),
        ("operations", localVar "next_ops")
      ])

    entrySelectorWithParams "charge_fee" "00000003"
        #[("gross", .u64), ("fee_bps", .u64)] .unit do
      letBind "fee" .u64 (div (mul (localVar "gross") (localVar "fee_bps")) (u64 10000))
      letBind "net" .u64 (sub (localVar "gross") (localVar "fee"))
      letBind "current" .u64 (storageScalarRead "balance")
      letBind "next" .u64 (add (localVar "current") (localVar "net"))
      letBind "current_fees" .u64 (storageScalarRead "fees")
      letBind "next_fees" .u64 (add (localVar "current_fees") (localVar "fee"))
      letBind "ops" .u64 (storageScalarRead "operations")
      letBind "next_ops" .u64 (add (localVar "ops") (u64 1))
      effect (storageScalarWrite "balance" (localVar "next"))
      effect (storageScalarWrite "fees" (localVar "next_fees"))
      effect (storageScalarWrite "last_value" (localVar "net"))
      effect (storageScalarWrite "operations" (localVar "next_ops"))
      effect (eventEmit "ValueCharged" #[
        ("gross", localVar "gross"),
        ("fee", localVar "fee"),
        ("net", localVar "net"),
        ("balance", localVar "next")
      ])

    entrySelectorWithParams "release" "00000004" #[("amount", .u64)] .unit do
      letBind "current" .u64 (storageScalarRead "balance")
      letBind "next" .u64 (sub (localVar "current") (localVar "amount"))
      letBind "released_before" .u64 (storageScalarRead "released")
      letBind "released_next" .u64 (add (localVar "released_before") (localVar "amount"))
      letBind "ops" .u64 (storageScalarRead "operations")
      letBind "next_ops" .u64 (add (localVar "ops") (u64 1))
      effect (storageScalarWrite "balance" (localVar "next"))
      effect (storageScalarWrite "released" (localVar "released_next"))
      effect (storageScalarWrite "last_value" (localVar "amount"))
      effect (storageScalarWrite "operations" (localVar "next_ops"))
      effect (eventEmit "ValueReleased" #[
        ("amount", localVar "amount"),
        ("balance", localVar "next"),
        ("released", localVar "released_next")
      ])

    entrySelectorReturns "snapshot" "00000005" .u64 do
      letBind "checkpoint" .u64 (contextRead .checkpointId)
      letBind "balance_now" .u64 (storageScalarRead "balance")
      letBind "released_now" .u64 (storageScalarRead "released")
      letBind "fees_now" .u64 (storageScalarRead "fees")
      effect (storageScalarWrite "last_checkpoint" (localVar "checkpoint"))
      effect (eventEmit "ValueSnapshot" #[
        ("balance", localVar "balance_now"),
        ("released", localVar "released_now"),
        ("fees", localVar "fees_now"),
        ("checkpoint", localVar "checkpoint")
      ])
      ret (localVar "balance_now")

    entrySelectorReturns "get_balance" "00000006" .u64 do
      ret (storageScalarRead "balance")

    entrySelectorReturns "get_net_value" "00000007" .u64 do
      letBind "balance_now" .u64 (storageScalarRead "balance")
      letBind "fees_now" .u64 (storageScalarRead "fees")
      ret (sub (localVar "balance_now") (localVar "fees_now"))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Contract.Examples.ValueVault
