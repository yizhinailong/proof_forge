import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.IR.Contract
import ProofForge.Target.Check
import ProofForge.Target.Registry
import ProofForge.Compiler.Yul.AST
import ProofForge.Compiler.Yul.Printer

namespace ProofForge.Backend.Evm.IR

open ProofForge.IR
open ProofForge.Target

structure LowerError where
  message : String
  deriving Repr, Inhabited

def LowerError.render (err : LowerError) : String :=
  err.message

def capabilityError (err : CapabilityError) : LowerError := {
  message := err.render
}

def stateInfo? (module : Module) (stateId : String) : Option (Nat × StateDecl) :=
  go 0 0 module.state
where
  stateSlotSpan (state : StateDecl) : Nat :=
    match state.kind, state.type with
    | .scalar, .structType typeName =>
        match module.structs.find? (fun decl => decl.name == typeName) with
        | some decl => decl.fields.size
        | none => 1
    | .array length, .structType typeName =>
        match module.structs.find? (fun decl => decl.name == typeName) with
        | some decl => length * decl.fields.size
        | none => length
    | .array length, _ => length
    | .scalar, _ | .map _ _, _ => 1

  go (idx slot : Nat) (states : Array StateDecl) : Option (Nat × StateDecl) :=
    if h : idx < states.size then
      let state := states[idx]
      if state.id == stateId then
        some (slot, state)
      else
        go (idx + 1) (slot + stateSlotSpan state) states
    else
      none

def stateSlot? (module : Module) (stateId : String) : Option Nat :=
  match stateInfo? module stateId with
  | some (slot, _) => some slot
  | none => none

def slotExpr (slot : Nat) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.Expr.num slot

def yulFunctionName (moduleName entrypointName : String) : String :=
  s!"f_{moduleName}_{entrypointName}"

def mapSlotFunctionName : String := "__proof_forge_map_slot"
def mapWriteFunctionName : String := "__proof_forge_map_write"
def mapSetReturnFunctionName : String := "__proof_forge_map_set_return"
def arraySlotFunctionName : String := "__proof_forge_array_slot"
def structArraySlotFunctionName : String := "__proof_forge_struct_array_slot"
def hashWordFunctionName : String := "__proof_forge_hash_word"
def hashPairFunctionName : String := "__proof_forge_hash_pair"
def crosscallFunctionName (arity : Nat) : String := s!"__proof_forge_crosscall_{arity}"

def twoPow64 : Nat := 18446744073709551616
def maxU64 : Nat := twoPow64 - 1

def checkedHashLiteralLimb (name : String) (value : Nat) : Except LowerError Nat :=
  if value <= maxU64 then
    .ok value
  else
    .error { message := s!"Hash literal limb `{name}` exceeds U64 range" }

def packedHashLiteral (a b c d : Nat) : Except LowerError Nat := do
  let a ← checkedHashLiteralLimb "a" a
  let b ← checkedHashLiteralLimb "b" b
  let c ← checkedHashLiteralLimb "c" c
  let d ← checkedHashLiteralLimb "d" d
  .ok ((((a * twoPow64) + b) * twoPow64 + c) * twoPow64 + d)

def hashPackExpr
    (a b c d : Lean.Compiler.Yul.Expr) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.builtin "or" #[
    Lean.Compiler.Yul.builtin "shl" #[Lean.Compiler.Yul.Expr.num 192, a],
    Lean.Compiler.Yul.builtin "or" #[
      Lean.Compiler.Yul.builtin "shl" #[Lean.Compiler.Yul.Expr.num 128, b],
      Lean.Compiler.Yul.builtin "or" #[
        Lean.Compiler.Yul.builtin "shl" #[Lean.Compiler.Yul.Expr.num 64, c],
        d
      ]
    ]
  ]

def eventNameWordAndLength (name : String) : Except LowerError (Nat × Nat) := do
  let bytes := name.toUTF8
  if bytes.size == 0 then
    .error { message := "event name must be non-empty for IR EVM v0" }
  if bytes.size > 32 then
    .error { message := s!"event `{name}` name is {bytes.size} byte(s); IR EVM v0 supports event names up to 32 UTF-8 bytes" }
  let mut wordVal := 0
  for _h : j in [0:32] do
    if j < bytes.size then
      let b := (bytes.get! j).toNat
      let shift := (31 - j) * 8
      wordVal := wordVal + (b * (2 ^ shift))
  .ok (wordVal, bytes.size)

def ensureEventFieldType (eventName fieldName : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 | .bool | .hash => .ok ()
  | .unit | .fixedArray _ _ | .structType _ =>
      .error { message := s!"event `{eventName}` field `{fieldName}` has unsupported EVM IR v0 type `{type.name}`; event fields must be U32, U64, Bool, or Hash" }

def validateEventFieldName (eventName fieldName : String) : Except LowerError Unit :=
  if fieldName.isEmpty then
    .error { message := s!"event `{eventName}` field name must be non-empty" }
  else
    .ok ()

def validateDistinctEventFieldName (eventName : String) (seen : Array String) (fieldName : String) : Except LowerError (Array String) := do
  validateEventFieldName eventName fieldName
  if seen.contains fieldName then
    .error { message := s!"duplicate event `{eventName}` field name `{fieldName}`" }
  else
    .ok (seen.push fieldName)

def revertStmt : Lean.Compiler.Yul.Statement :=
  Lean.Compiler.Yul.Statement.exprStmt
    (Lean.Compiler.Yul.builtin "revert" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])

def calldataWordExpr (paramIndex : Nat) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.builtin "calldataload" #[Lean.Compiler.Yul.Expr.num (4 + paramIndex * 32)]

def arrayLocalElementName (name : String) (index : Nat) : String :=
  s!"__proof_forge_array_{name}_{index}"

def structLocalFieldName (name fieldName : String) : String :=
  s!"__proof_forge_struct_{name}_{fieldName}"

def abiReturnName (index : Nat) : String :=
  s!"__proof_forge_return_{index}"

def abiDispatchResultName (index : Nat) : String :=
  s!"_r{index}"

def ensureAbiWordType (context : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 | .bool | .hash => .ok ()
  | .unit | .fixedArray _ _ | .structType _ =>
      .error {
        message := s!"{context} has unsupported EVM IR v0 ABI word type `{type.name}`; ABI aggregate words support U32, U64, Bool, or Hash"
      }

def abiValueWordTypes (module : Module) (context : String) : ValueType → Except LowerError (Array ValueType)
  | .u32 => .ok #[.u32]
  | .u64 => .ok #[.u64]
  | .bool => .ok #[.bool]
  | .hash => .ok #[.hash]
  | .unit =>
      .error { message := s!"{context} uses Unit; IR EVM v0 ABI values must use U32, U64, Bool, Hash, fixed arrays, or structs" }
  | .fixedArray elementType length => do
      if length == 0 then
        .error { message := s!"{context} uses Array<{elementType.name},0>; IR EVM v0 ABI fixed arrays must have non-zero length" }
      ensureAbiWordType s!"{context} fixed-array element" elementType
      let mut words : Array ValueType := #[]
      for _h : _idx in [0:length] do
        words := words.push elementType
      .ok words
  | .structType typeName => do
      let some decl := module.structs.find? fun decl => decl.name == typeName
        | .error { message := s!"{context} uses unknown struct `{typeName}`" }
      if decl.fields.isEmpty then
        .error { message := s!"{context} uses empty struct `{typeName}`; IR EVM v0 ABI structs must have at least one field" }
      let mut words : Array ValueType := #[]
      for field in decl.fields do
        ensureAbiWordType s!"{context} struct `{typeName}` field `{field.id}`" field.type
        words := words.push field.type
      .ok words

def abiValueParamNames
    (module : Module)
    (context name : String) : ValueType → Except LowerError (Array String)
  | .u32 | .u64 | .bool | .hash => .ok #[name]
  | .unit => do
      discard <| abiValueWordTypes module context .unit
      .ok #[]
  | .fixedArray elementType length => do
      discard <| abiValueWordTypes module context (.fixedArray elementType length)
      let mut names : Array String := #[]
      for _h : index in [0:length] do
        names := names.push (arrayLocalElementName name index)
      .ok names
  | .structType typeName => do
      discard <| abiValueWordTypes module context (.structType typeName)
      let some decl := module.structs.find? fun decl => decl.name == typeName
        | .error { message := s!"{context} uses unknown struct `{typeName}`" }
      .ok (decl.fields.map fun field => structLocalFieldName name field.id)

def lowerEntrypointParams (module : Module) (entrypoint : Entrypoint) : Except LowerError (Array Lean.Compiler.Yul.TypedName) :=
  entrypoint.params.foldlM (init := #[]) fun acc param => do
    let (name, type) := param
    let paramNames ← abiValueParamNames module s!"entrypoint `{entrypoint.name}` parameter `{name}`" name type
    .ok (acc ++ (paramNames.map fun name => ({ name := name } : Lean.Compiler.Yul.TypedName)))

def entrypointParamWordTypes (module : Module) (entrypoint : Entrypoint) : Except LowerError (Array ValueType) := do
  let mut words : Array ValueType := #[]
  for param in entrypoint.params do
    words := words ++ (← abiValueWordTypes module s!"entrypoint `{entrypoint.name}` parameter `{param.fst}`" param.snd)
  .ok words

def entrypointCallArgs (module : Module) (entrypoint : Entrypoint) : Except LowerError (Array Lean.Compiler.Yul.Expr) := do
  let wordTypes ← entrypointParamWordTypes module entrypoint
  let mut args : Array Lean.Compiler.Yul.Expr := #[]
  for _h : index in [0:wordTypes.size] do
    args := args.push (calldataWordExpr index)
  .ok args

def abiParamValidationStmts (module : Module) (entrypoint : Entrypoint) : Except LowerError (Array Lean.Compiler.Yul.Statement) := do
  let wordTypes ← entrypointParamWordTypes module entrypoint
  let minSize := 4 + wordTypes.size * 32
  let mut statements : Array Lean.Compiler.Yul.Statement :=
    if wordTypes.isEmpty then
      #[]
    else
      #[
        Lean.Compiler.Yul.Statement.ifStmt
          (Lean.Compiler.Yul.builtin "lt" #[Lean.Compiler.Yul.builtin "calldatasize" #[], Lean.Compiler.Yul.Expr.num minSize])
          { statements := #[revertStmt] }
      ]
  for h : idx in [0:wordTypes.size] do
    let word := calldataWordExpr idx
    statements :=
      match wordTypes[idx] with
      | .u32 =>
          statements.push <| Lean.Compiler.Yul.Statement.ifStmt
            (Lean.Compiler.Yul.builtin "gt" #[word, Lean.Compiler.Yul.Expr.num 4294967295])
            { statements := #[revertStmt] }
      | .bool =>
          statements.push <| Lean.Compiler.Yul.Statement.ifStmt
            (Lean.Compiler.Yul.builtin "gt" #[word, Lean.Compiler.Yul.Expr.num 1])
            { statements := #[revertStmt] }
      | _ => statements
  .ok statements

def lowerAssertStmt (condition : Lean.Compiler.Yul.Expr) : Lean.Compiler.Yul.Statement :=
  Lean.Compiler.Yul.Statement.ifStmt
    (Lean.Compiler.Yul.builtin "iszero" #[condition])
    { statements := #[revertStmt] }

def contextExpr : ContextField → Lean.Compiler.Yul.Expr
  | .userId => Lean.Compiler.Yul.builtin "caller" #[]
  | .contractId => Lean.Compiler.Yul.builtin "address" #[]
  | .checkpointId => Lean.Compiler.Yul.builtin "number" #[]

def mapShapeName (keyType valueType : ValueType) (capacity : Nat) : String :=
  s!"Map<{keyType.name}, {valueType.name}, {capacity}>"

def requireU64MapState (module : Module) (stateId : String) : Except LowerError Nat :=
  match stateInfo? module stateId with
  | none => .error { message := s!"unknown map state `{stateId}`" }
  | some (slot, state) =>
      match state.kind, state.type with
      | .map .u64 _, .u64 => .ok slot
      | .map keyType capacity, valueType =>
          .error { message := s!"map state `{stateId}` has unsupported EVM IR v0 type `{mapShapeName keyType valueType capacity}`; only Map<U64, U64, N> is supported" }
      | .scalar, _ => .error { message := s!"state `{stateId}` is scalar storage, not a map" }
      | .array _, _ => .error { message := s!"state `{stateId}` is array storage, not a map" }

def isStorageWordType : ValueType → Bool
  | .u32 | .u64 | .bool | .hash => true
  | .unit | .fixedArray _ _ | .structType _ => false

def requireStorageArrayState (module : Module) (stateId : String) : Except LowerError (Nat × Nat × ValueType) :=
  match stateInfo? module stateId with
  | none => .error { message := s!"unknown array state `{stateId}`" }
  | some (slot, state) =>
      match state.kind, state.type with
      | .array length, elementType =>
          if length == 0 then
            .error { message := s!"array state `{stateId}` must have non-zero length" }
          else if isStorageWordType elementType then
            .ok (slot, length, elementType)
          else
            match elementType with
            | .structType _ =>
                .error { message := s!"array state `{stateId}` is struct storage; use storage.array.struct.field.read/write" }
            | other =>
                .error { message := s!"array state `{stateId}` has unsupported EVM IR v0 element type `{other.name}`; storage arrays support U32, U64, Bool, Hash, or flat struct arrays" }
      | .scalar, _ => .error { message := s!"state `{stateId}` is scalar storage, not an array" }
      | .map _ _, _ => .error { message := s!"state `{stateId}` is map storage, not an array" }

structure LocalBinding where
  name : String
  type : ValueType
  isMutable : Bool
  deriving Repr

abbrev TypeEnv := Array LocalBinding

def findLocal? (env : TypeEnv) (name : String) : Option LocalBinding :=
  env.find? fun binding => binding.name == name

def addLocal (env : TypeEnv) (name : String) (type : ValueType) (isMutable : Bool) : Except LowerError TypeEnv :=
  if (findLocal? env name).isSome then
    .error { message := s!"duplicate local `{name}`" }
  else
    .ok (env.push { name, type, isMutable })

def ensureType (context : String) (expected actual : ValueType) : Except LowerError Unit :=
  if expected == actual then
    .ok ()
  else
    .error { message := s!"{context} expected `{expected.name}`, got `{actual.name}`" }

def ensureNumericType (context : String) (lhs rhs : ValueType) : Except LowerError ValueType :=
  match lhs, rhs with
  | .u32, .u32 => .ok .u32
  | .u64, .u64 => .ok .u64
  | _, _ => .error { message := s!"{context} expects matching numeric operands, got `{lhs.name}` and `{rhs.name}`" }

def ensureArrayIndexType (context : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 => .ok ()
  | _ => .error { message := s!"{context} expected U32 or U64 index, got `{type.name}`" }

def literalArrayIndex? : ProofForge.IR.Expr → Option Nat
  | .literal (.u32 value) => some value
  | .literal (.u64 value) => some value
  | _ => none

def requireStaticArrayIndex (context : String) (index : ProofForge.IR.Expr) : Except LowerError Nat :=
  match literalArrayIndex? index with
  | some value => .ok value
  | none =>
      .error {
        message := s!"{context} in IR EVM v0 requires a U32/U64 literal index for local fixed-array values"
      }

def ensureFixedArrayIndexInBounds (context : String) (index length : Nat) : Except LowerError Unit :=
  if index < length then
    .ok ()
  else
    .error { message := s!"{context} {index} is out of bounds for length {length}" }

def assignOpDiagnosticName : AssignOp → String
  | .add => "addition"
  | .sub => "subtraction"
  | .mul => "multiplication"
  | .div => "division"
  | .mod => "modulo"
  | .bitAnd => "bitwise and"
  | .bitOr => "bitwise or"
  | .bitXor => "bitwise xor"
  | .shiftLeft => "shift-left"
  | .shiftRight => "shift-right"

def assignOpBuiltinName : AssignOp → String
  | .add => "add"
  | .sub => "sub"
  | .mul => "mul"
  | .div => "div"
  | .mod => "mod"
  | .bitAnd => "and"
  | .bitOr => "or"
  | .bitXor => "xor"
  | .shiftLeft => "shl"
  | .shiftRight => "shr"

def mapAssignFunctionName (op : AssignOp) : String :=
  s!"__proof_forge_map_assign_{assignOpBuiltinName op}"

def ensureAssignOpTypes (op : AssignOp) (targetType valueType : ValueType) : Except LowerError Unit := do
  discard <| ensureNumericType s!"compound assignment {assignOpDiagnosticName op}" targetType valueType

def lowerAssignOpExpr
    (op : AssignOp)
    (target value : Lean.Compiler.Yul.Expr) : Lean.Compiler.Yul.Expr :=
  match op with
  | .shiftLeft | .shiftRight =>
      Lean.Compiler.Yul.builtin (assignOpBuiltinName op) #[value, target]
  | _ =>
      Lean.Compiler.Yul.builtin (assignOpBuiltinName op) #[target, value]

def ensureEqType (context : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .bool | .u32 | .u64 | .hash => .ok ()
  | .unit => .error { message := s!"{context} does not support Unit equality" }
  | .fixedArray _ _ | .structType _ =>
      .error { message := s!"{context} does not support `{type.name}` equality in IR EVM v0" }

def ensureCastType (source target : ValueType) : Except LowerError Unit :=
  match source, target with
  | .u32, .u64 => .ok ()
  | .u64, .u32 => .ok ()
  | .u32, .bool => .ok ()
  | .bool, .u64 => .ok ()
  | .bool, .u32 => .ok ()
  | .u64, .bool => .ok ()
  | _, _ =>
      .error { message := s!"cast from `{source.name}` to `{target.name}` is not supported by IR EVM v0" }

def stateDeclOf (module : Module) (stateId kind : String) : Except LowerError StateDecl :=
  match stateInfo? module stateId with
  | some (_, state) => .ok state
  | none => .error { message := s!"unknown {kind} state `{stateId}`" }

def scalarStateType (module : Module) (stateId : String) : Except LowerError ValueType := do
  let state ← stateDeclOf module stateId "scalar"
  match state.kind with
  | .scalar =>
      match state.type with
      | .structType _ =>
          .error { message := s!"state `{stateId}` is struct storage; use storage.struct.field.read/write" }
      | _ => .ok state.type
  | .map _ _ => .error { message := s!"state `{stateId}` is a map, not scalar storage" }
  | .array _ => .error { message := s!"state `{stateId}` is an array, not scalar storage" }

def mapStateTypes (module : Module) (stateId : String) : Except LowerError (ValueType × ValueType) := do
  let state ← stateDeclOf module stateId "map"
  match state.kind with
  | .map keyType _ => .ok (keyType, state.type)
  | .scalar => .error { message := s!"state `{stateId}` is scalar storage, not a map" }
  | .array _ => .error { message := s!"state `{stateId}` is array storage, not a map" }

def findStruct? (module : Module) (name : String) : Option StructDecl :=
  module.structs.find? fun decl => decl.name == name

def findStructField? (decl : StructDecl) (fieldName : String) : Option StructField :=
  decl.fields.find? fun field => field.id == fieldName

def findStructFieldWithOffset? (decl : StructDecl) (fieldName : String) : Option (Nat × StructField) :=
  Id.run do
    let mut found : Option (Nat × StructField) := none
    for h : idx in [0:decl.fields.size] do
      if found.isNone then
        let field := decl.fields[idx]
        if field.id == fieldName then
          found := some (idx, field)
    found

def ensureStructLocalFieldType (structName fieldName : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 | .bool | .hash => .ok ()
  | .unit | .fixedArray _ _ | .structType _ =>
      .error {
        message := s!"field `{fieldName}` in struct `{structName}` has unsupported EVM IR v0 local struct field type `{type.name}`; local structs support U32, U64, Bool, or Hash fields"
      }

def structFieldType (module : Module) (typeName fieldName : String) : Except LowerError ValueType := do
  let some decl := findStruct? module typeName
    | .error { message := s!"unknown struct `{typeName}`" }
  let some field := findStructField? decl fieldName
    | .error { message := s!"struct `{typeName}` has no field `{fieldName}`" }
  .ok field.type

def requireStructStateField
    (module : Module)
    (stateId fieldName : String) : Except LowerError (Nat × StructField) := do
  match stateInfo? module stateId with
  | none => .error { message := s!"unknown struct state `{stateId}`" }
  | some (slot, state) =>
      match state.kind, state.type with
      | .scalar, .structType typeName => do
          let some decl := findStruct? module typeName
            | .error { message := s!"state `{stateId}` uses unknown struct `{typeName}`" }
          let some (offset, field) := findStructFieldWithOffset? decl fieldName
            | .error { message := s!"struct `{typeName}` has no field `{fieldName}`" }
          ensureStructLocalFieldType typeName field.id field.type
          .ok (slot + offset, field)
      | .scalar, other =>
          .error { message := s!"state `{stateId}` has unsupported EVM IR v0 struct storage type `{other.name}`; expected struct storage" }
      | .array _, _ =>
          .error { message := s!"state `{stateId}` is array storage, not scalar struct storage" }
      | .map _ _, _ =>
          .error { message := s!"state `{stateId}` is map storage, not scalar struct storage" }

def requireStructArrayStateField
    (module : Module)
    (stateId fieldName : String) : Except LowerError (Nat × Nat × Nat × Nat × StructField) := do
  match stateInfo? module stateId with
  | none => .error { message := s!"unknown struct array state `{stateId}`" }
  | some (slot, state) =>
      match state.kind, state.type with
      | .array length, .structType typeName => do
          if length == 0 then
            .error { message := s!"array state `{stateId}` must have non-zero length" }
          let some decl := findStruct? module typeName
            | .error { message := s!"array state `{stateId}` uses unknown struct `{typeName}`" }
          let some (offset, field) := findStructFieldWithOffset? decl fieldName
            | .error { message := s!"struct `{typeName}` has no field `{fieldName}`" }
          ensureStructLocalFieldType typeName field.id field.type
          .ok (slot, length, decl.fields.size, offset, field)
      | .array _, other =>
          .error { message := s!"array state `{stateId}` has unsupported EVM IR v0 struct element type `{other.name}`; expected struct storage array" }
      | .scalar, _ =>
          .error { message := s!"state `{stateId}` is scalar storage, not a struct array" }
      | .map _ _, _ =>
          .error { message := s!"state `{stateId}` is map storage, not a struct array" }

def validateStructLiteralFields
    (module : Module)
    (typeName : String)
    (fields : Array (String × ProofForge.IR.Expr))
    (infer : ProofForge.IR.Expr → Except LowerError ValueType) : Except LowerError Unit := do
  if fields.isEmpty then
    .error { message := s!"struct literal `{typeName}` must have at least one field" }
  let some decl := findStruct? module typeName
    | .error { message := s!"unknown struct `{typeName}`" }
  if decl.fields.size != fields.size then
    .error { message := s!"struct literal `{typeName}` expected {decl.fields.size} field(s), got {fields.size}" }
  for field in fields do
    let expected ← structFieldType module typeName field.fst
    ensureStructLocalFieldType typeName field.fst expected
    let actual ← infer field.snd
    ensureType s!"struct literal `{typeName}` field `{field.fst}`" expected actual
  for expectedField in decl.fields do
    if !(fields.any fun field => field.fst == expectedField.id) then
      .error { message := s!"struct literal `{typeName}` is missing field `{expectedField.id}`" }

mutual
  partial def inferExprType (module : Module) (env : TypeEnv) : ProofForge.IR.Expr → Except LowerError ValueType
    | .literal (.u32 _) => .ok .u32
    | .literal (.u64 _) => .ok .u64
    | .literal (.bool _) => .ok .bool
    | .literal (.hash4 ..) => .ok .hash
    | .local name =>
        match findLocal? env name with
        | some binding => .ok binding.type
        | none => .error { message := s!"unknown local `{name}`" }
    | .arrayLit elementType values => do
        for value in values do
          ensureType "array literal element" elementType (← inferExprType module env value)
        .ok (.fixedArray elementType values.size)
    | .arrayGet array index => do
        ensureArrayIndexType "fixed array index" (← inferExprType module env index)
        match ← inferExprType module env array with
        | .fixedArray elementType length => do
            match literalArrayIndex? index with
            | some indexValue =>
                ensureFixedArrayIndexInBounds "fixed array index" indexValue length
            | none => pure ()
            .ok elementType
        | other => .error { message := s!"fixed array indexing target expected `Array`, got `{other.name}`" }
    | .structLit typeName fields => do
        validateStructLiteralFields module typeName fields (inferExprType module env)
        .ok (.structType typeName)
    | .field base fieldName => do
        match ← inferExprType module env base with
        | .structType typeName => do
            let fieldType ← structFieldType module typeName fieldName
            ensureStructLocalFieldType typeName fieldName fieldType
            .ok fieldType
        | other => .error { message := s!"field `{fieldName}` requires struct value, got `{other.name}`" }
    | .add lhs rhs => do inferBinaryNumericType "addition" module env lhs rhs
    | .sub lhs rhs => do inferBinaryNumericType "subtraction" module env lhs rhs
    | .mul lhs rhs => do inferBinaryNumericType "multiplication" module env lhs rhs
    | .div lhs rhs => do inferBinaryNumericType "division" module env lhs rhs
    | .mod lhs rhs => do inferBinaryNumericType "modulo" module env lhs rhs
    | .pow lhs rhs => do inferBinaryNumericType "exponentiation" module env lhs rhs
    | .bitAnd lhs rhs => do inferBinaryNumericType "bitwise and" module env lhs rhs
    | .bitOr lhs rhs => do inferBinaryNumericType "bitwise or" module env lhs rhs
    | .bitXor lhs rhs => do inferBinaryNumericType "bitwise xor" module env lhs rhs
    | .shiftLeft lhs rhs => do inferBinaryNumericType "shift-left" module env lhs rhs
    | .shiftRight lhs rhs => do inferBinaryNumericType "shift-right" module env lhs rhs
    | .cast value targetType => do
        ensureCastType (← inferExprType module env value) targetType
        .ok targetType
    | .eq lhs rhs => do
        let lhsType ← inferExprType module env lhs
        let rhsType ← inferExprType module env rhs
        ensureType "equality right operand" lhsType rhsType
        ensureEqType "equality expression" lhsType
        .ok .bool
    | .ne lhs rhs => do
        let lhsType ← inferExprType module env lhs
        let rhsType ← inferExprType module env rhs
        ensureType "inequality right operand" lhsType rhsType
        ensureEqType "inequality expression" lhsType
        .ok .bool
    | .lt lhs rhs => do
        discard <| inferBinaryNumericType "less-than" module env lhs rhs
        .ok .bool
    | .le lhs rhs => do
        discard <| inferBinaryNumericType "less-or-equal" module env lhs rhs
        .ok .bool
    | .gt lhs rhs => do
        discard <| inferBinaryNumericType "greater-than" module env lhs rhs
        .ok .bool
    | .ge lhs rhs => do
        discard <| inferBinaryNumericType "greater-or-equal" module env lhs rhs
        .ok .bool
    | .boolAnd lhs rhs => do
        ensureType "boolean and left operand" .bool (← inferExprType module env lhs)
        ensureType "boolean and right operand" .bool (← inferExprType module env rhs)
        .ok .bool
    | .boolOr lhs rhs => do
        ensureType "boolean or left operand" .bool (← inferExprType module env lhs)
        ensureType "boolean or right operand" .bool (← inferExprType module env rhs)
        .ok .bool
    | .boolNot value => do
        ensureType "boolean not operand" .bool (← inferExprType module env value)
        .ok .bool
    | .hashValue a b c d => do
        ensureType "hash value part 0" .u64 (← inferExprType module env a)
        ensureType "hash value part 1" .u64 (← inferExprType module env b)
        ensureType "hash value part 2" .u64 (← inferExprType module env c)
        ensureType "hash value part 3" .u64 (← inferExprType module env d)
        .ok .hash
    | .hash preimage => do
        ensureType "hash preimage" .hash (← inferExprType module env preimage)
        .ok .hash
    | .hashTwoToOne lhs rhs => do
        ensureType "hash_two_to_one left operand" .hash (← inferExprType module env lhs)
        ensureType "hash_two_to_one right operand" .hash (← inferExprType module env rhs)
        .ok .hash
    | .nativeValue => .ok .u64
    | .crosscallInvoke target methodId args => do
        ensureType "crosscall target contract id" .u64 (← inferExprType module env target)
        ensureType "crosscall method id" .u64 (← inferExprType module env methodId)
        for arg in args do
          ensureType "crosscall argument" .u64 (← inferExprType module env arg)
        .ok .u64
    | .effect effect => inferEffectExprType module env effect

  partial def inferBinaryNumericType
      (context : String)
      (module : Module)
      (env : TypeEnv)
      (lhs rhs : ProofForge.IR.Expr) : Except LowerError ValueType := do
    ensureNumericType context (← inferExprType module env lhs) (← inferExprType module env rhs)

  partial def inferStoragePathType
      (module : Module)
      (env : TypeEnv)
      (stateId : String)
      (path : Array StoragePathSegment) : Except LowerError ValueType := do
    let state ← stateDeclOf module stateId "storage path"
    match state.kind, state.type, path.toList with
    | .map keyType _, _, [StoragePathSegment.mapKey key] => do
        ensureType s!"map `{stateId}` key" keyType (← inferExprType module env key)
        .ok state.type
    | .map _ _, _, [] =>
        .error { message := s!"storage path state `{stateId}` is map storage; first segment must be a map key" }
    | .map _ _, _, _ =>
        .error { message := "EVM IR v0 supports only single-segment mapKey storage paths" }
    | .scalar, .structType _, [StoragePathSegment.field fieldName] => do
        let (_, field) ← requireStructStateField module stateId fieldName
        .ok field.type
    | .scalar, .structType _, [] =>
        .error { message := s!"storage path state `{stateId}` is struct storage; first segment must be a field" }
    | .scalar, .structType _, _ =>
        .error { message := "EVM IR v0 supports struct scalar storage paths only as a single field segment" }
    | .scalar, _, [] =>
        .ok state.type
    | .scalar, _, [StoragePathSegment.field fieldName] =>
        .error { message := s!"state `{stateId}` has unsupported EVM IR v0 struct storage type `{state.type.name}`; expected struct storage for field `{fieldName}`" }
    | .scalar, _, _ =>
        .error { message := "EVM IR v0 supports storage paths only for single-segment mapKey map access" }
    | .array _, .structType _, [StoragePathSegment.index index, StoragePathSegment.field fieldName] => do
        let (_, _, _, _, field) ← requireStructArrayStateField module stateId fieldName
        ensureArrayIndexType s!"struct array state `{stateId}` index" (← inferExprType module env index)
        .ok field.type
    | .array _, .structType _, [StoragePathSegment.index _] =>
        .error { message := s!"storage path state `{stateId}` is struct array storage; a field segment must follow the index" }
    | .array _, _, [] =>
        .error { message := s!"storage path state `{stateId}` is array storage; first segment must be an index" }
    | .array _, .structType _, _ =>
        .error { message := "EVM IR v0 supports struct-array storage paths only as index followed by field" }
    | .array _, _, [StoragePathSegment.index index] => do
        let (_, _, elementType) ← requireStorageArrayState module stateId
        ensureArrayIndexType s!"array state `{stateId}` index" (← inferExprType module env index)
        .ok elementType
    | .array _, _, _ =>
        .error { message := "EVM IR v0 supports only single-segment index storage paths for arrays" }

  partial def inferEffectExprType (module : Module) (env : TypeEnv) : Effect → Except LowerError ValueType
    | .storageScalarRead stateId =>
        scalarStateType module stateId
    | .storageScalarWrite _ _ =>
        .error { message := "storage.scalar.write is a statement effect, not an expression" }
    | .storageScalarAssignOp _ _ _ =>
        .error { message := "storage.scalar.assign_op is a statement effect, not an expression" }
    | .storageMapContains stateId key => do
        let (keyType, _) ← mapStateTypes module stateId
        ensureType s!"map `{stateId}` key" keyType (← inferExprType module env key)
        .ok .bool
    | .storageMapGet stateId key => do
        let (keyType, valueType) ← mapStateTypes module stateId
        ensureType s!"map `{stateId}` key" keyType (← inferExprType module env key)
        .ok valueType
    | .storageMapInsert stateId key value => do
        let (keyType, valueType) ← mapStateTypes module stateId
        ensureType s!"map `{stateId}` key" keyType (← inferExprType module env key)
        ensureType s!"map `{stateId}` value" valueType (← inferExprType module env value)
        .ok valueType
    | .storageMapSet stateId key value => do
        let (keyType, valueType) ← mapStateTypes module stateId
        ensureType s!"map `{stateId}` key" keyType (← inferExprType module env key)
        ensureType s!"map `{stateId}` value" valueType (← inferExprType module env value)
        .ok valueType
    | .storageArrayRead stateId index => do
        let (_, _, elementType) ← requireStorageArrayState module stateId
        ensureArrayIndexType s!"array state `{stateId}` index" (← inferExprType module env index)
        .ok elementType
    | .storageArrayWrite _ _ _ =>
        .error { message := "storage.array.write is a statement effect, not an expression" }
    | .storageArrayStructFieldRead stateId index fieldName => do
        let (_, _, _, _, field) ← requireStructArrayStateField module stateId fieldName
        ensureArrayIndexType s!"struct array state `{stateId}` index" (← inferExprType module env index)
        .ok field.type
    | .storageArrayStructFieldWrite _ _ _ _ =>
        .error { message := "storage.array.struct.field.write is a statement effect, not an expression" }
    | .storageStructFieldRead stateId fieldName => do
        let (_, field) ← requireStructStateField module stateId fieldName
        .ok field.type
    | .storageStructFieldWrite _ _ _ =>
        .error { message := "storage.struct.field.write is a statement effect, not an expression" }
    | .storagePathRead stateId path =>
        inferStoragePathType module env stateId path
    | .storagePathWrite _ _ _ =>
        .error { message := "storage.path.write is a statement effect, not an expression" }
    | .storagePathAssignOp _ _ _ _ =>
        .error { message := "storage.path.assign_op is a statement effect, not an expression" }
    | .contextRead _ =>
        .ok .u64
    | .eventEmit _ _ =>
        .error { message := "event.emit is a statement effect, not an expression" }
end

def validateEffectStmtTypes (module : Module) (env : TypeEnv) : Effect → Except LowerError Unit
  | .storageScalarRead _ =>
      .error { message := "storage.scalar.read must be used as an expression" }
  | .storageScalarWrite stateId value => do
      ensureType s!"scalar state `{stateId}` write" (← scalarStateType module stateId) (← inferExprType module env value)
  | .storageScalarAssignOp stateId op value => do
      ensureAssignOpTypes op (← scalarStateType module stateId) (← inferExprType module env value)
  | .storageMapContains _ _ =>
      .ok ()
  | .storageMapGet _ _ =>
      .error { message := "storage.map.get must be used as an expression" }
  | .storageMapInsert stateId key value => do
      let (keyType, valueType) ← mapStateTypes module stateId
      ensureType s!"map `{stateId}` key" keyType (← inferExprType module env key)
      ensureType s!"map `{stateId}` value" valueType (← inferExprType module env value)
  | .storageMapSet stateId key value => do
      let (keyType, valueType) ← mapStateTypes module stateId
      ensureType s!"map `{stateId}` key" keyType (← inferExprType module env key)
      ensureType s!"map `{stateId}` value" valueType (← inferExprType module env value)
  | .storageArrayRead _ _ =>
      .error { message := "storage.array.read must be used as an expression" }
  | .storageArrayWrite stateId index value => do
      let (_, _, elementType) ← requireStorageArrayState module stateId
      ensureArrayIndexType s!"array state `{stateId}` index" (← inferExprType module env index)
      ensureType s!"array state `{stateId}` write" elementType (← inferExprType module env value)
  | .storageArrayStructFieldRead _ _ _ =>
      .error { message := "storage.array.struct.field.read must be used as an expression" }
  | .storageArrayStructFieldWrite stateId index fieldName value => do
      let (_, _, _, _, field) ← requireStructArrayStateField module stateId fieldName
      ensureArrayIndexType s!"struct array state `{stateId}` index" (← inferExprType module env index)
      ensureType s!"struct array state `{stateId}` field `{fieldName}` write" field.type (← inferExprType module env value)
  | .storageStructFieldRead _ _ =>
      .error { message := "storage.struct.field.read must be used as an expression" }
  | .storageStructFieldWrite stateId fieldName value => do
      let (_, field) ← requireStructStateField module stateId fieldName
      ensureType s!"struct state `{stateId}` field `{fieldName}` write" field.type (← inferExprType module env value)
  | .storagePathRead _ _ =>
      .error { message := "storage.path.read must be used as an expression" }
  | .storagePathWrite stateId path value => do
      ensureType s!"storage path `{stateId}` write" (← inferStoragePathType module env stateId path) (← inferExprType module env value)
  | .storagePathAssignOp stateId path op value => do
      ensureAssignOpTypes op (← inferStoragePathType module env stateId path) (← inferExprType module env value)
  | .contextRead _ =>
      .error { message := "context reads must be used as expressions" }
  | .eventEmit name fields => do
      discard <| eventNameWordAndLength name
      let _ ← fields.foldlM (init := #[]) fun seen field =>
        validateDistinctEventFieldName name seen field.fst
      for field in fields do
        let actual ← inferExprType module env field.snd
        ensureEventFieldType name field.fst actual

mutual
  partial def validateStatements (module : Module) (entrypoint : Entrypoint) (env : TypeEnv) (statements : Array Statement) : Except LowerError TypeEnv :=
    statements.foldlM (init := env) fun env stmt =>
      validateStatementTypes module entrypoint env stmt

  partial def validateStatementTypes (module : Module) (entrypoint : Entrypoint) (env : TypeEnv) : Statement → Except LowerError TypeEnv
    | .letBind name type value => do
        ensureType s!"let binding `{name}`" type (← inferExprType module env value)
        addLocal env name type false
    | .letMutBind name type value => do
        ensureType s!"mutable let binding `{name}`" type (← inferExprType module env value)
        addLocal env name type true
    | .assign (.local name) value => do
        let some binding := findLocal? env name
          | .error { message := s!"unknown local `{name}`" }
        if !binding.isMutable then
          .error { message := s!"assignment target local `{name}` is not mutable" }
        ensureType "assignment value" binding.type (← inferExprType module env value)
        .ok env
    | .assign _ _ =>
        .error { message := "assignment target must be a local in IR EVM v0" }
    | .assignOp (.local name) op value => do
        let some binding := findLocal? env name
          | .error { message := s!"unknown local `{name}`" }
        if !binding.isMutable then
          .error { message := s!"assignment target local `{name}` is not mutable" }
        ensureAssignOpTypes op binding.type (← inferExprType module env value)
        .ok env
    | .assignOp _ _ _ =>
        .error { message := "compound assignment target must be a local in IR EVM v0" }
    | .effect effect => do
        validateEffectStmtTypes module env effect
        .ok env
    | .assert condition _ => do
        ensureType "assert condition" .bool (← inferExprType module env condition)
        .ok env
    | .assertEq lhs rhs _ => do
        let lhsType ← inferExprType module env lhs
        let rhsType ← inferExprType module env rhs
        ensureType "assert_eq right operand" lhsType rhsType
        ensureEqType "assert_eq" lhsType
        .ok env
    | .ifElse condition thenBody elseBody => do
        ensureType "if condition" .bool (← inferExprType module env condition)
        discard <| validateStatements module entrypoint env thenBody
        discard <| validateStatements module entrypoint env elseBody
        .ok env
    | .boundedFor indexName start stopExclusive body => do
        if stopExclusive <= start then
          .error { message := s!"bounded loop `{indexName}` must have stop greater than start" }
        let loopEnv ← addLocal env indexName .u32 false
        discard <| validateStatements module entrypoint loopEnv body
        .ok env
    | .return value => do
        ensureType "return value" entrypoint.returns (← inferExprType module env value)
        .ok env
end

def entrypointTypeEnv (entrypoint : Entrypoint) : TypeEnv :=
  entrypoint.params.map fun param => {
    name := param.fst
    type := param.snd
    isMutable := false
  }

def validateEntrypointTypes (module : Module) (entrypoint : Entrypoint) : Except LowerError Unit := do
  discard <| validateStatements module entrypoint (entrypointTypeEnv entrypoint) entrypoint.body

mutual
  partial def lowerMapSlotExpr (module : Module) (stateId : String) (key : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Expr := do
    let slot ← requireU64MapState module stateId
    .ok (Lean.Compiler.Yul.call mapSlotFunctionName #[slotExpr slot, ← lowerExpr module key])

  partial def lowerMapGetExpr (module : Module) (stateId : String) (key : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Expr := do
    .ok (Lean.Compiler.Yul.builtin "sload" #[← lowerMapSlotExpr module stateId key])

  partial def lowerMapSetReturnExpr (module : Module) (stateId : String) (key value : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Expr := do
    let slot ← requireU64MapState module stateId
    .ok (Lean.Compiler.Yul.call mapSetReturnFunctionName #[slotExpr slot, ← lowerExpr module key, ← lowerExpr module value])

  partial def lowerArraySlotExpr (module : Module) (stateId : String) (index : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Expr := do
    let (slot, length, _) ← requireStorageArrayState module stateId
    .ok (Lean.Compiler.Yul.call arraySlotFunctionName #[slotExpr slot, Lean.Compiler.Yul.Expr.num length, ← lowerExpr module index])

  partial def lowerArrayReadExpr (module : Module) (stateId : String) (index : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Expr := do
    .ok (Lean.Compiler.Yul.builtin "sload" #[← lowerArraySlotExpr module stateId index])

  partial def lowerStructFieldSlotExpr
      (module : Module)
      (stateId fieldName : String) : Except LowerError Lean.Compiler.Yul.Expr := do
    let (slot, _) ← requireStructStateField module stateId fieldName
    .ok (slotExpr slot)

  partial def lowerStructFieldReadExpr
      (module : Module)
      (stateId fieldName : String) : Except LowerError Lean.Compiler.Yul.Expr := do
    .ok (Lean.Compiler.Yul.builtin "sload" #[← lowerStructFieldSlotExpr module stateId fieldName])

  partial def lowerStructArrayFieldSlotExpr
      (module : Module)
      (stateId : String)
      (index : ProofForge.IR.Expr)
      (fieldName : String) : Except LowerError Lean.Compiler.Yul.Expr := do
    let (slot, length, fieldCount, fieldOffset, _) ← requireStructArrayStateField module stateId fieldName
    .ok (Lean.Compiler.Yul.call structArraySlotFunctionName #[
      slotExpr slot,
      Lean.Compiler.Yul.Expr.num length,
      Lean.Compiler.Yul.Expr.num fieldCount,
      Lean.Compiler.Yul.Expr.num fieldOffset,
      ← lowerExpr module index
    ])

  partial def lowerStructArrayFieldReadExpr
      (module : Module)
      (stateId : String)
      (index : ProofForge.IR.Expr)
      (fieldName : String) : Except LowerError Lean.Compiler.Yul.Expr := do
    .ok (Lean.Compiler.Yul.builtin "sload" #[← lowerStructArrayFieldSlotExpr module stateId index fieldName])

  partial def lowerStoragePathReadExpr (module : Module) (stateId : String) (path : Array StoragePathSegment) : Except LowerError Lean.Compiler.Yul.Expr :=
    match path.toList with
    | [StoragePathSegment.mapKey key] => lowerMapGetExpr module stateId key
    | [StoragePathSegment.index index] => lowerArrayReadExpr module stateId index
    | [StoragePathSegment.field fieldName] => lowerStructFieldReadExpr module stateId fieldName
    | [StoragePathSegment.index index, StoragePathSegment.field fieldName] =>
        lowerStructArrayFieldReadExpr module stateId index fieldName
    | [] => do
        let state ← stateDeclOf module stateId "storage path"
        match state.kind with
        | .map _ _ => .error { message := s!"storage path state `{stateId}` is map storage; first segment must be a map key" }
        | .array _ => .error { message := s!"storage path state `{stateId}` is array storage; first segment must be an index" }
        | .scalar => .error { message := "scalar storage paths are not supported by IR EVM v0; use storage.scalar.read" }
    | _ => .error { message := "EVM IR v0 supports storage paths as mapKey, index, field, or index followed by field" }

  partial def lowerLocalFixedArrayGetExpr
      (module : Module)
      (array index : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Expr := do
    let indexValue ← requireStaticArrayIndex "fixed array indexing" index
    match array with
    | .local name =>
        .ok (Lean.Compiler.Yul.Expr.id (arrayLocalElementName name indexValue))
    | .arrayLit _ values =>
        if h : indexValue < values.size then
          lowerExpr module values[indexValue]
        else
          .error { message := s!"fixed array literal index {indexValue} is out of bounds for length {values.size}" }
    | _ =>
        .error {
          message := "fixed array indexing in IR EVM v0 supports local fixed-array values or array literals only"
        }

  partial def lowerLocalStructFieldExpr
      (module : Module)
      (base : ProofForge.IR.Expr)
      (fieldName : String) : Except LowerError Lean.Compiler.Yul.Expr :=
    match base with
    | .local name =>
        .ok (Lean.Compiler.Yul.Expr.id (structLocalFieldName name fieldName))
    | .structLit _ fields => do
        let some field := fields.find? fun field => field.fst == fieldName
          | .error { message := s!"struct literal has no field `{fieldName}`" }
        lowerExpr module field.snd
    | _ =>
        .error {
          message := "struct field access in IR EVM v0 supports local struct values or struct literals only"
        }

  partial def lowerExpr (module : Module) : ProofForge.IR.Expr → Except LowerError Lean.Compiler.Yul.Expr
    | .literal (.u32 value) => .ok (Lean.Compiler.Yul.Expr.num value)
    | .literal (.u64 value) => .ok (Lean.Compiler.Yul.Expr.num value)
    | .literal (.bool value) => .ok (if value then Lean.Compiler.Yul.Expr.num 1 else Lean.Compiler.Yul.Expr.num 0)
    | .literal (.hash4 a b c d) => do
        .ok (Lean.Compiler.Yul.Expr.num (← packedHashLiteral a b c d))
    | .local name => .ok (Lean.Compiler.Yul.Expr.id name)
    | .arrayLit _ _ =>
        .error { message := "fixed array literals must be consumed by a fixed array local binding or literal index in IR EVM v0" }
    | .arrayGet array index =>
        lowerLocalFixedArrayGetExpr module array index
    | .structLit _ _ =>
        .error { message := "struct literals must be consumed by a struct local binding or field access in IR EVM v0" }
    | .field base fieldName =>
        lowerLocalStructFieldExpr module base fieldName
    | .add lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "add" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .sub lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "sub" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .mul lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "mul" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .div lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "div" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .mod lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "mod" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .pow lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "exp" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .bitAnd lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "and" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .bitOr lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "or" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .bitXor lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "xor" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .shiftLeft lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "shl" #[← lowerExpr module rhs, ← lowerExpr module lhs])
    | .shiftRight lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "shr" #[← lowerExpr module rhs, ← lowerExpr module lhs])
    | .cast value _ => do
        lowerExpr module value
    | .eq lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "eq" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .ne lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "iszero" #[Lean.Compiler.Yul.builtin "eq" #[← lowerExpr module lhs, ← lowerExpr module rhs]])
    | .lt lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "lt" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .le lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "iszero" #[Lean.Compiler.Yul.builtin "gt" #[← lowerExpr module lhs, ← lowerExpr module rhs]])
    | .gt lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "gt" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .ge lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "iszero" #[Lean.Compiler.Yul.builtin "lt" #[← lowerExpr module lhs, ← lowerExpr module rhs]])
    | .boolAnd lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "and" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .boolOr lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "or" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .boolNot value => do
        .ok (Lean.Compiler.Yul.builtin "iszero" #[← lowerExpr module value])
    | .hashValue a b c d => do
        .ok (hashPackExpr (← lowerExpr module a) (← lowerExpr module b) (← lowerExpr module c) (← lowerExpr module d))
    | .hash preimage => do
        .ok (Lean.Compiler.Yul.call hashWordFunctionName #[← lowerExpr module preimage])
    | .hashTwoToOne lhs rhs => do
        .ok (Lean.Compiler.Yul.call hashPairFunctionName #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .nativeValue =>
        .ok (Lean.Compiler.Yul.builtin "callvalue" #[])
    | .crosscallInvoke target methodId args => do
        let mut callArgs := #[
          ← lowerExpr module target,
          ← lowerExpr module methodId
        ]
        for arg in args do
          callArgs := callArgs.push (← lowerExpr module arg)
        .ok (Lean.Compiler.Yul.call (crosscallFunctionName args.size) callArgs)
    | .effect effect => lowerEffectExpr module effect

  partial def lowerEffectExpr (module : Module) : Effect → Except LowerError Lean.Compiler.Yul.Expr
    | .storageScalarRead stateId => do
        discard <| scalarStateType module stateId
        let some slot := stateSlot? module stateId
          | .error { message := s!"unknown scalar state `{stateId}`" }
        .ok (Lean.Compiler.Yul.builtin "sload" #[slotExpr slot])
    | .storageScalarWrite _ _ =>
        .error { message := "storage.scalar.write is a statement effect, not an expression" }
    | .storageScalarAssignOp _ _ _ =>
        .error { message := "storage.scalar.assign_op is a statement effect, not an expression" }
    | .storageMapContains _ _ =>
        .error { message := "storage.map.contains is not supported by IR EVM v0 because EVM mappings do not track key presence" }
    | .storageMapGet stateId key =>
        lowerMapGetExpr module stateId key
    | .storageMapInsert stateId key value =>
        lowerMapSetReturnExpr module stateId key value
    | .storageMapSet stateId key value =>
        lowerMapSetReturnExpr module stateId key value
    | .storageArrayRead stateId index =>
        lowerArrayReadExpr module stateId index
    | .storageArrayWrite _ _ _ =>
        .error { message := "storage.array.write is a statement effect, not an expression" }
    | .storageArrayStructFieldRead stateId index fieldName =>
        lowerStructArrayFieldReadExpr module stateId index fieldName
    | .storageArrayStructFieldWrite _ _ _ _ =>
        .error { message := "storage.array.struct.field.write is a statement effect, not an expression" }
    | .storageStructFieldRead stateId fieldName =>
        lowerStructFieldReadExpr module stateId fieldName
    | .storageStructFieldWrite _ _ _ =>
        .error { message := "storage.struct.field.write is a statement effect, not an expression" }
    | .storagePathRead stateId path =>
        lowerStoragePathReadExpr module stateId path
    | .storagePathWrite _ _ _ =>
        .error { message := "storage.path.write is a statement effect, not an expression" }
    | .storagePathAssignOp _ _ _ _ =>
        .error { message := "storage.path.assign_op is a statement effect, not an expression" }
    | .contextRead field =>
        .ok (contextExpr field)
    | .eventEmit _ _ =>
        .error { message := "event.emit is a statement effect, not an expression" }
end

def lowerEventEmitStmt
    (module : Module)
    (name : String)
    (fields : Array (String × ProofForge.IR.Expr)) : Except LowerError Lean.Compiler.Yul.Statement := do
  let (nameWord, nameLen) ← eventNameWordAndLength name
  let mut statements : Array Lean.Compiler.Yul.Statement := #[
    .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num nameWord]),
    .varDecl #[{ name := "_topic0" }]
      (some (Lean.Compiler.Yul.builtin "keccak256" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num nameLen]))
  ]
  for h : idx in [0:fields.size] do
    let field := fields[idx]
    statements := statements.push <|
      .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num (idx * 32), ← lowerExpr module field.snd])
  statements := statements.push <|
    .exprStmt (Lean.Compiler.Yul.builtin "log1" #[
      Lean.Compiler.Yul.Expr.num 0,
      Lean.Compiler.Yul.Expr.num (fields.size * 32),
      Lean.Compiler.Yul.Expr.id "_topic0"
    ])
  .ok (.block { statements := statements })

def lowerMapWriteStmt (module : Module) (stateId : String) (key value : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Statement := do
  let slot ← requireU64MapState module stateId
  .ok (.exprStmt (Lean.Compiler.Yul.call mapWriteFunctionName #[slotExpr slot, ← lowerExpr module key, ← lowerExpr module value]))

def lowerArrayWriteStmt (module : Module) (stateId : String) (index value : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Statement := do
  .ok (.exprStmt (Lean.Compiler.Yul.builtin "sstore" #[← lowerArraySlotExpr module stateId index, ← lowerExpr module value]))

def lowerStructFieldWriteStmt
    (module : Module)
    (stateId fieldName : String)
    (value : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Statement := do
  let (slot, _) ← requireStructStateField module stateId fieldName
  .ok (.exprStmt (Lean.Compiler.Yul.builtin "sstore" #[slotExpr slot, ← lowerExpr module value]))

partial def lowerStructArrayFieldWriteStmt
    (module : Module)
    (stateId : String)
    (index : ProofForge.IR.Expr)
    (fieldName : String)
    (value : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Statement := do
  .ok (.exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
    ← lowerStructArrayFieldSlotExpr module stateId index fieldName,
    ← lowerExpr module value
  ]))

def lowerStoragePathWriteStmt
    (module : Module)
    (stateId : String)
    (path : Array StoragePathSegment)
    (value : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Statement :=
  match path.toList with
  | [StoragePathSegment.mapKey key] => lowerMapWriteStmt module stateId key value
  | [StoragePathSegment.index index] => lowerArrayWriteStmt module stateId index value
  | [StoragePathSegment.field fieldName] => lowerStructFieldWriteStmt module stateId fieldName value
  | [StoragePathSegment.index index, StoragePathSegment.field fieldName] =>
      lowerStructArrayFieldWriteStmt module stateId index fieldName value
  | [] => do
      let state ← stateDeclOf module stateId "storage path"
      match state.kind with
      | .map _ _ => .error { message := s!"storage path state `{stateId}` is map storage; first segment must be a map key" }
      | .array _ => .error { message := s!"storage path state `{stateId}` is array storage; first segment must be an index" }
      | .scalar => .error { message := "scalar storage paths are not supported by IR EVM v0; use storage.scalar.write" }
  | _ => .error { message := "EVM IR v0 supports storage paths as mapKey, index, field, or index followed by field" }

def lowerStoragePathAssignOpStmt
    (module : Module)
    (stateId : String)
    (path : Array StoragePathSegment)
    (op : AssignOp)
    (value : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Statement :=
  match path.toList with
  | [StoragePathSegment.mapKey key] => do
      let slot ← requireU64MapState module stateId
      .ok (.exprStmt (Lean.Compiler.Yul.call (mapAssignFunctionName op) #[slotExpr slot, ← lowerExpr module key, ← lowerExpr module value]))
  | [StoragePathSegment.index index] => do
      let storageSlot ← lowerArraySlotExpr module stateId index
      .ok (.block { statements := #[
        .varDecl #[{ name := "_slot" }] (some storageSlot),
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          Lean.Compiler.Yul.Expr.id "_slot",
          lowerAssignOpExpr op (Lean.Compiler.Yul.builtin "sload" #[Lean.Compiler.Yul.Expr.id "_slot"]) (← lowerExpr module value)
        ])
      ]})
  | [StoragePathSegment.field fieldName] => do
      let storageSlot ← lowerStructFieldSlotExpr module stateId fieldName
      .ok (.block { statements := #[
        .varDecl #[{ name := "_slot" }] (some storageSlot),
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          Lean.Compiler.Yul.Expr.id "_slot",
          lowerAssignOpExpr op (Lean.Compiler.Yul.builtin "sload" #[Lean.Compiler.Yul.Expr.id "_slot"]) (← lowerExpr module value)
        ])
      ]})
  | [StoragePathSegment.index index, StoragePathSegment.field fieldName] => do
      let storageSlot ← lowerStructArrayFieldSlotExpr module stateId index fieldName
      .ok (.block { statements := #[
        .varDecl #[{ name := "_slot" }] (some storageSlot),
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          Lean.Compiler.Yul.Expr.id "_slot",
          lowerAssignOpExpr op (Lean.Compiler.Yul.builtin "sload" #[Lean.Compiler.Yul.Expr.id "_slot"]) (← lowerExpr module value)
        ])
      ]})
  | [] => do
      let state ← stateDeclOf module stateId "storage path"
      match state.kind with
      | .map _ _ => .error { message := s!"storage path state `{stateId}` is map storage; first segment must be a map key" }
      | .array _ => .error { message := s!"storage path state `{stateId}` is array storage; first segment must be an index" }
      | .scalar => .error { message := "scalar storage paths are not supported by IR EVM v0; use storage.scalar.assign_op" }
  | _ => .error { message := "EVM IR v0 supports storage paths as mapKey, index, field, or index followed by field" }

def lowerEffectStmt (module : Module) : Effect → Except LowerError Lean.Compiler.Yul.Statement
  | .storageScalarRead _ =>
      .error { message := "storage.scalar.read must be used as an expression" }
  | .storageScalarWrite stateId value => do
      discard <| scalarStateType module stateId
      let some slot := stateSlot? module stateId
        | .error { message := s!"unknown scalar state `{stateId}`" }
      .ok (.exprStmt (Lean.Compiler.Yul.builtin "sstore" #[slotExpr slot, ← lowerExpr module value]))
  | .storageScalarAssignOp stateId op value => do
      discard <| scalarStateType module stateId
      let some slot := stateSlot? module stateId
        | .error { message := s!"unknown scalar state `{stateId}`" }
      let storageSlot := slotExpr slot
      .ok (.exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
        storageSlot,
        lowerAssignOpExpr op (Lean.Compiler.Yul.builtin "sload" #[storageSlot]) (← lowerExpr module value)
      ]))
  | .storageMapContains _ _ =>
      .error { message := "storage.map.contains must be used as an expression, but EVM mappings do not track key presence" }
  | .storageMapGet _ _ =>
      .error { message := "storage.map.get must be used as an expression" }
  | .storageMapInsert stateId key value =>
      lowerMapWriteStmt module stateId key value
  | .storageMapSet stateId key value =>
      lowerMapWriteStmt module stateId key value
  | .storageArrayRead _ _ =>
      .error { message := "storage.array.read must be used as an expression" }
  | .storageArrayWrite stateId index value =>
      lowerArrayWriteStmt module stateId index value
  | .storageArrayStructFieldRead _ _ _ =>
      .error { message := "storage.array.struct.field.read must be used as an expression" }
  | .storageArrayStructFieldWrite stateId index fieldName value =>
      lowerStructArrayFieldWriteStmt module stateId index fieldName value
  | .storageStructFieldRead _ _ =>
      .error { message := "storage.struct.field.read must be used as an expression" }
  | .storageStructFieldWrite stateId fieldName value =>
      lowerStructFieldWriteStmt module stateId fieldName value
  | .storagePathRead _ _ =>
      .error { message := "storage.path.read must be used as an expression" }
  | .storagePathWrite stateId path value =>
      lowerStoragePathWriteStmt module stateId path value
  | .storagePathAssignOp stateId path op value =>
      lowerStoragePathAssignOpStmt module stateId path op value
  | .contextRead _ =>
      .error { message := "context reads must be used as expressions" }
  | .eventEmit name fields =>
      lowerEventEmitStmt module name fields

def ensureLocalScalarType (context name : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 | .bool | .hash => .ok ()
  | .unit => .error { message := s!"{context} `{name}` has unsupported EVM IR v0 type `Unit`" }
  | .fixedArray _ _ => .error { message := s!"{context} `{name}` has unsupported EVM IR v0 type `{type.name}`" }
  | .structType _ => .error { message := s!"{context} `{name}` has unsupported EVM IR v0 type `{type.name}`" }

def ensureLocalFixedArrayElementType (context name : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 | .bool | .hash => .ok ()
  | .unit | .fixedArray _ _ | .structType _ =>
      .error {
        message := s!"{context} `{name}` has unsupported EVM IR v0 fixed-array element type `{type.name}`; local fixed arrays support U32, U64, Bool, or Hash elements"
      }

def lowerFixedArrayLetBinding
    (module : Module)
    (name : String)
    (elementType : ValueType)
    (length : Nat)
    (value : ProofForge.IR.Expr) : Except LowerError (Array Lean.Compiler.Yul.Statement) := do
  if length == 0 then
    .error { message := s!"let binding `{name}` fixed array must have non-zero length in IR EVM v0" }
  ensureLocalFixedArrayElementType "let binding" name elementType
  match value with
  | .arrayLit literalElementType values => do
      ensureType s!"let binding `{name}` fixed-array element type" elementType literalElementType
      if values.size != length then
        .error {
          message := s!"let binding `{name}` expected fixed array length {length}, got {values.size}"
        }
      let mut statements : Array Lean.Compiler.Yul.Statement := #[]
      for h : index in [0:values.size] do
        statements := statements.push <|
          Lean.Compiler.Yul.Statement.varDecl
            #[{ name := arrayLocalElementName name index }]
            (some (← lowerExpr module values[index]))
      .ok statements
  | _ =>
      .error {
        message := s!"let binding `{name}` fixed array must be initialized from an array literal in IR EVM v0"
      }

def lowerStructLetBinding
    (module : Module)
    (name : String)
    (typeName : String)
    (value : ProofForge.IR.Expr) : Except LowerError (Array Lean.Compiler.Yul.Statement) := do
  let some decl := findStruct? module typeName
    | .error { message := s!"unknown struct `{typeName}`" }
  match value with
  | .structLit literalTypeName fields => do
      if literalTypeName != typeName then
        .error { message := s!"let binding `{name}` expected struct `{typeName}`, got `{literalTypeName}`" }
      let mut statements : Array Lean.Compiler.Yul.Statement := #[]
      for fieldDecl in decl.fields do
        ensureStructLocalFieldType typeName fieldDecl.id fieldDecl.type
        let some field := fields.find? fun field => field.fst == fieldDecl.id
          | .error { message := s!"struct literal `{typeName}` is missing field `{fieldDecl.id}`" }
        statements := statements.push <|
          Lean.Compiler.Yul.Statement.varDecl
            #[{ name := structLocalFieldName name fieldDecl.id }]
            (some (← lowerExpr module field.snd))
      .ok statements
  | _ =>
      .error {
        message := s!"let binding `{name}` struct must be initialized from a struct literal in IR EVM v0"
      }

partial def hasNestedReturn (statements : Array Statement) : Bool :=
  statements.any fun stmt =>
    match stmt with
    | .return _ => true
    | .ifElse _ thenBody elseBody => hasNestedReturn thenBody || hasNestedReturn elseBody
    | .boundedFor _ _ _ body => hasNestedReturn body
    | _ => false

def abiReturnNames (module : Module) (entrypointName : String) : ValueType → Except LowerError (Array String)
  | .unit => .ok #[]
  | .u32 | .u64 | .bool | .hash => .ok #["result"]
  | .fixedArray elementType length => do
      let words ← abiValueWordTypes module s!"entrypoint `{entrypointName}` return value" (.fixedArray elementType length)
      let mut names : Array String := #[]
      for _h : idx in [0:words.size] do
        names := names.push (abiReturnName idx)
      .ok names
  | .structType typeName => do
      let words ← abiValueWordTypes module s!"entrypoint `{entrypointName}` return value" (.structType typeName)
      let mut names : Array String := #[]
      for _h : idx in [0:words.size] do
        names := names.push (abiReturnName idx)
      .ok names

def abiReturnTypedNames (module : Module) (entrypoint : Entrypoint) : Except LowerError (Array Lean.Compiler.Yul.TypedName) := do
  let names ← abiReturnNames module entrypoint.name entrypoint.returns
  .ok (names.map fun name => ({ name := name } : Lean.Compiler.Yul.TypedName))

def lowerFixedArrayReturnWords
    (module : Module)
    (entrypointName : String)
    (elementType : ValueType)
    (length : Nat)
    (value : ProofForge.IR.Expr) : Except LowerError (Array Lean.Compiler.Yul.Expr) := do
  discard <| abiValueWordTypes module s!"entrypoint `{entrypointName}` return value" (.fixedArray elementType length)
  match value with
  | .local name => do
      let mut words : Array Lean.Compiler.Yul.Expr := #[]
      for h : idx in [0:length] do
        words := words.push (Lean.Compiler.Yul.Expr.id (arrayLocalElementName name idx))
      .ok words
  | .arrayLit literalElementType values => do
      ensureType s!"entrypoint `{entrypointName}` fixed-array return element type" elementType literalElementType
      if values.size != length then
        .error {
          message := s!"entrypoint `{entrypointName}` fixed-array return expected length {length}, got {values.size}"
        }
      let mut words : Array Lean.Compiler.Yul.Expr := #[]
      for h : idx in [0:values.size] do
        words := words.push (← lowerExpr module values[idx])
      .ok words
  | _ =>
      .error {
        message := s!"entrypoint `{entrypointName}` fixed-array returns in IR EVM v0 support local fixed-array values or array literals only"
      }

def lowerStructReturnWords
    (module : Module)
    (entrypointName typeName : String)
    (value : ProofForge.IR.Expr) : Except LowerError (Array Lean.Compiler.Yul.Expr) := do
  discard <| abiValueWordTypes module s!"entrypoint `{entrypointName}` return value" (.structType typeName)
  let some decl := findStruct? module typeName
    | .error { message := s!"entrypoint `{entrypointName}` return value uses unknown struct `{typeName}`" }
  match value with
  | .local name => do
      let mut words : Array Lean.Compiler.Yul.Expr := #[]
      for fieldDecl in decl.fields do
        ensureStructLocalFieldType typeName fieldDecl.id fieldDecl.type
        words := words.push (Lean.Compiler.Yul.Expr.id (structLocalFieldName name fieldDecl.id))
      .ok words
  | .structLit literalTypeName fields => do
      if literalTypeName != typeName then
        .error { message := s!"entrypoint `{entrypointName}` struct return expected `{typeName}`, got `{literalTypeName}`" }
      let mut words : Array Lean.Compiler.Yul.Expr := #[]
      for fieldDecl in decl.fields do
        ensureStructLocalFieldType typeName fieldDecl.id fieldDecl.type
        let some field := fields.find? fun field => field.fst == fieldDecl.id
          | .error { message := s!"struct literal `{typeName}` is missing field `{fieldDecl.id}`" }
        words := words.push (← lowerExpr module field.snd)
      .ok words
  | _ =>
      .error {
        message := s!"entrypoint `{entrypointName}` struct returns in IR EVM v0 support local struct values or struct literals only"
      }

def lowerReturnWords
    (module : Module)
    (entrypointName : String)
    (returnType : ValueType)
    (value : ProofForge.IR.Expr) : Except LowerError (Array Lean.Compiler.Yul.Expr) :=
  match returnType with
  | .unit =>
      .error { message := s!"entrypoint `{entrypointName}` has Unit return type and cannot return a value" }
  | .u32 | .u64 | .bool | .hash => do
      .ok #[← lowerExpr module value]
  | .fixedArray elementType length =>
      lowerFixedArrayReturnWords module entrypointName elementType length value
  | .structType typeName =>
      lowerStructReturnWords module entrypointName typeName value

def lowerReturnAssignments
    (module : Module)
    (entrypointName : String)
    (returnType : ValueType)
    (value : ProofForge.IR.Expr) : Except LowerError (Array Lean.Compiler.Yul.Statement) := do
  let names ← abiReturnNames module entrypointName returnType
  let words ← lowerReturnWords module entrypointName returnType value
  if names.size != words.size then
    .error { message := s!"entrypoint `{entrypointName}` return lowering produced {words.size} word(s), expected {names.size}" }
  let mut statements : Array Lean.Compiler.Yul.Statement := #[]
  for h : idx in [0:names.size] do
    let some word := words[idx]?
      | .error { message := s!"entrypoint `{entrypointName}` return lowering is missing word {idx}" }
    statements := statements.push (.assignment #[names[idx]] word)
  .ok statements

mutual
  partial def lowerStatements
      (module : Module)
      (entrypointName : String)
      (returnType : ValueType)
      (statements : Array Statement) : Except LowerError (Array Lean.Compiler.Yul.Statement) :=
    statements.foldlM (init := #[]) fun acc stmt => do
      .ok (acc ++ (← lowerStatement module entrypointName returnType stmt))

  partial def lowerStatement
      (module : Module)
      (entrypointName : String)
      (returnType : ValueType) : ProofForge.IR.Statement → Except LowerError (Array Lean.Compiler.Yul.Statement)
    | .letBind name (.fixedArray elementType length) value =>
        lowerFixedArrayLetBinding module name elementType length value
    | .letBind name (.structType typeName) value =>
        lowerStructLetBinding module name typeName value
    | .letBind name type value => do
        ensureLocalScalarType "let binding" name type
        .ok #[.varDecl #[({ name := name } : Lean.Compiler.Yul.TypedName)] (some (← lowerExpr module value))]
    | .letMutBind name type value => do
        ensureLocalScalarType "mutable let binding" name type
        .ok #[.varDecl #[({ name := name } : Lean.Compiler.Yul.TypedName)] (some (← lowerExpr module value))]
    | .assign (.local name) value => do
        .ok #[.assignment #[name] (← lowerExpr module value)]
    | .assign _ _ =>
        .error { message := "assignment target must be a local in IR EVM v0" }
    | .assignOp (.local name) op value => do
        .ok #[.assignment #[name] (lowerAssignOpExpr op (Lean.Compiler.Yul.Expr.id name) (← lowerExpr module value))]
    | .assignOp _ _ _ =>
        .error { message := "compound assignment target must be a local in IR EVM v0" }
    | .effect effect => do
        .ok #[← lowerEffectStmt module effect]
    | .assert condition _ => do
        .ok #[lowerAssertStmt (← lowerExpr module condition)]
    | .assertEq lhs rhs _ => do
        let condition := Lean.Compiler.Yul.builtin "eq" #[← lowerExpr module lhs, ← lowerExpr module rhs]
        .ok #[lowerAssertStmt condition]
    | .ifElse condition thenBody elseBody => do
        if hasNestedReturn thenBody || hasNestedReturn elseBody then
          .error { message := "return statements inside if/else branches are not supported by IR EVM v0; return must be the final entrypoint statement" }
        let thenStatements ← lowerStatements module entrypointName returnType thenBody
        let elseStatements ← lowerStatements module entrypointName returnType elseBody
        .ok #[.switchStmt (← lowerExpr module condition) #[
          {
            value := some (Lean.Compiler.Yul.Literal.natLit 0)
            body := { statements := elseStatements }
          },
          {
            value := none
            body := { statements := thenStatements }
          }
        ]]
    | .boundedFor indexName start stopExclusive body => do
        if stopExclusive <= start then
          .error { message := s!"bounded loop `{indexName}` must have stop greater than start" }
        if hasNestedReturn body then
          .error { message := "return statements inside bounded for loops are not supported by IR EVM v0; return must be the final entrypoint statement" }
        let bodyStatements ← lowerStatements module entrypointName returnType body
        .ok #[.forLoop
          { statements := #[
            .varDecl #[{ name := indexName }] (some (Lean.Compiler.Yul.Expr.num start))
          ] }
          (Lean.Compiler.Yul.builtin "lt" #[Lean.Compiler.Yul.Expr.id indexName, Lean.Compiler.Yul.Expr.num stopExclusive])
          { statements := #[
            .assignment #[indexName] (Lean.Compiler.Yul.builtin "add" #[Lean.Compiler.Yul.Expr.id indexName, Lean.Compiler.Yul.Expr.num 1])
          ] }
          { statements := bodyStatements }]
    | .return value => do
        lowerReturnAssignments module entrypointName returnType value
end

def lowerEntrypoint (module : Module) (entrypoint : Entrypoint) : Except LowerError Lean.Compiler.Yul.Statement := do
  let params ← lowerEntrypointParams module entrypoint
  match entrypoint.returns with
  | .unit => pure ()
  | _ =>
      match entrypoint.body.back? with
      | some (.return _) => pure ()
      | _ =>
          .error { message := s!"entrypoint `{entrypoint.name}` returns `{entrypoint.returns.name}` but does not end with a return statement" }
  validateEntrypointTypes module entrypoint
  let body ← lowerStatements module entrypoint.name entrypoint.returns entrypoint.body
  let returns ← abiReturnTypedNames module entrypoint
  .ok (.funcDef (yulFunctionName module.name entrypoint.name) params returns { statements := body })

def entrypointCallExpr (module : Module) (entrypoint : Entrypoint) : Except LowerError Lean.Compiler.Yul.Expr := do
  .ok (Lean.Compiler.Yul.call (yulFunctionName module.name entrypoint.name) (← entrypointCallArgs module entrypoint))

def dispatchResultNames (wordCount : Nat) : Array String :=
  if wordCount == 1 then
    #["_r"]
  else
    Id.run do
      let mut names : Array String := #[]
      for _h : idx in [0:wordCount] do
        names := names.push (abiDispatchResultName idx)
      names

def dispatchReturnStatements
    (module : Module)
    (entrypoint : Entrypoint)
    (callExpr : Lean.Compiler.Yul.Expr) : Except LowerError (Array Lean.Compiler.Yul.Statement) := do
  let validationStmts ← abiParamValidationStmts module entrypoint
  match entrypoint.returns with
  | .unit =>
      .ok (validationStmts ++ #[
        Lean.Compiler.Yul.Statement.exprStmt callExpr,
        Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])
      ])
  | _ => do
      let wordTypes ← abiValueWordTypes module s!"entrypoint `{entrypoint.name}` return value" entrypoint.returns
      let resultNames := dispatchResultNames wordTypes.size
      let mut statements : Array Lean.Compiler.Yul.Statement :=
        validationStmts ++ #[
          Lean.Compiler.Yul.Statement.varDecl
            (resultNames.map fun name => ({ name := name } : Lean.Compiler.Yul.TypedName))
            (some callExpr)
        ]
      for h : idx in [0:resultNames.size] do
        statements := statements.push <|
          Lean.Compiler.Yul.Statement.exprStmt
            (Lean.Compiler.Yul.builtin "mstore" #[
              Lean.Compiler.Yul.Expr.num (idx * 32),
              Lean.Compiler.Yul.Expr.id resultNames[idx]
            ])
      statements := statements.push <|
        Lean.Compiler.Yul.Statement.exprStmt
          (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num (wordTypes.size * 32)])
      .ok statements

def dispatchCase (module : Module) (entrypoint : Entrypoint) : Except LowerError Lean.Compiler.Yul.Case := do
  let some selector := entrypoint.selector?
    | .error { message := s!"entrypoint `{entrypoint.name}` has no EVM selector metadata" }
  let callExpr ← entrypointCallExpr module entrypoint
  let bodyStmts ← dispatchReturnStatements module entrypoint callExpr
  .ok {
    value := some (Lean.Compiler.Yul.Literal.hex ("0x" ++ selector))
    body := { statements := bodyStmts }
  }

def dispatchBlock (module : Module) : Except LowerError Lean.Compiler.Yul.Statement := do
  let selectorExpr := Lean.Compiler.Yul.builtin "shr" #[
    Lean.Compiler.Yul.Expr.num 224,
    Lean.Compiler.Yul.builtin "calldataload" #[Lean.Compiler.Yul.Expr.num 0]
  ]
  let cases ← module.entrypoints.foldlM (init := #[]) fun acc entrypoint => do
    .ok (acc.push (← dispatchCase module entrypoint))
  let defaultCase : Lean.Compiler.Yul.Case := {
    value := none
    body := {
      statements := #[revertStmt]
    }
  }
  .ok (.switchStmt selectorExpr (cases.push defaultCase))

def isSupportedMapState (state : StateDecl) : Bool :=
  match state.kind, state.type with
  | .map .u64 _, .u64 => true
  | _, _ => false

def moduleUsesSupportedMap (module : Module) : Bool :=
  module.state.any isSupportedMapState

def isSupportedArrayState (state : StateDecl) : Bool :=
  match state.kind, state.type with
  | .array length, elementType => length > 0 && isStorageWordType elementType
  | _, _ => false

def moduleUsesSupportedArray (module : Module) : Bool :=
  module.state.any isSupportedArrayState

def moduleUsesSupportedStructArray (module : Module) : Bool :=
  module.state.any fun state =>
    match state.kind, state.type with
    | .array length, .structType typeName =>
        length > 0 && (findStruct? module typeName).isSome
    | _, _ => false

def moduleUsesHash (module : Module) : Bool :=
  module.capabilities.contains .cryptoHash

def hashHelperFunctions : Array Lean.Compiler.Yul.Statement := #[
  .funcDef hashWordFunctionName
    #[{ name := "value" }]
    #[{ name := "result" }]
    {
      statements := #[
        .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.id "value"]),
        .assignment #["result"] (Lean.Compiler.Yul.builtin "keccak256" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 32])
      ]
    },
  .funcDef hashPairFunctionName
    #[{ name := "left" }, { name := "right" }]
    #[{ name := "result" }]
    {
      statements := #[
        .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.id "left"]),
        .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 32, Lean.Compiler.Yul.Expr.id "right"]),
        .assignment #["result"] (Lean.Compiler.Yul.builtin "keccak256" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 64])
      ]
    }
]

def mapBaseHelperFunctions : Array Lean.Compiler.Yul.Statement := #[
  .funcDef mapSlotFunctionName
    #[{ name := "slot" }, { name := "key" }]
    #[{ name := "result" }]
    {
      statements := #[
        .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.id "key"]),
        .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 32, Lean.Compiler.Yul.Expr.id "slot"]),
        .assignment #["result"] (Lean.Compiler.Yul.builtin "keccak256" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 64])
      ]
    },
  .funcDef mapWriteFunctionName
    #[{ name := "slot" }, { name := "key" }, { name := "value" }]
    #[]
    {
      statements := #[
        .varDecl #[{ name := "_slot" }] (some (Lean.Compiler.Yul.call mapSlotFunctionName #[Lean.Compiler.Yul.Expr.id "slot", Lean.Compiler.Yul.Expr.id "key"])),
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[Lean.Compiler.Yul.Expr.id "_slot", Lean.Compiler.Yul.Expr.id "value"])
      ]
    },
  .funcDef mapSetReturnFunctionName
    #[{ name := "slot" }, { name := "key" }, { name := "value" }]
    #[{ name := "old" }]
    {
      statements := #[
        .varDecl #[{ name := "_slot" }] (some (Lean.Compiler.Yul.call mapSlotFunctionName #[Lean.Compiler.Yul.Expr.id "slot", Lean.Compiler.Yul.Expr.id "key"])),
        .assignment #["old"] (Lean.Compiler.Yul.builtin "sload" #[Lean.Compiler.Yul.Expr.id "_slot"]),
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[Lean.Compiler.Yul.Expr.id "_slot", Lean.Compiler.Yul.Expr.id "value"])
      ]
    }
]

def mapAssignHelperFunction (op : AssignOp) : Lean.Compiler.Yul.Statement :=
  .funcDef (mapAssignFunctionName op)
    #[{ name := "slot" }, { name := "key" }, { name := "value" }]
    #[]
    {
      statements := #[
        .varDecl #[{ name := "_slot" }] (some (Lean.Compiler.Yul.call mapSlotFunctionName #[Lean.Compiler.Yul.Expr.id "slot", Lean.Compiler.Yul.Expr.id "key"])),
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          Lean.Compiler.Yul.Expr.id "_slot",
          lowerAssignOpExpr op (Lean.Compiler.Yul.builtin "sload" #[Lean.Compiler.Yul.Expr.id "_slot"]) (Lean.Compiler.Yul.Expr.id "value")
        ])
      ]
    }

def mapHelperFunctions (assignOps : Array AssignOp) : Array Lean.Compiler.Yul.Statement :=
  mapBaseHelperFunctions ++ assignOps.map mapAssignHelperFunction

def arrayHelperFunctions : Array Lean.Compiler.Yul.Statement := #[
  .funcDef arraySlotFunctionName
    #[{ name := "slot" }, { name := "length" }, { name := "index" }]
    #[{ name := "result" }]
    {
      statements := #[
        .ifStmt
          (Lean.Compiler.Yul.builtin "iszero" #[Lean.Compiler.Yul.builtin "lt" #[Lean.Compiler.Yul.Expr.id "index", Lean.Compiler.Yul.Expr.id "length"]])
          { statements := #[revertStmt] },
        .assignment #["result"] (Lean.Compiler.Yul.builtin "add" #[Lean.Compiler.Yul.Expr.id "slot", Lean.Compiler.Yul.Expr.id "index"])
      ]
    }
]

def structArrayHelperFunctions : Array Lean.Compiler.Yul.Statement := #[
  .funcDef structArraySlotFunctionName
    #[
      { name := "slot" },
      { name := "length" },
      { name := "field_count" },
      { name := "field_offset" },
      { name := "index" }
    ]
    #[{ name := "result" }]
    {
      statements := #[
        .ifStmt
          (Lean.Compiler.Yul.builtin "iszero" #[Lean.Compiler.Yul.builtin "lt" #[Lean.Compiler.Yul.Expr.id "index", Lean.Compiler.Yul.Expr.id "length"]])
          { statements := #[revertStmt] },
        .assignment #["result"] (Lean.Compiler.Yul.builtin "add" #[
          Lean.Compiler.Yul.builtin "add" #[
            Lean.Compiler.Yul.Expr.id "slot",
            Lean.Compiler.Yul.builtin "mul" #[Lean.Compiler.Yul.Expr.id "index", Lean.Compiler.Yul.Expr.id "field_count"]
          ],
          Lean.Compiler.Yul.Expr.id "field_offset"
        ])
      ]
    }
]

def crosscallArgName (idx : Nat) : String :=
  s!"arg{idx}"

def crosscallCalldataSize (arity : Nat) : Nat :=
  4 + arity * 32

def crosscallFunctionParams (arity : Nat) : Array Lean.Compiler.Yul.TypedName :=
  go 0 #[
    ({ name := "target" } : Lean.Compiler.Yul.TypedName),
    ({ name := "selector" } : Lean.Compiler.Yul.TypedName)
  ]
where
  go (idx : Nat) (acc : Array Lean.Compiler.Yul.TypedName) : Array Lean.Compiler.Yul.TypedName :=
    if h : idx < arity then
      go (idx + 1) (acc.push ({ name := crosscallArgName idx } : Lean.Compiler.Yul.TypedName))
    else
      acc

def crosscallArgStoreStatements (arity : Nat) : Array Lean.Compiler.Yul.Statement :=
  go 0 #[]
where
  go (idx : Nat) (acc : Array Lean.Compiler.Yul.Statement) : Array Lean.Compiler.Yul.Statement :=
    if h : idx < arity then
      let store := Lean.Compiler.Yul.Statement.exprStmt
        (Lean.Compiler.Yul.builtin "mstore" #[
          Lean.Compiler.Yul.Expr.num (4 + idx * 32),
          Lean.Compiler.Yul.Expr.id (crosscallArgName idx)
        ])
      go (idx + 1) (acc.push store)
    else
      acc

def crosscallHelperFunction (arity : Nat) : Lean.Compiler.Yul.Statement :=
  .funcDef (crosscallFunctionName arity)
    (crosscallFunctionParams arity)
    #[{ name := "result" }]
    {
      statements :=
        #[
          .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[
            Lean.Compiler.Yul.Expr.num 0,
            Lean.Compiler.Yul.builtin "shl" #[
              Lean.Compiler.Yul.Expr.num 224,
              Lean.Compiler.Yul.Expr.id "selector"
            ]
          ])
        ] ++
        crosscallArgStoreStatements arity ++
        #[
          .varDecl #[{ name := "_success" }]
            (some (Lean.Compiler.Yul.builtin "call" #[
              Lean.Compiler.Yul.builtin "gas" #[],
              Lean.Compiler.Yul.Expr.id "target",
              Lean.Compiler.Yul.Expr.num 0,
              Lean.Compiler.Yul.Expr.num 0,
              Lean.Compiler.Yul.Expr.num (crosscallCalldataSize arity),
              Lean.Compiler.Yul.Expr.num 0,
              Lean.Compiler.Yul.Expr.num 32
            ])),
          .ifStmt
            (Lean.Compiler.Yul.builtin "iszero" #[Lean.Compiler.Yul.Expr.id "_success"])
            { statements := #[revertStmt] },
          .ifStmt
            (Lean.Compiler.Yul.builtin "lt" #[
              Lean.Compiler.Yul.builtin "returndatasize" #[],
              Lean.Compiler.Yul.Expr.num 32
            ])
            { statements := #[revertStmt] },
          .exprStmt (Lean.Compiler.Yul.builtin "returndatacopy" #[
            Lean.Compiler.Yul.Expr.num 0,
            Lean.Compiler.Yul.Expr.num 0,
            Lean.Compiler.Yul.Expr.num 32
          ]),
          .assignment #["result"] (Lean.Compiler.Yul.builtin "mload" #[Lean.Compiler.Yul.Expr.num 0])
        ]
    }

def pushNatIfMissing (acc : Array Nat) (value : Nat) : Array Nat :=
  if acc.contains value then acc else acc.push value

def mergeNatSets (lhs rhs : Array Nat) : Array Nat :=
  rhs.foldl pushNatIfMissing lhs

mutual
  partial def crosscallAritiesExpr : ProofForge.IR.Expr → Array Nat
    | .literal _ => #[]
    | .local _ => #[]
    | .arrayLit _ values =>
        values.foldl (init := #[]) fun acc value => mergeNatSets acc (crosscallAritiesExpr value)
    | .arrayGet array index =>
        mergeNatSets (crosscallAritiesExpr array) (crosscallAritiesExpr index)
    | .structLit _ fields =>
        fields.foldl (init := #[]) fun acc field => mergeNatSets acc (crosscallAritiesExpr field.snd)
    | .field base _ =>
        crosscallAritiesExpr base
    | .add lhs rhs | .sub lhs rhs | .mul lhs rhs | .div lhs rhs | .mod lhs rhs
    | .pow lhs rhs | .bitAnd lhs rhs | .bitOr lhs rhs | .bitXor lhs rhs
    | .shiftLeft lhs rhs | .shiftRight lhs rhs | .eq lhs rhs | .ne lhs rhs
    | .lt lhs rhs | .le lhs rhs | .gt lhs rhs | .ge lhs rhs
    | .boolAnd lhs rhs | .boolOr lhs rhs | .hashTwoToOne lhs rhs =>
        mergeNatSets (crosscallAritiesExpr lhs) (crosscallAritiesExpr rhs)
    | .cast value _ | .boolNot value | .hash value =>
        crosscallAritiesExpr value
    | .hashValue a b c d =>
        mergeNatSets (mergeNatSets (crosscallAritiesExpr a) (crosscallAritiesExpr b))
          (mergeNatSets (crosscallAritiesExpr c) (crosscallAritiesExpr d))
    | .nativeValue => #[]
    | .crosscallInvoke target methodId args =>
        let nested := mergeNatSets (crosscallAritiesExpr target) (crosscallAritiesExpr methodId)
        let nested := args.foldl (init := nested) fun acc arg =>
          mergeNatSets acc (crosscallAritiesExpr arg)
        pushNatIfMissing nested args.size
    | .effect effect =>
        crosscallAritiesEffect effect

  partial def crosscallAritiesEffect : Effect → Array Nat
    | .storageScalarRead _ => #[]
    | .storageScalarWrite _ value =>
        crosscallAritiesExpr value
    | .storageScalarAssignOp _ _ value =>
        crosscallAritiesExpr value
    | .storageMapContains _ key =>
        crosscallAritiesExpr key
    | .storageMapGet _ key =>
        crosscallAritiesExpr key
    | .storageMapInsert _ key value | .storageMapSet _ key value =>
        mergeNatSets (crosscallAritiesExpr key) (crosscallAritiesExpr value)
    | .storageArrayRead _ index =>
        crosscallAritiesExpr index
    | .storageArrayWrite _ index value | .storageArrayStructFieldWrite _ index _ value =>
        mergeNatSets (crosscallAritiesExpr index) (crosscallAritiesExpr value)
    | .storageArrayStructFieldRead _ index _ =>
        crosscallAritiesExpr index
    | .storageStructFieldRead _ _ => #[]
    | .storageStructFieldWrite _ _ value =>
        crosscallAritiesExpr value
    | .storagePathRead _ path =>
        path.foldl (init := #[]) fun acc segment => mergeNatSets acc (crosscallAritiesStoragePathSegment segment)
    | .storagePathWrite _ path value =>
        let pathArities := path.foldl (init := #[]) fun acc segment =>
          mergeNatSets acc (crosscallAritiesStoragePathSegment segment)
        mergeNatSets pathArities (crosscallAritiesExpr value)
    | .storagePathAssignOp _ path _ value =>
        let pathArities := path.foldl (init := #[]) fun acc segment =>
          mergeNatSets acc (crosscallAritiesStoragePathSegment segment)
        mergeNatSets pathArities (crosscallAritiesExpr value)
    | .contextRead _ => #[]
    | .eventEmit _ fields =>
        fields.foldl (init := #[]) fun acc field => mergeNatSets acc (crosscallAritiesExpr field.snd)

  partial def crosscallAritiesStoragePathSegment : StoragePathSegment → Array Nat
    | .field _ => #[]
    | .index index => crosscallAritiesExpr index
    | .mapKey key => crosscallAritiesExpr key

  partial def crosscallAritiesStatement : Statement → Array Nat
    | .letBind _ _ value | .letMutBind _ _ value =>
        crosscallAritiesExpr value
    | .assign target value =>
        mergeNatSets (crosscallAritiesExpr target) (crosscallAritiesExpr value)
    | .assignOp target _ value =>
        mergeNatSets (crosscallAritiesExpr target) (crosscallAritiesExpr value)
    | .effect effect =>
        crosscallAritiesEffect effect
    | .assert condition _ =>
        crosscallAritiesExpr condition
    | .assertEq lhs rhs _ =>
        mergeNatSets (crosscallAritiesExpr lhs) (crosscallAritiesExpr rhs)
    | .ifElse condition thenBody elseBody =>
        let bodyArities := mergeNatSets (crosscallAritiesStatements thenBody) (crosscallAritiesStatements elseBody)
        mergeNatSets (crosscallAritiesExpr condition) bodyArities
    | .boundedFor _ _ _ body =>
        crosscallAritiesStatements body
    | .return value =>
        crosscallAritiesExpr value

  partial def crosscallAritiesStatements (statements : Array Statement) : Array Nat :=
    statements.foldl (init := #[]) fun acc stmt => mergeNatSets acc (crosscallAritiesStatement stmt)
end

def moduleCrosscallArities (module : Module) : Array Nat :=
  module.entrypoints.foldl (init := #[]) fun acc entrypoint =>
    mergeNatSets acc (crosscallAritiesStatements entrypoint.body)

def crosscallHelperFunctions (arities : Array Nat) : Array Lean.Compiler.Yul.Statement :=
  arities.map crosscallHelperFunction

def pushAssignOpIfMissing (acc : Array AssignOp) (value : AssignOp) : Array AssignOp :=
  if acc.any (fun existing => existing == value) then acc else acc.push value

def mergeAssignOpSets (lhs rhs : Array AssignOp) : Array AssignOp :=
  rhs.foldl pushAssignOpIfMissing lhs

mutual
  partial def storagePathAssignOpsStatement : Statement → Array AssignOp
    | .effect (.storagePathAssignOp _ _ op _) =>
        #[op]
    | .ifElse _ thenBody elseBody =>
        mergeAssignOpSets (storagePathAssignOpsStatements thenBody) (storagePathAssignOpsStatements elseBody)
    | .boundedFor _ _ _ body =>
        storagePathAssignOpsStatements body
    | _ =>
        #[]

  partial def storagePathAssignOpsStatements (statements : Array Statement) : Array AssignOp :=
    statements.foldl (init := #[]) fun acc stmt =>
      mergeAssignOpSets acc (storagePathAssignOpsStatement stmt)
end

def moduleStoragePathAssignOps (module : Module) : Array AssignOp :=
  module.entrypoints.foldl (init := #[]) fun acc entrypoint =>
    mergeAssignOpSets acc (storagePathAssignOpsStatements entrypoint.body)

def validateDistinctStructName (seen : Array String) (name : String) : Except LowerError (Array String) :=
  if name.isEmpty then
    .error { message := "struct name must be non-empty for IR EVM v0" }
  else if seen.contains name then
    .error { message := s!"duplicate struct `{name}`" }
  else
    .ok (seen.push name)

def validateDistinctStructFieldName (structName : String) (seen : Array String) (fieldName : String) : Except LowerError (Array String) :=
  if fieldName.isEmpty then
    .error { message := s!"struct `{structName}` field name must be non-empty" }
  else if seen.contains fieldName then
    .error { message := s!"duplicate field `{fieldName}` in struct `{structName}`" }
  else
    .ok (seen.push fieldName)

def validateStructs (module : Module) : Except LowerError Unit := do
  let _ ← module.structs.foldlM (init := #[]) fun seen decl =>
    validateDistinctStructName seen decl.name
  for decl in module.structs do
    if decl.fields.isEmpty then
      .error { message := s!"struct `{decl.name}` must declare at least one field" }
    let _ ← decl.fields.foldlM (init := #[]) fun seen field =>
      validateDistinctStructFieldName decl.name seen field.id
    for field in decl.fields do
      ensureStructLocalFieldType decl.name field.id field.type

def validateStorageStructState (context typeName : String) (module : Module) : Except LowerError Unit := do
  let some decl := findStruct? module typeName
    | .error { message := s!"{context} uses unknown struct `{typeName}`" }
  if decl.fields.isEmpty then
    .error { message := s!"{context} uses empty struct `{typeName}`; EVM IR v0 storage structs must have at least one field" }
  for field in decl.fields do
    ensureStructLocalFieldType decl.name field.id field.type

def validateState (module : Module) : Except LowerError Unit := do
  for state in module.state do
    match state.kind, state.type with
    | .scalar, .u32 => pure ()
    | .scalar, .u64 => pure ()
    | .scalar, .bool => pure ()
    | .scalar, .hash => pure ()
    | .scalar, .structType typeName =>
        validateStorageStructState s!"state `{state.id}`" typeName module
    | .scalar, other =>
        .error { message := s!"state `{state.id}` has unsupported EVM IR v0 type `{other.name}`" }
    | .map .u64 _, .u64 => pure ()
    | .map keyType capacity, valueType =>
        .error { message := s!"map state `{state.id}` has unsupported EVM IR v0 type `{mapShapeName keyType valueType capacity}`; only Map<U64, U64, N> is supported" }
    | .array 0, _ =>
        .error { message := s!"array state `{state.id}` must have non-zero length" }
    | .array _, .u32 => pure ()
    | .array _, .u64 => pure ()
    | .array _, .bool => pure ()
    | .array _, .hash => pure ()
    | .array _, .structType typeName =>
        validateStorageStructState s!"array state `{state.id}`" typeName module
    | .array _, other =>
        .error { message := s!"array state `{state.id}` has unsupported EVM IR v0 element type `{other.name}`; storage arrays support U32, U64, Bool, Hash, or flat struct arrays" }

def validateCapabilities (module : Module) : Except LowerError Unit :=
  match requireCapabilities Target.evm module.capabilities with
  | .ok () => .ok ()
  | .error err => .error (capabilityError err)

def lowerModule (module : Module) : Except LowerError Lean.Compiler.Yul.Object := do
  validateCapabilities module
  validateStructs module
  validateState module
  let functions ← module.entrypoints.foldlM (init := #[]) fun acc entrypoint => do
    .ok (acc.push (← lowerEntrypoint module entrypoint))
  let dispatch ← dispatchBlock module
  let helpers := if moduleUsesSupportedMap module then mapHelperFunctions (moduleStoragePathAssignOps module) else #[]
  let helpers := helpers ++ (if moduleUsesSupportedArray module then arrayHelperFunctions else #[])
  let helpers := helpers ++ (if moduleUsesSupportedStructArray module then structArrayHelperFunctions else #[])
  let helpers := helpers ++ (if moduleUsesHash module then hashHelperFunctions else #[])
  let helpers := helpers ++ crosscallHelperFunctions (moduleCrosscallArities module)
  .ok {
    name := module.name
    code := { statements := #[dispatch] ++ functions ++ helpers }
  }

def renderModule (module : Module) : Except LowerError String := do
  .ok (Lean.Compiler.Yul.Printer.render (← lowerModule module))

end ProofForge.Backend.Evm.IR
