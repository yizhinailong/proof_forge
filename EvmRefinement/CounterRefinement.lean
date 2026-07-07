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

@[simp] theorem counterStorageValue_setCounterStorage_same
    (address : EvmSemantics.AccountAddress) (slot : EvmSemantics.UInt256)
    (state : EvmState) (value : Nat) :
    counterStorageValue address slot (setCounterStorage address slot state value) =
      counterPackedCountValue value := by
  simp [counterStorageValue, counterAccount, setCounterStorage]

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
    counterStorageValue address slot evmState = counterPackedCountValue count

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
  simp

theorem counterStorageRel_set_count (irState : IRState) (evmState : EvmState)
    (count : Nat) (hbound : count < counterU64Modulus) :
    CounterStorageRel
      (irState.write "count" (.u64 count))
      (setCounterStorage counterContractAddress counterCountSlot evmState count) :=
  counterStorageRelAt_set_count counterContractAddress counterCountSlot irState evmState count hbound

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

def counterPowdrTraceStep (cfg : PowdrCounterConfig) (state : EvmState)
    (call : CounterCall) : Except String (EvmState × ObservableReturn) := do
  let (finalState, _observations) ←
    ProofForge.Backend.Evm.PowdrAdapter.runBytecode
      (prepareCounterCall cfg.runtimeCode call state) cfg.fuel
  let observable ← counterObservableFromResult call finalState.toResult
  .ok (finalState, observable)

theorem counterPowdrTraceStep_steps {cfg : PowdrCounterConfig}
    {state finalState : EvmState} {call : CounterCall}
    {obs : ObservableReturn}
    (h : counterPowdrTraceStep cfg state call = .ok (finalState, obs)) :
    EvmSemantics.EVM.Steps
      (prepareCounterCall cfg.runtimeCode call state) finalState := by
  unfold counterPowdrTraceStep at h
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

theorem counterCompiledPowdr_increment_packed_seven_executable_smoke :
    counterPowdrTraceReturns counterCompiledPowdrConfig
      [.increment, .get]
      (setCounterStorage counterContractAddress counterCountSlot counterBaseEvmState 7)
      #[.none, .u64 8] = true := by
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
  obtain ⟨nextIr, _nextCount, observable, hirStep, _htargetStep, _hcounterNext⟩ :=
    ProofForge.Backend.Refinement.CounterUniversal.counter_initialize_simulates
      irState 0
  obtain ⟨nextEvm, hpowdrStep, hrelNext⟩ :=
    obligations.initialize_simulates hirStep
  obtain ⟨finalIr, finalEvm, restObservables, hirRest, hpowdrRest,
      hrelFinal, hirTraceRest, hpowdrTraceRest⟩ :=
    counterPowdr_trace_simulates_from_obligations
      cfg obligations calls hrelNext
  refine ⟨finalIr, finalEvm, #[observable] ++ restObservables, ?_, ?_,
    hrelFinal,
    ProofForge.IR.StepSemantics.IRTraceMatches.cons hirStep hirTraceRest,
    ProofForge.IR.StepSemantics.IRTraceMatches.cons hpowdrStep hpowdrTraceRest⟩
  · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
      counterIRStep .initialize calls irState nextIr observable
      finalIr restObservables hirStep hirRest
  · exact ProofForge.IR.StepSemantics.runTraceListGen_cons_ok
      (counterPowdrTraceStep cfg) .initialize calls evmState nextEvm observable
      finalEvm restObservables hpowdrStep hpowdrRest

abbrev CounterCompiledPowdrEntrypointObligations :=
  CounterPowdrEntrypointObligations counterCompiledPowdrConfig

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

end ProofForge.Backend.Evm.CounterRefinement
