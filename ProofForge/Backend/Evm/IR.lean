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

mutual
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
    | .effect effect => lowerEffectExpr module effect

  partial def lowerEffectExpr (module : Module) : Effect → Except LowerError Lean.Compiler.Yul.Expr
    | .storageScalarRead stateId => do
        let some slot := stateSlot? module stateId
          | .error { message := s!"unknown scalar state `{stateId}`" }
        .ok (Lean.Compiler.Yul.builtin "sload" #[slotExpr slot])
    | .storageScalarWrite _ _ =>
        .error { message := "storage.scalar.write is a statement effect, not an expression" }
    | .storageMapContains _ _ =>
        .error { message := "storage.map.contains is not supported by IR EVM v0" }
    | .storageMapGet _ _ =>
        .error { message := "storage.map.get is not supported by IR EVM v0" }
    | .storageMapInsert _ _ _ =>
        .error { message := "storage.map.insert is not supported by IR EVM v0" }
    | .storageMapSet _ _ _ =>
        .error { message := "storage.map.set is not supported by IR EVM v0" }
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
    | .storagePathRead _ _ =>
        .error { message := "storage.path.read is not supported by IR EVM v0" }
    | .storagePathWrite _ _ _ =>
        .error { message := "storage.path.write is not supported by IR EVM v0" }
    | .contextRead field =>
        .error { message := s!"context field `{field.name}` is not supported by IR EVM v0" }
end

def lowerEffectStmt (module : Module) : Effect → Except LowerError Lean.Compiler.Yul.Statement
  | .storageScalarRead _ =>
      .error { message := "storage.scalar.read must be used as an expression" }
  | .storageScalarWrite stateId value => do
      let some slot := stateSlot? module stateId
        | .error { message := s!"unknown scalar state `{stateId}`" }
      .ok (.exprStmt (Lean.Compiler.Yul.builtin "sstore" #[slotExpr slot, ← lowerExpr module value]))
  | .storageMapContains _ _ =>
      .error { message := "storage.map.contains must be used as an expression, but IR EVM v0 does not support storage maps" }
  | .storageMapGet _ _ =>
      .error { message := "storage.map.get must be used as an expression, but IR EVM v0 does not support storage maps" }
  | .storageMapInsert _ _ _ =>
      .error { message := "storage.map.insert is not supported by IR EVM v0" }
  | .storageMapSet _ _ _ =>
      .error { message := "storage.map.set is not supported by IR EVM v0" }
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
      .error { message := "storage.path.read must be used as an expression, but IR EVM v0 does not support storage paths" }
  | .storagePathWrite _ _ _ =>
      .error { message := "storage.path.write is not supported by IR EVM v0" }
  | .contextRead _ =>
      .error { message := "context reads must be used as expressions" }

def lowerStatement (module : Module) : ProofForge.IR.Statement → Except LowerError Lean.Compiler.Yul.Statement
  | .letBind name type value => do
      match type with
      | .u32 | .u64 | .bool => pure ()
      | .unit => .error { message := s!"let binding `{name}` has unsupported EVM IR v0 type `Unit`" }
      | .hash => .error { message := s!"let binding `{name}` has unsupported EVM IR v0 type `Hash`" }
      | .fixedArray _ _ => .error { message := s!"let binding `{name}` has unsupported EVM IR v0 type `{type.name}`" }
      | .structType _ => .error { message := s!"let binding `{name}` has unsupported EVM IR v0 type `{type.name}`" }
      .ok (.varDecl #[({ name := name } : Lean.Compiler.Yul.TypedName)] (some (← lowerExpr module value)))
  | .letMutBind name _ _ =>
      .error { message := s!"mutable let binding `{name}` is not supported by IR EVM v0" }
  | .assign _ _ =>
      .error { message := "assignment statements are not supported by IR EVM v0" }
  | .assignOp _ _ _ =>
      .error { message := "compound assignment statements are not supported by IR EVM v0" }
  | .effect effect =>
      lowerEffectStmt module effect
  | .assert _ _ =>
      .error { message := "assert statements are not supported by IR EVM v0" }
  | .assertEq _ _ _ =>
      .error { message := "assert_eq statements are not supported by IR EVM v0" }
  | .ifElse _ _ _ =>
      .error { message := "if/else statements are not supported by IR EVM v0" }
  | .boundedFor _ _ _ _ =>
      .error { message := "bounded for loops are not supported by IR EVM v0" }
  | .return value => do
      .ok (.assignment #["result"] (← lowerExpr module value))

def lowerEntrypoint (module : Module) (entrypoint : Entrypoint) : Except LowerError Lean.Compiler.Yul.Statement := do
  if !entrypoint.params.isEmpty then
    .error { message := s!"entrypoint `{entrypoint.name}` has parameters; IR EVM v0 supports no parameters" }
  let body ← entrypoint.body.foldlM (init := #[]) fun acc stmt => do
    .ok (acc.push (← lowerStatement module stmt))
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
  .ok (.funcDef (yulFunctionName module.name entrypoint.name) #[] returns { statements := body })

def entrypointCallExpr (module : Module) (entrypoint : Entrypoint) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.call (yulFunctionName module.name entrypoint.name) #[]

def dispatchCase (module : Module) (entrypoint : Entrypoint) : Except LowerError Lean.Compiler.Yul.Case := do
  let some selector := entrypoint.selector?
    | .error { message := s!"entrypoint `{entrypoint.name}` has no EVM selector metadata" }
  if !entrypoint.params.isEmpty then
    .error { message := s!"entrypoint `{entrypoint.name}` has parameters; IR EVM dispatcher v0 supports no parameters" }
  let callExpr := entrypointCallExpr module entrypoint
  let bodyStmts :=
    match entrypoint.returns with
    | .unit =>
        #[
          Lean.Compiler.Yul.Statement.exprStmt callExpr,
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])
        ]
    | .u32 | .u64 | .bool =>
        #[
          Lean.Compiler.Yul.Statement.varDecl #[({ name := "_r" } : Lean.Compiler.Yul.TypedName)] (some callExpr),
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.id "_r"]),
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 32])
        ]
    | .hash =>
        #[
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "revert" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])
        ]
    | .fixedArray _ _ =>
        #[
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "revert" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])
        ]
    | .structType _ =>
        #[
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "revert" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])
        ]
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
      statements := #[
        Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "revert" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])
      ]
    }
  }
  .ok (.switchStmt selectorExpr (cases.push defaultCase))

def validateState (module : Module) : Except LowerError Unit := do
  for state in module.state do
    match state.kind, state.type with
    | .scalar, .u32 => pure ()
    | .scalar, .u64 => pure ()
    | .scalar, other =>
        .error { message := s!"state `{state.id}` has unsupported EVM IR v0 type `{other.name}`" }
    | .map _ _, _ =>
        .error { message := s!"state `{state.id}` is storage.map; IR EVM v0 does not lower portable map storage yet" }
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
  .ok {
    name := module.name
    code := { statements := #[dispatch] ++ functions }
  }

def renderModule (module : Module) : Except LowerError String := do
  .ok (Lean.Compiler.Yul.Printer.render (← lowerModule module))

end ProofForge.Backend.Evm.IR
