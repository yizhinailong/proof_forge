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
    | .literal (.u64 value) => .ok (Lean.Compiler.Yul.Expr.num value)
    | .literal (.bool value) => .ok (if value then Lean.Compiler.Yul.Expr.num 1 else Lean.Compiler.Yul.Expr.num 0)
    | .local name => .ok (Lean.Compiler.Yul.Expr.id name)
    | .add lhs rhs => do
        .ok (Lean.Compiler.Yul.builtin "add" #[← lowerExpr module lhs, ← lowerExpr module rhs])
    | .effect effect => lowerEffectExpr module effect

  partial def lowerEffectExpr (module : Module) : Effect → Except LowerError Lean.Compiler.Yul.Expr
    | .storageScalarRead stateId => do
        let some slot := stateSlot? module stateId
          | .error { message := s!"unknown scalar state `{stateId}`" }
        .ok (Lean.Compiler.Yul.builtin "sload" #[slotExpr slot])
    | .storageScalarWrite _ _ =>
        .error { message := "storage.scalar.write is a statement effect, not an expression" }
end

def lowerEffectStmt (module : Module) : Effect → Except LowerError Lean.Compiler.Yul.Statement
  | .storageScalarRead _ =>
      .error { message := "storage.scalar.read must be used as an expression" }
  | .storageScalarWrite stateId value => do
      let some slot := stateSlot? module stateId
        | .error { message := s!"unknown scalar state `{stateId}`" }
      .ok (.exprStmt (Lean.Compiler.Yul.builtin "sstore" #[slotExpr slot, ← lowerExpr module value]))

def lowerStatement (module : Module) : ProofForge.IR.Statement → Except LowerError Lean.Compiler.Yul.Statement
  | .letBind name value => do
      .ok (.varDecl #[({ name := name } : Lean.Compiler.Yul.TypedName)] (some (← lowerExpr module value)))
  | .effect effect =>
      lowerEffectStmt module effect
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
    | .u64 | .bool => #[{ name := "result" }]
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
    | .u64 | .bool =>
        #[
          Lean.Compiler.Yul.Statement.varDecl #[({ name := "_r" } : Lean.Compiler.Yul.TypedName)] (some callExpr),
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.id "_r"]),
          Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 32])
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
    | .scalar, .u64 => pure ()
    | .scalar, other =>
        .error { message := s!"state `{state.id}` has unsupported EVM IR v0 type `{other.name}`" }

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
