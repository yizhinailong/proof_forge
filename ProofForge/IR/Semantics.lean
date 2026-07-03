import ProofForge.IR.Contract
import ProofForge.IR.Examples.ArrayProbe
import ProofForge.IR.Examples.Counter
import ProofForge.IR.Examples.EvmAbiAggregateProbe
import ProofForge.IR.Examples.EvmMapProbe
import ProofForge.IR.Examples.EvmStorageStructProbe

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
  | array (values : List Value)
  | struct (typeName : String) (fields : List (String × Value))
  deriving Repr, BEq

def maxU32 : Nat := 4294967295

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

def listGet? {α : Type} : List α → Nat → Option α
  | [], _ => none
  | value :: _, 0 => some value
  | _ :: rest, index + 1 => listGet? rest index

structure State where
  storage : Bindings := []
  deriving Repr, BEq

structure Frame where
  locals : Bindings := []
  deriving Repr, BEq

def State.empty : State := {}

def Frame.empty : Frame := {}

def State.read (state : State) (name : String) : Option Value :=
  lookup name state.storage

def State.write (state : State) (name : String) (value : Value) : State :=
  { state with storage := insert name value state.storage }

def fieldKey (base fieldName : String) : String :=
  s!"{base}.{fieldName}"

def arrayKey (base : String) (index : Nat) : String :=
  s!"{base}[{index}]"

def arrayFieldKey (base : String) (index : Nat) (fieldName : String) : String :=
  s!"{arrayKey base index}.{fieldName}"

def mapKey (base key : String) : String :=
  base ++ "{" ++ key ++ "}"

def mapPresentKey (base key : String) : String :=
  s!"{mapKey base key}.present"

def State.readStructField (state : State) (stateId fieldName : String) : Option Value :=
  match state.read (fieldKey stateId fieldName) with
  | some value => some value
  | none =>
      match state.read stateId with
      | some (.struct _ fields) => lookup fieldName fields
      | _ => none

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
  | .fixedArray element length, .array values =>
      values.length == length && values.all (valueMatchesType element)
  | .structType expected, .struct actual _ => expected == actual
  | _, _ => false

partial def zeroLike : Value → Value
  | .unit => .unit
  | .bool _ => .bool false
  | .u32 _ => .u32 0
  | .u64 _ => .u64 0
  | .hash _ _ _ _ => .hash 0 0 0 0
  | .array values => .array (values.map zeroLike)
  | .struct typeName fields => .struct typeName (fields.map fun field => (field.fst, zeroLike field.snd))

partial def valueKey : Value → String
  | .unit => "unit"
  | .bool value => if value then "true" else "false"
  | .u32 value => s!"u32:{value}"
  | .u64 value => s!"u64:{value}"
  | .hash a b c d => s!"hash:{a}:{b}:{c}:{d}"
  | .array values =>
      "[" ++ String.intercalate "," (values.map valueKey) ++ "]"
  | .struct typeName fields =>
      let rendered :=
        fields.map fun field => s!"{field.fst}={valueKey field.snd}"
      typeName ++ "{" ++ String.intercalate "," rendered ++ "}"

def indexValue : Value → Except String Nat
  | .u32 value => .ok value
  | .u64 value => .ok value
  | _ => .error "array/storage index expects U32 or U64"

def arrayGetValue (value : Value) (index : Nat) : Except String Value :=
  match value with
  | .array values =>
      match listGet? values index with
      | some value => .ok value
      | none => .error s!"array index {index} out of bounds"
  | _ => .error "arrayGet expects an array value"

def structFieldValue (value : Value) (fieldName : String) : Except String Value :=
  match value with
  | .struct _ fields =>
      match lookup fieldName fields with
      | some value => .ok value
      | none => .error s!"unknown struct field `{fieldName}`"
  | _ => .error "field access expects a struct value"

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

def evalNumericBinary (opName : String) (op : Nat → Nat → Nat) (lhs rhs : Value) :
    Except String Value :=
  match lhs, rhs with
  | .u64 lhsValue, .u64 rhsValue => .ok (.u64 (op lhsValue rhsValue))
  | .u32 lhsValue, .u32 rhsValue => .ok (.u32 (op lhsValue rhsValue))
  | _, _ => .error s!"{opName} expects matching numeric operands"

def evalNumericPredicate (opName : String) (op : Nat → Nat → Bool) (lhs rhs : Value) :
    Except String Value :=
  match lhs, rhs with
  | .u64 lhsValue, .u64 rhsValue => .ok (.bool (op lhsValue rhsValue))
  | .u32 lhsValue, .u32 rhsValue => .ok (.bool (op lhsValue rhsValue))
  | _, _ => .error s!"{opName} expects matching numeric operands"

def evalEquality (lhs rhs : Value) : Except String Value :=
  match lhs, rhs with
  | .unit, .unit => .ok (.bool true)
  | .bool lhsValue, .bool rhsValue => .ok (.bool (lhsValue == rhsValue))
  | .u64 lhsValue, .u64 rhsValue => .ok (.bool (lhsValue == rhsValue))
  | .u32 lhsValue, .u32 rhsValue => .ok (.bool (lhsValue == rhsValue))
  | .hash a0 b0 c0 d0, .hash a1 b1 c1 d1 =>
      .ok (.bool (a0 == a1 && b0 == b1 && c0 == c1 && d0 == d1))
  | .array lhsValues, .array rhsValues => .ok (.bool (lhsValues == rhsValues))
  | .struct lhsName lhsFields, .struct rhsName rhsFields =>
      .ok (.bool (lhsName == rhsName && lhsFields == rhsFields))
  | _, _ => .error "equality expects matching operands"

def evalBooleanBinary (opName : String) (op : Bool → Bool → Bool) (lhs rhs : Value) :
    Except String Value :=
  match lhs, rhs with
  | .bool lhsValue, .bool rhsValue => .ok (.bool (op lhsValue rhsValue))
  | _, _ => .error s!"{opName} expects Bool operands"

def castValue (value : Value) (targetType : ValueType) : Except String Value :=
  match value, targetType with
  | .bool value, .bool => .ok (.bool value)
  | .bool value, .u32 => .ok (.u32 (if value then 1 else 0))
  | .bool value, .u64 => .ok (.u64 (if value then 1 else 0))
  | .u32 value, .u32 => .ok (.u32 value)
  | .u32 value, .u64 => .ok (.u64 value)
  | .u32 0, .bool => .ok (.bool false)
  | .u32 1, .bool => .ok (.bool true)
  | .u32 _, .bool => .error "U32 to Bool cast expects canonical 0 or 1"
  | .u64 value, .u64 => .ok (.u64 value)
  | .u64 value, .u32 =>
      if value <= maxU32 then
        .ok (.u32 value)
      else
        .error "U64 to U32 cast exceeds U32 range"
  | .u64 0, .bool => .ok (.bool false)
  | .u64 1, .bool => .ok (.bool true)
  | .u64 _, .bool => .error "U64 to Bool cast expects canonical 0 or 1"
  | .hash a b c d, .hash => .ok (.hash a b c d)
  | _, _ => .error s!"cast to `{targetType.name}` is not supported by the scalar semantics model"

def truthy : Value → Except String Bool
  | .bool value => .ok value
  | _ => .error "assertion condition expects Bool"

def evalAssignOp (op : AssignOp) (lhs rhs : Value) : Except String Value :=
  match op with
  | .add => evalNumericBinary "assignAdd" (· + ·) lhs rhs
  | .sub => evalNumericBinary "assignSub" (· - ·) lhs rhs
  | .mul => evalNumericBinary "assignMul" (· * ·) lhs rhs
  | .div => evalNumericBinary "assignDiv" (fun lhs rhs => if rhs == 0 then 0 else lhs / rhs) lhs rhs
  | .mod => evalNumericBinary "assignMod" (fun lhs rhs => if rhs == 0 then 0 else lhs % rhs) lhs rhs
  | .bitAnd => evalNumericBinary "assignBitAnd" Nat.land lhs rhs
  | .bitOr => evalNumericBinary "assignBitOr" Nat.lor lhs rhs
  | .bitXor => evalNumericBinary "assignBitXor" Nat.xor lhs rhs
  | .shiftLeft => evalNumericBinary "assignShiftLeft" (fun lhs rhs => lhs * (2 ^ rhs)) lhs rhs
  | .shiftRight => evalNumericBinary "assignShiftRight" (fun lhs rhs => lhs / (2 ^ rhs)) lhs rhs

mutual
partial def evalExpr (state : State) (frame : Frame) : Expr → Except String Value
  | .literal literal => literalValue literal
  | .local name =>
      match frame.read name with
      | some value => .ok value
      | none => .error s!"unknown local `{name}`"
  | .arrayLit _ values => do
      let mut evaluated := #[]
      for value in values do
        evaluated := evaluated.push (← evalExpr state frame value)
      .ok (.array evaluated.toList)
  | .arrayGet array index => do
      let arrayValue ← evalExpr state frame array
      let indexValue ← indexValue (← evalExpr state frame index)
      arrayGetValue arrayValue indexValue
  | .structLit typeName fields => do
      let mut evaluated := #[]
      for field in fields do
        evaluated := evaluated.push (field.fst, ← evalExpr state frame field.snd)
      .ok (.struct typeName evaluated.toList)
  | .field base fieldName => do
      structFieldValue (← evalExpr state frame base) fieldName
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
  | .pow lhs rhs => do
      evalNumericBinary "pow" (fun lhs rhs => lhs ^ rhs)
        (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .bitAnd lhs rhs => do
      evalNumericBinary "bitAnd" Nat.land (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .bitOr lhs rhs => do
      evalNumericBinary "bitOr" Nat.lor (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .bitXor lhs rhs => do
      evalNumericBinary "bitXor" Nat.xor (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .shiftLeft lhs rhs => do
      evalNumericBinary "shiftLeft" (fun lhs rhs => lhs * (2 ^ rhs))
        (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .shiftRight lhs rhs => do
      evalNumericBinary "shiftRight" (fun lhs rhs => lhs / (2 ^ rhs))
        (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .cast value targetType => do
      castValue (← evalExpr state frame value) targetType
  | .eq lhs rhs => do
      evalEquality (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .ne lhs rhs => do
      match ← evalEquality (← evalExpr state frame lhs) (← evalExpr state frame rhs) with
      | .bool value => .ok (.bool (!value))
      | _ => .error "equality returned a non-Bool value"
  | .lt lhs rhs => do
      evalNumericPredicate "lt" (· < ·) (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .le lhs rhs => do
      evalNumericPredicate "le" (· <= ·) (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .gt lhs rhs => do
      evalNumericPredicate "gt" (· > ·) (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .ge lhs rhs => do
      evalNumericPredicate "ge" (· >= ·) (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .boolAnd lhs rhs => do
      evalBooleanBinary "boolAnd" (fun lhs rhs => lhs && rhs)
        (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .boolOr lhs rhs => do
      evalBooleanBinary "boolOr" (fun lhs rhs => lhs || rhs)
        (← evalExpr state frame lhs) (← evalExpr state frame rhs)
  | .boolNot value => do
      match ← evalExpr state frame value with
      | .bool value => .ok (.bool (!value))
      | _ => .error "boolNot expects Bool operand"
  | .effect effect => evalEffect state frame effect
  | _ => .error "expression is not supported by the scalar semantics model"

partial def evalPathSegmentKey (state : State) (frame : Frame) : StoragePathSegment →
    Except String String
  | .field fieldName => .ok s!".{fieldName}"
  | .index indexExpr => do
      let index ← indexValue (← evalExpr state frame indexExpr)
      .ok s!"[{index}]"
  | .mapKey keyExpr => do
      let key ← evalExpr state frame keyExpr
      .ok ("{" ++ valueKey key ++ "}")

partial def evalStoragePathKey (state : State) (frame : Frame) (stateId : String)
    (path : Array StoragePathSegment) : Except String String := do
  let mut key := stateId
  for segment in path do
    key := key ++ (← evalPathSegmentKey state frame segment)
  .ok key

partial def evalEffect (state : State) (frame : Frame) : Effect → Except String Value
  | .storageScalarRead name =>
      match state.read name with
      | some value => .ok value
      | none => .error s!"unknown scalar state `{name}`"
  | .storageMapContains name keyExpr => do
      let key := valueKey (← evalExpr state frame keyExpr)
      .ok (.bool ((state.read (mapPresentKey name key)).isSome))
  | .storageMapGet name keyExpr => do
      let key := valueKey (← evalExpr state frame keyExpr)
      match state.read (mapKey name key) with
      | some value => .ok value
      | none => .error s!"unknown map state `{name}` key `{key}`"
  | .storageMapInsert name keyExpr valueExpr
  | .storageMapSet name keyExpr valueExpr => do
      let key := valueKey (← evalExpr state frame keyExpr)
      let newValue ← evalExpr state frame valueExpr
      .ok ((state.read (mapKey name key)).getD (zeroLike newValue))
  | .storageArrayRead name indexExpr => do
      let index ← indexValue (← evalExpr state frame indexExpr)
      match state.read (arrayKey name index) with
      | some value => .ok value
      | none => .error s!"unknown array state `{name}` index {index}"
  | .storageArrayStructFieldRead name indexExpr fieldName => do
      let index ← indexValue (← evalExpr state frame indexExpr)
      match state.read (arrayFieldKey name index fieldName) with
      | some value => .ok value
      | none => .error s!"unknown array struct field `{name}[{index}].{fieldName}`"
  | .storageStructFieldRead name fieldName =>
      match state.readStructField name fieldName with
      | some value => .ok value
      | none => .error s!"unknown struct field state `{name}.{fieldName}`"
  | .storagePathRead name path => do
      let key ← evalStoragePathKey state frame name path
      match state.read key with
      | some value => .ok value
      | none => .error s!"unknown storage path `{key}`"
  | .contextRead .checkpointId =>
      .ok (.u64 0)
  | .contextRead field =>
      .error s!"context field `{field.name}` is not supported by the scalar semantics model"
  | _ => .error "effect is not supported by the FV-2 executable semantics slice"
end

def evalEventFields (state : State) (frame : Frame) (fields : Array (String × Expr)) :
    Except String Unit := do
  for field in fields do
    let _ ← evalExpr state frame field.snd
  pure ()

def execEffectStmt (state : State) (frame : Frame) : Effect → Except String State
  | .storageScalarWrite name value => do
      .ok (state.write name (← evalExpr state frame value))
  | .storageScalarAssignOp name op value => do
      let current ←
        match state.read name with
        | some value => .ok value
        | none => .error s!"unknown scalar state `{name}`"
      .ok (state.write name (← evalAssignOp op current (← evalExpr state frame value)))
  | .storageMapInsert name keyExpr valueExpr
  | .storageMapSet name keyExpr valueExpr => do
      let key := valueKey (← evalExpr state frame keyExpr)
      let value ← evalExpr state frame valueExpr
      .ok ((state.write (mapKey name key) value).write (mapPresentKey name key) (.bool true))
  | .storageArrayWrite name indexExpr valueExpr => do
      let index ← indexValue (← evalExpr state frame indexExpr)
      .ok (state.write (arrayKey name index) (← evalExpr state frame valueExpr))
  | .storageArrayStructFieldWrite name indexExpr fieldName valueExpr => do
      let index ← indexValue (← evalExpr state frame indexExpr)
      .ok (state.write (arrayFieldKey name index fieldName) (← evalExpr state frame valueExpr))
  | .storageStructFieldWrite name fieldName valueExpr => do
      .ok (state.write (fieldKey name fieldName) (← evalExpr state frame valueExpr))
  | .storagePathWrite name path valueExpr => do
      let key ← evalStoragePathKey state frame name path
      let value ← evalExpr state frame valueExpr
      let state := state.write key value
      let state :=
        if path.any (fun segment => match segment with | .mapKey _ => true | _ => false) then
          state.write (key ++ ".present") (.bool true)
        else
          state
      .ok state
  | .storagePathAssignOp name path op valueExpr => do
      let key ← evalStoragePathKey state frame name path
      let current ←
        match state.read key with
        | some value => .ok value
        | none => .error s!"unknown storage path `{key}`"
      .ok (state.write key (← evalAssignOp op current (← evalExpr state frame valueExpr)))
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
  | .assert condition message _ => do
      if ← truthy (← evalExpr state frame condition) then
        .ok (state, frame, none)
      else
        .error s!"assertion failed: {message}"
  | .assertEq lhs rhs message _ => do
      if (← evalExpr state frame lhs) == (← evalExpr state frame rhs) then
        .ok (state, frame, none)
      else
        .error s!"assertion failed: {message}"
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

def resultValue : Except String (State × Option Value) → Except String (Option Value)
  | .ok (_, value) => .ok value
  | .error message => .error message

def resultMatches (lhs rhs : Except String (State × Option Value)) : Bool :=
  match lhs, rhs with
  | .ok (lhsState, lhsValue), .ok (rhsState, rhsValue) =>
      lhsState == rhsState && lhsValue == rhsValue
  | .error lhsMessage, .error rhsMessage => lhsMessage == rhsMessage
  | _, _ => false

def resultValueMatches (result : Except String (State × Option Value)) (expected : Option Value) :
    Bool :=
  match resultValue result with
  | .ok actual => actual == expected
  | .error _ => false

def counterTraceGetsOne : Bool :=
  resultMatches counterTrace (.ok ({ storage := [("count", .u64 1)] }, some (.u64 1)))

theorem counter_trace_gets_one :
    counterTraceGetsOne = true := by
  native_decide

theorem counter_exports_match_near_entrypoints :
    ProofForge.IR.Examples.Counter.module.entrypoints.map (fun entrypoint => entrypoint.name) =
      #["initialize", "increment", "get"] := by
  native_decide

def arraySumLiteralTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.ArrayProbe.sumLiteral

theorem array_sum_literal_trace_returns_sixty :
    resultValueMatches arraySumLiteralTrace (some (.u64 60)) = true := by
  native_decide

def arrayStorageLifecycleTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.ArrayProbe.storageLifecycle

theorem array_storage_lifecycle_trace_returns_thirty_one :
    resultValueMatches arrayStorageLifecycleTrace (some (.u64 31)) = true := by
  native_decide

def arrayPredicatesTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.ArrayProbe.arrayPredicates

theorem array_predicates_trace_returns_one :
    resultValueMatches arrayPredicatesTrace (some (.u64 1)) = true := by
  native_decide

def abiSumPairTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.sumPair
    #[.struct "Pair" [("left", .u64 12), ("right", .u64 30)]]

theorem abi_sum_pair_trace_returns_forty_two :
    resultValueMatches abiSumPairTrace (some (.u64 42)) = true := by
  native_decide

def abiMakeArrayTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.makeArray
    #[.u64 1, .u64 2, .u64 3]

theorem abi_make_array_trace_returns_array :
    resultValueMatches abiMakeArrayTrace (some (.array [.u64 1, .u64 2, .u64 3])) = true := by
  native_decide

def mapPathLifecycleTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmMapProbe.pathLifecycle

theorem map_path_lifecycle_trace_returns_seventy_seven :
    resultValueMatches mapPathLifecycleTrace (some (.u64 77)) = true := by
  native_decide

def mapPathAssignLifecycleTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmMapProbe.pathAssignLifecycle

theorem map_path_assign_lifecycle_trace_returns_fifty_eight :
    resultValueMatches mapPathAssignLifecycleTrace (some (.u64 58)) = true := by
  native_decide

def mapNestedPathLifecycleTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmMapProbe.nestedPathLifecycle

theorem map_nested_path_lifecycle_trace_returns_ninety_five :
    resultValueMatches mapNestedPathLifecycleTrace (some (.u64 95)) = true := by
  native_decide

def mapNestedPathDynamicTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmMapProbe.nestedPathDynamic
    #[.u64 41, .u64 42, .u64 1234]

theorem map_nested_path_dynamic_trace_returns_argument_value :
    resultValueMatches mapNestedPathDynamicTrace (some (.u64 1234)) = true := by
  native_decide

def storageStructPathLifecycleTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmStorageStructProbe.pathLifecycle

theorem storage_struct_path_lifecycle_trace_returns_forty_eight :
    resultValueMatches storageStructPathLifecycleTrace (some (.u64 48)) = true := by
  native_decide

def storageStructLifecycleTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmStorageStructProbe.structLifecycle

theorem storage_struct_lifecycle_trace_returns_eighteen :
    resultValueMatches storageStructLifecycleTrace (some (.u64 18)) = true := by
  native_decide

def storageStructArrayLifecycleTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmStorageStructProbe.arrayStructLifecycle

theorem storage_struct_array_lifecycle_trace_returns_twelve :
    resultValueMatches storageStructArrayLifecycleTrace (some (.u64 12)) = true := by
  native_decide

def storageStructArrayPathLifecycleTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmStorageStructProbe.arrayPathLifecycle

theorem storage_struct_array_path_lifecycle_trace_returns_twenty_three :
    resultValueMatches storageStructArrayPathLifecycleTrace (some (.u64 23)) = true := by
  native_decide

def storageStructWholeWriteTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmStorageStructProbe.wholeStructWriteSum

theorem storage_struct_whole_write_trace_returns_seventy :
    resultValueMatches storageStructWholeWriteTrace (some (.u64 70)) = true := by
  native_decide

def storageStructWholeReturnTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmStorageStructProbe.wholeStructReturn

theorem storage_struct_whole_return_trace_returns_point :
    resultValueMatches storageStructWholeReturnTrace
      (some (.struct "Point" [("x", .u64 8), ("y", .u64 13)])) = true := by
  native_decide

def storageStructSelfWriteTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmStorageStructProbe.selfStructStorageWrite

theorem storage_struct_self_write_trace_returns_seven_hundred_five :
    resultValueMatches storageStructSelfWriteTrace (some (.u64 705)) = true := by
  native_decide

def storageStructReturnPointsTrace : Except String (State × Option Value) :=
  runEntrypoint State.empty ProofForge.IR.Examples.EvmStorageStructProbe.returnPoints

theorem storage_struct_return_points_trace_returns_array :
    resultValueMatches storageStructReturnPointsTrace
      (some (.array [
        .struct "Point" [("x", .u64 29), ("y", .u64 31)],
        .struct "Point" [("x", .u64 37), ("y", .u64 41)]
      ])) = true := by
  native_decide

def abiSumArrayTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.sumArray
    #[.array [.u64 4, .u64 5, .u64 6]]

theorem abi_sum_array_trace_returns_fifteen :
    resultValueMatches abiSumArrayTrace (some (.u64 15)) = true := by
  native_decide

def abiSumMatrixTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.sumMatrix
    #[.array [.array [.u64 1, .u64 2], .array [.u64 3, .u64 4]]]

theorem abi_sum_matrix_trace_returns_ten :
    resultValueMatches abiSumMatrixTrace (some (.u64 10)) = true := by
  native_decide

def abiSumPairArrayTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.sumPairArray
    #[.array [
      .struct "Pair" [("left", .u64 1), ("right", .u64 2)],
      .struct "Pair" [("left", .u64 3), ("right", .u64 4)]
    ]]

theorem abi_sum_pair_array_trace_returns_ten :
    resultValueMatches abiSumPairArrayTrace (some (.u64 10)) = true := by
  native_decide

def abiMakePairTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.makePair
    #[.u64 8, .u64 13]

theorem abi_make_pair_trace_returns_struct :
    resultValueMatches abiMakePairTrace
      (some (.struct "Pair" [("left", .u64 8), ("right", .u64 13)])) = true := by
  native_decide

def abiMakePairArrayTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.makePairArray
    #[.u64 1, .u64 2, .u64 3, .u64 4]

theorem abi_make_pair_array_trace_returns_struct_array :
    resultValueMatches abiMakePairArrayTrace
      (some (.array [
        .struct "Pair" [("left", .u64 1), ("right", .u64 2)],
        .struct "Pair" [("left", .u64 3), ("right", .u64 4)]
      ])) = true := by
  native_decide

def abiMakeMatrixTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.makeMatrix
    #[.u64 5, .u64 6, .u64 7, .u64 8]

theorem abi_make_matrix_trace_returns_nested_array :
    resultValueMatches abiMakeMatrixTrace
      (some (.array [.array [.u64 5, .u64 6], .array [.u64 7, .u64 8]])) = true := by
  native_decide

def abiSumSmallTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.sumSmall
    #[.array [.u32 9, .u32 10]]

theorem abi_sum_small_trace_returns_nineteen :
    resultValueMatches abiSumSmallTrace (some (.u32 19)) = true := by
  native_decide

def abiSumSmallMatrixTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.sumSmallMatrix
    #[.array [.array [.u32 1, .u32 2], .array [.u32 3, .u32 4]]]

theorem abi_sum_small_matrix_trace_returns_ten :
    resultValueMatches abiSumSmallMatrixTrace (some (.u32 10)) = true := by
  native_decide

def abiAndFlagsTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.andFlags
    #[.struct "Flags" [("enabled", .bool true), ("archived", .bool false)]]

theorem abi_and_flags_trace_returns_false :
    resultValueMatches abiAndFlagsTrace (some (.bool false)) = true := by
  native_decide

def abiEchoHashPairTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.echoHashPair
    #[.struct "HashPair" [
      ("left", .hash 1 2 3 4),
      ("right", .hash 5 6 7 8)
    ]]

theorem abi_echo_hash_pair_trace_returns_right_hash :
    resultValueMatches abiEchoHashPairTrace (some (.hash 5 6 7 8)) = true := by
  native_decide

def abiMakeHashArrayTrace : Except String (State × Option Value) :=
  runEntrypointWithArgs State.empty ProofForge.IR.Examples.EvmAbiAggregateProbe.makeHashArray
    #[.hash 1 2 3 4, .hash 5 6 7 8]

theorem abi_make_hash_array_trace_returns_hash_array :
    resultValueMatches abiMakeHashArrayTrace
      (some (.array [.hash 1 2 3 4, .hash 5 6 7 8])) = true := by
  native_decide

end ProofForge.IR.Semantics
