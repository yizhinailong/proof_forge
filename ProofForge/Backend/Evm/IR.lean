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
  go 0 module.state
where
  go (idx : Nat) (states : Array StateDecl) : Option (Nat × StateDecl) :=
    if h : idx < states.size then
      let state := states[idx]
      if state.id == stateId then
        some (idx, state)
      else
        go (idx + 1) states
    else
      none

def stateSlot? (module : Module) (stateId : String) : Option Nat :=
  go 0 module.state
where
  go (idx : Nat) (states : Array StateDecl) : Option Nat :=
    if h : idx < states.size then
      let state := states[idx]
      if state.id == stateId then
        some idx
      else
        go (idx + 1) states
    else
      none

def slotExpr (slot : Nat) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.Expr.num slot

def yulFunctionName (moduleName entrypointName : String) : String :=
  s!"f_{moduleName}_{entrypointName}"

def mapSlotFunctionName : String := "__proof_forge_map_slot"
def mapWriteFunctionName : String := "__proof_forge_map_write"
def mapSetReturnFunctionName : String := "__proof_forge_map_set_return"
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

def ensureAbiScalarType (entrypointName paramName : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 | .bool | .hash => .ok ()
  | .unit =>
      .error { message := s!"entrypoint `{entrypointName}` parameter `{paramName}` uses Unit; IR EVM v0 ABI parameters must use U32, U64, Bool, or Hash" }
  | .fixedArray _ _ | .structType _ =>
      .error { message := s!"entrypoint `{entrypointName}` parameter `{paramName}` uses `{type.name}`; IR EVM v0 ABI parameters must use U32, U64, Bool, or Hash" }

def lowerEntrypointParams (entrypoint : Entrypoint) : Except LowerError (Array Lean.Compiler.Yul.TypedName) :=
  entrypoint.params.foldlM (init := #[]) fun acc param => do
    let (name, type) := param
    ensureAbiScalarType entrypoint.name name type
    .ok (acc.push ({ name := name } : Lean.Compiler.Yul.TypedName))

def entrypointCallArgs (entrypoint : Entrypoint) : Array Lean.Compiler.Yul.Expr :=
  go 0 #[]
where
  go (idx : Nat) (acc : Array Lean.Compiler.Yul.Expr) : Array Lean.Compiler.Yul.Expr :=
    if h : idx < entrypoint.params.size then
      go (idx + 1) (acc.push (calldataWordExpr idx))
    else
      acc

def abiParamValidationStmts (entrypoint : Entrypoint) : Array Lean.Compiler.Yul.Statement :=
  let minSize := 4 + entrypoint.params.size * 32
  let lengthGuard :=
    if entrypoint.params.isEmpty then
      #[]
    else
      #[
        Lean.Compiler.Yul.Statement.ifStmt
          (Lean.Compiler.Yul.builtin "lt" #[Lean.Compiler.Yul.builtin "calldatasize" #[], Lean.Compiler.Yul.Expr.num minSize])
          { statements := #[revertStmt] }
      ]
  go 0 lengthGuard
where
  go (idx : Nat) (acc : Array Lean.Compiler.Yul.Statement) : Array Lean.Compiler.Yul.Statement :=
    if h : idx < entrypoint.params.size then
      let (_, type) := entrypoint.params[idx]
      let word := calldataWordExpr idx
      let acc :=
        match type with
        | .u32 =>
            acc.push <| Lean.Compiler.Yul.Statement.ifStmt
              (Lean.Compiler.Yul.builtin "gt" #[word, Lean.Compiler.Yul.Expr.num 4294967295])
              { statements := #[revertStmt] }
        | .bool =>
            acc.push <| Lean.Compiler.Yul.Statement.ifStmt
              (Lean.Compiler.Yul.builtin "gt" #[word, Lean.Compiler.Yul.Expr.num 1])
              { statements := #[revertStmt] }
        | _ => acc
      go (idx + 1) acc
    else
      acc

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
  | .scalar => .ok state.type
  | .map _ _ => .error { message := s!"state `{stateId}` is a map, not scalar storage" }
  | .array _ => .error { message := s!"state `{stateId}` is an array, not scalar storage" }

def mapStateTypes (module : Module) (stateId : String) : Except LowerError (ValueType × ValueType) := do
  let state ← stateDeclOf module stateId "map"
  match state.kind with
  | .map keyType _ => .ok (keyType, state.type)
  | .scalar => .error { message := s!"state `{stateId}` is scalar storage, not a map" }
  | .array _ => .error { message := s!"state `{stateId}` is array storage, not a map" }

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
    | .arrayLit elementType _ => .ok (.fixedArray elementType 0)
    | .arrayGet _ _ => .error { message := "fixed array indexing is not supported by IR EVM v0" }
    | .structLit typeName _ => .ok (.structType typeName)
    | .field _ _ => .error { message := "struct field access is not supported by IR EVM v0" }
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
    match state.kind, path.toList with
    | .map keyType _, .mapKey key :: _ => do
        ensureType s!"map `{stateId}` key" keyType (← inferExprType module env key)
        .ok state.type
    | .map _ _, [] =>
        .ok state.type
    | .map _ _, _ =>
        .ok state.type
    | .scalar, [] =>
        .ok state.type
    | .scalar, _ =>
        .error { message := "EVM IR v0 supports storage paths only for single-segment mapKey map access" }
    | .array _, _ =>
        .error { message := "storage.array paths are not supported by IR EVM v0" }

  partial def inferEffectExprType (module : Module) (env : TypeEnv) : Effect → Except LowerError ValueType
    | .storageScalarRead stateId =>
        scalarStateType module stateId
    | .storageScalarWrite _ _ =>
        .error { message := "storage.scalar.write is a statement effect, not an expression" }
    | .storageScalarAssignOp _ _ _ =>
        .error { message := "storage.scalar.assign_op is not supported by IR EVM v0" }
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
    | .storageArrayRead _ _ =>
        .error { message := "storage.array.read is not supported by IR EVM v0" }
    | .storageArrayWrite _ _ _ =>
        .error { message := "storage.array.write is not supported by IR EVM v0" }
    | .storageArrayStructFieldRead _ _ _ =>
        .error { message := "storage.array.struct.field.read is not supported by IR EVM v0" }
    | .storageArrayStructFieldWrite _ _ _ _ =>
        .error { message := "storage.array.struct.field.write is not supported by IR EVM v0" }
    | .storageStructFieldRead _ _ =>
        .error { message := "storage.struct.field.read is not supported by IR EVM v0" }
    | .storageStructFieldWrite _ _ _ =>
        .error { message := "storage.struct.field.write is not supported by IR EVM v0" }
    | .storagePathRead stateId path =>
        inferStoragePathType module env stateId path
    | .storagePathWrite _ _ _ =>
        .error { message := "storage.path.write is a statement effect, not an expression" }
    | .storagePathAssignOp _ _ _ _ =>
        .error { message := "storage.path.assign_op is not supported by IR EVM v0" }
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
  | .storageScalarAssignOp _ _ _ =>
      .ok ()
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
      .ok ()
  | .storageArrayWrite _ _ _ =>
      .ok ()
  | .storageArrayStructFieldRead _ _ _ =>
      .ok ()
  | .storageArrayStructFieldWrite _ _ _ _ =>
      .ok ()
  | .storageStructFieldRead _ _ =>
      .ok ()
  | .storageStructFieldWrite _ _ _ =>
      .ok ()
  | .storagePathRead _ _ =>
      .error { message := "storage.path.read must be used as an expression" }
  | .storagePathWrite stateId path value => do
      ensureType s!"storage path `{stateId}` write" (← inferStoragePathType module env stateId path) (← inferExprType module env value)
  | .storagePathAssignOp _ _ _ _ =>
      .ok ()
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
    | .assignOp _ _ _ =>
        .ok env
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
    | .boundedFor _ _ _ _ =>
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

  partial def lowerStoragePathReadExpr (module : Module) (stateId : String) (path : Array StoragePathSegment) : Except LowerError Lean.Compiler.Yul.Expr :=
    match path.toList with
    | [StoragePathSegment.mapKey key] => lowerMapGetExpr module stateId key
    | [] => .error { message := s!"storage path state `{stateId}` is map storage; first segment must be a map key" }
    | _ => .error { message := "EVM IR v0 supports only single-segment mapKey storage paths" }

  partial def lowerExpr (module : Module) : ProofForge.IR.Expr → Except LowerError Lean.Compiler.Yul.Expr
    | .literal (.u32 value) => .ok (Lean.Compiler.Yul.Expr.num value)
    | .literal (.u64 value) => .ok (Lean.Compiler.Yul.Expr.num value)
    | .literal (.bool value) => .ok (if value then Lean.Compiler.Yul.Expr.num 1 else Lean.Compiler.Yul.Expr.num 0)
    | .literal (.hash4 a b c d) => do
        .ok (Lean.Compiler.Yul.Expr.num (← packedHashLiteral a b c d))
    | .local name => .ok (Lean.Compiler.Yul.Expr.id name)
    | .arrayLit _ _ =>
        .error { message := "fixed array literals are not supported by IR EVM v0" }
    | .arrayGet _ _ =>
        .error { message := "fixed array indexing is not supported by IR EVM v0" }
    | .structLit _ _ =>
        .error { message := "struct literals are not supported by IR EVM v0" }
    | .field _ _ =>
        .error { message := "struct field access is not supported by IR EVM v0" }
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
        .error { message := "native value inspection is not supported by IR EVM v0" }
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
        let some slot := stateSlot? module stateId
          | .error { message := s!"unknown scalar state `{stateId}`" }
        .ok (Lean.Compiler.Yul.builtin "sload" #[slotExpr slot])
    | .storageScalarWrite _ _ =>
        .error { message := "storage.scalar.write is a statement effect, not an expression" }
    | .storageScalarAssignOp _ _ _ =>
        .error { message := "storage.scalar.assign_op is not supported by IR EVM v0" }
    | .storageMapContains _ _ =>
        .error { message := "storage.map.contains is not supported by IR EVM v0 because EVM mappings do not track key presence" }
    | .storageMapGet stateId key =>
        lowerMapGetExpr module stateId key
    | .storageMapInsert stateId key value =>
        lowerMapSetReturnExpr module stateId key value
    | .storageMapSet stateId key value =>
        lowerMapSetReturnExpr module stateId key value
    | .storageArrayRead _ _ =>
        .error { message := "storage.array.read is not supported by IR EVM v0" }
    | .storageArrayWrite _ _ _ =>
        .error { message := "storage.array.write is not supported by IR EVM v0" }
    | .storageArrayStructFieldRead _ _ _ =>
        .error { message := "storage.array.struct.field.read is not supported by IR EVM v0" }
    | .storageArrayStructFieldWrite _ _ _ _ =>
        .error { message := "storage.array.struct.field.write is not supported by IR EVM v0" }
    | .storageStructFieldRead _ _ =>
        .error { message := "storage.struct.field.read is not supported by IR EVM v0" }
    | .storageStructFieldWrite _ _ _ =>
        .error { message := "storage.struct.field.write is not supported by IR EVM v0" }
    | .storagePathRead stateId path =>
        lowerStoragePathReadExpr module stateId path
    | .storagePathWrite _ _ _ =>
        .error { message := "storage.path.write is a statement effect, not an expression" }
    | .storagePathAssignOp _ _ _ _ =>
        .error { message := "storage.path.assign_op is not supported by IR EVM v0" }
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

def lowerStoragePathWriteStmt
    (module : Module)
    (stateId : String)
    (path : Array StoragePathSegment)
    (value : ProofForge.IR.Expr) : Except LowerError Lean.Compiler.Yul.Statement :=
  match path.toList with
  | [StoragePathSegment.mapKey key] => lowerMapWriteStmt module stateId key value
  | [] => .error { message := s!"storage path state `{stateId}` is map storage; first segment must be a map key" }
  | _ => .error { message := "EVM IR v0 supports only single-segment mapKey storage paths" }

def lowerEffectStmt (module : Module) : Effect → Except LowerError Lean.Compiler.Yul.Statement
  | .storageScalarRead _ =>
      .error { message := "storage.scalar.read must be used as an expression" }
  | .storageScalarWrite stateId value => do
      let some slot := stateSlot? module stateId
        | .error { message := s!"unknown scalar state `{stateId}`" }
      .ok (.exprStmt (Lean.Compiler.Yul.builtin "sstore" #[slotExpr slot, ← lowerExpr module value]))
  | .storageScalarAssignOp _ _ _ =>
      .error { message := "storage.scalar.assign_op is not supported by IR EVM v0" }
  | .storageMapContains _ _ =>
      .error { message := "storage.map.contains must be used as an expression, but EVM mappings do not track key presence" }
  | .storageMapGet _ _ =>
      .error { message := "storage.map.get must be used as an expression" }
  | .storageMapInsert stateId key value =>
      lowerMapWriteStmt module stateId key value
  | .storageMapSet stateId key value =>
      lowerMapWriteStmt module stateId key value
  | .storageArrayRead _ _ =>
      .error { message := "storage.array.read must be used as an expression, but IR EVM v0 does not support storage arrays" }
  | .storageArrayWrite _ _ _ =>
      .error { message := "storage.array.write is not supported by IR EVM v0" }
  | .storageArrayStructFieldRead _ _ _ =>
      .error { message := "storage.array.struct.field.read must be used as an expression, but IR EVM v0 does not support struct array storage" }
  | .storageArrayStructFieldWrite _ _ _ _ =>
      .error { message := "storage.array.struct.field.write is not supported by IR EVM v0" }
  | .storageStructFieldRead _ _ =>
      .error { message := "storage.struct.field.read must be used as an expression, but IR EVM v0 does not support struct storage" }
  | .storageStructFieldWrite _ _ _ =>
      .error { message := "storage.struct.field.write is not supported by IR EVM v0" }
  | .storagePathRead _ _ =>
      .error { message := "storage.path.read must be used as an expression" }
  | .storagePathWrite stateId path value =>
      lowerStoragePathWriteStmt module stateId path value
  | .storagePathAssignOp _ _ _ _ =>
      .error { message := "storage.path.assign_op is not supported by IR EVM v0" }
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

partial def hasNestedReturn (statements : Array Statement) : Bool :=
  statements.any fun stmt =>
    match stmt with
    | .return _ => true
    | .ifElse _ thenBody elseBody => hasNestedReturn thenBody || hasNestedReturn elseBody
    | .boundedFor _ _ _ body => hasNestedReturn body
    | _ => false

mutual
  partial def lowerStatements (module : Module) (statements : Array Statement) : Except LowerError (Array Lean.Compiler.Yul.Statement) :=
    statements.foldlM (init := #[]) fun acc stmt => do
      .ok (acc.push (← lowerStatement module stmt))

  partial def lowerStatement (module : Module) : ProofForge.IR.Statement → Except LowerError Lean.Compiler.Yul.Statement
    | .letBind name type value => do
        ensureLocalScalarType "let binding" name type
        .ok (.varDecl #[({ name := name } : Lean.Compiler.Yul.TypedName)] (some (← lowerExpr module value)))
    | .letMutBind name type value => do
        ensureLocalScalarType "mutable let binding" name type
        .ok (.varDecl #[({ name := name } : Lean.Compiler.Yul.TypedName)] (some (← lowerExpr module value)))
    | .assign (.local name) value => do
        .ok (.assignment #[name] (← lowerExpr module value))
    | .assign _ _ =>
        .error { message := "assignment target must be a local in IR EVM v0" }
    | .assignOp _ _ _ =>
        .error { message := "compound assignment statements are not supported by IR EVM v0" }
    | .effect effect =>
        lowerEffectStmt module effect
    | .assert condition _ => do
        .ok (lowerAssertStmt (← lowerExpr module condition))
    | .assertEq lhs rhs _ => do
        let condition := Lean.Compiler.Yul.builtin "eq" #[← lowerExpr module lhs, ← lowerExpr module rhs]
        .ok (lowerAssertStmt condition)
    | .ifElse condition thenBody elseBody => do
        if hasNestedReturn thenBody || hasNestedReturn elseBody then
          .error { message := "return statements inside if/else branches are not supported by IR EVM v0; return must be the final entrypoint statement" }
        let thenStatements ← lowerStatements module thenBody
        let elseStatements ← lowerStatements module elseBody
        .ok (.switchStmt (← lowerExpr module condition) #[
          {
            value := some (Lean.Compiler.Yul.Literal.natLit 0)
            body := { statements := elseStatements }
          },
          {
            value := none
            body := { statements := thenStatements }
          }
        ])
    | .boundedFor _ _ _ _ =>
        .error { message := "bounded for loops are not supported by IR EVM v0" }
    | .return value => do
        .ok (.assignment #["result"] (← lowerExpr module value))
end

def lowerEntrypoint (module : Module) (entrypoint : Entrypoint) : Except LowerError Lean.Compiler.Yul.Statement := do
  let params ← lowerEntrypointParams entrypoint
  match entrypoint.returns with
  | .unit => pure ()
  | _ =>
      match entrypoint.body.back? with
      | some (.return _) => pure ()
      | _ =>
          .error { message := s!"entrypoint `{entrypoint.name}` returns `{entrypoint.returns.name}` but does not end with a return statement" }
  validateEntrypointTypes module entrypoint
  let body ← lowerStatements module entrypoint.body
  let returns : Array Lean.Compiler.Yul.TypedName :=
    match entrypoint.returns with
    | .unit => #[]
    | .u32 | .u64 | .bool | .hash => #[{ name := "result" }]
    | .fixedArray _ _ => #[]
    | .structType _ => #[]
  if entrypoint.returns.capabilities.contains .dataFixedArray then
    .error { message := s!"entrypoint `{entrypoint.name}` returns `{entrypoint.returns.name}`; IR EVM v0 supports only Unit, U32, U64, Bool, and Hash" }
  if entrypoint.returns.capabilities.contains .dataStruct then
    .error { message := s!"entrypoint `{entrypoint.name}` returns `{entrypoint.returns.name}`; IR EVM v0 supports only Unit, U32, U64, Bool, and Hash" }
  .ok (.funcDef (yulFunctionName module.name entrypoint.name) params returns { statements := body })

def entrypointCallExpr (module : Module) (entrypoint : Entrypoint) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.call (yulFunctionName module.name entrypoint.name) (entrypointCallArgs entrypoint)

def dispatchCase (module : Module) (entrypoint : Entrypoint) : Except LowerError Lean.Compiler.Yul.Case := do
  let some selector := entrypoint.selector?
    | .error { message := s!"entrypoint `{entrypoint.name}` has no EVM selector metadata" }
  let callExpr := entrypointCallExpr module entrypoint
  let bodyStmts :=
    match entrypoint.returns with
    | .unit =>
        abiParamValidationStmts entrypoint ++ #[
          Lean.Compiler.Yul.Statement.exprStmt callExpr,
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])
        ]
    | .u32 | .u64 | .bool | .hash =>
        abiParamValidationStmts entrypoint ++ #[
          Lean.Compiler.Yul.Statement.varDecl #[({ name := "_r" } : Lean.Compiler.Yul.TypedName)] (some callExpr),
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.id "_r"]),
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 32])
        ]
    | .fixedArray _ _ =>
        #[revertStmt]
    | .structType _ =>
        #[revertStmt]
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

def mapHelperFunctions : Array Lean.Compiler.Yul.Statement := #[
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

def validateState (module : Module) : Except LowerError Unit := do
  for state in module.state do
    match state.kind, state.type with
    | .scalar, .u32 => pure ()
    | .scalar, .u64 => pure ()
    | .scalar, .hash => pure ()
    | .scalar, other =>
        .error { message := s!"state `{state.id}` has unsupported EVM IR v0 type `{other.name}`" }
    | .map .u64 _, .u64 => pure ()
    | .map keyType capacity, valueType =>
        .error { message := s!"map state `{state.id}` has unsupported EVM IR v0 type `{mapShapeName keyType valueType capacity}`; only Map<U64, U64, N> is supported" }
    | .array _, _ =>
        .error { message := s!"state `{state.id}` is storage.array; IR EVM v0 does not lower portable array storage yet" }

def validateCapabilities (module : Module) : Except LowerError Unit :=
  match requireCapabilities Target.evm module.capabilities with
  | .ok () => .ok ()
  | .error err => .error (capabilityError err)

def lowerModule (module : Module) : Except LowerError Lean.Compiler.Yul.Object := do
  validateCapabilities module
  validateState module
  let functions ← module.entrypoints.foldlM (init := #[]) fun acc entrypoint => do
    .ok (acc.push (← lowerEntrypoint module entrypoint))
  let dispatch ← dispatchBlock module
  let helpers := if moduleUsesSupportedMap module then mapHelperFunctions else #[]
  let helpers := helpers ++ (if moduleUsesHash module then hashHelperFunctions else #[])
  let helpers := helpers ++ crosscallHelperFunctions (moduleCrosscallArities module)
  .ok {
    name := module.name
    code := { statements := #[dispatch] ++ functions ++ helpers }
  }

def renderModule (module : Module) : Except LowerError String := do
  .ok (Lean.Compiler.Yul.Printer.render (← lowerModule module))

end ProofForge.Backend.Evm.IR
