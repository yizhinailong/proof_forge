import ProofForge.IR.Semantics

/-! ## Generic total fuel-indexed IR interpreter (FV-9.0)

This is the **shared, total, proof-usable** generic IR interpreter that FV-9's
`∀ module` compiler-correctness theorem quantifies over. It is fuel-indexed
(structural recursion on the `Nat` fuel argument), so Lean's kernel can unfold
and induct on it — unlike the broader `partial def` interpreter in
`Semantics.lean`, which cannot be used in proofs.

FV-9.0 origin: the fuel-indexed evaluator was originally written in
`CounterSemantics.lean` as a "Counter-fragment" total semantics. Inspection
(2026-07-08) showed its evaluator bodies contain **zero Counter-specific
identifiers** — they operate generically on `State`/`Frame`/`Expr`/`Effect`/
`Statement`. It was generic-but-misfiled. This file lifts it to the IR layer
as the canonical shared interpreter; `CounterSemantics.lean` now re-exports it
and keeps only the Counter-specific wrappers/proofs.

Coverage is intentionally narrow at first (the constructors Counter+ValueVault
already exercise): `Expr.literal/local/add/sub/mul/effect`,
`Effect.storageScalarRead/storageScalarWrite`, `Statement.letBind/letMutBind/
effect/return`. FV-9.0 M2 widens this to the full arithmetic + scalar/map
storage + control-flow + event core the supported fragment needs. Each
unsupported constructor falls through to `unsupported*` so totality is
preserved and the fragment predicate (FV-9.4) can admit exactly the proven
constructor set.

No contract names appear in this file.
-/

namespace ProofForge.IR.SemanticsFuel

open ProofForge.IR
open ProofForge.IR.Semantics

def defaultFuel : Nat := 32

def unsupportedExpr (expr : Expr) : Except String ExprResult :=
  .error s!"IR fuel semantics does not support expression `{repr expr}`"

def unsupportedEffect (effect : Effect) : Except String ExprResult :=
  .error s!"IR fuel semantics does not support effect `{repr effect}`"

def unsupportedStatement (statement : Statement) :
    Except String (State × Frame × Option Value) :=
  .error s!"IR fuel semantics does not support statement `{repr statement}`"

mutual
  def evalExprFuel : Nat → State → Frame → Expr → Except String ExprResult
    | 0, _, _, _ => .error "IR fuel semantics expression fuel exhausted"
    | fuel + 1, state, frame, expr =>
      match expr with
      | .literal literal => do
          let value ← literalValue literal
          .ok (state, value)
      | .local name =>
          match frame.read name with
          | some value => .ok (state, value)
          | none => .error s!"unknown local `{name}`"
      | .add lhs rhs _ => do
          let (stateAfterLhs, lhsValue) ← evalExprFuel fuel state frame lhs
          let (stateAfterRhs, rhsValue) ← evalExprFuel fuel stateAfterLhs frame rhs
          .ok (stateAfterRhs, ← evalNumericBinary "add" (· + ·) lhsValue rhsValue)
      | .sub lhs rhs _ => do
          let (stateAfterLhs, lhsValue) ← evalExprFuel fuel state frame lhs
          let (stateAfterRhs, rhsValue) ← evalExprFuel fuel stateAfterLhs frame rhs
          .ok (stateAfterRhs, ← evalNumericBinary "sub" (· - ·) lhsValue rhsValue)
      | .mul lhs rhs _ => do
          let (stateAfterLhs, lhsValue) ← evalExprFuel fuel state frame lhs
          let (stateAfterRhs, rhsValue) ← evalExprFuel fuel stateAfterLhs frame rhs
          .ok (stateAfterRhs, ← evalNumericBinary "mul" (· * ·) lhsValue rhsValue)
      | .effect effect =>
          evalEffectFuel fuel state frame effect
      | _ => unsupportedExpr expr

  def evalEffectFuel : Nat → State → Frame → Effect → Except String ExprResult
    | 0, _, _, _ => .error "IR fuel semantics effect fuel exhausted"
    | fuel + 1, state, frame, effect =>
      match effect with
      | .storageScalarRead name =>
          match state.read name with
          | some value => .ok (state, value)
          | none => .error s!"unknown scalar state `{name}`"
      | .storageScalarWrite name valueExpr => do
          let (nextState, value) ← evalExprFuel fuel state frame valueExpr
          .ok (nextState.write name value, .unit)
      | _ => unsupportedEffect effect

  def execStmtFuel : Nat → State → Frame → Statement →
      Except String (State × Frame × Option Value)
    | 0, _, _, _ => .error "IR fuel semantics statement fuel exhausted"
    | fuel + 1, state, frame, statement =>
      match statement with
      | .letBind name _ value => do
          let (nextState, evaluated) ← evalExprFuel fuel state frame value
          .ok (nextState, frame.write name evaluated, none)
      | .letMutBind name _ value => do
          let (nextState, evaluated) ← evalExprFuel fuel state frame value
          .ok (nextState, frame.write name evaluated, none)
      | .effect effect => do
          let (nextState, _) ← evalEffectFuel fuel state frame effect
          .ok (nextState, frame, none)
      | .return value => do
          let (nextState, returnValue) ← evalExprFuel fuel state frame value
          .ok (nextState, frame, some returnValue)
      | _ => unsupportedStatement statement

  def execStatementsFuel : Nat → List Statement → State → Frame →
      Except String (State × Option Value)
    | 0, _, _, _ => .error "IR fuel semantics statement-list fuel exhausted"
    | _fuel + 1, [], state, _frame => .ok (state, none)
    | fuel + 1, statement :: rest, state, frame => do
        let (nextState, nextFrame, returnValue?) ← execStmtFuel fuel state frame statement
        match returnValue? with
        | some returnValue => .ok (nextState, some returnValue)
        | none => execStatementsFuel fuel rest nextState nextFrame
end

/-- Run a single entrypoint with explicit args under the fueled interpreter. -/
def runEntrypointWithArgsFuel (fuel : Nat) (state : State)
    (entrypoint : Entrypoint) (args : Array Value) :
    Except String (State × Option Value) := do
  let frame ← bindParams entrypoint.params args
  execStatementsFuel fuel entrypoint.body.toList state frame

/-- Run a single entrypoint with no args under the fueled interpreter. -/
def runEntrypointNoArgsFuel (fuel : Nat) (state : State) (entrypoint : Entrypoint) :
    Except String (State × Option Value) :=
  execStatementsFuel fuel entrypoint.body.toList state Frame.empty

/-- Run an entrypoint with the default fuel. This is the fuel-less step shape
that `runTraceListGen` / `traceSimulation_lift` consume
(`State → Call → Except (State × Obs)` after a per-contract `Call` wrapper). -/
def runEntrypointFuel (state : State) (entrypoint : Entrypoint) :
    Except String (State × Option Value) :=
  runEntrypointNoArgsFuel defaultFuel state entrypoint

end ProofForge.IR.SemanticsFuel