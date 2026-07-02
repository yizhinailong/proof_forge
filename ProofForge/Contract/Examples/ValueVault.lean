import ProofForge.Contract.Surface

namespace ProofForge.Contract.Examples.ValueVault

open ProofForge.Contract.Surface

/-
Portable ValueVault is written through the Contract Surface API. The declaration
sections bind names, selectors, state slots, and parameters once; the entrypoint
bodies then use typed refs instead of repeating raw storage and local strings.
-/

namespace State

def balance : ScalarRef := slot "balance" .u64
def released : ScalarRef := slot "released" .u64
def fees : ScalarRef := slot "fees" .u64
def lastValue : ScalarRef := slot "last_value" .u64
def lastCheckpoint : ScalarRef := slot "last_checkpoint" .u64
def operations : ScalarRef := slot "operations" .u64

end State

namespace Input

def initial : BindingRef := binding "initial" .u64
def amount : BindingRef := binding "amount" .u64
def gross : BindingRef := binding "gross" .u64
def feeBps : BindingRef := binding "fee_bps" .u64

end Input

namespace Local

def checkpoint : BindingRef := binding "checkpoint" .u64
def current : BindingRef := binding "current" .u64
def next : BindingRef := binding "next" .u64
def ops : BindingRef := binding "ops" .u64
def nextOps : BindingRef := binding "next_ops" .u64
def fee : BindingRef := binding "fee" .u64
def net : BindingRef := binding "net" .u64
def currentFees : BindingRef := binding "current_fees" .u64
def nextFees : BindingRef := binding "next_fees" .u64
def releasedBefore : BindingRef := binding "released_before" .u64
def releasedNext : BindingRef := binding "released_next" .u64
def balanceNow : BindingRef := binding "balance_now" .u64
def releasedNow : BindingRef := binding "released_now" .u64
def feesNow : BindingRef := binding "fees_now" .u64

end Local

namespace Method

def init : MethodRef :=
  method "initialize" "fe4b84df" #[Input.initial]

def deposit : MethodRef :=
  method "deposit" "b6b55f25" #[Input.amount]

def chargeFee : MethodRef :=
  method "charge_fee" "be168a46" #[Input.gross, Input.feeBps]

def release : MethodRef :=
  method "release" "37bdc99b" #[Input.amount]

def snapshot : MethodRef :=
  method "snapshot" "9711715a" #[] .u64

def getBalance : MethodRef :=
  method "get_balance" "c1cfb99a" #[] .u64

def getNetValue : MethodRef :=
  method "get_net_value" "d43f79a2" #[] .u64

end Method

namespace Event

def vaultInitialized := "VaultInitialized"
def valueDeposited := "ValueDeposited"
def valueCharged := "ValueCharged"
def valueReleased := "ValueReleased"
def valueSnapshot := "ValueSnapshot"

end Event

def spec : ContractSpec :=
  contract "ValueVault" do
    scalar State.balance
    scalar State.released
    scalar State.fees
    scalar State.lastValue
    scalar State.lastCheckpoint
    scalar State.operations

    entry Method.init do
      bind Local.checkpoint checkpointId
      write State.balance (ref Input.initial)
      write State.released (u64 0)
      write State.fees (u64 0)
      write State.lastValue (ref Input.initial)
      write State.lastCheckpoint (ref Local.checkpoint)
      write State.operations (u64 1)
      emit Event.vaultInitialized #[
        fieldOf Input.initial,
        fieldOf Local.checkpoint
      ]

    entry Method.deposit do
      bind Local.current (read State.balance)
      bind Local.next (add (ref Local.current) (ref Input.amount))
      bind Local.ops (read State.operations)
      bind Local.nextOps (add (ref Local.ops) (u64 1))
      write State.balance (ref Local.next)
      write State.lastValue (ref Input.amount)
      write State.operations (ref Local.nextOps)
      emit Event.valueDeposited #[
        fieldOf Input.amount,
        fieldAs State.balance (ref Local.next),
        fieldAs State.operations (ref Local.nextOps)
      ]

    entry Method.chargeFee do
      bind Local.fee (div (mul (ref Input.gross) (ref Input.feeBps)) (u64 10000))
      bind Local.net (sub (ref Input.gross) (ref Local.fee))
      bind Local.current (read State.balance)
      bind Local.next (add (ref Local.current) (ref Local.net))
      bind Local.currentFees (read State.fees)
      bind Local.nextFees (add (ref Local.currentFees) (ref Local.fee))
      bind Local.ops (read State.operations)
      bind Local.nextOps (add (ref Local.ops) (u64 1))
      write State.balance (ref Local.next)
      write State.fees (ref Local.nextFees)
      write State.lastValue (ref Local.net)
      write State.operations (ref Local.nextOps)
      emit Event.valueCharged #[
        fieldOf Input.gross,
        fieldOf Local.fee,
        fieldOf Local.net,
        fieldAs State.balance (ref Local.next)
      ]

    entry Method.release do
      bind Local.current (read State.balance)
      bind Local.next (sub (ref Local.current) (ref Input.amount))
      bind Local.releasedBefore (read State.released)
      bind Local.releasedNext (add (ref Local.releasedBefore) (ref Input.amount))
      bind Local.ops (read State.operations)
      bind Local.nextOps (add (ref Local.ops) (u64 1))
      write State.balance (ref Local.next)
      write State.released (ref Local.releasedNext)
      write State.lastValue (ref Input.amount)
      write State.operations (ref Local.nextOps)
      emit Event.valueReleased #[
        fieldOf Input.amount,
        fieldAs State.balance (ref Local.next),
        fieldAs State.released (ref Local.releasedNext)
      ]

    entry Method.snapshot do
      bind Local.checkpoint checkpointId
      bind Local.balanceNow (read State.balance)
      bind Local.releasedNow (read State.released)
      bind Local.feesNow (read State.fees)
      write State.lastCheckpoint (ref Local.checkpoint)
      emit Event.valueSnapshot #[
        fieldAs State.balance (ref Local.balanceNow),
        fieldAs State.released (ref Local.releasedNow),
        fieldAs State.fees (ref Local.feesNow),
        fieldOf Local.checkpoint
      ]
      ret (ref Local.balanceNow)

    entry Method.getBalance do
      ret (read State.balance)

    entry Method.getNetValue do
      bind Local.balanceNow (read State.balance)
      bind Local.feesNow (read State.fees)
      ret (sub (ref Local.balanceNow) (ref Local.feesNow))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Contract.Examples.ValueVault
