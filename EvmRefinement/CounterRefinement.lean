import EvmRefinement.PowdrAdapter
import ProofForge.Backend.Evm.Plan.Storage
import ProofForge.Backend.Refinement.CounterUniversal

/-! Counter IR/powdr-EVM storage relation.

This is the first E3 relation layer: it ties the Counter IR state's `count`
binding to the storage word that ProofForge's EVM layout assigns to `count`,
using the real powdr `AccountMap`/`Storage` model under the opt-in
`EvmRefinement` target.
-/

namespace ProofForge.Backend.Evm.CounterRefinement

open ProofForge.IR
open ProofForge.IR.Semantics
open ProofForge.Backend.Refinement

abbrev IRState := ProofForge.IR.Semantics.State
abbrev EvmState := ProofForge.Backend.Evm.PowdrAdapter.State
abbrev CounterCall := ProofForge.Backend.Refinement.CounterUniversal.CounterCall
abbrev counterIRStep := ProofForge.Backend.Refinement.CounterUniversal.irStep

def counterCountSlotNat : Nat := 0

/-- The EVM layout assigns Counter.count to scalar storage slot 0. -/
theorem counter_count_slot_from_layout :
    ProofForge.Backend.Evm.Plan.stateSlot?
      ProofForge.IR.Examples.Counter.module "count" = some counterCountSlotNat := by
  native_decide

def counterCountSlot : EvmSemantics.UInt256 :=
  EvmSemantics.UInt256.ofNat counterCountSlotNat

def counterU64Modulus : Nat := 2 ^ 64

def counterU64StorageShift : Nat := 2 ^ 192

/-- The generated EVM runtime stores `count : U64` in the high 64 bits of slot 0. -/
def counterPackedCountNat (count : Nat) : Nat :=
  count * counterU64StorageShift

def counterPackedCountValue (count : Nat) : EvmSemantics.UInt256 :=
  EvmSemantics.UInt256.ofNat (counterPackedCountNat count)

def counterPaddedCountValue (count padding : Nat) : EvmSemantics.UInt256 :=
  EvmSemantics.UInt256.ofNat (counterPackedCountNat count + padding)

def counterLowPaddingNat (word : EvmSemantics.UInt256) : Nat :=
  word.toNat % counterU64StorageShift

def counterInitializeStorageWord (word : EvmSemantics.UInt256) : EvmSemantics.UInt256 :=
  counterPaddedCountValue 0 (counterLowPaddingNat word)

/-- The generated runtime stores `count : U64` in the high 64 bits and leaves
the lower 192 bits as padding/other-packed-field space. The relation therefore
tracks the high-bit count while allowing arbitrary low padding. -/
def CounterStorageWordRel (word : EvmSemantics.UInt256) (count : Nat) : Prop :=
  ∃ padding,
    padding < counterU64StorageShift ∧
    word = EvmSemantics.UInt256.ofNat (counterPackedCountNat count + padding)

theorem counterStorageWordRel_packed (count : Nat) :
    CounterStorageWordRel (counterPackedCountValue count) count := by
  refine ⟨0, ?_, ?_⟩
  · native_decide
  · simp [counterPackedCountValue, counterPackedCountNat]

theorem counterStorageWordRel_padded {count padding : Nat}
    (hpadding : padding < counterU64StorageShift) :
    CounterStorageWordRel (counterPaddedCountValue count padding) count := by
  exact ⟨padding, hpadding, rfl⟩

theorem counterLowPaddingNat_lt (word : EvmSemantics.UInt256) :
    counterLowPaddingNat word < counterU64StorageShift := by
  unfold counterLowPaddingNat
  have hshift : 0 < counterU64StorageShift := by
    native_decide
  exact Nat.mod_lt word.toNat hshift

theorem counterInitializeStorageWord_rel_zero (word : EvmSemantics.UInt256) :
    CounterStorageWordRel (counterInitializeStorageWord word) 0 := by
  unfold counterInitializeStorageWord
  exact counterStorageWordRel_padded (counterLowPaddingNat_lt word)

theorem counterUInt256_ext_toNat {a b : EvmSemantics.UInt256}
    (h : a.toNat = b.toNat) : a = b := by
  cases a with
  | mk aval =>
    cases b with
    | mk bval =>
      simp [EvmSemantics.UInt256.toNat] at h
      cases aval with
      | mk aval avalLt =>
        cases bval with
        | mk bval bvalLt =>
          simp at h
          subst bval
          rfl

theorem counterUInt256_land_toNat
    (a b : EvmSemantics.UInt256) :
    (EvmSemantics.UInt256.land a b).toNat = a.toNat &&& b.toNat := by
  unfold EvmSemantics.UInt256.land EvmSemantics.UInt256.toNat
  change (a.val &&& b.val).val = a.val.val &&& b.val.val
  exact Fin.and_val a.val b.val

theorem counterUInt256_lor_toNat
    (a b : EvmSemantics.UInt256) :
    (EvmSemantics.UInt256.lor a b).toNat = a.toNat ||| b.toNat := by
  unfold EvmSemantics.UInt256.lor EvmSemantics.UInt256.toNat
  change (a.val ||| b.val).val = a.val.val ||| b.val.val
  rw [Fin.or_val]
  rw [Nat.mod_eq_of_lt]
  exact Nat.or_lt_two_pow (by simp [EvmSemantics.UInt256.size])
    (by simp [EvmSemantics.UInt256.size])

theorem counterUInt256_ofNat_toNat_of_lt {n : Nat}
    (h : n < EvmSemantics.UInt256.size) :
    (EvmSemantics.UInt256.ofNat n).toNat = n := by
  unfold EvmSemantics.UInt256.ofNat EvmSemantics.UInt256.toNat
  rw [Fin.val_ofNat]
  exact Nat.mod_eq_of_lt h

theorem counterUInt256_ofNat_zero_toNat :
    (EvmSemantics.UInt256.ofNat 0).toNat = 0 :=
  counterUInt256_ofNat_toNat_of_lt (by native_decide)

/-- The `PUSH0; PUSH1 0xc0; SHL` segment in the compiled initialize body. -/
def counterInitializeSetValue : EvmSemantics.UInt256 :=
  EvmSemantics.UInt256.shiftLeft
    (EvmSemantics.UInt256.ofNat 0)
    (EvmSemantics.UInt256.ofNat 192)

/-- The low-192-bit preserve mask built by the compiled initialize body. -/
def counterInitializeLowMask : EvmSemantics.UInt256 :=
  EvmSemantics.UInt256.lnot
    (EvmSemantics.UInt256.shiftLeft
      (EvmSemantics.UInt256.ofNat (2 ^ 64 - 1))
      (EvmSemantics.UInt256.ofNat 192))

def counterInitializeBodyWriteWord
    (oldWord : EvmSemantics.UInt256) : EvmSemantics.UInt256 :=
  EvmSemantics.UInt256.lor
    (EvmSemantics.UInt256.land oldWord counterInitializeLowMask)
    counterInitializeSetValue

theorem counterInitializeSetValue_eq_zero :
    counterInitializeSetValue = EvmSemantics.UInt256.ofNat 0 := by
  native_decide

theorem counterInitializeLowMask_eq :
    counterInitializeLowMask =
      EvmSemantics.UInt256.ofNat (counterU64StorageShift - 1) := by
  native_decide

theorem counterInitializeLandLowMask_toNat (word : EvmSemantics.UInt256) :
    (EvmSemantics.UInt256.land word
        (EvmSemantics.UInt256.ofNat (counterU64StorageShift - 1))).toNat =
      counterLowPaddingNat word := by
  unfold counterLowPaddingNat counterU64StorageShift
  rw [counterUInt256_land_toNat]
  unfold EvmSemantics.UInt256.toNat EvmSemantics.UInt256.ofNat
  simp only [Fin.val_ofNat]
  rw [Nat.mod_eq_of_lt]
  · rw [Nat.and_two_pow_sub_one_eq_mod]
  · unfold EvmSemantics.UInt256.size
    native_decide

theorem counterLowPaddingNat_lt_uint256Size (word : EvmSemantics.UInt256) :
    counterLowPaddingNat word < EvmSemantics.UInt256.size :=
  Nat.lt_trans (counterLowPaddingNat_lt word) (by native_decide)

theorem counterInitializeBodyWriteWord_eq_storageWord
    (word : EvmSemantics.UInt256) :
    counterInitializeBodyWriteWord word = counterInitializeStorageWord word := by
  unfold counterInitializeBodyWriteWord
  rw [counterInitializeLowMask_eq, counterInitializeSetValue_eq_zero]
  apply counterUInt256_ext_toNat
  rw [counterUInt256_lor_toNat, counterInitializeLandLowMask_toNat,
    counterUInt256_ofNat_zero_toNat]
  simp only [Nat.or_zero]
  unfold counterInitializeStorageWord counterPaddedCountValue counterPackedCountNat
  simp only [Nat.zero_mul, Nat.zero_add]
  rw [counterUInt256_ofNat_toNat_of_lt
    (counterLowPaddingNat_lt_uint256Size word)]

theorem counterInitializeBodyWriteWord_rel_zero
    (word : EvmSemantics.UInt256) :
    CounterStorageWordRel (counterInitializeBodyWriteWord word) 0 := by
  rw [counterInitializeBodyWriteWord_eq_storageWord]
  exact counterInitializeStorageWord_rel_zero word

/-- Placeholder contract account address for the storage relation.

The later bytecode-entrypoint proof should replace this default with the
address from powdr's execution environment for the deployed Counter code. -/
def counterContractAddress : EvmSemantics.AccountAddress :=
  EvmSemantics.AccountAddress.ofNat 0

def counterAccount (address : EvmSemantics.AccountAddress) (state : EvmState) :
    EvmSemantics.Account :=
  state.accountMap address

def counterStorageValue (address : EvmSemantics.AccountAddress)
    (slot : EvmSemantics.UInt256) (state : EvmState) : EvmSemantics.UInt256 :=
  (counterAccount address state).storage slot

def setCounterStorage (address : EvmSemantics.AccountAddress)
    (slot : EvmSemantics.UInt256) (state : EvmState) (value : Nat) : EvmState :=
  let account := state.accountMap address
  let storage := account.storage.set slot (counterPackedCountValue value)
  { state with
    accountMap := state.accountMap.set address { account with storage := storage } }

def setCounterStorageWord (address : EvmSemantics.AccountAddress)
    (slot : EvmSemantics.UInt256) (state : EvmState)
    (word : EvmSemantics.UInt256) : EvmState :=
  let account := state.accountMap address
  let storage := account.storage.set slot word
  { state with
    accountMap := state.accountMap.set address { account with storage := storage } }

@[simp] theorem counterStorageValue_setCounterStorage_same
    (address : EvmSemantics.AccountAddress) (slot : EvmSemantics.UInt256)
    (state : EvmState) (value : Nat) :
    counterStorageValue address slot (setCounterStorage address slot state value) =
      counterPackedCountValue value := by
  simp [counterStorageValue, counterAccount, setCounterStorage]

@[simp] theorem counterStorageValue_setCounterStorageWord_same
    (address : EvmSemantics.AccountAddress) (slot : EvmSemantics.UInt256)
    (state : EvmState) (word : EvmSemantics.UInt256) :
    counterStorageValue address slot (setCounterStorageWord address slot state word) =
      word := by
  simp [counterStorageValue, counterAccount, setCounterStorageWord]

@[simp] theorem counterStorageValue_accountMap_set_storage_same
    (state : EvmState) (address : EvmSemantics.AccountAddress)
    (slot word : EvmSemantics.UInt256) :
    counterStorageValue address slot
      { state with
        accountMap := state.accountMap.set address
          { state.accountMap address with
            storage := (state.accountMap address).storage.set slot word } } =
      word := by
  simp [counterStorageValue, counterAccount]

def counterPush0Op : EvmSemantics.Operation.PushOp :=
  { width := ⟨0, by decide⟩ }

def counterPush1Op : EvmSemantics.Operation.PushOp :=
  { width := ⟨1, by decide⟩ }

def counterPush4Op : EvmSemantics.Operation.PushOp :=
  { width := ⟨4, by decide⟩ }

def counterDup1Op : EvmSemantics.Operation.DupOp :=
  { idx := ⟨0, by decide⟩ }

def counterStepFEReady (state : EvmState) (op : EvmSemantics.Operation) : Prop :=
  state.halt = .Running ∧
    EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
      state.executionEnv.codeAddr = false ∧
    ¬ state.stack.length + op.pushArity > 1024 + op.popArity ∧
    EvmSemantics.EVM.Gas.baseCost state.fork op ≤ state.gasAvailable

theorem counterStack_of_push0_ok
    {state gasState nextState : EvmState}
    {argOpt : Option (EvmSemantics.UInt256 × Nat)}
    (hstep :
      EvmSemantics.EVM.stepF.push state gasState counterPush0Op argOpt =
        .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.ofNat 0 :: state.stack := by
  unfold EvmSemantics.EVM.stepF.push counterPush0Op at hstep
  simp at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC,
    EvmSemantics.UInt256.ofNat]

theorem counterState_of_push0_ok
    {state gasState nextState : EvmState}
    {argOpt : Option (EvmSemantics.UInt256 × Nat)}
    (hstep :
      EvmSemantics.EVM.stepF.push state gasState counterPush0Op argOpt =
        .ok nextState) :
    nextState =
      gasState.replaceStackAndIncrPC
        (EvmSemantics.UInt256.ofNat 0 :: state.stack) := by
  unfold EvmSemantics.EVM.stepF.push counterPush0Op at hstep
  simp at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC,
    EvmSemantics.UInt256.ofNat]

theorem counterStack_of_stepFE_push0_ok
    {state nextState : EvmState}
    {argOpt : Option (EvmSemantics.UInt256 × Nat)}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded : state.decoded = some (.Push counterPush0Op, argOpt))
    (hstackOk :
      ¬ state.stack.length +
          (.Push counterPush0Op : EvmSemantics.Operation).pushArity >
        1024 + (.Push counterPush0Op : EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.Push counterPush0Op : EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.ofNat 0 :: state.stack := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_push0_ok hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_stepFE_push0_ok
    {state nextState : EvmState}
    {argOpt : Option (EvmSemantics.UInt256 × Nat)}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded : state.decoded = some (.Push counterPush0Op, argOpt))
    (hstackOk :
      ¬ state.stack.length +
          (.Push counterPush0Op : EvmSemantics.Operation).pushArity >
        1024 + (.Push counterPush0Op : EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.Push counterPush0Op : EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.Push counterPush0Op : EvmSemantics.Operation)) hgas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.ofNat 0 :: state.stack) := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_push0_ok hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_push1_ok
    {state gasState nextState : EvmState}
    {value : EvmSemantics.UInt256} {argBytes : Nat}
    (hstep :
      EvmSemantics.EVM.stepF.push state gasState counterPush1Op
        (some (value, argBytes)) = .ok nextState) :
    nextState.stack = value :: state.stack := by
  unfold EvmSemantics.EVM.stepF.push counterPush1Op at hstep
  simp at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC]

theorem counterStack_of_stepFE_push1_ok
    {state nextState : EvmState}
    {value : EvmSemantics.UInt256} {argBytes : Nat}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded = some (.Push counterPush1Op, some (value, argBytes)))
    (hstackOk :
      ¬ state.stack.length +
          (.Push counterPush1Op : EvmSemantics.Operation).pushArity >
        1024 + (.Push counterPush1Op : EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.Push counterPush1Op : EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = value :: state.stack := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_push1_ok hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_push1_ok
    {state gasState nextState : EvmState}
    {value : EvmSemantics.UInt256} {argBytes : Nat}
    (hstep :
      EvmSemantics.EVM.stepF.push state gasState counterPush1Op
        (some (value, argBytes)) = .ok nextState) :
    nextState =
      gasState.replaceStackAndIncrPC (value :: state.stack)
        (pcΔ := argBytes + 1) := by
  unfold EvmSemantics.EVM.stepF.push counterPush1Op at hstep
  simp at hstep
  cases hstep
  rfl

theorem counterState_of_stepFE_push1_ok
    {state nextState : EvmState}
    {value : EvmSemantics.UInt256} {argBytes : Nat}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded = some (.Push counterPush1Op, some (value, argBytes)))
    (hstackOk :
      ¬ state.stack.length +
          (.Push counterPush1Op : EvmSemantics.Operation).pushArity >
        1024 + (.Push counterPush1Op : EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.Push counterPush1Op : EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.Push counterPush1Op : EvmSemantics.Operation)) hgas).replaceStackAndIncrPC
        (value :: state.stack) (pcΔ := argBytes + 1) := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_push1_ok hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_push4_ok
    {state gasState nextState : EvmState}
    {value : EvmSemantics.UInt256} {argBytes : Nat}
    (hstep :
      EvmSemantics.EVM.stepF.push state gasState counterPush4Op
        (some (value, argBytes)) = .ok nextState) :
    nextState =
      gasState.replaceStackAndIncrPC (value :: state.stack)
        (pcΔ := argBytes + 1) := by
  unfold EvmSemantics.EVM.stepF.push counterPush4Op at hstep
  simp at hstep
  cases hstep
  rfl

theorem counterState_of_stepFE_push4_ok
    {state nextState : EvmState}
    {value : EvmSemantics.UInt256} {argBytes : Nat}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded = some (.Push counterPush4Op, some (value, argBytes)))
    (hstackOk :
      ¬ state.stack.length +
          (.Push counterPush4Op : EvmSemantics.Operation).pushArity >
        1024 + (.Push counterPush4Op : EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.Push counterPush4Op : EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.Push counterPush4Op : EvmSemantics.Operation)) hgas).replaceStackAndIncrPC
        (value :: state.stack) (pcΔ := argBytes + 1) := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_push4_ok hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_env_calldataload_ok
    {state gasState nextState : EvmState}
    {offset : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = offset :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.env state gasState
        (.CALLDATALOAD : EvmSemantics.Operation.EnvOps) = .ok nextState) :
    nextState =
      gasState.replaceStackAndIncrPC
        (EvmSemantics.UInt256.ofNat
          (EvmSemantics.Data.Bytes.bytesToBigEndianNat
            (EvmSemantics.MachineState.readPadded
              state.executionEnv.calldata offset.toNat 32)) :: rest) := by
  unfold EvmSemantics.EVM.stepF.env at hstep
  simp [hstack] at hstep
  cases hstep
  rfl

theorem counterState_of_stepFE_env_calldataload_ok
    {state nextState : EvmState}
    {offset : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps), none))
    (hstack : state.stack = offset :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps) :
            EvmSemantics.Operation)) hgas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.ofNat
          (EvmSemantics.Data.Bytes.bytesToBigEndianNat
            (EvmSemantics.MachineState.readPadded
              state.executionEnv.calldata offset.toNat 32)) :: rest) := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_env_calldataload_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_dup1_ok
    {state gasState nextState : EvmState}
    {top : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = top :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.dup state gasState counterDup1Op =
        .ok nextState) :
    nextState.stack = top :: top :: rest := by
  unfold EvmSemantics.EVM.stepF.dup counterDup1Op at hstep
  simp [hstack] at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC]

theorem counterState_of_dup1_ok
    {state gasState nextState : EvmState}
    {top : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = top :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.dup state gasState counterDup1Op =
        .ok nextState) :
    nextState = gasState.replaceStackAndIncrPC (top :: top :: rest) := by
  unfold EvmSemantics.EVM.stepF.dup counterDup1Op at hstep
  simp [hstack] at hstep
  cases hstep
  rfl

theorem counterStack_of_stepFE_dup1_ok
    {state nextState : EvmState}
    {top : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded : state.decoded = some (.Dup counterDup1Op, none))
    (hstack : state.stack = top :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.Dup counterDup1Op : EvmSemantics.Operation).pushArity >
        1024 + (.Dup counterDup1Op : EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.Dup counterDup1Op : EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = top :: top :: rest := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_dup1_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_stepFE_dup1_ok
    {state nextState : EvmState}
    {top : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded : state.decoded = some (.Dup counterDup1Op, none))
    (hstack : state.stack = top :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.Dup counterDup1Op : EvmSemantics.Operation).pushArity >
        1024 + (.Dup counterDup1Op : EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.Dup counterDup1Op : EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.Dup counterDup1Op : EvmSemantics.Operation)) hgas).replaceStackAndIncrPC
        (top :: top :: rest) := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_dup1_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_compBit_shl_ok
    {state gasState nextState : EvmState}
    {shift value : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = shift :: value :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.compBit state gasState
        (.SHL : EvmSemantics.Operation.CompareBitwiseOps) = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.shiftLeft value shift :: rest := by
  unfold EvmSemantics.EVM.stepF.compBit at hstep
  simp [hstack] at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC]

theorem counterStack_of_stepFE_compBit_shl_ok
    {state nextState : EvmState}
    {shift value : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = shift :: value :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.shiftLeft value shift :: rest := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_compBit_shl_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_compBit_shr_ok
    {state gasState nextState : EvmState}
    {shift value : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = shift :: value :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.compBit state gasState
        (.SHR : EvmSemantics.Operation.CompareBitwiseOps) = .ok nextState) :
    nextState =
      gasState.replaceStackAndIncrPC
        (EvmSemantics.UInt256.shiftRight value shift :: rest) := by
  unfold EvmSemantics.EVM.stepF.compBit at hstep
  simp [hstack] at hstep
  cases hstep
  rfl

theorem counterState_of_stepFE_compBit_shr_ok
    {state nextState : EvmState}
    {shift value : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = shift :: value :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation)) hgas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.shiftRight value shift :: rest) := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_compBit_shr_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_compBit_eq_ok
    {state gasState nextState : EvmState}
    {a b : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = a :: b :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.compBit state gasState
        (.EQ : EvmSemantics.Operation.CompareBitwiseOps) = .ok nextState) :
    nextState =
      gasState.replaceStackAndIncrPC
        (EvmSemantics.UInt256.eq a b :: rest) := by
  unfold EvmSemantics.EVM.stepF.compBit at hstep
  simp [hstack] at hstep
  cases hstep
  rfl

theorem counterState_of_stepFE_compBit_eq_ok
    {state nextState : EvmState}
    {a b : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = a :: b :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation)) hgas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.eq a b :: rest) := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_compBit_eq_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_compBit_not_ok
    {state gasState nextState : EvmState}
    {value : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = value :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.compBit state gasState
        (.NOT : EvmSemantics.Operation.CompareBitwiseOps) = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.lnot value :: rest := by
  unfold EvmSemantics.EVM.stepF.compBit at hstep
  simp [hstack] at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC]

theorem counterStack_of_stepFE_compBit_not_ok
    {state nextState : EvmState}
    {value : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = value :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.lnot value :: rest := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_compBit_not_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_stopArith_sub_ok
    {state gasState nextState : EvmState}
    {a b : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = a :: b :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.stopArith state gasState
        (.SUB : EvmSemantics.Operation.StopArithOps) = .ok nextState) :
    nextState.stack = (a - b) :: rest := by
  unfold EvmSemantics.EVM.stepF.stopArith at hstep
  simp [hstack] at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC]

theorem counterStack_of_stepFE_stopArith_sub_ok
    {state nextState : EvmState}
    {a b : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps), none))
    (hstack : state.stack = a :: b :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = (a - b) :: rest := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_stopArith_sub_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterInitializeU64MaskBase_eq :
    (EvmSemantics.UInt256.shiftLeft
        (EvmSemantics.UInt256.ofNat 1)
        (EvmSemantics.UInt256.ofNat 64) -
      EvmSemantics.UInt256.ofNat 1) =
      EvmSemantics.UInt256.ofNat (2 ^ 64 - 1) := by
  native_decide

theorem counterCountSlot_eq_zero :
    counterCountSlot = EvmSemantics.UInt256.ofNat 0 := by
  rfl

theorem counterStack_of_initialize_prefix_to_sload_ok
    {s0 g0 s1 g1 s2 g2 s3 g3 s4 g4 s5 g5 s6 g6 s7 g7 s8 g8
      s9 g9 s10 g10 s11 g11 s12 : EvmState}
    {rest : List EvmSemantics.UInt256}
    (h0 : s0.stack = rest)
    (hp0 :
      EvmSemantics.EVM.stepF.push s0 g0 counterPush0Op none = .ok s1)
    (hp192a :
      EvmSemantics.EVM.stepF.push s1 g1 counterPush1Op
        (some (EvmSemantics.UInt256.ofNat 192, 1)) = .ok s2)
    (hshlSet :
      EvmSemantics.EVM.stepF.compBit s2 g2
        (.SHL : EvmSemantics.Operation.CompareBitwiseOps) = .ok s3)
    (hp1a :
      EvmSemantics.EVM.stepF.push s3 g3 counterPush1Op
        (some (EvmSemantics.UInt256.ofNat 1, 1)) = .ok s4)
    (hdup1 :
      EvmSemantics.EVM.stepF.dup s4 g4 counterDup1Op = .ok s5)
    (hp64 :
      EvmSemantics.EVM.stepF.push s5 g5 counterPush1Op
        (some (EvmSemantics.UInt256.ofNat 64, 1)) = .ok s6)
    (hshl64 :
      EvmSemantics.EVM.stepF.compBit s6 g6
        (.SHL : EvmSemantics.Operation.CompareBitwiseOps) = .ok s7)
    (hsub :
      EvmSemantics.EVM.stepF.stopArith s7 g7
        (.SUB : EvmSemantics.Operation.StopArithOps) = .ok s8)
    (hp192b :
      EvmSemantics.EVM.stepF.push s8 g8 counterPush1Op
        (some (EvmSemantics.UInt256.ofNat 192, 1)) = .ok s9)
    (hshlMask :
      EvmSemantics.EVM.stepF.compBit s9 g9
        (.SHL : EvmSemantics.Operation.CompareBitwiseOps) = .ok s10)
    (hnot :
      EvmSemantics.EVM.stepF.compBit s10 g10
        (.NOT : EvmSemantics.Operation.CompareBitwiseOps) = .ok s11)
    (hp0Slot :
      EvmSemantics.EVM.stepF.push s11 g11 counterPush0Op none = .ok s12) :
    s12.stack =
      counterCountSlot :: counterInitializeLowMask ::
        counterInitializeSetValue :: rest := by
  have h1 : s1.stack = EvmSemantics.UInt256.ofNat 0 :: rest := by
    rw [counterStack_of_push0_ok hp0, h0]
  have h2 :
      s2.stack =
        EvmSemantics.UInt256.ofNat 192 ::
          EvmSemantics.UInt256.ofNat 0 :: rest := by
    rw [counterStack_of_push1_ok hp192a, h1]
  have h3 : s3.stack = counterInitializeSetValue :: rest := by
    rw [counterStack_of_compBit_shl_ok h2 hshlSet]
    rfl
  have h4 :
      s4.stack =
        EvmSemantics.UInt256.ofNat 1 :: counterInitializeSetValue :: rest := by
    rw [counterStack_of_push1_ok hp1a, h3]
  have h5 :
      s5.stack =
        EvmSemantics.UInt256.ofNat 1 :: EvmSemantics.UInt256.ofNat 1 ::
          counterInitializeSetValue :: rest := by
    rw [counterStack_of_dup1_ok h4 hdup1]
  have h6 :
      s6.stack =
        EvmSemantics.UInt256.ofNat 64 :: EvmSemantics.UInt256.ofNat 1 ::
          EvmSemantics.UInt256.ofNat 1 :: counterInitializeSetValue ::
            rest := by
    rw [counterStack_of_push1_ok hp64, h5]
  have h7 :
      s7.stack =
        EvmSemantics.UInt256.shiftLeft
          (EvmSemantics.UInt256.ofNat 1)
          (EvmSemantics.UInt256.ofNat 64) ::
          EvmSemantics.UInt256.ofNat 1 :: counterInitializeSetValue ::
            rest := by
    rw [counterStack_of_compBit_shl_ok h6 hshl64]
  have h8 :
      s8.stack =
        EvmSemantics.UInt256.ofNat (2 ^ 64 - 1) ::
          counterInitializeSetValue :: rest := by
    rw [counterStack_of_stopArith_sub_ok h7 hsub,
      counterInitializeU64MaskBase_eq]
  have h9 :
      s9.stack =
        EvmSemantics.UInt256.ofNat 192 ::
          EvmSemantics.UInt256.ofNat (2 ^ 64 - 1) ::
            counterInitializeSetValue :: rest := by
    rw [counterStack_of_push1_ok hp192b, h8]
  have h10 :
      s10.stack =
        EvmSemantics.UInt256.shiftLeft
          (EvmSemantics.UInt256.ofNat (2 ^ 64 - 1))
          (EvmSemantics.UInt256.ofNat 192) ::
          counterInitializeSetValue :: rest := by
    rw [counterStack_of_compBit_shl_ok h9 hshlMask]
  have h11 :
      s11.stack = counterInitializeLowMask :: counterInitializeSetValue ::
        rest := by
    rw [counterStack_of_compBit_not_ok h10 hnot]
    rfl
  rw [counterStack_of_push0_ok hp0Slot, h11, counterCountSlot_eq_zero]

theorem counterStack_of_sload_stackMemFlow_ok
    {state gasState nextState : EvmState} {slot : EvmSemantics.UInt256}
    {rest : List EvmSemantics.UInt256}
    (haddr : state.executionEnv.address = counterContractAddress)
    (hstack : state.stack = slot :: rest)
    (hslot : slot = counterCountSlot)
    (hstep :
      EvmSemantics.EVM.stepF.stackMemFlow state gasState
        (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    nextState.stack =
      counterStorageValue counterContractAddress counterCountSlot state :: rest := by
  unfold EvmSemantics.EVM.stepF.stackMemFlow at hstep
  simp [hstack] at hstep
  by_cases hgas : EvmSemantics.EVM.Gas.sloadTotal state slot ≤ state.gasAvailable
  · simp [hgas] at hstep
    cases hstep
    simp [counterStorageValue, counterAccount,
      EvmSemantics.EVM.State.replaceStackAndIncrPC, haddr, hslot]
  · simp [hgas] at hstep

theorem counterState_of_stackMemFlow_jumpdest_ok
    {state gasState nextState : EvmState}
    (hstep :
      EvmSemantics.EVM.stepF.stackMemFlow state gasState
        (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    nextState = gasState.incrPC := by
  unfold EvmSemantics.EVM.stepF.stackMemFlow at hstep
  cases hstep
  rfl

theorem counterState_of_stepFE_stackMemFlow_jumpdest_ok
    {state nextState : EvmState}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.StackMemFlow
          (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstackOk :
      ¬ state.stack.length +
          (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation)) hgas).incrPC := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_stackMemFlow_jumpdest_ok hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_stackMemFlow_jump_ok
    {state gasState nextState : EvmState}
    {dest : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = dest :: rest)
    (hvalid :
      EvmSemantics.EVM.Decode.isValidJumpDest state.executionEnv.code
        dest.toNat = true)
    (hstep :
      EvmSemantics.EVM.stepF.stackMemFlow state gasState
        (.JUMP : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    nextState = { gasState with pc := dest, stack := rest } := by
  unfold EvmSemantics.EVM.stepF.stackMemFlow at hstep
  simp [hstack, hvalid] at hstep
  cases hstep
  rfl

theorem counterState_of_stepFE_stackMemFlow_jump_ok
    {state nextState : EvmState}
    {dest : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.StackMemFlow
          (.JUMP : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = dest :: rest)
    (hvalid :
      EvmSemantics.EVM.Decode.isValidJumpDest state.executionEnv.code
        dest.toNat = true)
    (hstackOk :
      ¬ state.stack.length +
          (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      { state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps) :
              EvmSemantics.Operation)) hgas with
        pc := dest, stack := rest } := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_stackMemFlow_jump_ok hstack hvalid hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterState_of_stackMemFlow_jumpi_taken_ok
    {state gasState nextState : EvmState}
    {dest cond : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = dest :: cond :: rest)
    (hcond : cond.toNat ≠ 0)
    (hvalid :
      EvmSemantics.EVM.Decode.isValidJumpDest state.executionEnv.code
        dest.toNat = true)
    (hstep :
      EvmSemantics.EVM.stepF.stackMemFlow state gasState
        (.JUMPI : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    nextState = { gasState with pc := dest, stack := rest } := by
  unfold EvmSemantics.EVM.stepF.stackMemFlow at hstep
  simp [hstack, hcond, hvalid] at hstep
  cases hstep
  rfl

theorem counterState_of_stepFE_stackMemFlow_jumpi_taken_ok
    {state nextState : EvmState}
    {dest cond : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.StackMemFlow
          (.JUMPI : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = dest :: cond :: rest)
    (hcond : cond.toNat ≠ 0)
    (hvalid :
      EvmSemantics.EVM.Decode.isValidJumpDest state.executionEnv.code
        dest.toNat = true)
    (hstackOk :
      ¬ state.stack.length +
          (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState =
      { state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps) :
              EvmSemantics.Operation)) hgas with
        pc := dest, stack := rest } := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterState_of_stackMemFlow_jumpi_taken_ok hstack hcond hvalid hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_stepFE_stackMemFlow_sload_ok
    {state nextState : EvmState} {slot : EvmSemantics.UInt256}
    {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.StackMemFlow
          (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none))
    (haddr : state.executionEnv.address = counterContractAddress)
    (hstack : state.stack = slot :: rest)
    (hslot : slot = counterCountSlot)
    (hstackOk :
      ¬ state.stack.length +
          (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack =
      counterStorageValue counterContractAddress counterCountSlot state :: rest := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_sload_stackMemFlow_ok haddr hstack hslot hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_compBit_and_ok
    {state gasState nextState : EvmState} {a b : EvmSemantics.UInt256}
    {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = a :: b :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.compBit state gasState
        (.AND : EvmSemantics.Operation.CompareBitwiseOps) = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.land a b :: rest := by
  unfold EvmSemantics.EVM.stepF.compBit at hstep
  simp [hstack] at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC]

theorem counterStack_of_stepFE_compBit_and_ok
    {state nextState : EvmState}
    {a b : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = a :: b :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.land a b :: rest := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_compBit_and_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_compBit_or_ok
    {state gasState nextState : EvmState} {a b : EvmSemantics.UInt256}
    {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = a :: b :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.compBit state gasState
        (.OR : EvmSemantics.Operation.CompareBitwiseOps) = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.lor a b :: rest := by
  unfold EvmSemantics.EVM.stepF.compBit at hstep
  simp [hstack] at hstep
  cases hstep
  simp [EvmSemantics.EVM.State.replaceStackAndIncrPC]

theorem counterStack_of_stepFE_compBit_or_ok
    {state nextState : EvmState}
    {a b : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = a :: b :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = EvmSemantics.UInt256.lor a b :: rest := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_compBit_or_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_initialize_sload_and_or_ok
    {sloadState sloadGas afterSload andGas afterAnd orGas afterOr : EvmState}
    {mask setValue : EvmSemantics.UInt256} {rest : List EvmSemantics.UInt256}
    (haddr : sloadState.executionEnv.address = counterContractAddress)
    (hstack : sloadState.stack = counterCountSlot :: mask :: setValue :: rest)
    (hsload :
      EvmSemantics.EVM.stepF.stackMemFlow sloadState sloadGas
        (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) = .ok afterSload)
    (hand :
      EvmSemantics.EVM.stepF.compBit afterSload andGas
        (.AND : EvmSemantics.Operation.CompareBitwiseOps) = .ok afterAnd)
    (hor :
      EvmSemantics.EVM.stepF.compBit afterAnd orGas
        (.OR : EvmSemantics.Operation.CompareBitwiseOps) = .ok afterOr) :
    afterOr.stack =
      EvmSemantics.UInt256.lor
        (EvmSemantics.UInt256.land
          (counterStorageValue counterContractAddress counterCountSlot sloadState)
          mask)
        setValue :: rest := by
  have hsloadStack :
      afterSload.stack =
        counterStorageValue counterContractAddress counterCountSlot sloadState ::
          mask :: setValue :: rest :=
    counterStack_of_sload_stackMemFlow_ok haddr hstack rfl hsload
  have handStack :
      afterAnd.stack =
        EvmSemantics.UInt256.land
          (counterStorageValue counterContractAddress counterCountSlot sloadState)
          mask :: setValue :: rest :=
    counterStack_of_compBit_and_ok hsloadStack hand
  exact counterStack_of_compBit_or_ok handStack hor

theorem counterStack_of_initialize_sload_and_or_storageWord_ok
    {sloadState sloadGas afterSload andGas afterAnd orGas afterOr : EvmState}
    {rest : List EvmSemantics.UInt256}
    (haddr : sloadState.executionEnv.address = counterContractAddress)
    (hstack :
      sloadState.stack =
        counterCountSlot :: counterInitializeLowMask ::
          counterInitializeSetValue :: rest)
    (hsload :
      EvmSemantics.EVM.stepF.stackMemFlow sloadState sloadGas
        (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) = .ok afterSload)
    (hand :
      EvmSemantics.EVM.stepF.compBit afterSload andGas
        (.AND : EvmSemantics.Operation.CompareBitwiseOps) = .ok afterAnd)
    (hor :
      EvmSemantics.EVM.stepF.compBit afterAnd orGas
        (.OR : EvmSemantics.Operation.CompareBitwiseOps) = .ok afterOr) :
    afterOr.stack =
      counterInitializeStorageWord
        (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest := by
  have hstackAfter :=
    counterStack_of_initialize_sload_and_or_ok haddr hstack hsload hand hor
  rw [hstackAfter]
  change counterInitializeBodyWriteWord
      (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
        rest =
    counterInitializeStorageWord
      (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
        rest
  rw [counterInitializeBodyWriteWord_eq_storageWord]

theorem counterStorageValue_of_sstore_stackMemFlow_ok
    {state gasState nextState : EvmState} {slot value : EvmSemantics.UInt256}
    {rest : List EvmSemantics.UInt256}
    (haddr : state.executionEnv.address = counterContractAddress)
    (hstack : state.stack = slot :: value :: rest)
    (hslot : slot = counterCountSlot)
    (hstep :
      EvmSemantics.EVM.stepF.stackMemFlow state gasState
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    counterStorageValue counterContractAddress counterCountSlot nextState = value := by
  unfold EvmSemantics.EVM.stepF.stackMemFlow at hstep
  cases hperm : state.executionEnv.permitStateMutation
  · simp [hperm, EvmSemantics.EVM.static] at hstep
  · simp [hperm] at hstep
    by_cases hsentry :
        EvmSemantics.EVM.Gas.sstoreSentry state.fork gasState.gasAvailable
    · simp [hsentry] at hstep
    · simp [hsentry, hstack] at hstep
      by_cases hgas :
          EvmSemantics.EVM.Gas.sstoreCost state.fork
              (state.substate.originalStorage state.executionEnv.address slot)
              ((state.accountMap state.executionEnv.address).storage slot) value +
            EvmSemantics.EVM.Gas.sstoreColdSurcharge state slot ≤ gasState.gasAvailable
      · simp [hgas] at hstep
        cases hstep
        simp [counterStorageValue, counterAccount,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, haddr, hslot]
      · simp [hgas] at hstep

theorem counterStorageValue_of_stepFE_stackMemFlow_sstore_ok
    {state nextState : EvmState} {slot value : EvmSemantics.UInt256}
    {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.StackMemFlow
          (.SSTORE : EvmSemantics.Operation.StackMemFlowOps), none))
    (haddr : state.executionEnv.address = counterContractAddress)
    (hstack : state.stack = slot :: value :: rest)
    (hslot : slot = counterCountSlot)
    (hstackOk :
      ¬ state.stack.length +
          (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterStorageValue counterContractAddress counterCountSlot nextState = value := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStorageValue_of_sstore_stackMemFlow_ok haddr hstack hslot hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterStack_of_sstore_stackMemFlow_ok
    {state gasState nextState : EvmState} {slot value : EvmSemantics.UInt256}
    {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = slot :: value :: rest)
    (hstep :
      EvmSemantics.EVM.stepF.stackMemFlow state gasState
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    nextState.stack = rest := by
  unfold EvmSemantics.EVM.stepF.stackMemFlow at hstep
  cases hperm : state.executionEnv.permitStateMutation
  · simp [hperm, EvmSemantics.EVM.static] at hstep
  · simp [hperm] at hstep
    by_cases hsentry :
        EvmSemantics.EVM.Gas.sstoreSentry state.fork gasState.gasAvailable
    · simp [hsentry] at hstep
    · simp [hsentry, hstack] at hstep
      by_cases hgas :
          EvmSemantics.EVM.Gas.sstoreCost state.fork
              (state.substate.originalStorage state.executionEnv.address slot)
              ((state.accountMap state.executionEnv.address).storage slot) value +
            EvmSemantics.EVM.Gas.sstoreColdSurcharge state slot ≤ gasState.gasAvailable
      · simp [hgas] at hstep
        cases hstep
        simp [EvmSemantics.EVM.State.replaceStackAndIncrPC]
      · simp [hgas] at hstep

theorem counterStack_of_stepFE_stackMemFlow_sstore_ok
    {state nextState : EvmState} {slot value : EvmSemantics.UInt256}
    {rest : List EvmSemantics.UInt256}
    (hrunning : state.halt = .Running)
    (hprecompile :
      EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
        state.executionEnv.codeAddr = false)
    (hdecoded :
      state.decoded =
        some (.StackMemFlow
          (.SSTORE : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = slot :: value :: rest)
    (hstackOk :
      ¬ state.stack.length +
          (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).pushArity >
        1024 + (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).popArity)
    (hgas :
      EvmSemantics.EVM.Gas.baseCost state.fork
        (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
          EvmSemantics.Operation) ≤ state.gasAvailable)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack = rest := by
  unfold EvmSemantics.EVM.stepFE at hstep
  simp only [Id.run] at hstep
  split at hstep
  · split at hstep
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas] at hstep
      exact counterStack_of_sstore_stackMemFlow_ok hstack hstep
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem counterInitializeStorageValue_of_sstore_stackMemFlow_ok
    {state gasState nextState : EvmState} {rest : List EvmSemantics.UInt256}
    (haddr : state.executionEnv.address = counterContractAddress)
    (hstack :
      state.stack =
        counterCountSlot ::
          counterInitializeStorageWord
            (counterStorageValue counterContractAddress counterCountSlot state) ::
          rest)
    (hstep :
      EvmSemantics.EVM.stepF.stackMemFlow state gasState
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    counterStorageValue counterContractAddress counterCountSlot nextState =
      counterInitializeStorageWord
        (counterStorageValue counterContractAddress counterCountSlot state) :=
  counterStorageValue_of_sstore_stackMemFlow_ok haddr hstack rfl hstep

theorem counterStorageValue_of_initialize_sload_and_or_push_sstore_ok
    {sloadState sloadGas afterSload andGas afterAnd orGas afterOr pushGas
      sstoreState sstoreGas nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (haddrSload : sloadState.executionEnv.address = counterContractAddress)
    (haddrSstore : sstoreState.executionEnv.address = counterContractAddress)
    (hstack :
      sloadState.stack =
        counterCountSlot :: counterInitializeLowMask ::
          counterInitializeSetValue :: rest)
    (hsload :
      EvmSemantics.EVM.stepF.stackMemFlow sloadState sloadGas
        (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) = .ok afterSload)
    (hand :
      EvmSemantics.EVM.stepF.compBit afterSload andGas
        (.AND : EvmSemantics.Operation.CompareBitwiseOps) = .ok afterAnd)
    (hor :
      EvmSemantics.EVM.stepF.compBit afterAnd orGas
        (.OR : EvmSemantics.Operation.CompareBitwiseOps) = .ok afterOr)
    (hpushSlot :
      EvmSemantics.EVM.stepF.push afterOr pushGas counterPush0Op none =
        .ok sstoreState)
    (hsstore :
      EvmSemantics.EVM.stepF.stackMemFlow sstoreState sstoreGas
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    counterStorageValue counterContractAddress counterCountSlot nextState =
      counterInitializeStorageWord
        (counterStorageValue counterContractAddress counterCountSlot sloadState) := by
  have horStack :=
    counterStack_of_initialize_sload_and_or_storageWord_ok haddrSload hstack
      hsload hand hor
  have hsstoreStack :
      sstoreState.stack =
        counterCountSlot ::
          counterInitializeStorageWord
            (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest := by
    rw [counterStack_of_push0_ok hpushSlot, horStack]
    rw [← counterCountSlot_eq_zero]
  exact counterStorageValue_of_sstore_stackMemFlow_ok haddrSstore
    hsstoreStack rfl hsstore

theorem counterStorageValue_of_initialize_body_helpers_ok
    {s0 g0 s1 g1 s2 g2 s3 g3 s4 g4 s5 g5 s6 g6 s7 g7 s8 g8
      s9 g9 s10 g10 s11 g11 s12 sloadGas afterSload andGas afterAnd
      orGas afterOr pushGas sstoreState sstoreGas nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (haddrSload : s12.executionEnv.address = counterContractAddress)
    (haddrSstore : sstoreState.executionEnv.address = counterContractAddress)
    (h0 : s0.stack = rest)
    (hp0 :
      EvmSemantics.EVM.stepF.push s0 g0 counterPush0Op none = .ok s1)
    (hp192a :
      EvmSemantics.EVM.stepF.push s1 g1 counterPush1Op
        (some (EvmSemantics.UInt256.ofNat 192, 1)) = .ok s2)
    (hshlSet :
      EvmSemantics.EVM.stepF.compBit s2 g2
        (.SHL : EvmSemantics.Operation.CompareBitwiseOps) = .ok s3)
    (hp1a :
      EvmSemantics.EVM.stepF.push s3 g3 counterPush1Op
        (some (EvmSemantics.UInt256.ofNat 1, 1)) = .ok s4)
    (hdup1 :
      EvmSemantics.EVM.stepF.dup s4 g4 counterDup1Op = .ok s5)
    (hp64 :
      EvmSemantics.EVM.stepF.push s5 g5 counterPush1Op
        (some (EvmSemantics.UInt256.ofNat 64, 1)) = .ok s6)
    (hshl64 :
      EvmSemantics.EVM.stepF.compBit s6 g6
        (.SHL : EvmSemantics.Operation.CompareBitwiseOps) = .ok s7)
    (hsub :
      EvmSemantics.EVM.stepF.stopArith s7 g7
        (.SUB : EvmSemantics.Operation.StopArithOps) = .ok s8)
    (hp192b :
      EvmSemantics.EVM.stepF.push s8 g8 counterPush1Op
        (some (EvmSemantics.UInt256.ofNat 192, 1)) = .ok s9)
    (hshlMask :
      EvmSemantics.EVM.stepF.compBit s9 g9
        (.SHL : EvmSemantics.Operation.CompareBitwiseOps) = .ok s10)
    (hnot :
      EvmSemantics.EVM.stepF.compBit s10 g10
        (.NOT : EvmSemantics.Operation.CompareBitwiseOps) = .ok s11)
    (hp0Slot :
      EvmSemantics.EVM.stepF.push s11 g11 counterPush0Op none = .ok s12)
    (hsload :
      EvmSemantics.EVM.stepF.stackMemFlow s12 sloadGas
        (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) = .ok afterSload)
    (hand :
      EvmSemantics.EVM.stepF.compBit afterSload andGas
        (.AND : EvmSemantics.Operation.CompareBitwiseOps) = .ok afterAnd)
    (hor :
      EvmSemantics.EVM.stepF.compBit afterAnd orGas
        (.OR : EvmSemantics.Operation.CompareBitwiseOps) = .ok afterOr)
    (hpushSlot :
      EvmSemantics.EVM.stepF.push afterOr pushGas counterPush0Op none =
        .ok sstoreState)
    (hsstore :
      EvmSemantics.EVM.stepF.stackMemFlow sstoreState sstoreGas
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) = .ok nextState) :
    counterStorageValue counterContractAddress counterCountSlot nextState =
      counterInitializeStorageWord
        (counterStorageValue counterContractAddress counterCountSlot s12) := by
  have hsloadStack :=
    counterStack_of_initialize_prefix_to_sload_ok h0 hp0 hp192a hshlSet
      hp1a hdup1 hp64 hshl64 hsub hp192b hshlMask hnot hp0Slot
  exact counterStorageValue_of_initialize_sload_and_or_push_sstore_ok
    haddrSload haddrSstore hsloadStack hsload hand hor hpushSlot hsstore

def irCounterCount? (state : IRState) : Option Nat :=
  match state.read "count" with
  | some (.u64 count) => some count
  | _ => none

theorem irCounterCount?_write_count (state : IRState) (count : Nat) :
    irCounterCount? (state.write "count" (.u64 count)) = some count := by
  simp [irCounterCount?, State.read, State.write,
    ProofForge.Backend.Refinement.CounterUniversal.lookup_insert_same]

def CounterStorageRelAt (address : EvmSemantics.AccountAddress)
    (slot : EvmSemantics.UInt256) (irState : IRState) (evmState : EvmState) : Prop :=
  ∃ count,
    irCounterCount? irState = some count ∧
    count < counterU64Modulus ∧
    CounterStorageWordRel (counterStorageValue address slot evmState) count

def CounterStorageRel : IRState → EvmState → Prop :=
  CounterStorageRelAt counterContractAddress counterCountSlot

theorem counterStorageRel_left_counterStateRel
    {irState : IRState} {evmState : EvmState}
    (hrel : CounterStorageRel irState evmState) :
    ∃ count,
      ProofForge.Backend.Refinement.CounterUniversal.CounterStateRel irState count := by
  rcases hrel with ⟨count, hcount, _hbound, _hstorage⟩
  refine ⟨count, ?_⟩
  unfold ProofForge.Backend.Refinement.CounterUniversal.CounterStateRel
  unfold irCounterCount? at hcount
  cases hread : irState.read "count" with
  | none =>
      simp [hread] at hcount
  | some value =>
      cases value <;> simp [hread] at hcount
      case u64 value =>
        cases hcount
        rfl

theorem counterStateRel_irCounterCount?
    {irState : IRState} {count : Nat}
    (hcounter : ProofForge.Backend.Refinement.CounterUniversal.CounterStateRel
      irState count) :
    irCounterCount? irState = some count := by
  unfold ProofForge.Backend.Refinement.CounterUniversal.CounterStateRel at hcounter
  unfold irCounterCount?
  rw [hcounter]

theorem counterStateRel_of_irCounterCount?
    {irState : IRState} {count : Nat}
    (hcount : irCounterCount? irState = some count) :
    ProofForge.Backend.Refinement.CounterUniversal.CounterStateRel irState count := by
  unfold ProofForge.Backend.Refinement.CounterUniversal.CounterStateRel
  unfold irCounterCount? at hcount
  cases hread : irState.read "count" with
  | none =>
      simp [hread] at hcount
  | some value =>
      cases value <;> simp [hread] at hcount
      case u64 value =>
        cases hcount
        rfl

theorem counterStorageRel_count_bound
    {irState : IRState} {evmState : EvmState}
    (hrel : CounterStorageRel irState evmState) :
    ∃ count,
      irCounterCount? irState = some count ∧
      count < counterU64Modulus := by
  rcases hrel with ⟨count, hcount, hbound, _hstorage⟩
  exact ⟨count, hcount, hbound⟩

theorem counterStorageRelAt_set_count (address : EvmSemantics.AccountAddress)
    (slot : EvmSemantics.UInt256) (irState : IRState) (evmState : EvmState)
    (count : Nat) (hbound : count < counterU64Modulus) :
    CounterStorageRelAt address slot
      (irState.write "count" (.u64 count))
      (setCounterStorage address slot evmState count) := by
  refine ⟨count, irCounterCount?_write_count irState count, hbound, ?_⟩
  simp [counterStorageWordRel_packed]

theorem counterStorageRel_set_count (irState : IRState) (evmState : EvmState)
    (count : Nat) (hbound : count < counterU64Modulus) :
    CounterStorageRel
      (irState.write "count" (.u64 count))
      (setCounterStorage counterContractAddress counterCountSlot evmState count) :=
  counterStorageRelAt_set_count counterContractAddress counterCountSlot irState evmState count hbound

theorem counterStorageRelAt_set_padded_count (address : EvmSemantics.AccountAddress)
    (slot : EvmSemantics.UInt256) (irState : IRState) (evmState : EvmState)
    (count padding : Nat) (hbound : count < counterU64Modulus)
    (hpadding : padding < counterU64StorageShift) :
    CounterStorageRelAt address slot
      (irState.write "count" (.u64 count))
      (setCounterStorageWord address slot evmState
        (counterPaddedCountValue count padding)) := by
  refine ⟨count, irCounterCount?_write_count irState count, hbound, ?_⟩
  simp [counterStorageWordRel_padded hpadding]

theorem counterStorageRel_set_padded_count (irState : IRState) (evmState : EvmState)
    (count padding : Nat) (hbound : count < counterU64Modulus)
    (hpadding : padding < counterU64StorageShift) :
    CounterStorageRel
      (irState.write "count" (.u64 count))
      (setCounterStorageWord counterContractAddress counterCountSlot evmState
        (counterPaddedCountValue count padding)) :=
  counterStorageRelAt_set_padded_count counterContractAddress counterCountSlot
    irState evmState count padding hbound hpadding

def counterCallSelector : CounterCall → String
  | .initialize => "8129fc1c"
  | .increment => "d09de08a"
  | .get => "6d4ce63c"

theorem counterCallSelector_matches_entrypoint (call : CounterCall) :
    call.entrypoint.selector? = some (counterCallSelector call) := by
  cases call <;> rfl

def counterCallCalldata : CounterCall → ByteArray
  | .initialize => ByteArray.mk #[0x81, 0x29, 0xfc, 0x1c]
  | .increment => ByteArray.mk #[0xd0, 0x9d, 0xe0, 0x8a]
  | .get => ByteArray.mk #[0x6d, 0x4c, 0xe6, 0x3c]

theorem counterCallCalldata_size (call : CounterCall) :
    (counterCallCalldata call).size = 4 := by
  cases call <;> rfl

def counterTraceSafeFromCount : Nat → List CounterCall → Bool
  | count, [] => decide (count < counterU64Modulus)
  | _count, .initialize :: rest => counterTraceSafeFromCount 0 rest
  | count, .get :: rest =>
      decide (count < counterU64Modulus) && counterTraceSafeFromCount count rest
  | count, .increment :: rest =>
      decide (count + 1 < counterU64Modulus) &&
        counterTraceSafeFromCount (count + 1) rest

def counterTraceSafeAfterInitialize (calls : List CounterCall) : Bool :=
  counterTraceSafeFromCount 0 calls

def CounterTraceSafeAtState (irState : IRState) (calls : List CounterCall) : Prop :=
  ∀ count, irCounterCount? irState = some count →
    counterTraceSafeFromCount count calls = true

theorem counterTraceSafe_initialize_get_increment_get :
    counterTraceSafeAfterInitialize [.get, .increment, .get] = true := by
  native_decide

theorem counterTraceUnsafe_increment_at_u64_max :
    counterTraceSafeFromCount (counterU64Modulus - 1) [.increment] = false := by
  native_decide

def byteArrayHasSliceAt (bytes needle : ByteArray) (offset : Nat) : Bool :=
  offset + needle.size <= bytes.size &&
    bytes.extract offset (offset + needle.size) == needle

/-! The concrete Counter runtime emitted by:
`lake env proof-forge emit --target evm --fixture counter --format bytecode`.

This fixes the bytecode-side witness for the opt-in powdr lane. If the EVM
emitter or pinned `solc` changes, regenerate this literal and re-check the
selector-offset theorems below; the Yul-to-bytecode hop remains the documented
`solc` trust boundary.
-/
def counterCompiledRuntimeCode : ByteArray :=
  ByteArray.mk #[
    0x5f, 0x35, 0x60, 0xe0, 0x1c, 0x80, 0x63, 0x81, 0x29, 0xfc, 0x1c, 0x14,
    0x60, 0x3c, 0x57, 0x80, 0x63, 0xd0, 0x9d, 0xe0, 0x8a, 0x14, 0x60, 0x32,
    0x57, 0x63, 0x6d, 0x4c, 0xe6, 0x3c, 0x14, 0x60, 0x25, 0x57, 0x5f, 0x80,
    0xfd, 0x5b, 0x60, 0x2b, 0x60, 0x87, 0x56, 0x5b, 0x5f, 0x52, 0x60, 0x20,
    0x5f, 0xf3, 0x5b, 0x60, 0x38, 0x60, 0x5d, 0x56, 0x5b, 0x5f, 0x80, 0xf3,
    0x5b, 0x60, 0x42, 0x60, 0x46, 0x56, 0x5b, 0x5f, 0x80, 0xf3, 0x5b, 0x5f,
    0x60, 0xc0, 0x1b, 0x60, 0x01, 0x80, 0x60, 0x40, 0x1b, 0x03, 0x60, 0xc0,
    0x1b, 0x19, 0x5f, 0x54, 0x16, 0x17, 0x5f, 0x55, 0x56, 0x5b, 0x60, 0x71,
    0x60, 0x01, 0x80, 0x80, 0x60, 0x40, 0x1b, 0x03, 0x5f, 0x54, 0x60, 0xc0,
    0x1c, 0x16, 0x60, 0x97, 0x56, 0x5b, 0x60, 0xc0, 0x1b, 0x60, 0x01, 0x80,
    0x60, 0x40, 0x1b, 0x03, 0x60, 0xc0, 0x1b, 0x19, 0x5f, 0x54, 0x16, 0x17,
    0x5f, 0x55, 0x56, 0x5b, 0x60, 0x01, 0x80, 0x60, 0x40, 0x1b, 0x03, 0x5f,
    0x54, 0x60, 0xc0, 0x1c, 0x16, 0x90, 0x56, 0x5b, 0x81, 0x5f, 0x19, 0x03,
    0x81, 0x11, 0x60, 0xa4, 0x57, 0x01, 0x90, 0x56, 0x5b, 0x5f, 0x80, 0xfd,
    0xa1, 0x64, 0x73, 0x6f, 0x6c, 0x63, 0x43, 0x00, 0x08, 0x22, 0x00, 0x0a
  ]

theorem counterCompiledRuntimeCode_size :
    counterCompiledRuntimeCode.size = 180 := by
  native_decide

theorem counterCompiledRuntimeCode_dispatches_initialize :
    byteArrayHasSliceAt counterCompiledRuntimeCode
      (counterCallCalldata .initialize) 7 = true := by
  native_decide

theorem counterCompiledRuntimeCode_dispatches_increment :
    byteArrayHasSliceAt counterCompiledRuntimeCode
      (counterCallCalldata .increment) 17 = true := by
  native_decide

theorem counterCompiledRuntimeCode_dispatches_get :
    byteArrayHasSliceAt counterCompiledRuntimeCode
      (counterCallCalldata .get) 26 = true := by
  native_decide

def counterInitializeTrampolineOffset : Nat := 60

def counterInitializeSelectorNat : Nat := 2167012380

def counterInitializeCalldataWord : EvmSemantics.UInt256 :=
  EvmSemantics.UInt256.ofNat (counterInitializeSelectorNat * 2 ^ 224)

theorem counterInitialize_calldataload_zero_eq :
    EvmSemantics.UInt256.ofNat
        (EvmSemantics.Data.Bytes.bytesToBigEndianNat
          (EvmSemantics.MachineState.readPadded
            (counterCallCalldata .initialize) 0 32)) =
      counterInitializeCalldataWord := by
  native_decide

theorem counterInitialize_selector_shr224_eq :
    EvmSemantics.UInt256.shiftRight counterInitializeCalldataWord
        (EvmSemantics.UInt256.ofNat 224) =
      EvmSemantics.UInt256.ofNat counterInitializeSelectorNat := by
  native_decide

theorem counterInitialize_selector_eq_true :
    EvmSemantics.UInt256.eq
        (EvmSemantics.UInt256.ofNat counterInitializeSelectorNat)
        (EvmSemantics.UInt256.ofNat counterInitializeSelectorNat) =
      EvmSemantics.UInt256.ofNat 1 := by
  native_decide

theorem counterInitialize_selector_condition_nonzero :
    (EvmSemantics.UInt256.ofNat 1).toNat ≠ 0 := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_first_push0 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 0 =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_calldataload :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 1 =
      some (.Env
        (.CALLDATALOAD : EvmSemantics.Operation.EnvOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_selector_shift_push224 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 2 =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 224, 1)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_selector_shr :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 4 =
      some (.CompBit
        (.SHR : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_selector_dup1 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 5 =
      some (.Dup counterDup1Op, none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_initialize_selector_push4 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 6 =
      some (.Push counterPush4Op,
        some (EvmSemantics.UInt256.ofNat counterInitializeSelectorNat, 4)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_initialize_eq :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 11 =
      some (.CompBit
        (.EQ : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_initialize_trampoline_push :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 12 =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset, 1)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_dispatcher_initialize_jumpi :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode 14 =
      some (.StackMemFlow
        (.JUMPI : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

def counterInitializeReturnOffset : Nat := 66

def counterInitializeTrampolineBytes : ByteArray :=
  ByteArray.mk #[0x5b, 0x60, 0x42, 0x60, 0x46, 0x56]

theorem counterInitializeTrampolineBytes_size :
    counterInitializeTrampolineBytes.size = 6 := by
  native_decide

theorem counterCompiledRuntimeCode_has_initialize_trampoline :
    byteArrayHasSliceAt counterCompiledRuntimeCode
      counterInitializeTrampolineBytes counterInitializeTrampolineOffset = true := by
  native_decide

def counterInitializeBodyOffset : Nat := 70

def counterInitializeBodyBytes : ByteArray :=
  ByteArray.mk #[
    0x5b, 0x5f, 0x60, 0xc0, 0x1b, 0x60, 0x01, 0x80, 0x60, 0x40, 0x1b,
    0x03, 0x60, 0xc0, 0x1b, 0x19, 0x5f, 0x54, 0x16, 0x17, 0x5f, 0x55,
    0x56
  ]

theorem counterInitializeBodyBytes_size :
    counterInitializeBodyBytes.size = 23 := by
  native_decide

theorem counterCompiledRuntimeCode_has_initialize_body :
    byteArrayHasSliceAt counterCompiledRuntimeCode
      counterInitializeBodyBytes counterInitializeBodyOffset = true := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_trampoline_jumpdest :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        counterInitializeTrampolineOffset =
      some (.StackMemFlow
        (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_valid_initialize_trampoline_jumpdest :
    EvmSemantics.EVM.Decode.isValidJumpDest counterCompiledRuntimeCode
        counterInitializeTrampolineOffset = true := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_trampoline_return_push :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeTrampolineOffset + 1) =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat counterInitializeReturnOffset, 1)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_trampoline_body_push :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeTrampolineOffset + 3) =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat counterInitializeBodyOffset, 1)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_trampoline_jump :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeTrampolineOffset + 5) =
      some (.StackMemFlow
        (.JUMP : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_body_jumpdest :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        counterInitializeBodyOffset =
      some (.StackMemFlow
        (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_valid_initialize_body_jumpdest :
    EvmSemantics.EVM.Decode.isValidJumpDest counterCompiledRuntimeCode
        counterInitializeBodyOffset = true := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_first_push0 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 1) =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_setvalue_push192 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 2) =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 192, 1)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_setvalue_shl :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 4) =
      some (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_mask_push1 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 5) =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 1, 1)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_mask_dup1 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 7) =
      some (.Dup counterDup1Op, none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_mask_push64 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 8) =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 64, 1)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_mask_shl64 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 10) =
      some (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_mask_sub :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 11) =
      some (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_mask_push192 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 12) =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 192, 1)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_mask_shl192 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 14) =
      some (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_mask_not :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 15) =
      some (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_sload_slot_push0 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 16) =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_sload :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 17) =
      some (.StackMemFlow
        (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_and :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 18) =
      some (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_or :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 19) =
      some (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_sstore_slot_push0 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 20) =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_sstore :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 21) =
      some (.StackMemFlow
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_body_return_jump :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeBodyOffset + 22) =
      some (.StackMemFlow
        (.JUMP : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_valid_initialize_return_jumpdest :
    EvmSemantics.EVM.Decode.isValidJumpDest counterCompiledRuntimeCode
        counterInitializeReturnOffset = true := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_return_jumpdest :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        counterInitializeReturnOffset =
      some (.StackMemFlow
        (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_return_push0 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeReturnOffset + 1) =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_return_dup1 :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeReturnOffset + 2) =
      some (.Dup counterDup1Op, none) := by
  native_decide

theorem counterCompiledRuntimeCode_decodes_initialize_return :
    EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode
        (counterInitializeReturnOffset + 3) =
      some (.System
        (.RETURN : EvmSemantics.Operation.SystemOps), none) := by
  native_decide

def counterCompiledStateAt (state : EvmState) (pc : Nat) : Prop :=
  state.executionEnv.code = counterCompiledRuntimeCode ∧
    state.pc = EvmSemantics.UInt256.ofNat pc ∧
    EvmSemantics.Fork.Shanghai ≤ state.executionEnv.fork

theorem counterState_decoded_of_code_pc
    {state : EvmState}
    {pc : Nat} {op : EvmSemantics.Operation}
    {argOpt : Option (EvmSemantics.UInt256 × Nat)}
    (hcode : state.executionEnv.code = counterCompiledRuntimeCode)
    (hpc : state.pc = EvmSemantics.UInt256.ofNat pc)
    (hpcNat : (EvmSemantics.UInt256.ofNat pc).toNat = pc)
    (hdecode :
      EvmSemantics.EVM.Decode.decodeAt counterCompiledRuntimeCode pc =
        some (op, argOpt))
    (havailable : op.availableInFork state.executionEnv.fork = true) :
    state.decoded =
      some (op, argOpt) := by
  unfold EvmSemantics.EVM.State.decoded
  rw [hcode, hpc, hpcNat, hdecode]
  change (if op.availableInFork state.executionEnv.fork then some (op, argOpt)
    else none) = some (op, argOpt)
  simp [havailable]

theorem counterPreparedDispatcherFirstPush0_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 0) :
    state.decoded =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 0).toNat = 0 := by
    native_decide
  have havailable :
      ((.Push counterPush0Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush0Op, hfork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_first_push0 havailable

theorem counterPreparedDispatcherCalldataload_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 1) :
    state.decoded =
      some (.Env
        (.CALLDATALOAD : EvmSemantics.Operation.EnvOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 1).toNat = 1 := by
    native_decide
  have havailable :
      ((.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_calldataload havailable

theorem counterPreparedDispatcherSelectorShiftPush224_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 2) :
    state.decoded =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 224, 1)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 2).toNat = 2 := by
    native_decide
  have havailable :
      ((.Push counterPush1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush1Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_selector_shift_push224 havailable

theorem counterPreparedDispatcherSelectorShr_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 4) :
    state.decoded =
      some (.CompBit
        (.SHR : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 4).toNat = 4 := by
    native_decide
  have hconstantinople :
      EvmSemantics.Fork.Constantinople ≤ state.executionEnv.fork := by
    change EvmSemantics.Fork.Shanghai.toOrd ≤
      state.executionEnv.fork.toOrd at hfork
    change EvmSemantics.Fork.Constantinople.toOrd ≤
      state.executionEnv.fork.toOrd
    exact Nat.le_trans (by decide) hfork
  have havailable :
      ((.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, hconstantinople]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_selector_shr havailable

theorem counterPreparedDispatcherSelectorDup1_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 5) :
    state.decoded = some (.Dup counterDup1Op, none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 5).toNat = 5 := by
    native_decide
  have havailable :
      ((.Dup counterDup1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_selector_dup1 havailable

theorem counterPreparedDispatcherInitializeSelectorPush4_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 6) :
    state.decoded =
      some (.Push counterPush4Op,
        some (EvmSemantics.UInt256.ofNat counterInitializeSelectorNat, 4)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 6).toNat = 6 := by
    native_decide
  have havailable :
      ((.Push counterPush4Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush4Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_initialize_selector_push4 havailable

theorem counterPreparedDispatcherInitializeEq_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 11) :
    state.decoded =
      some (.CompBit
        (.EQ : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 11).toNat = 11 := by
    native_decide
  have havailable :
      ((.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_initialize_eq havailable

theorem counterPreparedDispatcherInitializeTrampolinePush_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 12) :
    state.decoded =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset, 1)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 12).toNat = 12 := by
    native_decide
  have havailable :
      ((.Push counterPush1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush1Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_initialize_trampoline_push havailable

theorem counterPreparedDispatcherInitializeJumpi_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state 14) :
    state.decoded =
      some (.StackMemFlow
        (.JUMPI : EvmSemantics.Operation.StackMemFlowOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat : (EvmSemantics.UInt256.ofNat 14).toNat = 14 := by
    native_decide
  have havailable :
      ((.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_dispatcher_initialize_jumpi havailable

theorem counterState_of_dispatcher_first_push0_stepFE_to_calldataload_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = rest)
    (hat : counterCompiledStateAt state 0)
    (hready : counterStepFEReady state (.Push counterPush0Op))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState 1 ∧
      nextState.decoded =
        some (.Env
          (.CALLDATALOAD : EvmSemantics.Operation.EnvOps), none) ∧
      nextState.stack = EvmSemantics.UInt256.ofNat 0 :: rest ∧
      nextState.executionEnv.calldata = state.executionEnv.calldata := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_push0_ok hrunning hprecompile
      (counterPreparedDispatcherFirstPush0_decoded hat) hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState 1 := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.replaceStackAndIncrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC] using hfork
  refine ⟨hnextAt, counterPreparedDispatcherCalldataload_decoded hnextAt, ?_, ?_⟩
  · rw [hstate]
    simp [EvmSemantics.EVM.State.consumeGas,
      EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack]
  · rw [hstate]
    simp [EvmSemantics.EVM.State.consumeGas,
      EvmSemantics.EVM.State.replaceStackAndIncrPC]

theorem counterState_of_dispatcher_calldataload_stepFE_to_shift_push_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = EvmSemantics.UInt256.ofNat 0 :: rest)
    (hcalldata : state.executionEnv.calldata = counterCallCalldata .initialize)
    (hat : counterCompiledStateAt state 1)
    (hready :
      counterStepFEReady state
        (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps)))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState 2 ∧
      nextState.decoded =
        some (.Push counterPush1Op,
          some (EvmSemantics.UInt256.ofNat 224, 1)) ∧
      nextState.stack = counterInitializeCalldataWord :: rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_env_calldataload_ok hrunning hprecompile
      (counterPreparedDispatcherCalldataload_decoded hat) hstack hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState 2 := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.replaceStackAndIncrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC] using hfork
  refine ⟨hnextAt, counterPreparedDispatcherSelectorShiftPush224_decoded hnextAt, ?_⟩
  rw [hstate]
  simp [EvmSemantics.EVM.State.consumeGas,
    EvmSemantics.EVM.State.replaceStackAndIncrPC, hcalldata,
    counterUInt256_ofNat_zero_toNat, counterInitialize_calldataload_zero_eq]

theorem counterState_of_dispatcher_selector_shift_push_stepFE_to_shr_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = counterInitializeCalldataWord :: rest)
    (hat : counterCompiledStateAt state 2)
    (hready : counterStepFEReady state (.Push counterPush1Op))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState 4 ∧
      nextState.decoded =
        some (.CompBit
          (.SHR : EvmSemantics.Operation.CompareBitwiseOps), none) ∧
      nextState.stack =
        EvmSemantics.UInt256.ofNat 224 :: counterInitializeCalldataWord ::
          rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_push1_ok hrunning hprecompile
      (counterPreparedDispatcherSelectorShiftPush224_decoded hat) hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState 4 := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.replaceStackAndIncrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC] using hfork
  refine ⟨hnextAt, counterPreparedDispatcherSelectorShr_decoded hnextAt, ?_⟩
  rw [hstate]
  simp [EvmSemantics.EVM.State.consumeGas,
    EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack]

theorem counterState_of_dispatcher_selector_shr_stepFE_to_dup_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack :
      state.stack =
        EvmSemantics.UInt256.ofNat 224 :: counterInitializeCalldataWord :: rest)
    (hat : counterCompiledStateAt state 4)
    (hready :
      counterStepFEReady state
        (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState 5 ∧
      nextState.decoded = some (.Dup counterDup1Op, none) ∧
      nextState.stack =
        EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_compBit_shr_ok hrunning hprecompile
      (counterPreparedDispatcherSelectorShr_decoded hat) hstack hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState 5 := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.replaceStackAndIncrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC] using hfork
  refine ⟨hnextAt, counterPreparedDispatcherSelectorDup1_decoded hnextAt, ?_⟩
  rw [hstate]
  simp [EvmSemantics.EVM.State.consumeGas,
    EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack,
    counterInitialize_selector_shr224_eq]

theorem counterState_of_dispatcher_selector_dup_stepFE_to_selector_push_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack :
      state.stack =
        EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest)
    (hat : counterCompiledStateAt state 5)
    (hready : counterStepFEReady state (.Dup counterDup1Op))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState 6 ∧
      nextState.decoded =
        some (.Push counterPush4Op,
          some (EvmSemantics.UInt256.ofNat counterInitializeSelectorNat, 4)) ∧
      nextState.stack =
        EvmSemantics.UInt256.ofNat counterInitializeSelectorNat ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_dup1_ok hrunning hprecompile
      (counterPreparedDispatcherSelectorDup1_decoded hat) hstack hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState 6 := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.replaceStackAndIncrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC] using hfork
  refine ⟨hnextAt, counterPreparedDispatcherInitializeSelectorPush4_decoded hnextAt, ?_⟩
  rw [hstate]
  simp [EvmSemantics.EVM.State.consumeGas,
    EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack]

theorem counterState_of_dispatcher_initialize_selector_push_stepFE_to_eq_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack :
      state.stack =
        EvmSemantics.UInt256.ofNat counterInitializeSelectorNat ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest)
    (hat : counterCompiledStateAt state 6)
    (hready : counterStepFEReady state (.Push counterPush4Op))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState 11 ∧
      nextState.decoded =
        some (.CompBit
          (.EQ : EvmSemantics.Operation.CompareBitwiseOps), none) ∧
      nextState.stack =
        EvmSemantics.UInt256.ofNat counterInitializeSelectorNat ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_push4_ok hrunning hprecompile
      (counterPreparedDispatcherInitializeSelectorPush4_decoded hat)
      hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState 11 := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.replaceStackAndIncrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC] using hfork
  refine ⟨hnextAt, counterPreparedDispatcherInitializeEq_decoded hnextAt, ?_⟩
  rw [hstate]
  simp [EvmSemantics.EVM.State.consumeGas,
    EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack]

theorem counterState_of_dispatcher_initialize_eq_stepFE_to_trampoline_push_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack :
      state.stack =
        EvmSemantics.UInt256.ofNat counterInitializeSelectorNat ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest)
    (hat : counterCompiledStateAt state 11)
    (hready :
      counterStepFEReady state
        (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState 12 ∧
      nextState.decoded =
        some (.Push counterPush1Op,
          some (EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset, 1)) ∧
      nextState.stack =
        EvmSemantics.UInt256.ofNat 1 ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_compBit_eq_ok hrunning hprecompile
      (counterPreparedDispatcherInitializeEq_decoded hat) hstack hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState 12 := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.replaceStackAndIncrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC] using hfork
  refine ⟨hnextAt, counterPreparedDispatcherInitializeTrampolinePush_decoded hnextAt, ?_⟩
  rw [hstate]
  simp [EvmSemantics.EVM.State.consumeGas,
    EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack,
    counterInitialize_selector_eq_true]

theorem counterState_of_dispatcher_trampoline_push_stepFE_to_jumpi_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack :
      state.stack =
        EvmSemantics.UInt256.ofNat 1 ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest)
    (hat : counterCompiledStateAt state 12)
    (hready : counterStepFEReady state (.Push counterPush1Op))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState 14 ∧
      nextState.decoded =
        some (.StackMemFlow
          (.JUMPI : EvmSemantics.Operation.StackMemFlowOps), none) ∧
      nextState.stack =
        EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset ::
          EvmSemantics.UInt256.ofNat 1 ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_push1_ok hrunning hprecompile
      (counterPreparedDispatcherInitializeTrampolinePush_decoded hat)
      hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState 14 := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.replaceStackAndIncrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.replaceStackAndIncrPC] using hfork
  refine ⟨hnextAt, counterPreparedDispatcherInitializeJumpi_decoded hnextAt, ?_⟩
  rw [hstate]
  simp [EvmSemantics.EVM.State.consumeGas,
    EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack]

theorem counterState_of_dispatcher_initialize_jumpi_stepFE_to_trampoline_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack :
      state.stack =
        EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset ::
          EvmSemantics.UInt256.ofNat 1 ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest)
    (hat : counterCompiledStateAt state 14)
    (hready :
      counterStepFEReady state
        (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState counterInitializeTrampolineOffset ∧
      nextState.decoded =
        some (.StackMemFlow
          (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) ∧
      nextState.stack =
        EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hdestNat :
      (EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset).toNat =
        counterInitializeTrampolineOffset := by
    native_decide
  have hvalid :
      EvmSemantics.EVM.Decode.isValidJumpDest state.executionEnv.code
        (EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset).toNat =
        true := by
    rw [hcode, hdestNat]
    exact counterCompiledRuntimeCode_valid_initialize_trampoline_jumpdest
  have hstate :=
    counterState_of_stepFE_stackMemFlow_jumpi_taken_ok hrunning hprecompile
      (counterPreparedDispatcherInitializeJumpi_decoded ⟨hcode, hpc, hfork⟩)
      hstack counterInitialize_selector_condition_nonzero hvalid hstackOk hgas hstep
  have hnextAt :
      counterCompiledStateAt nextState counterInitializeTrampolineOffset := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas, hcode]
    · constructor
      · simp
      · simpa [EvmSemantics.EVM.State.consumeGas] using hfork
  have hdecodedNext :
      nextState.decoded =
        some (.StackMemFlow
          (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) := by
    rcases hnextAt with ⟨hcodeNext, hpcNext, _hforkNext⟩
    have hpcNat :
        (EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset).toNat =
          counterInitializeTrampolineOffset := by
      native_decide
    have havailable :
        ((.StackMemFlow
          (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
            EvmSemantics.Operation).availableInFork nextState.executionEnv.fork) =
          true := by
      simp [EvmSemantics.Operation.availableInFork]
    exact counterState_decoded_of_code_pc hcodeNext hpcNext hpcNat
      counterCompiledRuntimeCode_decodes_initialize_trampoline_jumpdest havailable
  refine ⟨hnextAt, hdecodedNext, ?_⟩
  rw [hstate]

theorem counterPreparedInitializeTrampolineJumpdest_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state counterInitializeTrampolineOffset) :
    state.decoded =
      some (.StackMemFlow
        (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat counterInitializeTrampolineOffset).toNat =
        counterInitializeTrampolineOffset := by
    native_decide
  have havailable :
      ((.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_trampoline_jumpdest havailable

theorem counterPreparedInitializeTrampolineReturnPush_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeTrampolineOffset + 1)) :
    state.decoded =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat counterInitializeReturnOffset, 1)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeTrampolineOffset + 1)).toNat =
        counterInitializeTrampolineOffset + 1 := by
    native_decide
  have havailable :
      ((.Push counterPush1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush1Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_trampoline_return_push havailable

theorem counterPreparedInitializeTrampolineBodyPush_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeTrampolineOffset + 3)) :
    state.decoded =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat counterInitializeBodyOffset, 1)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeTrampolineOffset + 3)).toNat =
        counterInitializeTrampolineOffset + 3 := by
    native_decide
  have havailable :
      ((.Push counterPush1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush1Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_trampoline_body_push havailable

theorem counterPreparedInitializeTrampolineJump_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeTrampolineOffset + 5)) :
    state.decoded =
      some (.StackMemFlow
        (.JUMP : EvmSemantics.Operation.StackMemFlowOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeTrampolineOffset + 5)).toNat =
        counterInitializeTrampolineOffset + 5 := by
    native_decide
  have havailable :
      ((.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_trampoline_jump havailable

theorem counterPreparedInitializeBodyJumpdest_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state counterInitializeBodyOffset) :
    state.decoded =
      some (.StackMemFlow
        (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat counterInitializeBodyOffset).toNat =
        counterInitializeBodyOffset := by
    native_decide
  have havailable :
      ((.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_body_jumpdest havailable

theorem counterState_of_initialize_trampoline_stepFE_to_body_ok
    {s0 s1 s2 s3 s4 : EvmState}
    {rest : List EvmSemantics.UInt256}
    (h0 : s0.stack = rest)
    (hat0 : counterCompiledStateAt s0 counterInitializeTrampolineOffset)
    (hready0 :
      counterStepFEReady s0
        (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep0 : EvmSemantics.EVM.stepFE s0 = .ok s1)
    (hat1 : counterCompiledStateAt s1 (counterInitializeTrampolineOffset + 1))
    (hready1 : counterStepFEReady s1 (.Push counterPush1Op))
    (hstep1 : EvmSemantics.EVM.stepFE s1 = .ok s2)
    (hat2 : counterCompiledStateAt s2 (counterInitializeTrampolineOffset + 3))
    (hready2 : counterStepFEReady s2 (.Push counterPush1Op))
    (hstep2 : EvmSemantics.EVM.stepFE s2 = .ok s3)
    (hat3 : counterCompiledStateAt s3 (counterInitializeTrampolineOffset + 5))
    (hready3 :
      counterStepFEReady s3
        (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep3 : EvmSemantics.EVM.stepFE s3 = .ok s4) :
    counterCompiledStateAt s4 counterInitializeBodyOffset ∧
      s4.decoded =
        some (.StackMemFlow
          (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) ∧
      s4.stack = EvmSemantics.UInt256.ofNat counterInitializeReturnOffset :: rest := by
  rcases hready0 with ⟨hrunning0, hprecompile0, hstackOk0, hgas0⟩
  rcases hready1 with ⟨hrunning1, hprecompile1, hstackOk1, hgas1⟩
  rcases hready2 with ⟨hrunning2, hprecompile2, hstackOk2, hgas2⟩
  rcases hready3 with ⟨hrunning3, hprecompile3, hstackOk3, hgas3⟩
  have hstate1 :=
    counterState_of_stepFE_stackMemFlow_jumpdest_ok hrunning0 hprecompile0
      (counterPreparedInitializeTrampolineJumpdest_decoded hat0) hstackOk0
      hgas0 hstep0
  have hstack1 : s1.stack = rest := by
    rw [hstate1]
    simp [EvmSemantics.EVM.State.consumeGas, EvmSemantics.EVM.State.incrPC, h0]
  have hstate2 :=
    counterState_of_stepFE_push1_ok hrunning1 hprecompile1
      (counterPreparedInitializeTrampolineReturnPush_decoded hat1) hstackOk1
      hgas1 hstep1
  have hstack2 :
      s2.stack =
        EvmSemantics.UInt256.ofNat counterInitializeReturnOffset :: rest := by
    rw [hstate2]
    simp [EvmSemantics.EVM.State.consumeGas,
      EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack1]
  have hstate3 :=
    counterState_of_stepFE_push1_ok hrunning2 hprecompile2
      (counterPreparedInitializeTrampolineBodyPush_decoded hat2) hstackOk2
      hgas2 hstep2
  have hstack3 :
      s3.stack =
        EvmSemantics.UInt256.ofNat counterInitializeBodyOffset ::
          EvmSemantics.UInt256.ofNat counterInitializeReturnOffset :: rest := by
    rw [hstate3]
    simp [EvmSemantics.EVM.State.consumeGas,
      EvmSemantics.EVM.State.replaceStackAndIncrPC, hstack2]
  have hdecoded3 := counterPreparedInitializeTrampolineJump_decoded hat3
  rcases hat3 with ⟨hcode3, _hpc3, hfork3⟩
  have hvalid :
      EvmSemantics.EVM.Decode.isValidJumpDest s3.executionEnv.code
        (EvmSemantics.UInt256.ofNat counterInitializeBodyOffset).toNat = true := by
    rw [hcode3]
    have hbodyNat :
        (EvmSemantics.UInt256.ofNat counterInitializeBodyOffset).toNat =
          counterInitializeBodyOffset := by
      native_decide
    rw [hbodyNat]
    exact counterCompiledRuntimeCode_valid_initialize_body_jumpdest
  have hstate4 :=
    counterState_of_stepFE_stackMemFlow_jump_ok hrunning3 hprecompile3
      hdecoded3 hstack3 hvalid hstackOk3 hgas3 hstep3
  have hfinalAt : counterCompiledStateAt s4 counterInitializeBodyOffset := by
    unfold counterCompiledStateAt
    rw [hstate4]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas, hcode3]
    · constructor
      · simp
      · simpa [EvmSemantics.EVM.State.consumeGas] using hfork3
  refine ⟨hfinalAt, counterPreparedInitializeBodyJumpdest_decoded hfinalAt, ?_⟩
  rw [hstate4]

theorem counterPreparedInitializeFirstPush0_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 1)) :
    state.decoded =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 1)).toNat =
        counterInitializeBodyOffset + 1 := by
    native_decide
  have havailable :
      ((.Push counterPush0Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush0Op, hfork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_first_push0 havailable

theorem counterState_of_initialize_body_jumpdest_stepFE_to_first_opcode_ok
    {state nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (hstack : state.stack = rest)
    (hat : counterCompiledStateAt state counterInitializeBodyOffset)
    (hready :
      counterStepFEReady state
        (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    counterCompiledStateAt nextState (counterInitializeBodyOffset + 1) ∧
      nextState.decoded =
        some (.Push counterPush0Op,
          some (EvmSemantics.UInt256.ofNat 0, 0)) ∧
      nextState.stack = rest := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  have hstate :=
    counterState_of_stepFE_stackMemFlow_jumpdest_ok hrunning hprecompile
      (counterPreparedInitializeBodyJumpdest_decoded hat) hstackOk hgas hstep
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hnextAt : counterCompiledStateAt nextState (counterInitializeBodyOffset + 1) := by
    unfold counterCompiledStateAt
    rw [hstate]
    constructor
    · simp [EvmSemantics.EVM.State.consumeGas,
        EvmSemantics.EVM.State.incrPC, hcode]
    · constructor
      · simp [EvmSemantics.EVM.State.consumeGas, EvmSemantics.EVM.State.incrPC, hpc]
        native_decide
      · simpa [EvmSemantics.EVM.State.consumeGas,
          EvmSemantics.EVM.State.incrPC] using hfork
  refine ⟨hnextAt, counterPreparedInitializeFirstPush0_decoded hnextAt, ?_⟩
  rw [hstate]
  simp [EvmSemantics.EVM.State.consumeGas, EvmSemantics.EVM.State.incrPC, hstack]

theorem counterState_of_dispatcher_trampoline_stepFE_to_initialize_first_opcode_ok
    {s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 s12 s13 s14 : EvmState}
    {rest : List EvmSemantics.UInt256}
    (h0 : s0.stack = rest)
    (hat0 : counterCompiledStateAt s0 0)
    (hready0 : counterStepFEReady s0 (.Push counterPush0Op))
    (hstep0 : EvmSemantics.EVM.stepFE s0 = .ok s1)
    (hcalldata0 : s0.executionEnv.calldata = counterCallCalldata .initialize)
    (hready1 :
      counterStepFEReady s1
        (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps)))
    (hstep1 : EvmSemantics.EVM.stepFE s1 = .ok s2)
    (hready2 : counterStepFEReady s2 (.Push counterPush1Op))
    (hstep2 : EvmSemantics.EVM.stepFE s2 = .ok s3)
    (hready3 :
      counterStepFEReady s3
        (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep3 : EvmSemantics.EVM.stepFE s3 = .ok s4)
    (hready4 : counterStepFEReady s4 (.Dup counterDup1Op))
    (hstep4 : EvmSemantics.EVM.stepFE s4 = .ok s5)
    (hready5 : counterStepFEReady s5 (.Push counterPush4Op))
    (hstep5 : EvmSemantics.EVM.stepFE s5 = .ok s6)
    (hready6 :
      counterStepFEReady s6
        (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep6 : EvmSemantics.EVM.stepFE s6 = .ok s7)
    (hready7 : counterStepFEReady s7 (.Push counterPush1Op))
    (hstep7 : EvmSemantics.EVM.stepFE s7 = .ok s8)
    (hready8 :
      counterStepFEReady s8
        (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep8 : EvmSemantics.EVM.stepFE s8 = .ok s9)
    (hready9 :
      counterStepFEReady s9
        (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep9 : EvmSemantics.EVM.stepFE s9 = .ok s10)
    (hat10 : counterCompiledStateAt s10 (counterInitializeTrampolineOffset + 1))
    (hready10 : counterStepFEReady s10 (.Push counterPush1Op))
    (hstep10 : EvmSemantics.EVM.stepFE s10 = .ok s11)
    (hat11 : counterCompiledStateAt s11 (counterInitializeTrampolineOffset + 3))
    (hready11 : counterStepFEReady s11 (.Push counterPush1Op))
    (hstep11 : EvmSemantics.EVM.stepFE s11 = .ok s12)
    (hat12 : counterCompiledStateAt s12 (counterInitializeTrampolineOffset + 5))
    (hready12 :
      counterStepFEReady s12
        (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep12 : EvmSemantics.EVM.stepFE s12 = .ok s13)
    (hready13 :
      counterStepFEReady s13
        (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep13 : EvmSemantics.EVM.stepFE s13 = .ok s14) :
    counterCompiledStateAt s14 (counterInitializeBodyOffset + 1) ∧
      s14.decoded =
        some (.Push counterPush0Op,
          some (EvmSemantics.UInt256.ofNat 0, 0)) ∧
      s14.stack =
        EvmSemantics.UInt256.ofNat counterInitializeReturnOffset ::
          EvmSemantics.UInt256.ofNat counterInitializeSelectorNat :: rest := by
  obtain ⟨hat1, _hdecoded1, hstack1, hcalldata1From0⟩ :=
    counterState_of_dispatcher_first_push0_stepFE_to_calldataload_ok
      h0 hat0 hready0 hstep0
  have hcalldata1 : s1.executionEnv.calldata = counterCallCalldata .initialize := by
    rw [hcalldata1From0, hcalldata0]
  obtain ⟨hat2, _hdecoded2, hstack2⟩ :=
    counterState_of_dispatcher_calldataload_stepFE_to_shift_push_ok
      hstack1 hcalldata1 hat1 hready1 hstep1
  obtain ⟨hat3, _hdecoded3, hstack3⟩ :=
    counterState_of_dispatcher_selector_shift_push_stepFE_to_shr_ok
      hstack2 hat2 hready2 hstep2
  obtain ⟨hat4, _hdecoded4, hstack4⟩ :=
    counterState_of_dispatcher_selector_shr_stepFE_to_dup_ok
      hstack3 hat3 hready3 hstep3
  obtain ⟨hat5, _hdecoded5, hstack5⟩ :=
    counterState_of_dispatcher_selector_dup_stepFE_to_selector_push_ok
      hstack4 hat4 hready4 hstep4
  obtain ⟨hat6, _hdecoded6, hstack6⟩ :=
    counterState_of_dispatcher_initialize_selector_push_stepFE_to_eq_ok
      hstack5 hat5 hready5 hstep5
  obtain ⟨hat7, _hdecoded7, hstack7⟩ :=
    counterState_of_dispatcher_initialize_eq_stepFE_to_trampoline_push_ok
      hstack6 hat6 hready6 hstep6
  obtain ⟨hat8, _hdecoded8, hstack8⟩ :=
    counterState_of_dispatcher_trampoline_push_stepFE_to_jumpi_ok
      hstack7 hat7 hready7 hstep7
  obtain ⟨hat9, _hdecoded9, hstack9⟩ :=
    counterState_of_dispatcher_initialize_jumpi_stepFE_to_trampoline_ok
      hstack8 hat8 hready8 hstep8
  obtain ⟨hat13, _hdecoded13, hstack13⟩ :=
    counterState_of_initialize_trampoline_stepFE_to_body_ok
      hstack9 hat9 hready9 hstep9 hat10 hready10 hstep10
      hat11 hready11 hstep11 hat12 hready12 hstep12
  exact counterState_of_initialize_body_jumpdest_stepFE_to_first_opcode_ok
    hstack13 hat13 hready13 hstep13

theorem counterPreparedInitializeSetValuePush192_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 2)) :
    state.decoded =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 192, 1)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 2)).toNat =
        counterInitializeBodyOffset + 2 := by
    native_decide
  have havailable :
      ((.Push counterPush1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush1Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_setvalue_push192 havailable

theorem counterPreparedInitializeSetValueShl_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 4)) :
    state.decoded =
      some (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 4)).toNat =
        counterInitializeBodyOffset + 4 := by
    native_decide
  have hconstantinople :
      EvmSemantics.Fork.Constantinople ≤ state.executionEnv.fork := by
    change EvmSemantics.Fork.Shanghai.toOrd ≤
      state.executionEnv.fork.toOrd at hfork
    change EvmSemantics.Fork.Constantinople.toOrd ≤
      state.executionEnv.fork.toOrd
    exact Nat.le_trans (by decide) hfork
  have havailable :
      ((.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, hconstantinople]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_setvalue_shl havailable

theorem counterPreparedInitializeMaskPush1_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 5)) :
    state.decoded =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 1, 1)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 5)).toNat =
        counterInitializeBodyOffset + 5 := by
    native_decide
  have havailable :
      ((.Push counterPush1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush1Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_mask_push1 havailable

theorem counterPreparedInitializeMaskDup1_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 7)) :
    state.decoded = some (.Dup counterDup1Op, none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 7)).toNat =
        counterInitializeBodyOffset + 7 := by
    native_decide
  have havailable :
      ((.Dup counterDup1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_mask_dup1 havailable

theorem counterPreparedInitializeMaskPush64_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 8)) :
    state.decoded =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 64, 1)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 8)).toNat =
        counterInitializeBodyOffset + 8 := by
    native_decide
  have havailable :
      ((.Push counterPush1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush1Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_mask_push64 havailable

theorem counterPreparedInitializeMaskShl64_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 10)) :
    state.decoded =
      some (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 10)).toNat =
        counterInitializeBodyOffset + 10 := by
    native_decide
  have hconstantinople :
      EvmSemantics.Fork.Constantinople ≤ state.executionEnv.fork := by
    change EvmSemantics.Fork.Shanghai.toOrd ≤
      state.executionEnv.fork.toOrd at hfork
    change EvmSemantics.Fork.Constantinople.toOrd ≤
      state.executionEnv.fork.toOrd
    exact Nat.le_trans (by decide) hfork
  have havailable :
      ((.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, hconstantinople]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_mask_shl64 havailable

theorem counterPreparedInitializeMaskSub_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 11)) :
    state.decoded =
      some (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 11)).toNat =
        counterInitializeBodyOffset + 11 := by
    native_decide
  have havailable :
      ((.StopArith (.SUB : EvmSemantics.Operation.StopArithOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_mask_sub havailable

theorem counterPreparedInitializeMaskPush192_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 12)) :
    state.decoded =
      some (.Push counterPush1Op,
        some (EvmSemantics.UInt256.ofNat 192, 1)) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 12)).toNat =
        counterInitializeBodyOffset + 12 := by
    native_decide
  have havailable :
      ((.Push counterPush1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush1Op]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_mask_push192 havailable

theorem counterPreparedInitializeMaskShl192_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 14)) :
    state.decoded =
      some (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 14)).toNat =
        counterInitializeBodyOffset + 14 := by
    native_decide
  have hconstantinople :
      EvmSemantics.Fork.Constantinople ≤ state.executionEnv.fork := by
    change EvmSemantics.Fork.Shanghai.toOrd ≤
      state.executionEnv.fork.toOrd at hfork
    change EvmSemantics.Fork.Constantinople.toOrd ≤
      state.executionEnv.fork.toOrd
    exact Nat.le_trans (by decide) hfork
  have havailable :
      ((.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, hconstantinople]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_mask_shl192 havailable

theorem counterPreparedInitializeMaskNot_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 15)) :
    state.decoded =
      some (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 15)).toNat =
        counterInitializeBodyOffset + 15 := by
    native_decide
  have havailable :
      ((.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_mask_not havailable

theorem counterPreparedInitializeSloadSlotPush0_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 16)) :
    state.decoded =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 16)).toNat =
        counterInitializeBodyOffset + 16 := by
    native_decide
  have havailable :
      ((.Push counterPush0Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush0Op, hfork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_sload_slot_push0 havailable

theorem counterPreparedInitializeSload_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 17)) :
    state.decoded =
      some (.StackMemFlow
        (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 17)).toNat =
        counterInitializeBodyOffset + 17 := by
    native_decide
  have havailable :
      ((.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_sload havailable

theorem counterPreparedInitializeAnd_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 18)) :
    state.decoded =
      some (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 18)).toNat =
        counterInitializeBodyOffset + 18 := by
    native_decide
  have havailable :
      ((.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_and havailable

theorem counterPreparedInitializeOr_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 19)) :
    state.decoded =
      some (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 19)).toNat =
        counterInitializeBodyOffset + 19 := by
    native_decide
  have havailable :
      ((.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_or havailable

theorem counterPreparedInitializeSstoreSlotPush0_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 20)) :
    state.decoded =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 20)).toNat =
        counterInitializeBodyOffset + 20 := by
    native_decide
  have havailable :
      ((.Push counterPush0Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush0Op, hfork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_sstore_slot_push0 havailable

theorem counterPreparedInitializeSstore_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 21)) :
    state.decoded =
      some (.StackMemFlow
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 21)).toNat =
        counterInitializeBodyOffset + 21 := by
    native_decide
  have havailable :
      ((.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_sstore havailable

theorem counterPreparedInitializeBodyReturnJump_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeBodyOffset + 22)) :
    state.decoded =
      some (.StackMemFlow
        (.JUMP : EvmSemantics.Operation.StackMemFlowOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeBodyOffset + 22)).toNat =
        counterInitializeBodyOffset + 22 := by
    native_decide
  have havailable :
      ((.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_body_return_jump havailable

theorem counterPreparedInitializeReturnJumpdest_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state counterInitializeReturnOffset) :
    state.decoded =
      some (.StackMemFlow
        (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat counterInitializeReturnOffset).toNat =
        counterInitializeReturnOffset := by
    native_decide
  have havailable :
      ((.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_return_jumpdest havailable

theorem counterPreparedInitializeReturnPush0_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeReturnOffset + 1)) :
    state.decoded =
      some (.Push counterPush0Op,
        some (EvmSemantics.UInt256.ofNat 0, 0)) := by
  rcases hat with ⟨hcode, hpc, hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeReturnOffset + 1)).toNat =
        counterInitializeReturnOffset + 1 := by
    native_decide
  have havailable :
      ((.Push counterPush0Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork, counterPush0Op, hfork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_return_push0 havailable

theorem counterPreparedInitializeReturnDup1_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeReturnOffset + 2)) :
    state.decoded = some (.Dup counterDup1Op, none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeReturnOffset + 2)).toNat =
        counterInitializeReturnOffset + 2 := by
    native_decide
  have havailable :
      ((.Dup counterDup1Op : EvmSemantics.Operation).availableInFork
        state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_return_dup1 havailable

theorem counterPreparedInitializeReturn_decoded
    {state : EvmState}
    (hat : counterCompiledStateAt state (counterInitializeReturnOffset + 3)) :
    state.decoded =
      some (.System
        (.RETURN : EvmSemantics.Operation.SystemOps), none) := by
  rcases hat with ⟨hcode, hpc, _hfork⟩
  have hpcNat :
      (EvmSemantics.UInt256.ofNat (counterInitializeReturnOffset + 3)).toNat =
        counterInitializeReturnOffset + 3 := by
    native_decide
  have havailable :
      ((.System (.RETURN : EvmSemantics.Operation.SystemOps) :
        EvmSemantics.Operation).availableInFork state.executionEnv.fork) = true := by
    simp [EvmSemantics.Operation.availableInFork]
  exact counterState_decoded_of_code_pc hcode hpc hpcNat
    counterCompiledRuntimeCode_decodes_initialize_return havailable

theorem counterStack_of_initialize_prefix_stepFE_to_sload_ok
    {s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 s12 : EvmState}
    {rest : List EvmSemantics.UInt256}
    (h0 : s0.stack = rest)
    (hat0 : counterCompiledStateAt s0 (counterInitializeBodyOffset + 1))
    (hready0 : counterStepFEReady s0 (.Push counterPush0Op))
    (hstep0 : EvmSemantics.EVM.stepFE s0 = .ok s1)
    (hat1 : counterCompiledStateAt s1 (counterInitializeBodyOffset + 2))
    (hready1 : counterStepFEReady s1 (.Push counterPush1Op))
    (hstep1 : EvmSemantics.EVM.stepFE s1 = .ok s2)
    (hat2 : counterCompiledStateAt s2 (counterInitializeBodyOffset + 4))
    (hready2 :
      counterStepFEReady s2
        (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep2 : EvmSemantics.EVM.stepFE s2 = .ok s3)
    (hat3 : counterCompiledStateAt s3 (counterInitializeBodyOffset + 5))
    (hready3 : counterStepFEReady s3 (.Push counterPush1Op))
    (hstep3 : EvmSemantics.EVM.stepFE s3 = .ok s4)
    (hat4 : counterCompiledStateAt s4 (counterInitializeBodyOffset + 7))
    (hready4 : counterStepFEReady s4 (.Dup counterDup1Op))
    (hstep4 : EvmSemantics.EVM.stepFE s4 = .ok s5)
    (hat5 : counterCompiledStateAt s5 (counterInitializeBodyOffset + 8))
    (hready5 : counterStepFEReady s5 (.Push counterPush1Op))
    (hstep5 : EvmSemantics.EVM.stepFE s5 = .ok s6)
    (hat6 : counterCompiledStateAt s6 (counterInitializeBodyOffset + 10))
    (hready6 :
      counterStepFEReady s6
        (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep6 : EvmSemantics.EVM.stepFE s6 = .ok s7)
    (hat7 : counterCompiledStateAt s7 (counterInitializeBodyOffset + 11))
    (hready7 :
      counterStepFEReady s7
        (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps)))
    (hstep7 : EvmSemantics.EVM.stepFE s7 = .ok s8)
    (hat8 : counterCompiledStateAt s8 (counterInitializeBodyOffset + 12))
    (hready8 : counterStepFEReady s8 (.Push counterPush1Op))
    (hstep8 : EvmSemantics.EVM.stepFE s8 = .ok s9)
    (hat9 : counterCompiledStateAt s9 (counterInitializeBodyOffset + 14))
    (hready9 :
      counterStepFEReady s9
        (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep9 : EvmSemantics.EVM.stepFE s9 = .ok s10)
    (hat10 : counterCompiledStateAt s10 (counterInitializeBodyOffset + 15))
    (hready10 :
      counterStepFEReady s10
        (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep10 : EvmSemantics.EVM.stepFE s10 = .ok s11)
    (hat11 : counterCompiledStateAt s11 (counterInitializeBodyOffset + 16))
    (hready11 : counterStepFEReady s11 (.Push counterPush0Op))
    (hstep11 : EvmSemantics.EVM.stepFE s11 = .ok s12) :
    s12.stack =
      counterCountSlot :: counterInitializeLowMask ::
        counterInitializeSetValue :: rest := by
  rcases hready0 with ⟨hrunning0, hprecompile0, hstackOk0, hgas0⟩
  rcases hready1 with ⟨hrunning1, hprecompile1, hstackOk1, hgas1⟩
  rcases hready2 with ⟨hrunning2, hprecompile2, hstackOk2, hgas2⟩
  rcases hready3 with ⟨hrunning3, hprecompile3, hstackOk3, hgas3⟩
  rcases hready4 with ⟨hrunning4, hprecompile4, hstackOk4, hgas4⟩
  rcases hready5 with ⟨hrunning5, hprecompile5, hstackOk5, hgas5⟩
  rcases hready6 with ⟨hrunning6, hprecompile6, hstackOk6, hgas6⟩
  rcases hready7 with ⟨hrunning7, hprecompile7, hstackOk7, hgas7⟩
  rcases hready8 with ⟨hrunning8, hprecompile8, hstackOk8, hgas8⟩
  rcases hready9 with ⟨hrunning9, hprecompile9, hstackOk9, hgas9⟩
  rcases hready10 with ⟨hrunning10, hprecompile10, hstackOk10, hgas10⟩
  rcases hready11 with ⟨hrunning11, hprecompile11, hstackOk11, hgas11⟩
  have h1 : s1.stack = EvmSemantics.UInt256.ofNat 0 :: rest := by
    rw [counterStack_of_stepFE_push0_ok hrunning0 hprecompile0
      (counterPreparedInitializeFirstPush0_decoded hat0) hstackOk0 hgas0 hstep0,
      h0]
  have h2 :
      s2.stack =
        EvmSemantics.UInt256.ofNat 192 ::
          EvmSemantics.UInt256.ofNat 0 :: rest := by
    rw [counterStack_of_stepFE_push1_ok hrunning1 hprecompile1
      (counterPreparedInitializeSetValuePush192_decoded hat1) hstackOk1 hgas1
      hstep1, h1]
  have h3 : s3.stack = counterInitializeSetValue :: rest := by
    rw [counterStack_of_stepFE_compBit_shl_ok hrunning2 hprecompile2
      (counterPreparedInitializeSetValueShl_decoded hat2) h2 hstackOk2 hgas2 hstep2]
    rfl
  have h4 :
      s4.stack =
        EvmSemantics.UInt256.ofNat 1 :: counterInitializeSetValue :: rest := by
    rw [counterStack_of_stepFE_push1_ok hrunning3 hprecompile3
      (counterPreparedInitializeMaskPush1_decoded hat3) hstackOk3 hgas3 hstep3, h3]
  have h5 :
      s5.stack =
        EvmSemantics.UInt256.ofNat 1 :: EvmSemantics.UInt256.ofNat 1 ::
          counterInitializeSetValue :: rest := by
    rw [counterStack_of_stepFE_dup1_ok hrunning4 hprecompile4
      (counterPreparedInitializeMaskDup1_decoded hat4) h4 hstackOk4 hgas4 hstep4]
  have h6 :
      s6.stack =
        EvmSemantics.UInt256.ofNat 64 :: EvmSemantics.UInt256.ofNat 1 ::
          EvmSemantics.UInt256.ofNat 1 :: counterInitializeSetValue ::
            rest := by
    rw [counterStack_of_stepFE_push1_ok hrunning5 hprecompile5
      (counterPreparedInitializeMaskPush64_decoded hat5) hstackOk5 hgas5 hstep5, h5]
  have h7 :
      s7.stack =
        EvmSemantics.UInt256.shiftLeft
          (EvmSemantics.UInt256.ofNat 1)
          (EvmSemantics.UInt256.ofNat 64) ::
          EvmSemantics.UInt256.ofNat 1 :: counterInitializeSetValue ::
            rest := by
    rw [counterStack_of_stepFE_compBit_shl_ok hrunning6 hprecompile6
      (counterPreparedInitializeMaskShl64_decoded hat6) h6 hstackOk6 hgas6 hstep6]
  have h8 :
      s8.stack =
        EvmSemantics.UInt256.ofNat (2 ^ 64 - 1) ::
          counterInitializeSetValue :: rest := by
    rw [counterStack_of_stepFE_stopArith_sub_ok hrunning7 hprecompile7
      (counterPreparedInitializeMaskSub_decoded hat7) h7 hstackOk7 hgas7 hstep7,
      counterInitializeU64MaskBase_eq]
  have h9 :
      s9.stack =
        EvmSemantics.UInt256.ofNat 192 ::
          EvmSemantics.UInt256.ofNat (2 ^ 64 - 1) ::
            counterInitializeSetValue :: rest := by
    rw [counterStack_of_stepFE_push1_ok hrunning8 hprecompile8
      (counterPreparedInitializeMaskPush192_decoded hat8) hstackOk8 hgas8
      hstep8, h8]
  have h10 :
      s10.stack =
        EvmSemantics.UInt256.shiftLeft
          (EvmSemantics.UInt256.ofNat (2 ^ 64 - 1))
          (EvmSemantics.UInt256.ofNat 192) ::
          counterInitializeSetValue :: rest := by
    rw [counterStack_of_stepFE_compBit_shl_ok hrunning9 hprecompile9
      (counterPreparedInitializeMaskShl192_decoded hat9) h9 hstackOk9 hgas9 hstep9]
  have h11 :
      s11.stack = counterInitializeLowMask :: counterInitializeSetValue ::
        rest := by
    rw [counterStack_of_stepFE_compBit_not_ok hrunning10 hprecompile10
      (counterPreparedInitializeMaskNot_decoded hat10) h10 hstackOk10 hgas10 hstep10]
    rfl
  rw [counterStack_of_stepFE_push0_ok hrunning11 hprecompile11
    (counterPreparedInitializeSloadSlotPush0_decoded hat11) hstackOk11 hgas11
    hstep11, h11, counterCountSlot_eq_zero]

theorem counterStorageValue_of_initialize_tail_stepFE_ok
    {sloadState afterSload afterAnd afterOr sstoreState nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (haddrSload : sloadState.executionEnv.address = counterContractAddress)
    (haddrSstore : sstoreState.executionEnv.address = counterContractAddress)
    (hstack :
      sloadState.stack =
        counterCountSlot :: counterInitializeLowMask ::
          counterInitializeSetValue :: rest)
    (hatSload : counterCompiledStateAt sloadState (counterInitializeBodyOffset + 17))
    (hreadySload :
      counterStepFEReady sloadState
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (hsload : EvmSemantics.EVM.stepFE sloadState = .ok afterSload)
    (hatAnd : counterCompiledStateAt afterSload (counterInitializeBodyOffset + 18))
    (hreadyAnd :
      counterStepFEReady afterSload
        (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps)))
    (hand : EvmSemantics.EVM.stepFE afterSload = .ok afterAnd)
    (hatOr : counterCompiledStateAt afterAnd (counterInitializeBodyOffset + 19))
    (hreadyOr :
      counterStepFEReady afterAnd
        (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps)))
    (hor : EvmSemantics.EVM.stepFE afterAnd = .ok afterOr)
    (hatPush :
      counterCompiledStateAt afterOr (counterInitializeBodyOffset + 20))
    (hreadyPush : counterStepFEReady afterOr (.Push counterPush0Op))
    (hpush : EvmSemantics.EVM.stepFE afterOr = .ok sstoreState)
    (hatSstore : counterCompiledStateAt sstoreState (counterInitializeBodyOffset + 21))
    (hreadySstore :
      counterStepFEReady sstoreState
        (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps)))
    (hsstore : EvmSemantics.EVM.stepFE sstoreState = .ok nextState) :
    counterStorageValue counterContractAddress counterCountSlot nextState =
      counterInitializeStorageWord
        (counterStorageValue counterContractAddress counterCountSlot sloadState) := by
  rcases hreadySload with ⟨hrunningSload, hprecompileSload, hstackOkSload,
    hgasSload⟩
  rcases hreadyAnd with ⟨hrunningAnd, hprecompileAnd, hstackOkAnd, hgasAnd⟩
  rcases hreadyOr with ⟨hrunningOr, hprecompileOr, hstackOkOr, hgasOr⟩
  rcases hreadyPush with ⟨hrunningPush, hprecompilePush, hstackOkPush, hgasPush⟩
  rcases hreadySstore with ⟨hrunningSstore, hprecompileSstore, hstackOkSstore,
    hgasSstore⟩
  have hsloadStack :
      afterSload.stack =
        counterStorageValue counterContractAddress counterCountSlot sloadState ::
          counterInitializeLowMask :: counterInitializeSetValue :: rest :=
    counterStack_of_stepFE_stackMemFlow_sload_ok hrunningSload
      hprecompileSload (counterPreparedInitializeSload_decoded hatSload)
      haddrSload hstack rfl hstackOkSload hgasSload hsload
  have handStack :
      afterAnd.stack =
        EvmSemantics.UInt256.land
          (counterStorageValue counterContractAddress counterCountSlot sloadState)
          counterInitializeLowMask :: counterInitializeSetValue :: rest :=
    counterStack_of_stepFE_compBit_and_ok hrunningAnd hprecompileAnd
      (counterPreparedInitializeAnd_decoded hatAnd) hsloadStack hstackOkAnd
      hgasAnd hand
  have horStack :
      afterOr.stack =
        counterInitializeStorageWord
          (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest := by
    rw [counterStack_of_stepFE_compBit_or_ok hrunningOr hprecompileOr
      (counterPreparedInitializeOr_decoded hatOr) handStack hstackOkOr hgasOr hor]
    change counterInitializeBodyWriteWord
        (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest =
      counterInitializeStorageWord
        (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest
    rw [counterInitializeBodyWriteWord_eq_storageWord]
  have hsstoreStack :
      sstoreState.stack =
        counterCountSlot ::
          counterInitializeStorageWord
            (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest := by
    rw [counterStack_of_stepFE_push0_ok hrunningPush hprecompilePush
      (counterPreparedInitializeSstoreSlotPush0_decoded hatPush) hstackOkPush
      hgasPush hpush, horStack, counterCountSlot_eq_zero]
  exact counterStorageValue_of_stepFE_stackMemFlow_sstore_ok hrunningSstore
    hprecompileSstore (counterPreparedInitializeSstore_decoded hatSstore)
    haddrSstore hsstoreStack rfl hstackOkSstore hgasSstore hsstore

theorem counterStack_of_initialize_tail_stepFE_ok
    {sloadState afterSload afterAnd afterOr sstoreState nextState : EvmState}
    {rest : List EvmSemantics.UInt256}
    (haddrSload : sloadState.executionEnv.address = counterContractAddress)
    (hstack :
      sloadState.stack =
        counterCountSlot :: counterInitializeLowMask ::
          counterInitializeSetValue :: rest)
    (hatSload : counterCompiledStateAt sloadState (counterInitializeBodyOffset + 17))
    (hreadySload :
      counterStepFEReady sloadState
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (hsload : EvmSemantics.EVM.stepFE sloadState = .ok afterSload)
    (hatAnd : counterCompiledStateAt afterSload (counterInitializeBodyOffset + 18))
    (hreadyAnd :
      counterStepFEReady afterSload
        (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps)))
    (hand : EvmSemantics.EVM.stepFE afterSload = .ok afterAnd)
    (hatOr : counterCompiledStateAt afterAnd (counterInitializeBodyOffset + 19))
    (hreadyOr :
      counterStepFEReady afterAnd
        (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps)))
    (hor : EvmSemantics.EVM.stepFE afterAnd = .ok afterOr)
    (hatPush :
      counterCompiledStateAt afterOr (counterInitializeBodyOffset + 20))
    (hreadyPush : counterStepFEReady afterOr (.Push counterPush0Op))
    (hpush : EvmSemantics.EVM.stepFE afterOr = .ok sstoreState)
    (hatSstore : counterCompiledStateAt sstoreState (counterInitializeBodyOffset + 21))
    (hreadySstore :
      counterStepFEReady sstoreState
        (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps)))
    (hsstore : EvmSemantics.EVM.stepFE sstoreState = .ok nextState) :
    nextState.stack = rest := by
  rcases hreadySload with ⟨hrunningSload, hprecompileSload, hstackOkSload,
    hgasSload⟩
  rcases hreadyAnd with ⟨hrunningAnd, hprecompileAnd, hstackOkAnd, hgasAnd⟩
  rcases hreadyOr with ⟨hrunningOr, hprecompileOr, hstackOkOr, hgasOr⟩
  rcases hreadyPush with ⟨hrunningPush, hprecompilePush, hstackOkPush, hgasPush⟩
  rcases hreadySstore with ⟨hrunningSstore, hprecompileSstore, hstackOkSstore,
    hgasSstore⟩
  have hsloadStack :
      afterSload.stack =
        counterStorageValue counterContractAddress counterCountSlot sloadState ::
          counterInitializeLowMask :: counterInitializeSetValue :: rest :=
    counterStack_of_stepFE_stackMemFlow_sload_ok hrunningSload
      hprecompileSload (counterPreparedInitializeSload_decoded hatSload)
      haddrSload hstack rfl hstackOkSload hgasSload hsload
  have handStack :
      afterAnd.stack =
        EvmSemantics.UInt256.land
          (counterStorageValue counterContractAddress counterCountSlot sloadState)
          counterInitializeLowMask :: counterInitializeSetValue :: rest :=
    counterStack_of_stepFE_compBit_and_ok hrunningAnd hprecompileAnd
      (counterPreparedInitializeAnd_decoded hatAnd) hsloadStack hstackOkAnd
      hgasAnd hand
  have horStack :
      afterOr.stack =
        counterInitializeStorageWord
          (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest := by
    rw [counterStack_of_stepFE_compBit_or_ok hrunningOr hprecompileOr
      (counterPreparedInitializeOr_decoded hatOr) handStack hstackOkOr hgasOr hor]
    change counterInitializeBodyWriteWord
        (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest =
      counterInitializeStorageWord
        (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest
    rw [counterInitializeBodyWriteWord_eq_storageWord]
  have hsstoreStack :
      sstoreState.stack =
        counterCountSlot ::
          counterInitializeStorageWord
            (counterStorageValue counterContractAddress counterCountSlot sloadState) ::
          rest := by
    rw [counterStack_of_stepFE_push0_ok hrunningPush hprecompilePush
      (counterPreparedInitializeSstoreSlotPush0_decoded hatPush) hstackOkPush
      hgasPush hpush, horStack, counterCountSlot_eq_zero]
  exact counterStack_of_stepFE_stackMemFlow_sstore_ok hrunningSstore
    hprecompileSstore (counterPreparedInitializeSstore_decoded hatSstore)
    hsstoreStack hstackOkSstore hgasSstore hsstore

theorem counterStorageValue_of_initialize_body_stepFE_from_first_opcode_ok
    {s0 s1 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 s12 s13 s14 s15 s16 s17 :
      EvmState}
    {rest : List EvmSemantics.UInt256}
    (h0 : s0.stack = rest)
    (hat0 : counterCompiledStateAt s0 (counterInitializeBodyOffset + 1))
    (hready0 : counterStepFEReady s0 (.Push counterPush0Op))
    (hstep0 : EvmSemantics.EVM.stepFE s0 = .ok s1)
    (hat1 : counterCompiledStateAt s1 (counterInitializeBodyOffset + 2))
    (hready1 : counterStepFEReady s1 (.Push counterPush1Op))
    (hstep1 : EvmSemantics.EVM.stepFE s1 = .ok s2)
    (hat2 : counterCompiledStateAt s2 (counterInitializeBodyOffset + 4))
    (hready2 :
      counterStepFEReady s2
        (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep2 : EvmSemantics.EVM.stepFE s2 = .ok s3)
    (hat3 : counterCompiledStateAt s3 (counterInitializeBodyOffset + 5))
    (hready3 : counterStepFEReady s3 (.Push counterPush1Op))
    (hstep3 : EvmSemantics.EVM.stepFE s3 = .ok s4)
    (hat4 : counterCompiledStateAt s4 (counterInitializeBodyOffset + 7))
    (hready4 : counterStepFEReady s4 (.Dup counterDup1Op))
    (hstep4 : EvmSemantics.EVM.stepFE s4 = .ok s5)
    (hat5 : counterCompiledStateAt s5 (counterInitializeBodyOffset + 8))
    (hready5 : counterStepFEReady s5 (.Push counterPush1Op))
    (hstep5 : EvmSemantics.EVM.stepFE s5 = .ok s6)
    (hat6 : counterCompiledStateAt s6 (counterInitializeBodyOffset + 10))
    (hready6 :
      counterStepFEReady s6
        (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep6 : EvmSemantics.EVM.stepFE s6 = .ok s7)
    (hat7 : counterCompiledStateAt s7 (counterInitializeBodyOffset + 11))
    (hready7 :
      counterStepFEReady s7
        (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps)))
    (hstep7 : EvmSemantics.EVM.stepFE s7 = .ok s8)
    (hat8 : counterCompiledStateAt s8 (counterInitializeBodyOffset + 12))
    (hready8 : counterStepFEReady s8 (.Push counterPush1Op))
    (hstep8 : EvmSemantics.EVM.stepFE s8 = .ok s9)
    (hat9 : counterCompiledStateAt s9 (counterInitializeBodyOffset + 14))
    (hready9 :
      counterStepFEReady s9
        (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep9 : EvmSemantics.EVM.stepFE s9 = .ok s10)
    (hat10 : counterCompiledStateAt s10 (counterInitializeBodyOffset + 15))
    (hready10 :
      counterStepFEReady s10
        (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep10 : EvmSemantics.EVM.stepFE s10 = .ok s11)
    (hat11 : counterCompiledStateAt s11 (counterInitializeBodyOffset + 16))
    (hready11 : counterStepFEReady s11 (.Push counterPush0Op))
    (hstep11 : EvmSemantics.EVM.stepFE s11 = .ok s12)
    (hat12 : counterCompiledStateAt s12 (counterInitializeBodyOffset + 17))
    (haddrSload : s12.executionEnv.address = counterContractAddress)
    (hready12 :
      counterStepFEReady s12
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep12 : EvmSemantics.EVM.stepFE s12 = .ok s13)
    (hat13 : counterCompiledStateAt s13 (counterInitializeBodyOffset + 18))
    (hready13 :
      counterStepFEReady s13
        (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep13 : EvmSemantics.EVM.stepFE s13 = .ok s14)
    (hat14 : counterCompiledStateAt s14 (counterInitializeBodyOffset + 19))
    (hready14 :
      counterStepFEReady s14
        (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps)))
    (hstep14 : EvmSemantics.EVM.stepFE s14 = .ok s15)
    (hat15 : counterCompiledStateAt s15 (counterInitializeBodyOffset + 20))
    (hready15 : counterStepFEReady s15 (.Push counterPush0Op))
    (hstep15 : EvmSemantics.EVM.stepFE s15 = .ok s16)
    (hat16 : counterCompiledStateAt s16 (counterInitializeBodyOffset + 21))
    (haddrSstore : s16.executionEnv.address = counterContractAddress)
    (hready16 :
      counterStepFEReady s16
        (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps)))
    (hstep16 : EvmSemantics.EVM.stepFE s16 = .ok s17) :
    counterStorageValue counterContractAddress counterCountSlot s17 =
      counterInitializeStorageWord
        (counterStorageValue counterContractAddress counterCountSlot s12) := by
  have hstack12 :
      s12.stack =
        counterCountSlot :: counterInitializeLowMask ::
          counterInitializeSetValue :: rest :=
    counterStack_of_initialize_prefix_stepFE_to_sload_ok
      h0 hat0 hready0 hstep0 hat1 hready1 hstep1
      hat2 hready2 hstep2 hat3 hready3 hstep3
      hat4 hready4 hstep4 hat5 hready5 hstep5
      hat6 hready6 hstep6 hat7 hready7 hstep7
      hat8 hready8 hstep8 hat9 hready9 hstep9
      hat10 hready10 hstep10 hat11 hready11 hstep11
  exact counterStorageValue_of_initialize_tail_stepFE_ok
    haddrSload haddrSstore hstack12
    hat12 hready12 hstep12 hat13 hready13 hstep13
    hat14 hready14 hstep14 hat15 hready15 hstep15
    hat16 hready16 hstep16

def counterRuntimeGasAvailable : Nat := 1000000

def counterRuntimeBlockGasLimit : Nat := 30000000

def counterRuntimeChainId : Nat := 31337

def counterCallerAddress : EvmSemantics.AccountAddress :=
  EvmSemantics.AccountAddress.ofNat 1

def installCounterRuntimeCode (runtimeCode : ByteArray) (state : EvmState) :
    EvmState :=
  let account := state.accountMap counterContractAddress
  { state with
    accountMap := state.accountMap.set counterContractAddress
      { account with code := runtimeCode } }

def counterCallExecutionEnv (runtimeCode : ByteArray) (call : CounterCall)
    (state : EvmState) : EvmSemantics.ExecutionEnv := {
  state.executionEnv with
    address := counterContractAddress
    origin := counterCallerAddress
    caller := counterCallerAddress
    weiValue := EvmSemantics.UInt256.ofNat 0
    calldata := counterCallCalldata call
    code := runtimeCode
    codeAddr := counterContractAddress
    gasPrice := EvmSemantics.UInt256.ofNat 0
    header := {
      state.executionEnv.header with
        gasLimit := EvmSemantics.UInt256.ofNat counterRuntimeBlockGasLimit
        chainId := EvmSemantics.UInt256.ofNat counterRuntimeChainId
    }
    depth := 0
    permitStateMutation := true
    blobVersionedHashes := #[]
    fork := EvmSemantics.Fork.Cancun
}

/-- Prepare a top-level powdr frame for executing one Counter selector.

The runtime bytecode is an explicit parameter: the later proof should pass the
actual ProofForge EVM artifact bytes here, rather than replacing the compiler
pipeline with a handwritten bytecode fixture. -/
def prepareCounterCall (runtimeCode : ByteArray) (call : CounterCall)
    (state : EvmState) : EvmState :=
  let state := installCounterRuntimeCode runtimeCode state
  { state with
    gasAvailable := counterRuntimeGasAvailable
    activeWords := EvmSemantics.UInt256.ofNat 0
    memory := ByteArray.empty
    returnData := ByteArray.empty
    hReturn := ByteArray.empty
    executionEnv := counterCallExecutionEnv runtimeCode call state
    pc := EvmSemantics.UInt256.ofNat 0
    stack := []
    execLength := 0
    halt := .Running
    callStack := [] }

theorem counterStorageValue_installCounterRuntimeCode
    (runtimeCode : ByteArray) (state : EvmState) :
    counterStorageValue counterContractAddress counterCountSlot
        (installCounterRuntimeCode runtimeCode state) =
      counterStorageValue counterContractAddress counterCountSlot state := by
  simp [installCounterRuntimeCode, counterStorageValue, counterAccount]

theorem counterStorageValue_prepareCounterCall
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    counterStorageValue counterContractAddress counterCountSlot
        (prepareCounterCall runtimeCode call state) =
      counterStorageValue counterContractAddress counterCountSlot state := by
  simp [prepareCounterCall, counterStorageValue, counterAccount, installCounterRuntimeCode]

theorem counterStorageRel_prepareCounterCall
    {irState : IRState} {evmState : EvmState}
    (runtimeCode : ByteArray) (call : CounterCall)
    (hrel : CounterStorageRel irState evmState) :
    CounterStorageRel irState (prepareCounterCall runtimeCode call evmState) := by
  rcases hrel with ⟨count, hcount, hbound, hstorage⟩
  refine ⟨count, hcount, hbound, ?_⟩
  rw [counterStorageValue_prepareCounterCall]
  exact hstorage

@[simp] theorem prepareCounterCall_gasAvailable
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    (prepareCounterCall runtimeCode call state).gasAvailable =
      counterRuntimeGasAvailable := rfl

@[simp] theorem prepareCounterCall_pc
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    (prepareCounterCall runtimeCode call state).pc = EvmSemantics.UInt256.ofNat 0 := rfl

@[simp] theorem prepareCounterCall_stack
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    (prepareCounterCall runtimeCode call state).stack = [] := rfl

@[simp] theorem prepareCounterCall_halt
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    (prepareCounterCall runtimeCode call state).halt = .Running := rfl

@[simp] theorem prepareCounterCall_callStack
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    (prepareCounterCall runtimeCode call state).callStack = [] := rfl

@[simp] theorem prepareCounterCall_calldata
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    (prepareCounterCall runtimeCode call state).executionEnv.calldata =
      counterCallCalldata call := rfl

@[simp] theorem prepareCounterCall_code
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    (prepareCounterCall runtimeCode call state).executionEnv.code =
      runtimeCode := rfl

@[simp] theorem prepareCounterCall_isDone
    (runtimeCode : ByteArray) (call : CounterCall) (state : EvmState) :
    (prepareCounterCall runtimeCode call state).isDone = false := by
  simp [prepareCounterCall, EvmSemantics.EVM.State.isDone,
    EvmSemantics.EVM.State.isHalted, EvmSemantics.EVM.State.isRunning]

structure PowdrCounterConfig where
  runtimeCode : ByteArray
  fuel : Nat

def counterCompiledRuntimeFuel : Nat := 5000

def counterCompiledPowdrConfig : PowdrCounterConfig := {
  runtimeCode := counterCompiledRuntimeCode
  fuel := counterCompiledRuntimeFuel
}

def counterBaseEvmState : EvmState :=
  { (default : EvmState) with
    gasAvailable := counterRuntimeGasAvailable
    executionEnv := {
      (default : EvmSemantics.ExecutionEnv) with
        address := counterContractAddress
        origin := counterCallerAddress
        caller := counterCallerAddress
        weiValue := EvmSemantics.UInt256.ofNat 0
        calldata := ByteArray.empty
        code := counterCompiledRuntimeCode
        codeAddr := counterContractAddress
        gasPrice := EvmSemantics.UInt256.ofNat 0
        header := { (default : EvmSemantics.BlockHeader) with
          gasLimit := EvmSemantics.UInt256.ofNat counterRuntimeBlockGasLimit
          chainId := EvmSemantics.UInt256.ofNat counterRuntimeChainId }
        depth := 0
        permitStateMutation := true
        fork := EvmSemantics.Fork.Cancun }
    pc := EvmSemantics.UInt256.ofNat 0
    stack := []
    execLength := 0
    halt := .Running
    callStack := [] }

def counterUnitObservableFromResult (name : String) :
    EvmSemantics.EVM.ExecutionResult → Except String ObservableReturn
  | .success => .ok .none
  | .returned output =>
      if output.size == 0 then
        .ok .none
      else
        .error s!"Counter.{name} returned unexpected EVM output bytes"
  | .reverted _ => .ok (.reverted s!"Counter.{name} reverted")
  | .exception _ => .error s!"Counter.{name} halted with an EVM exception"

def counterGetObservableFromResult :
    EvmSemantics.EVM.ExecutionResult → Except String ObservableReturn
  | .returned output =>
      .ok (.u64 (EvmSemantics.MachineState.readWord output 0).toNat)
  | .success => .error "Counter.get stopped without EVM return data"
  | .reverted _ => .ok (.reverted "Counter.get reverted")
  | .exception _ => .error "Counter.get halted with an EVM exception"

def counterObservableFromResult (call : CounterCall)
    (result : EvmSemantics.EVM.ExecutionResult) : Except String ObservableReturn :=
  match call with
  | .initialize => counterUnitObservableFromResult "initialize" result
  | .increment => counterUnitObservableFromResult "increment" result
  | .get => counterGetObservableFromResult result

def counterPowdrPreparedTraceStep (cfg : PowdrCounterConfig) (preparedState : EvmState)
    (call : CounterCall) : Except String (EvmState × ObservableReturn) := do
  let (finalState, _observations) ←
    ProofForge.Backend.Evm.PowdrAdapter.runBytecode preparedState cfg.fuel
  let observable ← counterObservableFromResult call finalState.toResult
  .ok (finalState, observable)

def counterPowdrTraceStep (cfg : PowdrCounterConfig) (state : EvmState)
    (call : CounterCall) : Except String (EvmState × ObservableReturn) := do
  counterPowdrPreparedTraceStep cfg (prepareCounterCall cfg.runtimeCode call state) call

def CounterPreparedCall (cfg : PowdrCounterConfig) (call : CounterCall)
    (state : EvmState) : Prop :=
  ∃ sourceState, state = prepareCounterCall cfg.runtimeCode call sourceState

theorem counterCompiledPreparedInitialize_entry_facts
    {preparedState : EvmState}
    (hprepared :
      CounterPreparedCall counterCompiledPowdrConfig .initialize preparedState) :
    counterCompiledStateAt preparedState 0 ∧
      preparedState.stack = [] ∧
      preparedState.executionEnv.calldata = counterCallCalldata .initialize ∧
      preparedState.executionEnv.address = counterContractAddress := by
  rcases hprepared with ⟨sourceState, rfl⟩
  refine ⟨?_, ?_, ?_, ?_⟩
  · unfold counterCompiledStateAt
    simp [counterCompiledPowdrConfig, prepareCounterCall, counterCallExecutionEnv]
    change EvmSemantics.Fork.Shanghai.toOrd ≤ EvmSemantics.Fork.Cancun.toOrd
    decide
  · rfl
  · rfl
  · rfl

theorem counterPreparedCall_isDone
    {cfg : PowdrCounterConfig} {call : CounterCall} {state : EvmState}
    (hprepared : CounterPreparedCall cfg call state) :
    state.isDone = false := by
  rcases hprepared with ⟨sourceState, rfl⟩
  exact prepareCounterCall_isDone cfg.runtimeCode call sourceState

theorem counterPreparedCall_not_isDone
    {cfg : PowdrCounterConfig} {call : CounterCall} {state : EvmState}
    (hprepared : CounterPreparedCall cfg call state) :
    ¬ state.isDone := by
  rw [counterPreparedCall_isDone hprepared]
  simp

theorem counterPreparedCall_stepF_ok
    {cfg : PowdrCounterConfig} {call : CounterCall} {state : EvmState}
    (hprepared : CounterPreparedCall cfg call state) :
    ProofForge.Backend.Evm.PowdrAdapter.stepF state =
      .ok (ProofForge.Backend.Evm.PowdrAdapter.rawStepF state) := by
  unfold ProofForge.Backend.Evm.PowdrAdapter.stepF
  rw [counterPreparedCall_isDone hprepared]
  rfl

theorem counterPreparedCall_stepF_step
    {cfg : PowdrCounterConfig} {call : CounterCall} {state : EvmState}
    (hprepared : CounterPreparedCall cfg call state) :
    ProofForge.Backend.Evm.PowdrAdapter.Step state
      (ProofForge.Backend.Evm.PowdrAdapter.rawStepF state) :=
  ProofForge.Backend.Evm.PowdrAdapter.raw_stepF_sound state
    (counterPreparedCall_not_isDone hprepared)

theorem counterPowdrTraceStep_steps {cfg : PowdrCounterConfig}
    {state finalState : EvmState} {call : CounterCall}
    {obs : ObservableReturn}
    (h : counterPowdrTraceStep cfg state call = .ok (finalState, obs)) :
    EvmSemantics.EVM.Steps
      (prepareCounterCall cfg.runtimeCode call state) finalState := by
  unfold counterPowdrTraceStep at h
  unfold counterPowdrPreparedTraceStep at h
  cases hrun : ProofForge.Backend.Evm.PowdrAdapter.runBytecode
      (prepareCounterCall cfg.runtimeCode call state) cfg.fuel with
  | error message =>
      rw [hrun] at h
      change (Except.bind (Except.error message)
        (fun result : EvmState × Array ProofForge.Backend.Evm.PowdrAdapter.ObservableStep =>
          Except.bind (counterObservableFromResult call result.fst.toResult)
            (fun observable : ObservableReturn =>
              Except.ok (result.fst, observable)))) = Except.ok (finalState, obs) at h
      simp [Except.bind] at h
  | ok result =>
      rcases result with ⟨runFinalState, observations⟩
      have hsteps :=
        ProofForge.Backend.Evm.PowdrAdapter.runBytecode_steps hrun
      rw [hrun] at h
      change (Except.bind (Except.ok
        ((runFinalState, observations) :
          EvmState × Array ProofForge.Backend.Evm.PowdrAdapter.ObservableStep))
        (fun result : EvmState × Array ProofForge.Backend.Evm.PowdrAdapter.ObservableStep =>
              Except.bind (counterObservableFromResult call result.fst.toResult)
                (fun observable : ObservableReturn =>
                  Except.ok (result.fst, observable)))) = Except.ok (finalState, obs) at h
      change (Except.bind (counterObservableFromResult call runFinalState.toResult)
        (fun observable : ObservableReturn =>
          Except.ok (runFinalState, observable))) = Except.ok (finalState, obs) at h
      cases hobs : counterObservableFromResult call runFinalState.toResult with
      | error message =>
          rw [hobs] at h
          change (Except.error message : Except String (EvmState × ObservableReturn)) =
            Except.ok (finalState, obs) at h
          cases h
      | ok targetObservable =>
          rw [hobs] at h
          change Except.ok (runFinalState, targetObservable) =
            Except.ok (finalState, obs) at h
          cases h
          exact hsteps

theorem counterPowdrTraceStep_observable {cfg : PowdrCounterConfig}
    {state finalState : EvmState} {call : CounterCall}
    {obs : ObservableReturn}
    (h : counterPowdrTraceStep cfg state call = .ok (finalState, obs)) :
    counterObservableFromResult call finalState.toResult = .ok obs := by
  unfold counterPowdrTraceStep at h
  unfold counterPowdrPreparedTraceStep at h
  cases hrun : ProofForge.Backend.Evm.PowdrAdapter.runBytecode
      (prepareCounterCall cfg.runtimeCode call state) cfg.fuel with
  | error message =>
      rw [hrun] at h
      change (Except.bind (Except.error message)
        (fun result : EvmState × Array ProofForge.Backend.Evm.PowdrAdapter.ObservableStep =>
          Except.bind (counterObservableFromResult call result.fst.toResult)
            (fun observable : ObservableReturn =>
              Except.ok (result.fst, observable)))) = Except.ok (finalState, obs) at h
      simp [Except.bind] at h
  | ok result =>
      rcases result with ⟨runFinalState, observations⟩
      rw [hrun] at h
      change (Except.bind (Except.ok
        ((runFinalState, observations) :
          EvmState × Array ProofForge.Backend.Evm.PowdrAdapter.ObservableStep))
        (fun result : EvmState × Array ProofForge.Backend.Evm.PowdrAdapter.ObservableStep =>
              Except.bind (counterObservableFromResult call result.fst.toResult)
                (fun observable : ObservableReturn =>
                  Except.ok (result.fst, observable)))) = Except.ok (finalState, obs) at h
      change (Except.bind (counterObservableFromResult call runFinalState.toResult)
        (fun observable : ObservableReturn =>
          Except.ok (runFinalState, observable))) = Except.ok (finalState, obs) at h
      cases hobs : counterObservableFromResult call runFinalState.toResult with
      | error message =>
          rw [hobs] at h
          change (Except.error message : Except String (EvmState × ObservableReturn)) =
            Except.ok (finalState, obs) at h
          cases h
      | ok targetObservable =>
          rw [hobs] at h
          change Except.ok (runFinalState, targetObservable) =
            Except.ok (finalState, obs) at h
          cases h
          exact hobs

def counterPowdrRunTrace (cfg : PowdrCounterConfig) :
    List CounterCall → EvmState → Except String (EvmState × Array ObservableReturn) :=
  ProofForge.IR.StepSemantics.runTraceListGen (counterPowdrTraceStep cfg)

def counterPowdrStepReturns (cfg : PowdrCounterConfig) (state : EvmState)
    (call : CounterCall) (expected : ObservableReturn) : Bool :=
  match counterPowdrTraceStep cfg state call with
  | .ok (_, observable) => observable == expected
  | .error _ => false

def counterPowdrTraceReturns (cfg : PowdrCounterConfig) (calls : List CounterCall)
    (state : EvmState) (expected : Array ObservableReturn) : Bool :=
  match counterPowdrRunTrace cfg calls state with
  | .ok (_, observables) => observables == expected
  | .error _ => false

theorem counterCompiledPowdr_initialize_executable_smoke :
    counterPowdrStepReturns counterCompiledPowdrConfig counterBaseEvmState
      .initialize .none = true := by
  native_decide

theorem counterCompiledPowdr_get_zero_executable_smoke :
    counterPowdrStepReturns counterCompiledPowdrConfig counterBaseEvmState
      .get (.u64 0) = true := by
  native_decide

theorem counterCompiledPowdr_get_packed_seven_executable_smoke :
    counterPowdrStepReturns counterCompiledPowdrConfig
      (setCounterStorage counterContractAddress counterCountSlot counterBaseEvmState 7)
      .get (.u64 7) = true := by
  native_decide

theorem counterCompiledPowdr_get_padded_seven_executable_smoke :
    counterPowdrStepReturns counterCompiledPowdrConfig
      (setCounterStorageWord counterContractAddress counterCountSlot counterBaseEvmState
        (counterPaddedCountValue 7 123))
      .get (.u64 7) = true := by
  native_decide

theorem counterCompiledPowdr_increment_packed_seven_executable_smoke :
    counterPowdrTraceReturns counterCompiledPowdrConfig
      [.increment, .get]
      (setCounterStorage counterContractAddress counterCountSlot counterBaseEvmState 7)
      #[.none, .u64 8] = true := by
  native_decide

theorem counterCompiledPowdr_initialize_padded_get_executable_smoke :
    counterPowdrTraceReturns counterCompiledPowdrConfig
      [.initialize, .get]
      (setCounterStorageWord counterContractAddress counterCountSlot counterBaseEvmState
        (counterPaddedCountValue 7 123))
      #[.none, .u64 0] = true := by
  native_decide

theorem counterCompiledPowdr_initialize_increment_get_executable_smoke :
    counterPowdrTraceReturns counterCompiledPowdrConfig
      [.initialize, .increment, .get] counterBaseEvmState
      #[.none, .none, .u64 1] = true := by
  native_decide

theorem counterPowdrRunTrace_eq_traceStep (cfg : PowdrCounterConfig)
    (calls : List CounterCall) (state : EvmState) :
    counterPowdrRunTrace cfg calls state =
      ProofForge.IR.StepSemantics.runTraceListGen
        (counterPowdrTraceStep cfg) calls state := rfl

def counterCallFromTraceCall? (call : TraceCall) : Option CounterCall :=
  if call.args.size == 0 && call.evmArgs.size == 0 then
    if isCounterInitializeEntrypoint call.entrypoint then
      some .initialize
    else if isCounterIncrementEntrypoint call.entrypoint then
      some .increment
    else if isCounterGetEntrypoint call.entrypoint then
      some .get
    else
      none
  else
    none

def counterCallsFromTraceCalls? : List TraceCall → Option (List CounterCall)
  | [] => some []
  | call :: rest => do
      let counterCall ← counterCallFromTraceCall? call
      let counterRest ← counterCallsFromTraceCalls? rest
      some (counterCall :: counterRest)

def counterExpectedStepMatches (call : CounterCall)
    (observable : ObservableReturn) (expected : ObservableStep) : Bool :=
  expected.entrypointName == call.entrypoint.name &&
    expected.selector == counterCallSelector call &&
    expected.returnValue == observable &&
    expected.logs.isEmpty

def counterExpectedTraceMatches :
    List CounterCall → List ObservableReturn → List ObservableStep → Bool
  | [], [], [] => true
  | call :: calls, observable :: observables, expected :: expectedRest =>
      counterExpectedStepMatches call observable expected &&
        counterExpectedTraceMatches calls observables expectedRest
  | _, _, _ => false

def counterPowdrExecutableTraceOk (cfg : PowdrCounterConfig) (state : EvmState)
    (obligation : TraceObligation) : Bool :=
  FormalFragment.counter.acceptsModule obligation.module &&
    match counterCallsFromTraceCalls? obligation.calls.toList with
    | none => false
    | some calls =>
        match counterPowdrRunTrace cfg calls state with
        | .ok (_, observables) =>
            counterExpectedTraceMatches calls observables.toList obligation.expected.toList
        | .error _ => false

def counterPowdrTargetSemantics (cfg : PowdrCounterConfig) : TargetSemantics := {
  id := "evm-powdr-counter"
  supportedFragments := #[.counter]
  MachineState := EvmState
  Call := CounterCall
  Obs := ObservableReturn
  traceStep := counterPowdrTraceStep cfg
  runTrace := counterPowdrRunTrace cfg
  runTrace_eq_traceStep := counterPowdrRunTrace_eq_traceStep cfg
  executableTraceOk := fun _ => false
}

def counterCompiledPowdrExecutableTraceOk (obligation : TraceObligation) : Bool :=
  counterPowdrExecutableTraceOk counterCompiledPowdrConfig counterBaseEvmState obligation

def counterCompiledPowdrTargetSemantics : TargetSemantics :=
  { counterPowdrTargetSemantics counterCompiledPowdrConfig with
    executableTraceOk := counterCompiledPowdrExecutableTraceOk }

def counterCompiledPowdrTraceObligation : TraceObligation := {
  name := "Counter.powdr.initialize-get-increment-get"
  module := ProofForge.IR.Examples.Counter.module
  calls := #[
    { entrypoint := ProofForge.IR.Examples.Counter.initializeEntrypoint },
    { entrypoint := ProofForge.IR.Examples.Counter.get },
    { entrypoint := ProofForge.IR.Examples.Counter.increment },
    { entrypoint := ProofForge.IR.Examples.Counter.get }
  ]
  expected := #[
    { entrypointName := "initialize", selector := "8129fc1c", returnValue := .none },
    { entrypointName := "get", selector := "6d4ce63c", returnValue := .u64 0 },
    { entrypointName := "increment", selector := "d09de08a", returnValue := .none },
    { entrypointName := "get", selector := "6d4ce63c", returnValue := .u64 1 }
  ]
}

theorem counterCompiledPowdr_executable_trace_ok :
    counterCompiledPowdrTargetSemantics.executableTraceOk
      counterCompiledPowdrTraceObligation = true := by
  native_decide

structure CounterPowdrEntrypointObligations (cfg : PowdrCounterConfig) where
  initialize_simulates :
    ∀ {irState evmState nextIr observable},
      counterIRStep irState .initialize = .ok (nextIr, observable) →
        ∃ nextEvm,
          counterPowdrTraceStep cfg evmState .initialize = .ok (nextEvm, observable) ∧
          CounterStorageRel nextIr nextEvm
  increment_simulates :
    ∀ {irState evmState nextIr observable},
      CounterStorageRel irState evmState →
      counterIRStep irState .increment = .ok (nextIr, observable) →
        ∃ nextEvm,
          counterPowdrTraceStep cfg evmState .increment = .ok (nextEvm, observable) ∧
          CounterStorageRel nextIr nextEvm
  get_simulates :
    ∀ {irState evmState nextIr observable},
      CounterStorageRel irState evmState →
      counterIRStep irState .get = .ok (nextIr, observable) →
        ∃ nextEvm,
          counterPowdrTraceStep cfg evmState .get = .ok (nextEvm, observable) ∧
          CounterStorageRel nextIr nextEvm

def CounterStepSafe (call : CounterCall) (irState : IRState) : Prop :=
  match call with
  | .initialize => True
  | .get =>
      ∀ count, irCounterCount? irState = some count → count < counterU64Modulus
  | .increment =>
      ∀ count, irCounterCount? irState = some count → count + 1 < counterU64Modulus

structure CounterPowdrSafeEntrypointObligations (cfg : PowdrCounterConfig) where
  initialize_simulates :
    ∀ {irState evmState nextIr observable},
      counterIRStep irState .initialize = .ok (nextIr, observable) →
        ∃ nextEvm,
          counterPowdrTraceStep cfg evmState .initialize = .ok (nextEvm, observable) ∧
          CounterStorageRel nextIr nextEvm
  increment_simulates :
    ∀ {irState evmState nextIr observable},
      CounterStorageRel irState evmState →
      CounterStepSafe .increment irState →
      counterIRStep irState .increment = .ok (nextIr, observable) →
        ∃ nextEvm,
          counterPowdrTraceStep cfg evmState .increment = .ok (nextEvm, observable) ∧
          CounterStorageRel nextIr nextEvm
  get_simulates :
    ∀ {irState evmState nextIr observable},
      CounterStorageRel irState evmState →
      CounterStepSafe .get irState →
      counterIRStep irState .get = .ok (nextIr, observable) →
        ∃ nextEvm,
          counterPowdrTraceStep cfg evmState .get = .ok (nextEvm, observable) ∧
          CounterStorageRel nextIr nextEvm

structure CounterPowdrEvmPostconditions (cfg : PowdrCounterConfig) where
  initialize_writes_zero :
    ∀ {evmState},
      ∃ nextEvm,
        counterPowdrTraceStep cfg evmState .initialize = .ok (nextEvm, .none) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) 0
  increment_writes_succ :
    ∀ {evmState count},
      count + 1 < counterU64Modulus →
      CounterStorageWordRel
        (counterStorageValue counterContractAddress counterCountSlot evmState) count →
      ∃ nextEvm,
        counterPowdrTraceStep cfg evmState .increment = .ok (nextEvm, .none) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) (count + 1)
  get_returns_count :
    ∀ {evmState count},
      count < counterU64Modulus →
      CounterStorageWordRel
        (counterStorageValue counterContractAddress counterCountSlot evmState) count →
      ∃ nextEvm,
        counterPowdrTraceStep cfg evmState .get = .ok (nextEvm, .u64 count) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) count

structure CounterPowdrPreparedEvmPostconditions (cfg : PowdrCounterConfig) where
  initialize_writes_zero :
    ∀ {preparedState},
      CounterPreparedCall cfg .initialize preparedState →
      ∃ nextEvm,
        counterPowdrPreparedTraceStep cfg preparedState .initialize =
          .ok (nextEvm, .none) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) 0
  increment_writes_succ :
    ∀ {preparedState count},
      CounterPreparedCall cfg .increment preparedState →
      count + 1 < counterU64Modulus →
      CounterStorageWordRel
        (counterStorageValue counterContractAddress counterCountSlot preparedState) count →
      ∃ nextEvm,
        counterPowdrPreparedTraceStep cfg preparedState .increment =
          .ok (nextEvm, .none) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) (count + 1)
  get_returns_count :
    ∀ {preparedState count},
      CounterPreparedCall cfg .get preparedState →
      count < counterU64Modulus →
      CounterStorageWordRel
        (counterStorageValue counterContractAddress counterCountSlot preparedState) count →
      ∃ nextEvm,
        counterPowdrPreparedTraceStep cfg preparedState .get = .ok (nextEvm, .u64 count) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) count

structure CounterPowdrPreparedStorageModels (cfg : PowdrCounterConfig) where
  initialize_writes_storage_model :
    ∀ {preparedState},
      CounterPreparedCall cfg .initialize preparedState →
      ∃ nextEvm,
        counterPowdrPreparedTraceStep cfg preparedState .initialize =
          .ok (nextEvm, .none) ∧
        counterStorageValue counterContractAddress counterCountSlot nextEvm =
          counterInitializeStorageWord
            (counterStorageValue counterContractAddress counterCountSlot preparedState)
  increment_writes_succ :
    ∀ {preparedState count},
      CounterPreparedCall cfg .increment preparedState →
      count + 1 < counterU64Modulus →
      CounterStorageWordRel
        (counterStorageValue counterContractAddress counterCountSlot preparedState) count →
      ∃ nextEvm,
        counterPowdrPreparedTraceStep cfg preparedState .increment =
          .ok (nextEvm, .none) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) (count + 1)
  get_returns_count :
    ∀ {preparedState count},
      CounterPreparedCall cfg .get preparedState →
      count < counterU64Modulus →
      CounterStorageWordRel
        (counterStorageValue counterContractAddress counterCountSlot preparedState) count →
      ∃ nextEvm,
        counterPowdrPreparedTraceStep cfg preparedState .get = .ok (nextEvm, .u64 count) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) count

theorem counterPreparedInitializePostconditionOfStorageModel
    (cfg : PowdrCounterConfig)
    (hmodel :
      ∀ {preparedState},
        CounterPreparedCall cfg .initialize preparedState →
        ∃ nextEvm,
          counterPowdrPreparedTraceStep cfg preparedState .initialize =
            .ok (nextEvm, .none) ∧
          counterStorageValue counterContractAddress counterCountSlot nextEvm =
            counterInitializeStorageWord
              (counterStorageValue counterContractAddress counterCountSlot preparedState)) :
    ∀ {preparedState},
      CounterPreparedCall cfg .initialize preparedState →
      ∃ nextEvm,
        counterPowdrPreparedTraceStep cfg preparedState .initialize =
          .ok (nextEvm, .none) ∧
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot nextEvm) 0 := by
  intro preparedState hprepared
  obtain ⟨nextEvm, hstep, hstorage⟩ := hmodel hprepared
  refine ⟨nextEvm, hstep, ?_⟩
  rw [hstorage]
  exact counterInitializeStorageWord_rel_zero
    (counterStorageValue counterContractAddress counterCountSlot preparedState)

def counterPowdrPreparedEvmPostconditionsOfStorageModels
    (cfg : PowdrCounterConfig) (models : CounterPowdrPreparedStorageModels cfg) :
    CounterPowdrPreparedEvmPostconditions cfg where
  initialize_writes_zero :=
    counterPreparedInitializePostconditionOfStorageModel cfg
      models.initialize_writes_storage_model
  increment_writes_succ := models.increment_writes_succ
  get_returns_count := models.get_returns_count

def counterPowdrEvmPostconditionsOfPrepared
    (cfg : PowdrCounterConfig) (post : CounterPowdrPreparedEvmPostconditions cfg) :
    CounterPowdrEvmPostconditions cfg where
  initialize_writes_zero := by
    intro evmState
    exact post.initialize_writes_zero ⟨evmState, rfl⟩
  increment_writes_succ := by
    intro evmState count hbound hstorage
    have hstoragePrepared :
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot
            (prepareCounterCall cfg.runtimeCode .increment evmState)) count := by
      rw [counterStorageValue_prepareCounterCall]
      exact hstorage
    exact post.increment_writes_succ ⟨evmState, rfl⟩ hbound hstoragePrepared
  get_returns_count := by
    intro evmState count hbound hstorage
    have hstoragePrepared :
        CounterStorageWordRel
          (counterStorageValue counterContractAddress counterCountSlot
            (prepareCounterCall cfg.runtimeCode .get evmState)) count := by
      rw [counterStorageValue_prepareCounterCall]
      exact hstorage
    exact post.get_returns_count ⟨evmState, rfl⟩ hbound hstoragePrepared

def counterPowdrSafeEntrypointObligationsOfPostconditions
    (cfg : PowdrCounterConfig) (post : CounterPowdrEvmPostconditions cfg) :
    CounterPowdrSafeEntrypointObligations cfg where
  initialize_simulates := by
    intro irState evmState nextIr observable hirStep
    obtain ⟨modelNextIr, nextCount, modelObservable, hirModel, htargetStep,
      hcounterNext⟩ :=
        ProofForge.Backend.Refinement.CounterUniversal.counter_initialize_simulates
          irState 0
    change ProofForge.Backend.Refinement.CounterUniversal.irStep irState .initialize =
      .ok (nextIr, observable) at hirStep
    rw [hirModel] at hirStep
    cases hirStep
    cases htargetStep
    obtain ⟨nextEvm, hpowdrStep, hstorageNext⟩ :=
      post.initialize_writes_zero (evmState := evmState)
    refine ⟨nextEvm, hpowdrStep, ?_⟩
    refine ⟨0, counterStateRel_irCounterCount? hcounterNext, ?_, hstorageNext⟩
    native_decide
  increment_simulates := by
    intro irState evmState nextIr observable hrel hsafe hirStep
    rcases hrel with ⟨count, hcount, _hbound, hstorage⟩
    have hcounter := counterStateRel_of_irCounterCount? hcount
    have hnextBound : count + 1 < counterU64Modulus := hsafe count hcount
    obtain ⟨modelNextIr, nextCount, modelObservable, hirModel, htargetStep,
      hcounterNext⟩ :=
        ProofForge.Backend.Refinement.CounterUniversal.counter_increment_simulates
          hcounter
    change ProofForge.Backend.Refinement.CounterUniversal.irStep irState .increment =
      .ok (nextIr, observable) at hirStep
    rw [hirModel] at hirStep
    cases hirStep
    cases htargetStep
    obtain ⟨nextEvm, hpowdrStep, hstorageNext⟩ :=
      post.increment_writes_succ hnextBound hstorage
    refine ⟨nextEvm, hpowdrStep, ?_⟩
    exact ⟨count + 1, counterStateRel_irCounterCount? hcounterNext,
      hnextBound, hstorageNext⟩
  get_simulates := by
    intro irState evmState nextIr observable hrel hsafe hirStep
    rcases hrel with ⟨count, hcount, hbound, hstorage⟩
    have hcounter := counterStateRel_of_irCounterCount? hcount
    obtain ⟨modelNextIr, nextCount, modelObservable, hirModel, htargetStep,
      hcounterNext⟩ :=
        ProofForge.Backend.Refinement.CounterUniversal.counter_get_simulates
          hcounter
    change ProofForge.Backend.Refinement.CounterUniversal.irStep irState .get =
      .ok (nextIr, observable) at hirStep
    rw [hirModel] at hirStep
    cases hirStep
    cases htargetStep
    obtain ⟨nextEvm, hpowdrStep, hstorageNext⟩ :=
      post.get_returns_count hbound hstorage
    refine ⟨nextEvm, hpowdrStep, ?_⟩
    exact ⟨count, counterStateRel_irCounterCount? hcounterNext, hbound, hstorageNext⟩

def counterPowdrSafeEntrypointObligationsOfPreparedStorageModels
    (cfg : PowdrCounterConfig) (models : CounterPowdrPreparedStorageModels cfg) :
    CounterPowdrSafeEntrypointObligations cfg :=
  counterPowdrSafeEntrypointObligationsOfPostconditions cfg
    (counterPowdrEvmPostconditionsOfPrepared cfg
      (counterPowdrPreparedEvmPostconditionsOfStorageModels cfg models))

theorem counterPowdr_step_simulates_from_obligations
    (cfg : PowdrCounterConfig) (obligations : CounterPowdrEntrypointObligations cfg)
    (call : CounterCall) {irState : IRState} {evmState : EvmState}
    (hrel : CounterStorageRel irState evmState) :
    ∃ nextIr nextEvm observable,
      counterIRStep irState call = .ok (nextIr, observable) ∧
      counterPowdrTraceStep cfg evmState call = .ok (nextEvm, observable) ∧
      CounterStorageRel nextIr nextEvm := by
  obtain ⟨count, hcounter⟩ := counterStorageRel_left_counterStateRel hrel
  cases call
  · obtain ⟨nextIr, _nextCount, observable, hirStep, _htargetStep, _hcounterNext⟩ :=
      ProofForge.Backend.Refinement.CounterUniversal.counter_initialize_simulates
        irState count
    obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
      obligations.initialize_simulates hirStep
    exact ⟨nextIr, nextEvm, observable, hirStep, hpowdrStep, hrelNext⟩
  · obtain ⟨nextIr, _nextCount, observable, hirStep, _htargetStep, _hcounterNext⟩ :=
      ProofForge.Backend.Refinement.CounterUniversal.counter_increment_simulates
        hcounter
    obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
      obligations.increment_simulates hrel hirStep
    exact ⟨nextIr, nextEvm, observable, hirStep, hpowdrStep, hrelNext⟩
  · obtain ⟨nextIr, _nextCount, observable, hirStep, _htargetStep, _hcounterNext⟩ :=
      ProofForge.Backend.Refinement.CounterUniversal.counter_get_simulates
        hcounter
    obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
      obligations.get_simulates hrel hirStep
    exact ⟨nextIr, nextEvm, observable, hirStep, hpowdrStep, hrelNext⟩

theorem counterPowdr_safe_step_simulates_from_obligations
    (cfg : PowdrCounterConfig) (obligations : CounterPowdrSafeEntrypointObligations cfg)
    (call : CounterCall) {irState : IRState} {evmState : EvmState}
    (hrel : CounterStorageRel irState evmState)
    (hsafe : CounterStepSafe call irState) :
    ∃ nextIr nextEvm observable,
      counterIRStep irState call = .ok (nextIr, observable) ∧
      counterPowdrTraceStep cfg evmState call = .ok (nextEvm, observable) ∧
      CounterStorageRel nextIr nextEvm := by
  obtain ⟨count, hcounter⟩ := counterStorageRel_left_counterStateRel hrel
  cases call
  · obtain ⟨nextIr, _nextCount, observable, hirStep, _htargetStep, _hcounterNext⟩ :=
      ProofForge.Backend.Refinement.CounterUniversal.counter_initialize_simulates
        irState count
    obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
      obligations.initialize_simulates hirStep
    exact ⟨nextIr, nextEvm, observable, hirStep, hpowdrStep, hrelNext⟩
  · obtain ⟨nextIr, _nextCount, observable, hirStep, _htargetStep, _hcounterNext⟩ :=
      ProofForge.Backend.Refinement.CounterUniversal.counter_increment_simulates
        hcounter
    obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
      obligations.increment_simulates hrel hsafe hirStep
    exact ⟨nextIr, nextEvm, observable, hirStep, hpowdrStep, hrelNext⟩
  · obtain ⟨nextIr, _nextCount, observable, hirStep, _htargetStep, _hcounterNext⟩ :=
      ProofForge.Backend.Refinement.CounterUniversal.counter_get_simulates
        hcounter
    have hsafeGet : CounterStepSafe .get irState := by
      exact hsafe
    obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
      obligations.get_simulates hrel hsafeGet hirStep
    exact ⟨nextIr, nextEvm, observable, hirStep, hpowdrStep, hrelNext⟩

theorem counterPowdr_safe_trace_simulates_from_obligations
    (cfg : PowdrCounterConfig) (obligations : CounterPowdrSafeEntrypointObligations cfg)
    (calls : List CounterCall) {irState : IRState} {evmState : EvmState} {count : Nat}
    (hrel : CounterStorageRel irState evmState)
    (hcounter : ProofForge.Backend.Refinement.CounterUniversal.CounterStateRel
      irState count)
    (hsafe : counterTraceSafeFromCount count calls = true) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep calls irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen (counterPowdrTraceStep cfg) calls evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep irState calls observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep cfg) evmState calls observables := by
  induction calls generalizing irState evmState count with
  | nil =>
      refine ⟨irState, evmState, #[], rfl, rfl, hrel,
        ProofForge.IR.StepSemantics.IRTraceMatches.nil,
        ProofForge.IR.StepSemantics.IRTraceMatches.nil⟩
  | cons call rest ih =>
      cases call
      · have hsafeRest : counterTraceSafeFromCount 0 rest = true := by
          simpa [counterTraceSafeFromCount] using hsafe
        obtain ⟨nextIr, nextCount, observable, hirStep, htargetStep, hcounterNext⟩ :=
          ProofForge.Backend.Refinement.CounterUniversal.counter_initialize_simulates
            irState count
        cases htargetStep
        obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
          obligations.initialize_simulates hirStep
        obtain ⟨finalIr, finalEvm, restObservables, hirRest, hpowdrRest,
            hrelFinal, hirTraceRest, hpowdrTraceRest⟩ :=
          ih (irState := nextIr) (evmState := nextEvm) (count := 0)
            hrelNext hcounterNext hsafeRest
        refine ⟨finalIr, finalEvm, #[.none] ++ restObservables, ?_, ?_,
          hrelFinal,
          ProofForge.IR.StepSemantics.IRTraceMatches.cons hirStep hirTraceRest,
          ProofForge.IR.StepSemantics.IRTraceMatches.cons hpowdrStep hpowdrTraceRest⟩
        · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
            counterIRStep .initialize rest irState nextIr .none
            finalIr restObservables hirStep hirRest
        · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
            (counterPowdrTraceStep cfg) .initialize rest evmState nextEvm .none
            finalEvm restObservables hpowdrStep hpowdrRest
      · have hsafePair :
            (count + 1 < counterU64Modulus) ∧
              counterTraceSafeFromCount (count + 1) rest = true := by
          simpa [counterTraceSafeFromCount] using hsafe
        have hstepSafe : CounterStepSafe .increment irState := by
          intro count' hcount'
          have hread := counterStateRel_irCounterCount? hcounter
          rw [hread] at hcount'
          cases hcount'
          exact hsafePair.left
        obtain ⟨nextIr, nextCount, observable, hirStep, htargetStep, hcounterNext⟩ :=
          ProofForge.Backend.Refinement.CounterUniversal.counter_increment_simulates
            hcounter
        cases htargetStep
        obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
          obligations.increment_simulates hrel hstepSafe hirStep
        obtain ⟨finalIr, finalEvm, restObservables, hirRest, hpowdrRest,
            hrelFinal, hirTraceRest, hpowdrTraceRest⟩ :=
          ih (irState := nextIr) (evmState := nextEvm) (count := count + 1)
            hrelNext hcounterNext hsafePair.right
        refine ⟨finalIr, finalEvm, #[.none] ++ restObservables, ?_, ?_,
          hrelFinal,
          ProofForge.IR.StepSemantics.IRTraceMatches.cons hirStep hirTraceRest,
          ProofForge.IR.StepSemantics.IRTraceMatches.cons hpowdrStep hpowdrTraceRest⟩
        · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
            counterIRStep .increment rest irState nextIr .none
            finalIr restObservables hirStep hirRest
        · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
            (counterPowdrTraceStep cfg) .increment rest evmState nextEvm .none
            finalEvm restObservables hpowdrStep hpowdrRest
      · have hsafePair :
            (count < counterU64Modulus) ∧
              counterTraceSafeFromCount count rest = true := by
          simpa [counterTraceSafeFromCount] using hsafe
        have hstepSafe : CounterStepSafe .get irState := by
          intro count' hcount'
          have hread := counterStateRel_irCounterCount? hcounter
          rw [hread] at hcount'
          cases hcount'
          exact hsafePair.left
        obtain ⟨nextIr, nextCount, observable, hirStep, htargetStep, hcounterNext⟩ :=
          ProofForge.Backend.Refinement.CounterUniversal.counter_get_simulates
            hcounter
        cases htargetStep
        obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
          obligations.get_simulates hrel hstepSafe hirStep
        obtain ⟨finalIr, finalEvm, restObservables, hirRest, hpowdrRest,
            hrelFinal, hirTraceRest, hpowdrTraceRest⟩ :=
          ih (irState := nextIr) (evmState := nextEvm) (count := count)
            hrelNext hcounterNext hsafePair.right
        refine ⟨finalIr, finalEvm, #[.u64 count] ++ restObservables, ?_, ?_,
          hrelFinal,
          ProofForge.IR.StepSemantics.IRTraceMatches.cons hirStep hirTraceRest,
          ProofForge.IR.StepSemantics.IRTraceMatches.cons hpowdrStep hpowdrTraceRest⟩
        · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
            counterIRStep .get rest irState nextIr (.u64 count)
            finalIr restObservables hirStep hirRest
        · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
            (counterPowdrTraceStep cfg) .get rest evmState nextEvm (.u64 count)
            finalEvm restObservables hpowdrStep hpowdrRest

theorem counterPowdr_safe_trace_simulates_from_state_safe_obligations
    (cfg : PowdrCounterConfig) (obligations : CounterPowdrSafeEntrypointObligations cfg)
    (calls : List CounterCall) {irState : IRState} {evmState : EvmState}
    (hrel : CounterStorageRel irState evmState)
    (hsafe : CounterTraceSafeAtState irState calls) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep calls irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen (counterPowdrTraceStep cfg) calls evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep irState calls observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep cfg) evmState calls observables := by
  obtain ⟨count, hcounter⟩ := counterStorageRel_left_counterStateRel hrel
  exact counterPowdr_safe_trace_simulates_from_obligations
    cfg obligations calls hrel hcounter (hsafe count (counterStateRel_irCounterCount? hcounter))

theorem counterPowdr_trace_simulates_from_obligations
    (cfg : PowdrCounterConfig) (obligations : CounterPowdrEntrypointObligations cfg)
    (calls : List CounterCall) {irState : IRState} {evmState : EvmState}
    (hrel : CounterStorageRel irState evmState) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep calls irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen (counterPowdrTraceStep cfg) calls evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep irState calls observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep cfg) evmState calls observables :=
  ProofForge.Backend.Refinement.traceSimulation_lift
    counterIRStep (counterPowdrTraceStep cfg) CounterStorageRel
    (fun call {_irState} {_targetState} hrel =>
      counterPowdr_step_simulates_from_obligations cfg obligations call hrel)
    calls hrel

theorem counterPowdr_trace_simulates_after_initialize_from_obligations
    (cfg : PowdrCounterConfig) (obligations : CounterPowdrEntrypointObligations cfg)
    (calls : List CounterCall) (irState : IRState) (evmState : EvmState) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep
          (.initialize :: calls) irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen (counterPowdrTraceStep cfg)
          (.initialize :: calls) evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep
        irState (.initialize :: calls) observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep cfg) evmState (.initialize :: calls) observables := by
  obtain ⟨nextIr, _nextCount, observable, hirStep, htargetStep, _hcounterNext⟩ :=
    ProofForge.Backend.Refinement.CounterUniversal.counter_initialize_simulates
      irState 0
  cases htargetStep
  obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
    obligations.initialize_simulates hirStep
  obtain ⟨finalIr, finalEvm, restObservables, hirRest, hpowdrRest,
      hrelFinal, hirTraceRest, hpowdrTraceRest⟩ :=
    counterPowdr_trace_simulates_from_obligations
      cfg obligations calls hrelNext
  refine ⟨finalIr, finalEvm, #[.none] ++ restObservables, ?_, ?_,
    hrelFinal,
    ProofForge.IR.StepSemantics.IRTraceMatches.cons hirStep hirTraceRest,
    ProofForge.IR.StepSemantics.IRTraceMatches.cons hpowdrStep hpowdrTraceRest⟩
  · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
      counterIRStep .initialize calls irState nextIr .none
      finalIr restObservables hirStep hirRest
  · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
      (counterPowdrTraceStep cfg) .initialize calls evmState nextEvm .none
      finalEvm restObservables hpowdrStep hpowdrRest

theorem counterPowdr_safe_trace_simulates_after_initialize_from_obligations
    (cfg : PowdrCounterConfig) (obligations : CounterPowdrSafeEntrypointObligations cfg)
    (calls : List CounterCall) (irState : IRState) (evmState : EvmState)
    (hsafe : counterTraceSafeAfterInitialize calls = true) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep
          (.initialize :: calls) irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen (counterPowdrTraceStep cfg)
          (.initialize :: calls) evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep
        irState (.initialize :: calls) observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep cfg) evmState (.initialize :: calls) observables := by
  obtain ⟨nextIr, nextCount, observable, hirStep, htargetStep, hcounterNext⟩ :=
    ProofForge.Backend.Refinement.CounterUniversal.counter_initialize_simulates
      irState 0
  cases htargetStep
  have hsafeRest : counterTraceSafeFromCount 0 calls = true := by
    simpa [counterTraceSafeAfterInitialize] using hsafe
  obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
    obligations.initialize_simulates hirStep
  obtain ⟨finalIr, finalEvm, restObservables, hirRest, hpowdrRest,
      hrelFinal, hirTraceRest, hpowdrTraceRest⟩ :=
    counterPowdr_safe_trace_simulates_from_obligations
      cfg obligations calls hrelNext hcounterNext hsafeRest
  refine ⟨finalIr, finalEvm, #[.none] ++ restObservables, ?_, ?_,
    hrelFinal,
    ProofForge.IR.StepSemantics.IRTraceMatches.cons hirStep hirTraceRest,
    ProofForge.IR.StepSemantics.IRTraceMatches.cons hpowdrStep hpowdrTraceRest⟩
  · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
      counterIRStep .initialize calls irState nextIr .none
      finalIr restObservables hirStep hirRest
  · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
      (counterPowdrTraceStep cfg) .initialize calls evmState nextEvm .none
      finalEvm restObservables hpowdrStep hpowdrRest

abbrev CounterCompiledPowdrEntrypointObligations :=
  CounterPowdrEntrypointObligations counterCompiledPowdrConfig

abbrev CounterCompiledPowdrEvmPostconditions :=
  CounterPowdrEvmPostconditions counterCompiledPowdrConfig

abbrev CounterCompiledPowdrPreparedEvmPostconditions :=
  CounterPowdrPreparedEvmPostconditions counterCompiledPowdrConfig

abbrev CounterCompiledPowdrPreparedStorageModels :=
  CounterPowdrPreparedStorageModels counterCompiledPowdrConfig

def counterCompiledPowdrEvmPostconditionsOfPrepared
    (post : CounterCompiledPowdrPreparedEvmPostconditions) :
    CounterCompiledPowdrEvmPostconditions :=
  counterPowdrEvmPostconditionsOfPrepared counterCompiledPowdrConfig post

abbrev CounterCompiledPowdrSafeEntrypointObligations :=
  CounterPowdrSafeEntrypointObligations counterCompiledPowdrConfig

def counterCompiledPowdrSafeEntrypointObligationsOfPostconditions
    (post : CounterCompiledPowdrEvmPostconditions) :
    CounterCompiledPowdrSafeEntrypointObligations :=
  counterPowdrSafeEntrypointObligationsOfPostconditions
    counterCompiledPowdrConfig post

def counterCompiledPowdrPreparedEvmPostconditionsOfStorageModels
    (models : CounterCompiledPowdrPreparedStorageModels) :
    CounterCompiledPowdrPreparedEvmPostconditions :=
  counterPowdrPreparedEvmPostconditionsOfStorageModels counterCompiledPowdrConfig models

def counterCompiledPowdrSafeEntrypointObligationsOfPreparedStorageModels
    (models : CounterCompiledPowdrPreparedStorageModels) :
    CounterCompiledPowdrSafeEntrypointObligations :=
  counterPowdrSafeEntrypointObligationsOfPreparedStorageModels
    counterCompiledPowdrConfig models

theorem counterCompiledPowdr_trace_simulates_after_initialize_from_obligations
    (obligations : CounterCompiledPowdrEntrypointObligations)
    (calls : List CounterCall) (irState : IRState) (evmState : EvmState) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep
          (.initialize :: calls) irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen
          (counterPowdrTraceStep counterCompiledPowdrConfig)
          (.initialize :: calls) evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep
        irState (.initialize :: calls) observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep counterCompiledPowdrConfig)
        evmState (.initialize :: calls) observables :=
  counterPowdr_trace_simulates_after_initialize_from_obligations
    counterCompiledPowdrConfig obligations calls irState evmState

theorem counterCompiledPowdr_safe_trace_simulates_after_initialize_from_obligations
    (obligations : CounterCompiledPowdrSafeEntrypointObligations)
    (calls : List CounterCall) (irState : IRState) (evmState : EvmState)
    (hsafe : counterTraceSafeAfterInitialize calls = true) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep
          (.initialize :: calls) irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen
          (counterPowdrTraceStep counterCompiledPowdrConfig)
          (.initialize :: calls) evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep
        irState (.initialize :: calls) observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep counterCompiledPowdrConfig)
        evmState (.initialize :: calls) observables :=
  counterPowdr_safe_trace_simulates_after_initialize_from_obligations
    counterCompiledPowdrConfig obligations calls irState evmState hsafe

theorem counterCompiledPowdr_safe_trace_simulates_after_initialize_from_prepared_storage_models
    (models : CounterCompiledPowdrPreparedStorageModels)
    (calls : List CounterCall) (irState : IRState) (evmState : EvmState)
    (hsafe : counterTraceSafeAfterInitialize calls = true) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep
          (.initialize :: calls) irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen
          (counterPowdrTraceStep counterCompiledPowdrConfig)
          (.initialize :: calls) evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep
        irState (.initialize :: calls) observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep counterCompiledPowdrConfig)
        evmState (.initialize :: calls) observables :=
  counterCompiledPowdr_safe_trace_simulates_after_initialize_from_obligations
    (counterCompiledPowdrSafeEntrypointObligationsOfPreparedStorageModels models)
    calls irState evmState hsafe

theorem counterCompiledPowdr_safe_trace_simulates_from_state_safe_obligations
    (obligations : CounterCompiledPowdrSafeEntrypointObligations)
    (calls : List CounterCall) {irState : IRState} {evmState : EvmState}
    (hrel : CounterStorageRel irState evmState)
    (hsafe : CounterTraceSafeAtState irState calls) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep calls irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen
          (counterPowdrTraceStep counterCompiledPowdrConfig) calls evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep
        irState calls observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep counterCompiledPowdrConfig)
        evmState calls observables :=
  counterPowdr_safe_trace_simulates_from_state_safe_obligations
    counterCompiledPowdrConfig obligations calls hrel hsafe

theorem counterCompiledPowdr_safe_trace_simulates_from_state_safe_prepared_storage_models
    (models : CounterCompiledPowdrPreparedStorageModels)
    (calls : List CounterCall) {irState : IRState} {evmState : EvmState}
    (hrel : CounterStorageRel irState evmState)
    (hsafe : CounterTraceSafeAtState irState calls) :
    ∃ finalIr finalEvm observables,
      ProofForge.IR.StepSemantics.runTraceListGen counterIRStep calls irState =
        .ok (finalIr, observables) ∧
      ProofForge.IR.StepSemantics.runTraceListGen
          (counterPowdrTraceStep counterCompiledPowdrConfig) calls evmState =
        .ok (finalEvm, observables) ∧
      CounterStorageRel finalIr finalEvm ∧
      ProofForge.IR.StepSemantics.IRTraceMatches counterIRStep
        irState calls observables ∧
      ProofForge.IR.StepSemantics.IRTraceMatches
        (counterPowdrTraceStep counterCompiledPowdrConfig)
        evmState calls observables :=
  counterCompiledPowdr_safe_trace_simulates_from_state_safe_obligations
    (counterCompiledPowdrSafeEntrypointObligationsOfPreparedStorageModels models)
    calls hrel hsafe

end ProofForge.Backend.Evm.CounterRefinement
