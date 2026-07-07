import ProofForge.IR.Contract
import ProofForge.IR.Semantics

namespace ProofForge.Backend.Refinement

open ProofForge.IR

/-! Shared refinement surfaces for target executable trace checks.

Backend-specific refinement modules fill these shared observable types from
their own artifact semantics.  The default IR runner below is intentionally
small: it covers pure IR observable returns without target-specific selector,
event-log, or host-state interpretation.
-/

inductive ObservableReturn where
  | none
  | bool (value : Bool)
  | u8 (value : Nat)
  | u32 (value : Nat)
  | u64 (value : Nat)
  | u128 (value : Nat)
  | hash (a b c d : Nat)
  | words (values : Array Nat)
  | reverted (message : String)
  deriving Repr, BEq, DecidableEq

structure ObservableEventLog where
  eventName : String
  topics : Array Nat := #[]
  dataWords : Array Nat := #[]
  deriving Repr, BEq, DecidableEq

structure ObservableStep where
  entrypointName : String
  selector : String := ""
  returnValue : ObservableReturn
  logs : Array ObservableEventLog := #[]
  deriving Repr, BEq, DecidableEq

structure TraceCall where
  entrypoint : Entrypoint
  args : Array ProofForge.IR.Semantics.Value := #[]
  evmArgs : Array Nat := #[]
  deriving Repr

structure TraceObligation where
  name : String
  module : Module
  calls : Array TraceCall
  expected : Array ObservableStep
  deriving Repr

def traceCallsFromEntrypoints (entrypoints : Array Entrypoint) : Array TraceCall :=
  entrypoints.map (fun entrypoint => { entrypoint })

def TraceObligation.entrypoints (obligation : TraceObligation) : Array Entrypoint :=
  obligation.calls.map (fun call => call.entrypoint)

partial def observableWordsFromValue (value : ProofForge.IR.Semantics.Value) :
    Except String (Array Nat) :=
  match value with
  | .unit => .ok #[]
  | .bool value => .ok #[if value then 1 else 0]
  | .u8 value => .ok #[value]
  | .u32 value => .ok #[value]
  | .u64 value => .ok #[value]
  | .u128 value => .ok #[value]
  | .address value => .ok #[value]
  | .bytes values => do
      let wordCount := (values.length + 31) / 32
      let mut words := #[values.length]
      for _h : _idx in [0:wordCount] do
        words := words.push 0
      .ok words
  | .string value => do
      let bytes := value.toUTF8
      let wordCount := (bytes.size + 31) / 32
      let mut words := #[bytes.size]
      for _h : _idx in [0:wordCount] do
        words := words.push 0
      .ok words
  | .hash a b c d =>
      .ok #[a, b, c, d]
  | .array values => do
      let mut words := #[]
      for value in values do
        words := words ++ (← observableWordsFromValue value)
      .ok words
  | .struct _ fields => do
      let mut words := #[]
      for field in fields do
        words := words ++ (← observableWordsFromValue field.snd)
      .ok words

def observableReturn (expectedType : ValueType) (value? : Option ProofForge.IR.Semantics.Value) :
    Except String ObservableReturn :=
  match expectedType, value? with
  | .unit, none => .ok .none
  | .unit, some .unit => .ok .none
  | .bool, some (.bool value) => .ok (.bool value)
  | .u8, some (.u8 value) => .ok (.u8 value)
  | .u32, some (.u32 value) => .ok (.u32 value)
  | .u64, some (.u64 value) => .ok (.u64 value)
  | .u128, some (.u128 value) => .ok (.u128 value)
  | .hash, some (.hash a b c d) => .ok (.hash a b c d)
  | .address, some (.address value) => .ok (.u64 value)
  | .bytes, some (.bytes _) | .string, some (.string _) => .ok .none
  | .fixedArray _ _, some value => do
      .ok (.words (← observableWordsFromValue value))
  | .structType _, some value => do
      .ok (.words (← observableWordsFromValue value))
  | _, none => .error s!"entrypoint expected `{expectedType.name}` but returned no value"
  | _, some _ => .error s!"entrypoint returned a value that does not match `{expectedType.name}`"

def runEntrypointObservable (state : ProofForge.IR.Semantics.State) (call : TraceCall) :
    Except String (ProofForge.IR.Semantics.State × ObservableStep) := do
  let entrypoint := call.entrypoint
  match ProofForge.IR.Semantics.runEntrypointWithArgsResult state entrypoint call.args with
  | .ok (nextState, result?) =>
      let returnValue ← observableReturn entrypoint.returns result?
      .ok (nextState, {
        entrypointName := entrypoint.name
        returnValue
      })
  | .reverted message =>
      .ok (state, {
        entrypointName := entrypoint.name
        returnValue := .reverted message
      })
  | .error message =>
      .error message

def runTraceList : List TraceCall → ProofForge.IR.Semantics.State →
    Except String (ProofForge.IR.Semantics.State × Array ObservableStep)
  | [], state => .ok (state, #[])
  | call :: rest, state => do
      let (nextState, step) ← runEntrypointObservable state call
      let (finalState, steps) ← runTraceList rest nextState
      .ok (finalState, #[step] ++ steps)

def runTrace (calls : Array TraceCall) : Except String (Array ObservableStep) := do
  let (_, steps) ← runTraceList calls.toList ProofForge.IR.Semantics.State.empty
  .ok steps

def TraceObligation.irTraceOk (obligation : TraceObligation) : Bool :=
  match runTrace obligation.calls with
  | .ok actual => actual == obligation.expected
  | .error _ => false

inductive FormalFragment where
  | counter
  deriving Repr, BEq, DecidableEq

def FormalFragment.id : FormalFragment → String
  | .counter => "counter"

def noArgFunctionReturning (entrypoint : Entrypoint) (name : String)
    (returns : ValueType) : Bool :=
  entrypoint.name == name &&
    entrypoint.kind == .function &&
    entrypoint.params.size == 0 &&
    entrypoint.returns == returns

def isCounterStateDecl (decl : StateDecl) : Bool :=
  decl.id == "count" &&
    decl.kind == .scalar &&
    decl.type == .u64

def isCounterInitializeEntrypoint (entrypoint : Entrypoint) : Bool :=
  noArgFunctionReturning entrypoint "initialize" .unit &&
    entrypoint.selector? == some "8129fc1c" &&
    match entrypoint.body.toList with
    | [.effect (.storageScalarWrite stateId (.literal (.u64 0)))] =>
        stateId == "count"
    | _ => false

def isCounterIncrementEntrypoint (entrypoint : Entrypoint) : Bool :=
  noArgFunctionReturning entrypoint "increment" .unit &&
    entrypoint.selector? == some "d09de08a" &&
    match entrypoint.body.toList with
    | [
        .letBind localName localType (.effect (.storageScalarRead readStateId)),
        .effect (.storageScalarWrite writeStateId
          (.add (.local addLocalName) (.literal (.u64 1))))
      ] =>
        localName == "n" &&
          localType == .u64 &&
          readStateId == "count" &&
          writeStateId == "count" &&
          addLocalName == "n"
    | _ => false

def isCounterGetEntrypoint (entrypoint : Entrypoint) : Bool :=
  noArgFunctionReturning entrypoint "get" .u64 &&
    entrypoint.selector? == some "6d4ce63c" &&
    match entrypoint.body.toList with
    | [.return (.effect (.storageScalarRead stateId))] =>
        stateId == "count"
    | _ => false

def isCounterModule (module : Module) : Bool :=
  module.name == "Counter" &&
    module.structs.size == 0 &&
    module.evmProxyPattern?.isNone &&
    module.nearCrosscallStrings.size == 0 &&
    !module.overflowChecked &&
    match module.state.toList, module.entrypoints.toList with
    | stateDecl :: [], entry0 :: entry1 :: entry2 :: [] =>
        isCounterStateDecl stateDecl &&
          isCounterInitializeEntrypoint entry0 &&
          isCounterIncrementEntrypoint entry1 &&
          isCounterGetEntrypoint entry2
    | _, _ => false

def FormalFragment.acceptsModule : FormalFragment → Module → Bool
  | .counter, module => isCounterModule module

structure TargetSemantics where
  id : String := "anonymous-target-semantics"
  supportedFragments : Array FormalFragment := #[]
  MachineState : Type
  step : MachineState → Except String MachineState
  run : Nat → MachineState → Except String MachineState
  observe : MachineState → ObservableReturn
  executableTraceOk : TraceObligation → Bool

def TargetSemantics.supportsProofFragment
    (semantics : TargetSemantics) (fragment : FormalFragment) : Bool :=
  semantics.supportedFragments.any (fun supported => supported == fragment)

def TargetSemantics.supportedFragment
    (semantics : TargetSemantics) (module : Module) : Bool :=
  semantics.supportedFragments.any (fun fragment => fragment.acceptsModule module)

def TargetSemantics.requireSupportedFragment
    (semantics : TargetSemantics) (module : Module) : Except String Module :=
  if semantics.supportedFragment module then
    .ok module
  else
    .error s!"target semantics `{semantics.id}` does not support module `{module.name}` in its proved fragment"

end ProofForge.Backend.Refinement
