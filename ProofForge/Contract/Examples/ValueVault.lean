import ProofForge.Contract.Surface

namespace ProofForge.Contract.Examples.ValueVault

open ProofForge.Contract.Surface

/-
Portable ValueVault is written through the Contract Surface API. The declaration
sections derive IR names from declarations for state slots, parameters, locals,
methods, and events; the entrypoint bodies use typed refs instead of repeating
raw storage and local strings. EVM ABI selectors are target-derived during CLI
emission rather than written in this source file.
-/

namespace State

state_decl balance : .u64
state_decl released : .u64
state_decl fees : .u64
state_decl last_value : .u64
state_decl last_checkpoint : .u64
state_decl operations : .u64

end State

namespace Input

binding_decl initial : .u64
binding_decl amount : .u64
binding_decl gross : .u64
binding_decl fee_bps : .u64

end Input

namespace Local

binding_decl checkpoint : .u64
binding_decl current : .u64
binding_decl next : .u64
binding_decl ops : .u64
binding_decl next_ops : .u64
binding_decl fee : .u64
binding_decl net : .u64
binding_decl current_fees : .u64
binding_decl next_fees : .u64
binding_decl released_before : .u64
binding_decl released_next : .u64
binding_decl balance_now : .u64
binding_decl released_now : .u64
binding_decl fees_now : .u64

end Local

namespace Method

method_decl «initialize» : #[Input.initial]

method_decl deposit : #[Input.amount]

method_decl charge_fee : #[Input.gross, Input.fee_bps]

method_decl release : #[Input.amount]

method_return_decl snapshot : .u64 := #[]

method_return_decl get_balance : .u64 := #[]

method_return_decl get_net_value : .u64 := #[]

end Method

namespace Event

event_decl VaultInitialized
event_decl ValueDeposited
event_decl ValueCharged
event_decl ValueReleased
event_decl ValueSnapshot

end Event

def spec : ContractSpec :=
  contract_decl ValueVault do
    scalar State.balance
    scalar State.released
    scalar State.fees
    scalar State.last_value
    scalar State.last_checkpoint
    scalar State.operations

    entry Method.«initialize» do
      bind Local.checkpoint checkpointId
      write State.balance (ref Input.initial)
      write State.released (u64 0)
      write State.fees (u64 0)
      write State.last_value (ref Input.initial)
      write State.last_checkpoint (ref Local.checkpoint)
      write State.operations (u64 1)
      emit Event.VaultInitialized #[
        fieldOf Input.initial,
        fieldOf Local.checkpoint
      ]

    entry Method.deposit do
      bind Local.current (read State.balance)
      bind Local.next (add (ref Local.current) (ref Input.amount))
      bind Local.ops (read State.operations)
      bind Local.next_ops (add (ref Local.ops) (u64 1))
      write State.balance (ref Local.next)
      write State.last_value (ref Input.amount)
      write State.operations (ref Local.next_ops)
      emit Event.ValueDeposited #[
        fieldOf Input.amount,
        fieldAs State.balance (ref Local.next),
        fieldAs State.operations (ref Local.next_ops)
      ]

    entry Method.charge_fee do
      bind Local.fee (div (mul (ref Input.gross) (ref Input.fee_bps)) (u64 10000))
      bind Local.net (sub (ref Input.gross) (ref Local.fee))
      bind Local.current (read State.balance)
      bind Local.next (add (ref Local.current) (ref Local.net))
      bind Local.current_fees (read State.fees)
      bind Local.next_fees (add (ref Local.current_fees) (ref Local.fee))
      bind Local.ops (read State.operations)
      bind Local.next_ops (add (ref Local.ops) (u64 1))
      write State.balance (ref Local.next)
      write State.fees (ref Local.next_fees)
      write State.last_value (ref Local.net)
      write State.operations (ref Local.next_ops)
      emit Event.ValueCharged #[
        fieldOf Input.gross,
        fieldOf Local.fee,
        fieldOf Local.net,
        fieldAs State.balance (ref Local.next)
      ]

    entry Method.release do
      bind Local.current (read State.balance)
      bind Local.next (sub (ref Local.current) (ref Input.amount))
      bind Local.released_before (read State.released)
      bind Local.released_next (add (ref Local.released_before) (ref Input.amount))
      bind Local.ops (read State.operations)
      bind Local.next_ops (add (ref Local.ops) (u64 1))
      write State.balance (ref Local.next)
      write State.released (ref Local.released_next)
      write State.last_value (ref Input.amount)
      write State.operations (ref Local.next_ops)
      emit Event.ValueReleased #[
        fieldOf Input.amount,
        fieldAs State.balance (ref Local.next),
        fieldAs State.released (ref Local.released_next)
      ]

    entry Method.snapshot do
      bind Local.checkpoint checkpointId
      bind Local.balance_now (read State.balance)
      bind Local.released_now (read State.released)
      bind Local.fees_now (read State.fees)
      write State.last_checkpoint (ref Local.checkpoint)
      emit Event.ValueSnapshot #[
        fieldAs State.balance (ref Local.balance_now),
        fieldAs State.released (ref Local.released_now),
        fieldAs State.fees (ref Local.fees_now),
        fieldOf Local.checkpoint
      ]
      ret (ref Local.balance_now)

    entry Method.get_balance do
      ret (read State.balance)

    entry Method.get_net_value do
      bind Local.balance_now (read State.balance)
      bind Local.fees_now (read State.fees)
      ret (sub (ref Local.balance_now) (ref Local.fees_now))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Contract.Examples.ValueVault
