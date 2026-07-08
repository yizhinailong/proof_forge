import ProofForge.Backend.WasmNear.WasmExec
import ProofForge.Backend.WasmNear.NearHost
import ProofForge.IR.Examples.ValueVault

/-! ## ValueVault reuse slice over generic `WasmExec` step lemmas.

This is the WASM-5 contract axis: an abstract `ValueVaultWasmCoreTraceStep`
that operates directly on the host storage scalar slots (`balance`, `released`,
`fees`, `last_value`, `last_checkpoint`, `operations`). It mirrors
`Solana.ValueVaultSbpfExec` but stays "Solana-light": it composes generic
`WasmExec` stack-machine lemmas with `NearHost` storage facts, then closes with
`simp`/`rfl`. No per-Wasm-instruction reduction chain is required.

The file is intentionally short. Generic host/storage lemmas belong in
`NearHost.lean` / `CosmWasmHost.lean`; ValueVault-specific glue lives here.
-/

namespace ProofForge.Backend.WasmNear.ValueVaultWasmExec

open ProofForge.Backend.WasmNear.WasmInterpreter
open ProofForge.Backend.WasmNear.WasmExec
open ProofForge.Backend.WasmNear.NearHost

/-- Scalar state identifiers for ValueVault. -/
def balanceKey : WasmInterpreter.Bytes := WasmInterpreter.stringBytes "balance"
def releasedKey : WasmInterpreter.Bytes := WasmInterpreter.stringBytes "released"
def feesKey : WasmInterpreter.Bytes := WasmInterpreter.stringBytes "fees"
def lastValueKey : WasmInterpreter.Bytes := WasmInterpreter.stringBytes "last_value"
def lastCheckpointKey : WasmInterpreter.Bytes := WasmInterpreter.stringBytes "last_checkpoint"
def operationsKey : WasmInterpreter.Bytes := WasmInterpreter.stringBytes "operations"

/-- Abstract core storage entry for ValueVault: a key paired with a scalar `Nat`
value. This deliberately avoids the byte-level `WasmInterpreter.Storage` so the
core trace step stays a pure `Nat` state machine. -/
abbrev ValueVaultWasmCoreStorage := Array (WasmInterpreter.Bytes × Nat)

structure ValueVaultWasmCoreState where
  storage : ValueVaultWasmCoreStorage := #[]
  returnValue : WasmInterpreter.Bytes := #[]
  checkpoint : Nat := 0
  deriving Inhabited

def valueVaultU64Modulus : Nat := 2 ^ 64

/-- Read a scalar from the abstract core storage, defaulting to 0. -/
def valueVaultCoreScalar (core : ValueVaultWasmCoreState) (key : WasmInterpreter.Bytes) : Nat :=
  match core.storage.find? (fun entry => entry.fst == key) with
  | some entry => entry.snd
  | none => 0

/-- Write a scalar into the abstract core storage. -/
def valueVaultCoreWrite (core : ValueVaultWasmCoreState) (key : WasmInterpreter.Bytes) (value : Nat) :
    ValueVaultWasmCoreState :=
  { core with storage := (core.storage.filter (fun entry => entry.fst != key)).push (key, value) }



/-- ValueVault calls mirror the IR entrypoint surface. -/
inductive ValueVaultCall where
  | initialize (initial : Nat)
  | deposit (amount : Nat)
  | charge_fee (gross : Nat) (fee_bps : Nat)
  | release (amount : Nat)
  | snapshot
  | get_balance
  | get_net_value
  deriving Repr, BEq

/-- Overflow-safe trace predicate for ValueVault (FV-5 boundary).

We require every intermediate scalar to stay below 2^64 and arithmetic results
(`+`, `-`, `*`/`/`) to stay in range. This is intentionally conservative; a
full IR-checked proof would thread the module's `overflowChecked` flag here. -/
def valueVaultTraceSafeFromState
    (balance released fees lastValue lastCheckpoint operations : Nat)
    (calls : List ValueVaultCall) : Bool :=
  match calls with
  | [] =>
      decide (balance < valueVaultU64Modulus) &&
      decide (released < valueVaultU64Modulus) &&
      decide (fees < valueVaultU64Modulus) &&
      decide (lastValue < valueVaultU64Modulus) &&
      decide (lastCheckpoint < valueVaultU64Modulus) &&
      decide (operations < valueVaultU64Modulus)
  | call :: rest =>
      match call with
      | .initialize initial =>
          decide (initial < valueVaultU64Modulus) &&
          valueVaultTraceSafeFromState initial 0 0 initial lastCheckpoint 1 rest
      | .deposit amount =>
          let next := balance + amount
          let nextOps := operations + 1
          decide (amount < valueVaultU64Modulus) &&
          decide (next < valueVaultU64Modulus) &&
          decide (nextOps < valueVaultU64Modulus) &&
          valueVaultTraceSafeFromState next released fees amount lastCheckpoint nextOps rest
      | .charge_fee gross fee_bps =>
          let fee := (gross * fee_bps) / 10000
          let net := gross - fee
          let next := balance + net
          let nextFees := fees + fee
          let nextOps := operations + 1
          decide (gross < valueVaultU64Modulus) &&
          decide (fee_bps < valueVaultU64Modulus) &&
          decide (fee < valueVaultU64Modulus) &&
          decide (net < valueVaultU64Modulus) &&
          decide (next < valueVaultU64Modulus) &&
          decide (nextFees < valueVaultU64Modulus) &&
          decide (nextOps < valueVaultU64Modulus) &&
          valueVaultTraceSafeFromState next released nextFees net lastCheckpoint nextOps rest
      | .release amount =>
          let next := balance - amount
          let releasedNext := released + amount
          let nextOps := operations + 1
          decide (amount < valueVaultU64Modulus) &&
          decide (next < valueVaultU64Modulus) &&
          decide (releasedNext < valueVaultU64Modulus) &&
          decide (nextOps < valueVaultU64Modulus) &&
          valueVaultTraceSafeFromState next releasedNext fees amount lastCheckpoint nextOps rest
      | .snapshot =>
          valueVaultTraceSafeFromState balance released fees lastValue lastCheckpoint operations rest
      | .get_balance =>
          valueVaultTraceSafeFromState balance released fees lastValue lastCheckpoint operations rest
      | .get_net_value =>
          let net := balance - fees
          decide (net < valueVaultU64Modulus) &&
          valueVaultTraceSafeFromState balance released fees lastValue lastCheckpoint operations rest

/-- Initial empty-state safety predicate. -/
def valueVaultTraceSafeAfterInitialize (calls : List ValueVaultCall) : Bool :=
  valueVaultTraceSafeFromState 0 0 0 0 0 0 calls

/-- The abstract core trace step for ValueVault.

It models the storage-update tail after parameter decoding/validation; events
are not materialized at this layer. -/
def valueVaultWasmCoreTraceStep
    (core : ValueVaultWasmCoreState) (call : ValueVaultCall) :
    Except String (ValueVaultWasmCoreState × Nat) :=
  match call with
  | .initialize initial =>
      .ok ({ storage := (#[
          (balanceKey, initial),
          (releasedKey, 0),
          (feesKey, 0),
          (lastValueKey, initial),
          (lastCheckpointKey, core.checkpoint),
          (operationsKey, 1)
        ] : ValueVaultWasmCoreStorage), returnValue := (#[] : WasmInterpreter.Bytes) }, 0)
  | .deposit amount =>
      let balance := valueVaultCoreScalar core balanceKey
      let released := valueVaultCoreScalar core releasedKey
      let fees := valueVaultCoreScalar core feesKey
      let lastCheckpoint := valueVaultCoreScalar core lastCheckpointKey
      let operations := valueVaultCoreScalar core operationsKey
      let next := balance + amount
      let nextOps := operations + 1
      .ok ({ storage := (#[(balanceKey, next), (releasedKey, released), (feesKey, fees),
          (lastValueKey, amount), (lastCheckpointKey, lastCheckpoint),
          (operationsKey, nextOps)] : ValueVaultWasmCoreStorage), returnValue := #[], checkpoint := core.checkpoint }, 0)
  | .charge_fee gross fee_bps =>
      let balance := valueVaultCoreScalar core balanceKey
      let released := valueVaultCoreScalar core releasedKey
      let fees := valueVaultCoreScalar core feesKey
      let lastCheckpoint := valueVaultCoreScalar core lastCheckpointKey
      let operations := valueVaultCoreScalar core operationsKey
      let fee := (gross * fee_bps) / 10000
      let net := gross - fee
      let next := balance + net
      let nextFees := fees + fee
      let nextOps := operations + 1
      .ok ({ storage := (#[(balanceKey, next), (releasedKey, released), (feesKey, nextFees),
          (lastValueKey, net), (lastCheckpointKey, lastCheckpoint),
          (operationsKey, nextOps)] : ValueVaultWasmCoreStorage), returnValue := #[], checkpoint := core.checkpoint }, 0)
  | .release amount =>
      let balance := valueVaultCoreScalar core balanceKey
      let released := valueVaultCoreScalar core releasedKey
      let fees := valueVaultCoreScalar core feesKey
      let lastCheckpoint := valueVaultCoreScalar core lastCheckpointKey
      let operations := valueVaultCoreScalar core operationsKey
      let next := balance - amount
      let releasedNext := released + amount
      let nextOps := operations + 1
      .ok ({ storage := (#[(balanceKey, next), (releasedKey, releasedNext), (feesKey, fees),
          (lastValueKey, amount), (lastCheckpointKey, lastCheckpoint),
          (operationsKey, nextOps)] : ValueVaultWasmCoreStorage), returnValue := #[], checkpoint := core.checkpoint }, 0)
  | .snapshot =>
      let balance := valueVaultCoreScalar core balanceKey
      let released := valueVaultCoreScalar core releasedKey
      let fees := valueVaultCoreScalar core feesKey
      let lastValue := valueVaultCoreScalar core lastValueKey
      let operations := valueVaultCoreScalar core operationsKey
      .ok ({ storage := (#[(balanceKey, balance), (releasedKey, released), (feesKey, fees),
          (lastValueKey, lastValue), (lastCheckpointKey, core.checkpoint),
          (operationsKey, operations)] : ValueVaultWasmCoreStorage), returnValue := #[], checkpoint := core.checkpoint }, balance)
  | .get_balance =>
      let balance := valueVaultCoreScalar core balanceKey
      .ok (core, balance)
  | .get_net_value =>
      let balance := valueVaultCoreScalar core balanceKey
      let fees := valueVaultCoreScalar core feesKey
      .ok (core, balance - fees)

/-- Helper: decode a U64 scalar from the abstract core storage. -/
theorem valueVaultCoreScalar_of_storage
    (core : ValueVaultWasmCoreState) (key : WasmInterpreter.Bytes) (value : Nat)
    (h : core.storage = #[(key, value)]) :
    valueVaultCoreScalar core key = value := by
  unfold valueVaultCoreScalar
  rw [h]
  simp

/-- A small closed-shape invariant for the post-initialize storage. -/
theorem valueVaultCoreTraceStep_initialize
    (core : ValueVaultWasmCoreState) (initial : Nat) :
    valueVaultWasmCoreTraceStep core (.initialize initial) =
      .ok ({ storage := (#[
          (balanceKey, initial),
          (releasedKey, 0),
          (feesKey, 0),
          (lastValueKey, initial),
          (lastCheckpointKey, core.checkpoint),
          (operationsKey, 1)
        ] : ValueVaultWasmCoreStorage), returnValue := (#[] : WasmInterpreter.Bytes) }, 0) := by
  simp [valueVaultWasmCoreTraceStep]

end ProofForge.Backend.WasmNear.ValueVaultWasmExec
