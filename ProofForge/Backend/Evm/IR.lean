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
  deriving Repr

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

def revertStmt : Lean.Compiler.Yul.Statement :=
  Lean.Compiler.Yul.Statement.exprStmt
    (Lean.Compiler.Yul.builtin "revert" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])

def calldataWordExpr (paramIndex : Nat) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.builtin "calldataload" #[Lean.Compiler.Yul.Expr.num (4 + paramIndex * 32)]

def ensureAbiScalarType (entrypointName paramName : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 | .bool => .ok ()
  | .unit =>
      .error { message := s!"entrypoint `{entrypointName}` parameter `{paramName}` uses Unit; IR EVM v0 ABI parameters must use U32, U64, or Bool" }
  | .hash =>
      .error { message := s!"entrypoint `{entrypointName}` parameter `{paramName}` uses Hash; IR EVM v0 ABI parameters must use U32, U64, or Bool" }
  | .fixedArray _ _ | .structType _ =>
      .error { message := s!"entrypoint `{entrypointName}` parameter `{paramName}` uses `{type.name}`; IR EVM v0 ABI parameters must use U32, U64, or Bool" }

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
    | .literal (.hash4 _ _ _ _) =>
        .error { message := "Hash literals are not supported by IR EVM v0" }
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
    | .hashValue _ _ _ _ =>
        .error { message := "Hash value construction is not supported by IR EVM v0" }
    | .hash _ =>
        .error { message := "crypto.hash is not supported by IR EVM v0" }
    | .hashTwoToOne _ _ =>
        .error { message := "crypto.hash_two_to_one is not supported by IR EVM v0" }
    | .nativeValue =>
        .error { message := "native value inspection is not supported by IR EVM v0" }
    | .crosscallInvoke _ _ _ =>
        .error { message := "cross-contract calls are not supported by IR EVM v0" }
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
        .error { message := "event emission is not supported by IR EVM v0" }
end

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
  | .eventEmit _ _ =>
      .error { message := "event emission is not supported by IR EVM v0" }

def ensureLocalScalarType (context name : String) (type : ValueType) : Except LowerError Unit :=
  match type with
  | .u32 | .u64 | .bool => .ok ()
  | .unit => .error { message := s!"{context} `{name}` has unsupported EVM IR v0 type `Unit`" }
  | .hash => .error { message := s!"{context} `{name}` has unsupported EVM IR v0 type `Hash`" }
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
  let body ← lowerStatements module entrypoint.body
  let returns : Array Lean.Compiler.Yul.TypedName :=
    match entrypoint.returns with
    | .unit => #[]
    | .u32 | .u64 | .bool => #[{ name := "result" }]
    | .hash => #[]
    | .fixedArray _ _ => #[]
    | .structType _ => #[]
  if entrypoint.returns == .hash then
    .error { message := s!"entrypoint `{entrypoint.name}` returns Hash; IR EVM v0 supports only Unit, U64, and Bool" }
  if entrypoint.returns.capabilities.contains .dataFixedArray then
    .error { message := s!"entrypoint `{entrypoint.name}` returns `{entrypoint.returns.name}`; IR EVM v0 supports only Unit, U64, and Bool" }
  if entrypoint.returns.capabilities.contains .dataStruct then
    .error { message := s!"entrypoint `{entrypoint.name}` returns `{entrypoint.returns.name}`; IR EVM v0 supports only Unit, U64, and Bool" }
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
    | .u32 | .u64 | .bool =>
        abiParamValidationStmts entrypoint ++ #[
          Lean.Compiler.Yul.Statement.varDecl #[({ name := "_r" } : Lean.Compiler.Yul.TypedName)] (some callExpr),
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.id "_r"]),
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 32])
        ]
    | .hash =>
        #[revertStmt]
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

def validateState (module : Module) : Except LowerError Unit := do
  for state in module.state do
    match state.kind, state.type with
    | .scalar, .u32 => pure ()
    | .scalar, .u64 => pure ()
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
  .ok {
    name := module.name
    code := { statements := #[dispatch] ++ functions ++ helpers }
  }

def renderModule (module : Module) : Except LowerError String := do
  .ok (Lean.Compiler.Yul.Printer.render (← lowerModule module))

end ProofForge.Backend.Evm.IR
