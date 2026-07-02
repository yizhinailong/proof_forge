/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

EmitTS — lowers `ProofForge.IR.Module` to a TypeScript `TS.Module` for
Cloudflare Workers.

This first milestone only supports the Counter-shaped IR subset:
- single `u64` scalar storage
- `initialize` / `increment` / `get` style entrypoints
- arithmetic, local bindings, if/else, return

It deliberately does not cover maps, arrays, structs, cross-call, events, or
context reads yet.
-/

import Init
import Init.Control.State
import ProofForge.IR.Contract
import ProofForge.Compiler.TS.AST

section

namespace ProofForge.Compiler.TS.Emit

open ProofForge.IR
open ProofForge.Compiler.TS

/-- State for the TS emitter: accumulated statements and a fresh-name counter. -/
structure EmitState where
  stmts : Array Stmt := #[]
  fresh : Nat := 0
  deriving Inhabited

abbrev EmitTSM := StateT EmitState Id

@[inline]
def emit (s : Stmt) : EmitTSM Unit :=
  modify fun st => { st with stmts := st.stmts.push s }

/-- Generate a fresh local identifier. -/
def freshName (pfx : String := "_t") : EmitTSM String := do
  let st ← get
  set { st with fresh := st.fresh + 1 }
  pure s!"{pfx}{st.fresh}"

/-- Capture statements emitted by an action without mutating the outer buffer. -/
def captureStmts (act : EmitTSM Unit) : EmitTSM (Array Stmt) := do
  let saved ← get
  modify fun _ => { saved with stmts := #[] }
  act
  let st ← get
  modify fun _ => { saved with fresh := st.fresh }
  pure st.stmts

-- ---------------------------------------------------------------------------
-- Value type mapping
-- ---------------------------------------------------------------------------

/-- Map an IR value type to a TypeScript type. -/
def tsType : ValueType → Ty
  | .unit => .void
  | .bool => .boolean
  | .u32 => .number
  | .u64 => .bigint
  | .hash => .string
  | .fixedArray elem _ => .named s!"Array<{printTypeName elem}>"
  | .structType name => .named name
where
  printTypeName : ValueType → String
    | .unit => "void"
    | .bool => "boolean"
    | .u32 => "number"
    | .u64 => "bigint"
    | .hash => "string"
    | .fixedArray elem len => s!"Array<{printTypeName elem},{len}>"
    | .structType name => name

-- ---------------------------------------------------------------------------
-- KV binding helpers
-- ---------------------------------------------------------------------------

/-- KV namespace binding name exposed in `Env`. Hard-coded for the Counter spike
    to match `wrangler.toml`; future versions should derive this from state id
    or module metadata. -/
def kvBindingName : String := "COUNTER_KV"

/-- Expression: `env.<KV>.get('key')` -/
def kvGetExpr (key : String) : Expr :=
  .await (.call1 (.member (.member (.ident "env") kvBindingName) "get") (.str key))

/-- Expression: `env.<KV>.put('key', value)` -/
def kvPutExpr (key : String) (value : Expr) : Expr :=
  .await (.call2 (.member (.member (.ident "env") kvBindingName) "put") (.str key) value)

-- ---------------------------------------------------------------------------
-- Expression lowering
-- ---------------------------------------------------------------------------

/-- Lower an IR literal to a TS expression. -/
def emitLit : Literal → Expr
  | .u32 n => .num n
  | .u64 n => .bigint n
  | .bool b => .bool b
  | .hash4 a b c d => .str s!"{a}{b}{c}{d}"

/-- Convert a stored-string expression to the requested IR type. -/
def fromStoredString (type : ValueType) (raw : Expr) : Expr :=
  match type with
  | .u64 => .call1 (.ident "BigInt") raw
  | .u32 => .call2 (.ident "parseInt") raw (.num 10)
  | .bool => .binary .eq raw (.str "true")
  | _ => raw

/-- Convert a value expression to a string suitable for KV storage. -/
def toStoredString (type : ValueType) (value : Expr) : Expr :=
  match type with
  | .u64 | .u32 => .call0 (.member value "toString")
  | .bool => .call1 (.ident "String") value
  | _ => value

mutual
  /-- Lower an IR expression to a TS expression. `expected` tells us how to
      interpret storage reads and numeric literals. -/
  partial def emitExpr (expected : ValueType) : ProofForge.IR.Expr → EmitTSM ProofForge.Compiler.TS.Expr
    | .literal l => pure (emitLit l)
    | .local name => pure (.ident name)
    | .add lhs rhs => emitBinOp expected .add lhs rhs
    | .sub lhs rhs => emitBinOp expected .sub lhs rhs
    | .mul lhs rhs => emitBinOp expected .mul lhs rhs
    | .div lhs rhs => emitBinOp expected .div lhs rhs
    | .mod lhs rhs => emitBinOp expected .mod lhs rhs
    | .eq lhs rhs => emitCmpOp .eq lhs rhs
    | .ne lhs rhs => emitCmpOp .ne lhs rhs
    | .lt lhs rhs => emitCmpOp .lt lhs rhs
    | .le lhs rhs => emitCmpOp .le lhs rhs
    | .gt lhs rhs => emitCmpOp .gt lhs rhs
    | .ge lhs rhs => emitCmpOp .ge lhs rhs
    | .boolAnd lhs rhs => emitBoolOp .and lhs rhs
    | .boolOr lhs rhs => emitBoolOp .or lhs rhs
    | .boolNot v => do let e ← emitExpr .bool v; pure (.paren (.binary .eq e (.bool false)))
    | .cast v target => emitExpr target v
    | .effect e => emitEffectExpr expected e
    | _ => panic! "EmitTS: unsupported expression"

  partial def emitBinOp (expected : ValueType) (op : BinOp) (lhs rhs : ProofForge.IR.Expr) : EmitTSM ProofForge.Compiler.TS.Expr := do
    let l ← emitExpr expected lhs
    let r ← emitExpr expected rhs
    pure (.binary op l r)

  partial def emitCmpOp (op : BinOp) (lhs rhs : ProofForge.IR.Expr) : EmitTSM ProofForge.Compiler.TS.Expr := do
    let l ← emitExpr expected lhs
    let r ← emitExpr expected rhs
    pure (.binary op l r)
  where expected := ValueType.u64 -- comparison operands default to u64 for Counter

  partial def emitBoolOp (op : BinOp) (lhs rhs : ProofForge.IR.Expr) : EmitTSM ProofForge.Compiler.TS.Expr := do
    let l ← emitExpr .bool lhs
    let r ← emitExpr .bool rhs
    pure (.binary op l r)

  /-- Lower an IR effect that appears in expression position. -/
  partial def emitEffectExpr (expected : ValueType) : Effect → EmitTSM ProofForge.Compiler.TS.Expr
    | .storageScalarRead stateId => do
        let tmp ← freshName "_sv"
        emit (.constDecl tmp (some (.optional .string)) (kvGetExpr stateId))
        pure (fromStoredString expected (.coalesce (.ident tmp) (.str "0")))
    | _ => panic! "EmitTS: unsupported effect expression"
end

-- ---------------------------------------------------------------------------
-- Statement lowering
-- ---------------------------------------------------------------------------

def expectedUnit : ValueType := ValueType.unit

mutual
  /-- Lower a single IR statement to zero or more TS statements. -/
  partial def emitStmt : Statement → EmitTSM Unit
    | .letBind name type value => do
        let e ← emitExpr type value
        emit (.constDecl name (some (tsType type)) e)
    | .letMutBind name type value => do
        let e ← emitExpr type value
        emit (.letDecl name (some (tsType type)) e)
    | .assign target value => do
        let t ← emitExpr expectedUnit target
        let v ← emitExpr expectedUnit value
        emit (.assign t v)
    | .assignOp target op value => do
        let t ← emitExpr expectedUnit target
        let v ← emitExpr expectedUnit value
        let tsOp := match op with
          | .add => BinOp.add | .sub => BinOp.sub | .mul => BinOp.mul
          | .div => BinOp.div | .mod => BinOp.mod
          | .bitAnd => BinOp.and | .bitOr => BinOp.or | .bitXor => BinOp.and
          | .shiftLeft => BinOp.mul | .shiftRight => BinOp.div
        emit (.assign t (.binary tsOp t v))
    | .effect (.storageScalarWrite stateId value) => do
        let v ← emitExpr (inferType value) value
        emit (.exprStmt (kvPutExpr stateId (toStoredString (inferType value) v)))
    | .effect (.storageScalarAssignOp stateId op value) => do
        let tmp ← freshName "_cur"
        emit (.constDecl tmp (some (.optional .string)) (kvGetExpr stateId))
        let cur := fromStoredString .u64 (.coalesce (.ident tmp) (.str "0"))
        let v ← emitExpr .u64 value
        let tsOp := match op with | .add => BinOp.add | .sub => BinOp.sub | _ => BinOp.add
        let next := .binary tsOp cur v
        emit (.exprStmt (kvPutExpr stateId (toStoredString .u64 next)))
    | .effect e => panic! s!"EmitTS: unsupported statement effect {repr e}"
    | .assert cond msg => do
        let c ← emitExpr .bool cond
        emit (.ifStmt (.paren (.binary .eq c (.bool false)))
          #[.throw (.new (.ident "Error") #[.str msg])]
          none)
    | .ifElse cond thenBody elseBody => do
        let c ← emitExpr .bool cond
        let thenStmts ← captureStmts (thenBody.forM emitStmt)
        let elseStmts ← captureStmts (elseBody.forM emitStmt)
        emit (.ifStmt c thenStmts (if elseStmts.isEmpty then none else some elseStmts))
    | .boundedFor indexName start stopExclusive _body => do
        let init := Expr.call2 (.ident "range") (Expr.num start) (Expr.num stopExclusive)
        emit (.exprStmt (.call2 (.member init "forEach")
          (.ident indexName)
          (.objectLit #[])))
    | .assertEq lhs rhs msg => do
        let l ← emitExpr .u64 lhs
        let r ← emitExpr .u64 rhs
        emit (.ifStmt (.paren (.binary .ne l r))
          #[.throw (.new (.ident "Error") #[Expr.str msg])]
          none)
    -- TS/JS is garbage-collected, so releasing an owned heap local is a no-op.
    | .release _ => pure ()
    | .return value => do
        let e ← emitExpr (inferType value) value
        emit (.return (stringifyForResponse (inferType value) e))

  /-- A very rough type inference used for storage write stringification. -/
  partial def inferType : ProofForge.IR.Expr → ValueType
    | .literal (.u32 _) => .u32
    | .literal (.u64 _) => .u64
    | .literal (.bool _) => .bool
    | .local _ => .u64 -- Counter locals are u64
    | .add _ _ | .sub _ _ | .mul _ _ | .div _ _ | .mod _ _ => .u64
    | .effect (.storageScalarRead _) => .u64
    | .cast _ target => target
    | _ => .u64

  /-- Convert a returned value to a response string. -/
  partial def stringifyForResponse (type : ValueType) (e : ProofForge.Compiler.TS.Expr) : ProofForge.Compiler.TS.Expr :=
    match type with
    | .unit => .str ""
    | .u64 | .u32 => .call0 (.member e "toString")
    | .bool => .call1 (.ident "String") e
    | _ => e
end

-- ---------------------------------------------------------------------------
-- Entrypoint / module lowering
-- ---------------------------------------------------------------------------

/-- Decide HTTP method and path for an entrypoint by convention. -/
def routeForEntrypoint (ep : Entrypoint) : String × String :=
  let nameLower := ep.name.toLower
  if nameLower.startsWith "get" || nameLower.startsWith "query" then
    ("GET", "/" ++ nameLower)
  else
    ("POST", "/" ++ nameLower)

/-- Lower an IR entrypoint to a top-level async function returning a response
    body string. -/
def emitEntrypoint (ep : Entrypoint) : TopLevel :=
  let paramEnv : Param := { name := "env", type := .named "Env" }
  let (_, st) := (emitStmts ep.body).run { stmts := #[] }
  let body := st.stmts
  -- Unit entrypoints that don't explicitly return need a default empty response.
  let hasReturn := body.any fun s => match s with | .return _ => true | _ => false
  let body :=
    if ep.returns == .unit && !hasReturn then
      body.push (.return (.str ""))
    else
      body
  TopLevel.fn true ep.name #[paramEnv] (some (.promise .string)) body
where
  emitStmts (stmts : Array Statement) : EmitTSM Unit :=
    stmts.forM emitStmt

/-- Build the flat if statements that dispatch to entrypoint functions. -/
def buildRouterBody (entrypoints : Array Entrypoint) : Array Stmt :=
  let urlStmt := Stmt.const_ "url" (.new (.ident "URL") #[.member (.ident "request") "url"])
  let routeStmts := entrypoints.map fun ep =>
    let (method, path) := routeForEntrypoint ep
    let cond : Expr :=
      .binary .and
        (.binary .eq (.member (.ident "request") "method") (.str method))
        (.binary .eq (.member (.ident "url") "pathname") (.str path))
    let call : Expr := .await (.call1 (.ident ep.name) (.ident "env"))
    .ifStmt cond #[.return (.new (.ident "Response") #[call])] none
  let fallback : Stmt :=
    .return (.new (.ident "Response") #[Expr.str "not found", .objectLit #[("status", Expr.num 404)]])
  #[urlStmt] ++ routeStmts ++ #[fallback]

/-- Build the top-level `fetch` handler and the `export default { fetch }`
    re-export. Using a named function avoids an arrow-expression in the AST and
    keeps the generated code readable. -/
def emitRouter (entrypoints : Array Entrypoint) : Array TopLevel :=
  let paramRequest : Param := { name := "request", type := .named "Request" }
  let paramEnv : Param := { name := "env", type := .named "Env" }
  let paramCtx : Param := { name := "ctx", type := .named "ExecutionContext" }
  let body := buildRouterBody entrypoints
  let fetchFn := TopLevel.fn true "fetch" #[paramRequest, paramEnv, paramCtx]
    (some (.promise (.named "Response"))) body
  let exportDefault := TopLevel.exportDefault (.objectLit #[("fetch", .ident "fetch")])
  #[fetchFn, exportDefault]

/-- Lower a full IR module to a TS module. -/
def emitModule (m : ProofForge.IR.Module) : ProofForge.Compiler.TS.Module :=
  let envInterface : TopLevel :=
    .exportInterface "Env" #[(kvBindingName, .named "KVNamespace")]
  let funcs := m.entrypoints.map emitEntrypoint
  let routerItems := emitRouter m.entrypoints
  { items := #[envInterface] ++ funcs ++ routerItems }

end ProofForge.Compiler.TS.Emit
