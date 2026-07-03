import ProofForge.IR.Contract
import ProofForge.IR.Examples.Counter

namespace ProofForge.IR.Semantics

open ProofForge.IR

local instance instDecidableEqExcept {ε α : Type} [DecidableEq ε] [DecidableEq α] :
    DecidableEq (Except ε α) := by
  intro lhs rhs
  cases lhs with
  | error lhsError =>
      cases rhs with
      | error rhsError =>
          cases decEq lhsError rhsError with
          | isTrue equal =>
              exact isTrue (by cases equal; rfl)
          | isFalse notEqual =>
              exact isFalse (by intro equal; cases equal; exact notEqual rfl)
      | ok _ =>
          exact isFalse (by intro equal; cases equal)
  | ok lhsValue =>
      cases rhs with
      | error _ =>
          exact isFalse (by intro equal; cases equal)
      | ok rhsValue =>
          cases decEq lhsValue rhsValue with
          | isTrue equal =>
              exact isTrue (by cases equal; rfl)
          | isFalse notEqual =>
              exact isFalse (by intro equal; cases equal; exact notEqual rfl)

/-! A small executable semantics for the scalar IR subset.

This is the first formal anchor for proving the NEAR Wasm path: proofs can
state the intended IR behavior here, while later refinement lemmas relate
EmitWat output to these traces.
-/

inductive Value where
  | unit
  | bool (value : Bool)
  | u32 (value : Nat)
  | u64 (value : Nat)
  | hash (a b c d : Nat)
  deriving Repr, BEq, DecidableEq

abbrev Bindings := List (String × Value)

def lookup (name : String) : Bindings → Option Value
  | [] => none
  | (key, value) :: rest =>
      if key == name then
        some value
      else
        lookup name rest

def insert (name : String) (value : Value) : Bindings → Bindings
  | [] => [(name, value)]
  | (key, oldValue) :: rest =>
      if key == name then
        (key, value) :: rest
      else
        (key, oldValue) :: insert name value rest

structure State where
  storage : Bindings := []
  deriving Repr, BEq, DecidableEq

structure Frame where
  locals : Bindings := []
  deriving Repr, BEq, DecidableEq

def State.empty : State := {}

def Frame.empty : Frame := {}

def State.read (state : State) (name : String) : Option Value :=
  lookup name state.storage

def State.write (state : State) (name : String) (value : Value) : State :=
  { state with storage := insert name value state.storage }

def Frame.read (frame : Frame) (name : String) : Option Value :=
  lookup name frame.locals

def Frame.write (frame : Frame) (name : String) (value : Value) : Frame :=
  { frame with locals := insert name value frame.locals }

def literalValue : Literal → Except String Value
  | .u32 value => .ok (.u32 value)
  | .u64 value => .ok (.u64 value)
  | .bool value => .ok (.bool value)
  | .hash4 a b c d => .ok (.hash a b c d)

def valueMatchesType : ValueType → Value → Bool
  | .unit, .unit => true
  | .bool, .bool _ => true
  | .u32, .u32 _ => true
  | .u64, .u64 _ => true
  | .hash, .hash _ _ _ _ => true
  | .fixedArray _ _, _ => false
  | .structType _, _ => false
  | _, _ => false

def bindParams (params : Array (String × ValueType)) (args : Array Value) :
    Except String Frame := do
  if params.size != args.size then
    .error s!"entrypoint expected {params.size} argument(s), got {args.size}"
  let mut frame := Frame.empty
  for h : idx in [0:params.size] do
    let param := params[idx]
    let some arg := args[idx]?
      | .error s!"missing entrypoint argument {idx}"
    if valueMatchesType param.snd arg then
      frame := frame.write param.fst arg
    else
      .error s!"entrypoint argument `{param.fst}` does not match `{param.snd.name}`"
  .ok frame

def evalEffect (state : State) (_frame : Frame) : Effect → Except String Value
  | .storageScalarRead name =>
      match state.read name with
      | some value => .ok value
      | none => .error s!"unknown scalar state `{name}`"
  | .contextRead .checkpointId =>
      .ok (.u64 0)
  | .contextRead field =>
      .error s!"context field `{field.name}` is not supported by the scalar semantics model"
  | _ => .error "effect is not supported by the scalar semantics model"

def evalNumericBinary (opName : String) (op : Nat → Nat → Nat) (lhs rhs : Value) :
    Except String Value :=
  match lhs, rhs with
  | .u64 lhsValue, .u64 rhsValue => .ok (.u64 (op lhsValue rhsValue))
  | .u32 lhsValue, .u32 rhsValue => .ok (.u32 (op lhsValue rhsValue))
  | _, _ => .error s!"{opName} expects matching numeric operands"

def evalExpr (state : State) (frame : Frame) : Expr → Except String Value
  | .literal literal => literalValue literal
  | .local name =>
      match frame.read name with
      | some value => .ok value
      | none => .error s!"unknown local `{name}`"
  | .add lhs rhs => do
      evalNumericBinary "add" (· + ·) (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .sub lhs rhs => do
      evalNumericBinary "sub" (· - ·) (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .mul lhs rhs => do
      evalNumericBinary "mul" (· * ·) (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .div lhs rhs => do
      evalNumericBinary "div" (fun lhs rhs => if rhs == 0 then 0 else lhs / rhs)
        (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .mod lhs rhs => do
      evalNumericBinary "mod" (fun lhs rhs => if rhs == 0 then 0 else lhs % rhs)
        (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .effect effect => evalEffect state frame effect
  | _ => .error "expression is not supported by the scalar semantics model"

def evalEventFields (state : State) (frame : Frame) (fields : Array (String × Expr)) :
    Except String Unit := do
  for field in fields do
    let _ ← evalExpr state frame field.snd
  pure ()

def execEffectStmt (state : State) (frame : Frame) : Effect → Except String State
  | .storageScalarWrite name value => do
      .ok (state.write name (← evalExpr state frame value))
  | .eventEmit _ fields => do
      evalEventFields state frame fields
      .ok state
  | .eventEmitIndexed _ indexedFields dataFields => do
      evalEventFields state frame indexedFields
      evalEventFields state frame dataFields
      .ok state
  | _ => .error "statement effect is not supported by the scalar semantics model"

def execStmt (state : State) (frame : Frame) : Statement →
    Except String (State × Frame × Option Value)
  | .letBind name _ value => do
      let evaluated ← evalExpr state frame value
      .ok (state, frame.write name evaluated, none)
  | .letMutBind name _ value => do
      let evaluated ← evalExpr state frame value
      .ok (state, frame.write name evaluated, none)
  | .effect effect => do
      .ok (← execEffectStmt state frame effect, frame, none)
  | .return value => do
      .ok (state, frame, some (← evalExpr state frame value))
  | _ => .error "statement is not supported by the scalar semantics model"

def execStatements : List Statement → State → Frame → Except String (State × Option Value)
  | [], state, _frame => .ok (state, none)
  | statement :: rest, state, frame => do
      let (nextState, nextFrame, returnValue?) ← execStmt state frame statement
      match returnValue? with
      | some returnValue => .ok (nextState, some returnValue)
      | none => execStatements rest nextState nextFrame

def runEntrypointWithArgs (state : State) (entrypoint : Entrypoint) (args : Array Value) :
    Except String (State × Option Value) := do
  let frame ← bindParams entrypoint.params args
  execStatements entrypoint.body.toList state frame

def runEntrypoint (state : State) (entrypoint : Entrypoint) :
    Except String (State × Option Value) :=
  runEntrypointWithArgs state entrypoint #[]

def counterTrace : Except String (State × Option Value) := do
  let (initialized, _) ←
    runEntrypoint State.empty ProofForge.IR.Examples.Counter.initializeEntrypoint
  let (incremented, _) ←
    runEntrypoint initialized ProofForge.IR.Examples.Counter.increment
  runEntrypoint incremented ProofForge.IR.Examples.Counter.get

theorem counter_trace_gets_one :
    counterTrace =
      .ok ({ storage := [("count", .u64 1)] }, some (.u64 1)) := by
  native_decide

theorem counter_exports_match_near_entrypoints :
    ProofForge.IR.Examples.Counter.module.entrypoints.map (fun entrypoint => entrypoint.name) =
      #["initialize", "increment", "get"] := by
  native_decide

end ProofForge.IR.Semantics
