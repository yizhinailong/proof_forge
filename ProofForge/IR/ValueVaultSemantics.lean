import ProofForge.IR.Semantics
import ProofForge.IR.Examples.ValueVault
import ProofForge.IR.StepSemantics
import ProofForge.Backend.Refinement.CounterUniversal

namespace ProofForge.IR.ValueVaultSemantics

open ProofForge.IR
open ProofForge.IR.Semantics
open ProofForge.IR.StepSemantics
open ProofForge.Backend.Refinement
open ProofForge.Backend.Refinement.CounterUniversal (lookup_insert_same)
open Except

/-! ## Shallow total ValueVault IR semantics

This is a hand-crafted, shallow executable semantics for the ValueVault
contract. It directly computes the post-state and return value for each
entrypoint, avoiding the need to reduce the generic (partial) IR interpreter
inside proofs. It is used by `ValueVaultWasmRefinement` as the IR reference.

The shallow step is intentionally simple: it pattern-matches on the call,
updates the six scalar fields, and returns the appropriate `Option Value`.
-/

inductive ValueVaultCall where
  | initialize (initial : Nat)
  | deposit (amount : Nat)
  | chargeFee (gross feeBps : Nat)
  | release (amount : Nat)
  | snapshot
  | getBalance
  | getNetValue
  deriving Repr, DecidableEq

def ValueVaultCall.entrypoint : ValueVaultCall → Entrypoint
  | .initialize _ => ProofForge.IR.Examples.ValueVault.initializeEntrypoint
  | .deposit _ => ProofForge.IR.Examples.ValueVault.depositEntrypoint
  | .chargeFee _ _ => ProofForge.IR.Examples.ValueVault.chargeFeeEntrypoint
  | .release _ => ProofForge.IR.Examples.ValueVault.releaseEntrypoint
  | .snapshot => ProofForge.IR.Examples.ValueVault.snapshotEntrypoint
  | .getBalance => ProofForge.IR.Examples.ValueVault.getBalanceEntrypoint
  | .getNetValue => ProofForge.IR.Examples.ValueVault.getNetValueEntrypoint

def valueVaultObservableReturn (call : ValueVaultCall) (value? : Option Value) :
    Except String ObservableReturn :=
  match call, value? with
  | .initialize _, none => .ok ObservableReturn.none
  | .deposit _, none => .ok ObservableReturn.none
  | .chargeFee _ _, none => .ok ObservableReturn.none
  | .release _, none => .ok ObservableReturn.none
  | .snapshot, some (.u64 value) => .ok (.u64 value)
  | .getBalance, some (.u64 value) => .ok (.u64 value)
  | .getNetValue, some (.u64 value) => .ok (.u64 value)
  | .snapshot, none => .error "ValueVault.snapshot returned no value"
  | .getBalance, none => .error "ValueVault.getBalance returned no value"
  | .getNetValue, none => .error "ValueVault.getNetValue returned no value"
  | _, some _ => .error "ValueVault entrypoint returned an unexpected value"

/-- Shallow IR step: directly computes the next state and return value. -/
def valueVaultIrStep (state : State) (call : ValueVaultCall) :
    Except String (State × ObservableReturn) :=
  match call with
  | .initialize initial =>
      .ok (State.write
        (State.write
          (State.write
            (State.write
              (State.write
                (State.write state "balance" (.u64 initial))
                "released" (.u64 0))
              "fees" (.u64 0))
            "last_value" (.u64 initial))
          "last_checkpoint" (.u64 0))
        "operations" (.u64 1), ObservableReturn.none)
  | .deposit amount =>
      match state.read "balance", state.read "operations" with
      | some (.u64 balance), some (.u64 operations) =>
          .ok (State.write
            (State.write
              (State.write state "balance" (.u64 (balance + amount)))
              "last_value" (.u64 amount))
            "operations" (.u64 (operations + 1)), ObservableReturn.none)
      | _, _ => .error "ValueVault.deposit: missing state"
  | .chargeFee gross feeBps =>
      match state.read "balance", state.read "fees", state.read "operations" with
      | some (.u64 balance), some (.u64 fees), some (.u64 operations) =>
          let fee := (gross * feeBps) / 10000
          let net := gross - fee
          .ok (State.write
            (State.write
              (State.write
                (State.write state "balance" (.u64 (balance + net)))
                "fees" (.u64 (fees + fee)))
              "last_value" (.u64 net))
            "operations" (.u64 (operations + 1)), ObservableReturn.none)
      | _, _, _ => .error "ValueVault.chargeFee: missing state"
  | .release amount =>
      match state.read "balance", state.read "released", state.read "operations" with
      | some (.u64 balance), some (.u64 released), some (.u64 operations) =>
          .ok (State.write
            (State.write
              (State.write
                (State.write state "balance" (.u64 (balance - amount)))
                "released" (.u64 (released + amount)))
              "last_value" (.u64 amount))
            "operations" (.u64 (operations + 1)), ObservableReturn.none)
      | _, _, _ => .error "ValueVault.release: missing state"
  | .snapshot =>
      match state.read "balance" with
      | some (.u64 balance) =>
          .ok (State.write state "last_checkpoint" (.u64 0), ObservableReturn.u64 balance)
      | _ => .error "ValueVault.snapshot: missing balance"
  | .getBalance =>
      match state.read "balance" with
      | some (.u64 balance) => .ok (state, ObservableReturn.u64 balance)
      | _ => .error "ValueVault.getBalance: missing balance"
  | .getNetValue =>
      match state.read "balance", state.read "fees" with
      | some (.u64 balance), some (.u64 fees) => .ok (state, ObservableReturn.u64 (balance - fees))
      | _, _ => .error "ValueVault.getNetValue: missing state"

/-- Relation between an IR state and the six ValueVault scalar fields. -/
structure ValueVaultStateRel (state : State)
    (balance released fees lastValue lastCheckpoint operations : Nat) : Prop where
  hBalance : state.read "balance" = some (.u64 balance)
  hReleased : state.read "released" = some (.u64 released)
  hFees : state.read "fees" = some (.u64 fees)
  hLastValue : state.read "last_value" = some (.u64 lastValue)
  hLastCheckpoint : state.read "last_checkpoint" = some (.u64 lastCheckpoint)
  hOperations : state.read "operations" = some (.u64 operations)


/-- Lookup at a different key is preserved by insert. -/
theorem lookup_insert_other (name key : String) (value : Value) (bindings : Bindings)
    (hne : name ≠ key) :
    lookup name (ProofForge.IR.Semantics.insert key value bindings) =
      lookup name bindings := by
  induction bindings with
  | nil =>
      simp [ProofForge.IR.Semantics.insert, lookup]
      intro h
      apply hne
      exact h.symm
  | cons binding rest ih =>
      rcases binding with ⟨k, oldValue⟩
      by_cases hkey : k = key
      · rw [hkey]
        have h : key ≠ name := fun heq => hne heq.symm
        simp [ProofForge.IR.Semantics.insert, lookup, h]
      · simp [ProofForge.IR.Semantics.insert, lookup, hkey, ih]

/-- Reading a different key after a write returns the old value (non-struct). -/
theorem read_write_other (state : State) (name other : String) (n : Nat)
    (hne : name ≠ other) :
    (State.write state other (.u64 n)).read name = state.read name := by
  simp [State.write, State.read]
  exact lookup_insert_other name other (Value.u64 n) state.storage hne

/-- Reading the same key after a write returns the new value (non-struct). -/
theorem read_write_same (state : State) (name : String) (n : Nat) :
    (State.write state name (.u64 n)).read name = some (.u64 n) := by
  simp [State.write, State.read, CounterUniversal.lookup_insert_same]

theorem valueVaultStateRel_write_balance
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations)
    (next : Nat) :
    ValueVaultStateRel (State.write state "balance" (.u64 next)) next released fees lastValue lastCheckpoint operations := by
  constructor
  · exact read_write_same state "balance" next
  · rw [read_write_other state "released" "balance" next (by decide)]; exact h.hReleased
  · rw [read_write_other state "fees" "balance" next (by decide)]; exact h.hFees
  · rw [read_write_other state "last_value" "balance" next (by decide)]; exact h.hLastValue
  · rw [read_write_other state "last_checkpoint" "balance" next (by decide)]; exact h.hLastCheckpoint
  · rw [read_write_other state "operations" "balance" next (by decide)]; exact h.hOperations

theorem valueVaultStateRel_write_released
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations)
    (next : Nat) :
    ValueVaultStateRel (State.write state "released" (.u64 next)) balance next fees lastValue lastCheckpoint operations := by
  constructor
  · rw [read_write_other state "balance" "released" next (by decide)]; exact h.hBalance
  · exact read_write_same state "released" next
  · rw [read_write_other state "fees" "released" next (by decide)]; exact h.hFees
  · rw [read_write_other state "last_value" "released" next (by decide)]; exact h.hLastValue
  · rw [read_write_other state "last_checkpoint" "released" next (by decide)]; exact h.hLastCheckpoint
  · rw [read_write_other state "operations" "released" next (by decide)]; exact h.hOperations

theorem valueVaultStateRel_write_fees
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations)
    (next : Nat) :
    ValueVaultStateRel (State.write state "fees" (.u64 next)) balance released next lastValue lastCheckpoint operations := by
  constructor
  · rw [read_write_other state "balance" "fees" next (by decide)]; exact h.hBalance
  · rw [read_write_other state "released" "fees" next (by decide)]; exact h.hReleased
  · exact read_write_same state "fees" next
  · rw [read_write_other state "last_value" "fees" next (by decide)]; exact h.hLastValue
  · rw [read_write_other state "last_checkpoint" "fees" next (by decide)]; exact h.hLastCheckpoint
  · rw [read_write_other state "operations" "fees" next (by decide)]; exact h.hOperations

theorem valueVaultStateRel_write_last_value
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations)
    (next : Nat) :
    ValueVaultStateRel (State.write state "last_value" (.u64 next)) balance released fees next lastCheckpoint operations := by
  constructor
  · rw [read_write_other state "balance" "last_value" next (by decide)]; exact h.hBalance
  · rw [read_write_other state "released" "last_value" next (by decide)]; exact h.hReleased
  · rw [read_write_other state "fees" "last_value" next (by decide)]; exact h.hFees
  · exact read_write_same state "last_value" next
  · rw [read_write_other state "last_checkpoint" "last_value" next (by decide)]; exact h.hLastCheckpoint
  · rw [read_write_other state "operations" "last_value" next (by decide)]; exact h.hOperations

theorem valueVaultStateRel_write_last_checkpoint
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations)
    (next : Nat) :
    ValueVaultStateRel (State.write state "last_checkpoint" (.u64 next)) balance released fees lastValue next operations := by
  constructor
  · rw [read_write_other state "balance" "last_checkpoint" next (by decide)]; exact h.hBalance
  · rw [read_write_other state "released" "last_checkpoint" next (by decide)]; exact h.hReleased
  · rw [read_write_other state "fees" "last_checkpoint" next (by decide)]; exact h.hFees
  · rw [read_write_other state "last_value" "last_checkpoint" next (by decide)]; exact h.hLastValue
  · exact read_write_same state "last_checkpoint" next
  · rw [read_write_other state "operations" "last_checkpoint" next (by decide)]; exact h.hOperations

theorem valueVaultStateRel_write_operations
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations)
    (next : Nat) :
    ValueVaultStateRel (State.write state "operations" (.u64 next)) balance released fees lastValue lastCheckpoint next := by
  constructor
  · rw [read_write_other state "balance" "operations" next (by decide)]; exact h.hBalance
  · rw [read_write_other state "released" "operations" next (by decide)]; exact h.hReleased
  · rw [read_write_other state "fees" "operations" next (by decide)]; exact h.hFees
  · rw [read_write_other state "last_value" "operations" next (by decide)]; exact h.hLastValue
  · rw [read_write_other state "last_checkpoint" "operations" next (by decide)]; exact h.hLastCheckpoint
  · exact read_write_same state "operations" next

theorem valueVault_initialize_simulates
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations)
    (initial : Nat) :
    ∃ nextState,
      valueVaultIrStep state (.initialize initial) = Except.ok (nextState, ObservableReturn.none) ∧
      ValueVaultStateRel nextState initial 0 0 initial 0 1 := by
  simp [valueVaultIrStep]
  exact valueVaultStateRel_write_operations
    (valueVaultStateRel_write_last_checkpoint
      (valueVaultStateRel_write_last_value
        (valueVaultStateRel_write_fees
          (valueVaultStateRel_write_released
            (valueVaultStateRel_write_balance h initial)
            0)
          0)
        initial)
      0)
    1

/-- IR state with all six ValueVault slots explicitly zero (pre-initialize shape). -/
def valueVaultPreInitIr : State :=
  State.empty
    |>.write "balance" (.u64 0)
    |>.write "released" (.u64 0)
    |>.write "fees" (.u64 0)
    |>.write "last_value" (.u64 0)
    |>.write "last_checkpoint" (.u64 0)
    |>.write "operations" (.u64 0)

theorem valueVaultStateRel_preInit : ValueVaultStateRel valueVaultPreInitIr 0 0 0 0 0 0 := by
  constructor <;> simp [valueVaultPreInitIr, ValueVaultStateRel, State.read, State.write,
    lookup_insert_other, lookup_insert_same, State.empty]

theorem valueVault_deposit_simulates
    {state : State} {balance released fees lastValue lastCheckpoint operations amount : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations) :
    ∃ nextState,
      valueVaultIrStep state (.deposit amount) = Except.ok (nextState, ObservableReturn.none) ∧
      ValueVaultStateRel nextState (balance + amount) released fees amount lastCheckpoint (operations + 1) := by
  simp [valueVaultIrStep, h.hBalance, h.hOperations]
  exact valueVaultStateRel_write_operations
    (valueVaultStateRel_write_last_value
      (valueVaultStateRel_write_balance h (balance + amount))
      amount)
    (operations + 1)

theorem valueVault_chargeFee_simulates
    {state : State} {balance released fees lastValue lastCheckpoint operations gross feeBps : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations) :
    let fee := (gross * feeBps) / 10000
    let net := gross - fee
    ∃ nextState,
      valueVaultIrStep state (.chargeFee gross feeBps) = Except.ok (nextState, ObservableReturn.none) ∧
      ValueVaultStateRel nextState (balance + net) released (fees + fee) net lastCheckpoint (operations + 1) := by
  simp [valueVaultIrStep, h.hBalance, h.hFees, h.hOperations]
  exact valueVaultStateRel_write_operations
    (valueVaultStateRel_write_last_value
      (valueVaultStateRel_write_fees
        (valueVaultStateRel_write_balance h (balance + (gross - (gross * feeBps) / 10000)))
        (fees + (gross * feeBps) / 10000))
      (gross - (gross * feeBps) / 10000))
    (operations + 1)

theorem valueVault_release_simulates
    {state : State} {balance released fees lastValue lastCheckpoint operations amount : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations) :
    ∃ nextState,
      valueVaultIrStep state (.release amount) = Except.ok (nextState, ObservableReturn.none) ∧
      ValueVaultStateRel nextState (balance - amount) (released + amount) fees amount lastCheckpoint (operations + 1) := by
  simp [valueVaultIrStep, h.hBalance, h.hReleased, h.hOperations]
  exact valueVaultStateRel_write_operations
    (valueVaultStateRel_write_last_value
      (valueVaultStateRel_write_released
        (valueVaultStateRel_write_balance h (balance - amount))
        (released + amount))
      amount)
    (operations + 1)

theorem valueVault_snapshot_simulates
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations) :
    ∃ nextState,
      valueVaultIrStep state .snapshot = Except.ok (nextState, ObservableReturn.u64 balance) ∧
      ValueVaultStateRel nextState balance released fees lastValue 0 operations := by
  simp [valueVaultIrStep, h.hBalance]
  exact valueVaultStateRel_write_last_checkpoint h 0

theorem valueVault_getBalance_simulates
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations) :
    valueVaultIrStep state .getBalance = Except.ok (state, ObservableReturn.u64 balance) := by
  simp [valueVaultIrStep, h.hBalance]

theorem valueVault_getNetValue_simulates
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations) :
    valueVaultIrStep state .getNetValue = Except.ok (state, ObservableReturn.u64 (balance - fees)) := by
  simp [valueVaultIrStep, h.hBalance, h.hFees]

theorem valueVault_step_simulates (call : ValueVaultCall)
    {state : State} {balance released fees lastValue lastCheckpoint operations : Nat}
    (h : ValueVaultStateRel state balance released fees lastValue lastCheckpoint operations) :
    ∃ nextState observable,
      valueVaultIrStep state call = Except.ok (nextState, observable) := by
  cases call
  · obtain ⟨s, hs, _⟩ := valueVault_initialize_simulates h _
    exact ⟨s, ObservableReturn.none, hs⟩
  · obtain ⟨s, hs, _⟩ := valueVault_deposit_simulates h
    exact ⟨s, ObservableReturn.none, hs⟩
  · obtain ⟨s, hs, _⟩ := valueVault_chargeFee_simulates h
    exact ⟨s, ObservableReturn.none, hs⟩
  · obtain ⟨s, hs, _⟩ := valueVault_release_simulates h
    exact ⟨s, ObservableReturn.none, hs⟩
  · obtain ⟨s, hs, _⟩ := valueVault_snapshot_simulates h
    exact ⟨s, ObservableReturn.u64 balance, hs⟩
  · exact ⟨state, ObservableReturn.u64 balance, valueVault_getBalance_simulates h⟩
  · exact ⟨state, ObservableReturn.u64 (balance - fees), valueVault_getNetValue_simulates h⟩

end ProofForge.IR.ValueVaultSemantics
