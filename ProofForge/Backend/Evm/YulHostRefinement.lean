/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# IR ↔ EVM Yul-subset host paired simulation (Counter + ValueVault)

Portable-IR-first EVM lane companion to Solana's host refinement stack.
Uses in-tree `YulSemantics` (mathlib-free) and the shared
`executableSimulationTraceOk` substrate.

Observables are `ObservableReturn` (not full `ObservableStep`) so IR/Yul
selector metadata differences do not block lockstep — same pattern as
Solana `CounterCall` / `fullHostTraceStepCounterCall`.

```
Portable IR.Semantics
        │ paired-step (ObservableReturn)
        ▼
EvmYulMachineState + YulSemantics
```

Product path (Yul → solc) and opt-in powdr bytecode lane are unchanged.
-/

import ProofForge.Backend.Evm.IR
import ProofForge.Backend.Evm.Refinement
import ProofForge.Backend.Evm.YulSemantics
import ProofForge.Backend.Refinement.Core
import ProofForge.Backend.Refinement.CounterUniversal
import ProofForge.IR.Examples.Counter
import ProofForge.IR.StepSemantics

namespace ProofForge.Backend.Evm.YulHostRefinement

open ProofForge.IR
open ProofForge.Backend.Refinement
  (executableSimulationTraceOk executableSimulationTraceOk_sound
    executableStepSimulationOk TraceCall ObservableReturn)
open ProofForge.Backend.Refinement.CounterUniversal
open ProofForge.Backend.Evm.Refinement

/-- High-64 packing of `U64` into a 256-bit storage word. -/
def counterU64StorageShift : Nat := 2 ^ 192

def countFromStorageWord (word : Nat) : Nat :=
  word / counterU64StorageShift

/-- Extract a packed unsigned integer from a 256-bit EVM storage word.
`byteOffset` and `byteWidth` follow the layout produced by
`ProofForge.Backend.Evm.Plan.storageLayout` and the packing used by
`scalarStoragePackedReadExpr`. -/
def packedU64FromWord (word : Nat) (byteOffset byteWidth : Nat) : Nat :=
  let shiftBits := (32 - (byteOffset + byteWidth)) * 8
  (word / 2 ^ shiftBits) % 2 ^ (byteWidth * 8)

/-- IR `count` ↔ Yul storage slot 0 high-64 bits. -/
def counterYulSimulationRel
    (irState : ProofForge.IR.Semantics.State)
    (machine : EvmYulMachineState) : Bool :=
  let word := ProofForge.Backend.Evm.YulSemantics.lookupWord 0 machine.storage
  match irState.read "count" with
  | some (.u64 c) => countFromStorageWord word == c
  | none => word == 0
  | _ => false

def counterYulInitial (object : Lean.Compiler.Yul.Object) : EvmYulMachineState :=
  { object, storage := [] }

/-- IR step projecting only `ObservableReturn` (shared with Solana CounterCall). -/
def irReturnStep (state : ProofForge.IR.Semantics.State) (call : TraceCall) :
    Except String (ProofForge.IR.Semantics.State × ObservableReturn) := do
  let (next, step) ←
    ProofForge.Backend.Refinement.runEntrypointObservable state call
  .ok (next, step.returnValue)

/-- Yul step projecting only `ObservableReturn`. -/
def yulReturnStep (state : EvmYulMachineState) (call : TraceCall) :
    Except String (EvmYulMachineState × ObservableReturn) := do
  let (next, step) ← EvmYulMachineState.traceStep state call
  .ok (next, step.returnValue)

def counterTraceCallList : List TraceCall := counterTraceCalls.toList

def counterYulTraceSimulationOk : Bool :=
  match ProofForge.Backend.Evm.IR.lowerModule ProofForge.IR.Examples.Counter.module with
  | .error _ => false
  | .ok object =>
      executableSimulationTraceOk
        irReturnStep
        yulReturnStep
        counterYulSimulationRel
        counterTraceCallList
        ProofForge.IR.Semantics.State.empty
        (counterYulInitial object)

theorem counter_yul_trace_simulation_ok :
    counterYulTraceSimulationOk = true := by
  native_decide

theorem counter_yul_trace_simulation_sound_checked :
    match ProofForge.Backend.Evm.IR.lowerModule ProofForge.IR.Examples.Counter.module with
    | .error _ => True
    | .ok object =>
        ∃ finalIr finalTarget observables,
          ProofForge.IR.StepSemantics.runTraceListGen
            irReturnStep
            counterTraceCallList
            ProofForge.IR.Semantics.State.empty =
              .ok (finalIr, observables) ∧
          ProofForge.IR.StepSemantics.runTraceListGen
            yulReturnStep
            counterTraceCallList
            (counterYulInitial object) =
              .ok (finalTarget, observables) ∧
          counterYulSimulationRel finalIr finalTarget = true := by
  have h := counter_yul_trace_simulation_ok
  unfold counterYulTraceSimulationOk at h
  cases hmod : ProofForge.Backend.Evm.IR.lowerModule
      ProofForge.IR.Examples.Counter.module with
  | error _ => trivial
  | ok object =>
      simp [hmod] at h
      exact executableSimulationTraceOk_sound
        irReturnStep
        yulReturnStep
        counterYulSimulationRel
        counterTraceCallList
        ProofForge.IR.Semantics.State.empty
        (counterYulInitial object)
        h

/-! ### CounterCall vocabulary -/

def counterCallToTraceCall : CounterCall → TraceCall
  | .initialize => { entrypoint := ProofForge.IR.Examples.Counter.initializeEntrypoint }
  | .increment => { entrypoint := ProofForge.IR.Examples.Counter.increment }
  | .get => { entrypoint := ProofForge.IR.Examples.Counter.get }

def yulTraceStepCounterCall (state : EvmYulMachineState) (call : CounterCall) :
    Except String (EvmYulMachineState × ObservableReturn) :=
  yulReturnStep state (counterCallToTraceCall call)

def counterYulCounterCallTraceOk : Bool :=
  match ProofForge.Backend.Evm.IR.lowerModule ProofForge.IR.Examples.Counter.module with
  | .error _ => false
  | .ok object =>
      executableSimulationTraceOk
        irStep
        yulTraceStepCounterCall
        (fun irState machine => counterYulSimulationRel irState machine)
        [.initialize, .get, .increment, .get]
        ProofForge.IR.Semantics.State.empty
        (counterYulInitial object)

theorem counter_yul_counter_call_trace_ok :
    counterYulCounterCallTraceOk = true := by
  native_decide

theorem counter_yul_counter_call_trace_sound_checked :
    match ProofForge.Backend.Evm.IR.lowerModule ProofForge.IR.Examples.Counter.module with
    | .error _ => True
    | .ok object =>
        ∃ finalIr finalTarget observables,
          ProofForge.IR.StepSemantics.runTraceListGen
            irStep
            [.initialize, .get, .increment, .get]
            ProofForge.IR.Semantics.State.empty =
              .ok (finalIr, observables) ∧
          ProofForge.IR.StepSemantics.runTraceListGen
            yulTraceStepCounterCall
            [.initialize, .get, .increment, .get]
            (counterYulInitial object) =
              .ok (finalTarget, observables) ∧
          counterYulSimulationRel finalIr finalTarget = true := by
  have h := counter_yul_counter_call_trace_ok
  unfold counterYulCounterCallTraceOk at h
  cases hmod : ProofForge.Backend.Evm.IR.lowerModule
      ProofForge.IR.Examples.Counter.module with
  | error _ => trivial
  | ok object =>
      simp [hmod] at h
      exact executableSimulationTraceOk_sound
        irStep
        yulTraceStepCounterCall
        (fun irState machine => counterYulSimulationRel irState machine)
        [.initialize, .get, .increment, .get]
        ProofForge.IR.Semantics.State.empty
        (counterYulInitial object)
        h

/-! ### ValueVault: return-value lockstep + multi-field storage relation -/

def valueVaultYulInitial (object : Lean.Compiler.Yul.Object) : EvmYulMachineState :=
  { object, storage := [] }

def valueVaultYulSimulationRel
    (irState : ProofForge.IR.Semantics.State)
    (machine : EvmYulMachineState) : Bool :=
  let word0 := ProofForge.Backend.Evm.YulSemantics.lookupWord 0 machine.storage
  let word1 := ProofForge.Backend.Evm.YulSemantics.lookupWord 1 machine.storage
  let fieldOk name slotWord byteOffset byteWidth : Bool :=
    match irState.read name with
    | some (.u64 c) => packedU64FromWord slotWord byteOffset byteWidth == c
    | none => packedU64FromWord slotWord byteOffset byteWidth == 0
    | _ => false
  fieldOk "balance" word0 0 8 &&
  fieldOk "released" word0 8 8 &&
  fieldOk "fees" word0 16 8 &&
  fieldOk "last_value" word0 24 8 &&
  fieldOk "last_checkpoint" word1 0 8 &&
  fieldOk "operations" word1 8 8

def valueVaultYulTraceOk : Bool :=
  match ProofForge.Backend.Evm.IR.lowerModule valueVaultEvmModule with
  | .error _ => false
  | .ok object =>
      executableSimulationTraceOk
        irReturnStep
        yulReturnStep
        valueVaultYulSimulationRel
        valueVaultTraceObligation.calls.toList
        ProofForge.IR.Semantics.State.empty
        (valueVaultYulInitial object)

theorem value_vault_yul_trace_simulation_ok :
    valueVaultYulTraceOk = true := by
  native_decide

theorem value_vault_yul_trace_simulation_sound_checked :
    match ProofForge.Backend.Evm.IR.lowerModule valueVaultEvmModule with
    | .error _ => True
    | .ok object =>
        ∃ finalIr finalTarget observables,
          ProofForge.IR.StepSemantics.runTraceListGen
            irReturnStep
            valueVaultTraceObligation.calls.toList
            ProofForge.IR.Semantics.State.empty =
              .ok (finalIr, observables) ∧
          ProofForge.IR.StepSemantics.runTraceListGen
            yulReturnStep
            valueVaultTraceObligation.calls.toList
            (valueVaultYulInitial object) =
              .ok (finalTarget, observables) ∧
          valueVaultYulSimulationRel finalIr finalTarget = true := by
  have h := value_vault_yul_trace_simulation_ok
  unfold valueVaultYulTraceOk at h
  cases hmod : ProofForge.Backend.Evm.IR.lowerModule valueVaultEvmModule with
  | error _ => trivial
  | ok object =>
      simp [hmod] at h
      exact executableSimulationTraceOk_sound
        irReturnStep
        yulReturnStep
        valueVaultYulSimulationRel
        valueVaultTraceObligation.calls.toList
        ProofForge.IR.Semantics.State.empty
        (valueVaultYulInitial object)
        h

/-! ### Executable-trace anchors still hold -/

theorem value_vault_yul_executable_still_ok :
    evmYulTraceOk valueVaultTraceObligation = true := by
  native_decide

theorem counter_yul_executable_still_ok :
    evmYulTraceOk counterTraceObligation = true := by
  native_decide

end ProofForge.Backend.Evm.YulHostRefinement
