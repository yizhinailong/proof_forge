import ProofForge.IR.Contract
import ProofForge.Compiler.Leo.AST
import ProofForge.Compiler.Leo.Printer

namespace ProofForge.Compiler.Leo.Emit

open ProofForge.IR
open ProofForge.Compiler.Leo.AST

/-- Map a portable IR value type to a Leo type. -/
def valueType (t : ValueType) : Except AST.LowerError LeoType :=
  match t with
  | .unit => .ok .unit
  | .bool => .ok .boolean
  | .u32 => .ok (.integer .u32)
  | .u64 => .ok (.integer .u64)
  | .hash => .error { message := "Leo emitter does not support Hash" }
  | .fixedArray _ _ => .error { message := "Leo emitter does not support fixed arrays" }
  | .structType name => .ok (.composite name)

/-- Map a portable IR literal to a Leo literal. -/
def lit : IR.Literal → AST.Literal
  | .u32 value => .integer .u32 value
  | .u64 value => .integer .u64 value
  | .bool value => .boolean value
  | .hash4 _ _ _ _ => .none

mutual
  /-- Map a portable IR expression to a Leo expression. -/
  partial def expr : Expr → Except AST.LowerError Expression
    | .literal l => .ok (.literal (lit l))
    | .local name => .ok (.identifier name)
    | .add lhs rhs => do .ok (.binary ⟨.add, ← expr lhs, ← expr rhs⟩)
    | .sub lhs rhs => do .ok (.binary ⟨.sub, ← expr lhs, ← expr rhs⟩)
    | .mul lhs rhs => do .ok (.binary ⟨.mul, ← expr lhs, ← expr rhs⟩)
    | .div lhs rhs => do .ok (.binary ⟨.div, ← expr lhs, ← expr rhs⟩)
    | .mod lhs rhs => do .ok (.binary ⟨.mod, ← expr lhs, ← expr rhs⟩)
    | .eq lhs rhs => do .ok (.binary ⟨.eq, ← expr lhs, ← expr rhs⟩)
    | .ne lhs rhs => do .ok (.binary ⟨.neq, ← expr lhs, ← expr rhs⟩)
    | .lt lhs rhs => do .ok (.binary ⟨.lt, ← expr lhs, ← expr rhs⟩)
    | .le lhs rhs => do .ok (.binary ⟨.lte, ← expr lhs, ← expr rhs⟩)
    | .gt lhs rhs => do .ok (.binary ⟨.gt, ← expr lhs, ← expr rhs⟩)
    | .ge lhs rhs => do .ok (.binary ⟨.gte, ← expr lhs, ← expr rhs⟩)
    | .boolAnd lhs rhs => do .ok (.binary ⟨.and, ← expr lhs, ← expr rhs⟩)
    | .boolOr lhs rhs => do .ok (.binary ⟨.or, ← expr lhs, ← expr rhs⟩)
    | .boolNot value => do .ok (.unary ⟨.not, ← expr value⟩)
    | .cast value target => do .ok (.cast ⟨← expr value, ← valueType target⟩)
    | .effect (.storageScalarRead stateId) =>
        .ok (.call ⟨#["Mapping", "get_or_use"], #[], #[.identifier stateId, .literal (.integer .u64 0), .literal (.integer .u64 0)]⟩)
    | .effect ef =>
        .error { message := s!"Leo emitter does not support effect: {repr ef}" }
    | other =>
        .error { message := s!"Leo emitter does not support expression: {repr other}" }

  /-- Map a portable IR statement to Leo statements. -/
  partial def statement : IR.Statement → Except AST.LowerError (Array AST.Statement)
    | .letBind name ty value => do
        let v ← expr value
        .ok #[.definition (.single name) (some (← valueType ty)) v]
    | .letMutBind name ty value => do
        let v ← expr value
        .ok #[.definition (.single name) (some (← valueType ty)) v]
    | .effect (.storageScalarWrite stateId value) => do
        let v ← expr value
        .ok #[.expression (.call ⟨#["Mapping", "set"], #[], #[.identifier stateId, .literal (.integer .u64 0), v]⟩)]
    | .effect ef =>
        .error { message := s!"Leo emitter does not support effect statement: {repr ef}" }
    | .«return» value => do
        let v ← expr value
        .ok #[.returnSt (some v)]
    | other =>
        .error { message := s!"Leo emitter does not support statement: {repr other}" }
end

def statements (body : Array IR.Statement) : Except AST.LowerError (Array AST.Statement) := do
  let mut result := #[]
  for stmt in body do
    let ss ← statement stmt
    result := result ++ ss
  .ok result

/-- Build a Leo mapping from a scalar U64 state declaration. -/
def stateMapping (state : StateDecl) : Except AST.LowerError Mapping :=
  match state.kind with
  | .scalar =>
      match state.type with
      | .u64 => .ok { identifier := state.id, keyType := .integer .u64, valueType := .integer .u64 }
      | other => .error { message := s!"Leo emitter scalar state only supports U64, got {other.name}" }
  | .map _ _ => .error { message := s!"Leo emitter does not support map state `{state.id}`" }
  | .array _ => .error { message := s!"Leo emitter does not support array state `{state.id}`" }

/-- Build the @noupgrade constructor required by Leo 4.0.2. -/
def constructor : Constructor :=
  { annotations := #[{ name := "noupgrade" }], block := { statements := #[] } }

def futureUnit : LeoType :=
  .future #[] .unit

/-- Build an entrypoint function. Counter spike special-cases initialize/get/increment. -/
def entrypointFunction (ep : Entrypoint) : Except AST.LowerError Function := do
  if ep.name == "initialize" then
    if ep.returns != .unit then
      .error { message := "Aleo IR v0 expects `initialize` entrypoint to return Unit" }
    else
      let setCall := Expression.call ⟨#["Mapping", "set"], #[], #[.identifier "count", .literal (.integer .u64 0), .literal (.integer .u64 0)]⟩
      let asyncBlock : Block := { statements := #[.expression setCall] }
      .ok {
        annotations := #[]
        variant := .entryPoint
        identifier := "initialize"
        constParameters := #[]
        input := #[]
        output := #[]
        outputType := futureUnit
        block := { statements := #[.returnSt (some (.async asyncBlock))] }
      }
  else if ep.name == "get" then
    if ep.returns != .u64 then
      .error { message := "Aleo IR v0 expects `get` entrypoint to return U64" }
    else
      let readCall := Expression.call ⟨#["Mapping", "get_or_use"], #[], #[.identifier "count", .literal (.integer .u64 0), .literal (.integer .u64 0)]⟩
      let asyncBlock : Block := { statements := #[.definition (.single "n") (some (.integer .u64)) readCall] }
      .ok {
        annotations := #[]
        variant := .entryPoint
        identifier := "get"
        constParameters := #[]
        input := #[]
        output := #[]
        outputType := futureUnit
        block := { statements := #[.returnSt (some (.async asyncBlock))] }
      }
  else if ep.name == "increment" then
    if ep.returns != .unit then
      .error { message := "Aleo IR v0 expects `increment` entrypoint to return Unit" }
    else
      let bodyStmts ← statements ep.body
      let asyncBlock : Block := { statements := bodyStmts }
      .ok {
        annotations := #[]
        variant := .entryPoint
        identifier := "increment"
        constParameters := #[]
        input := #[]
        output := #[]
        outputType := futureUnit
        block := { statements := #[.returnSt (some (.async asyncBlock))] }
      }
  else
    .error { message := s!"Aleo IR v0 does not support entrypoint `{ep.name}`" }

/-- Emit a full IR module as a Leo Program AST. -/
def emitModule (module : Module) : Except AST.LowerError Program := do
  let mappings ← module.state.mapM stateMapping
  let functions ← module.entrypoints.mapM entrypointFunction
  let scope : ProgramScope := {
    programId := module.name.toLower ++ ".aleo"
    parents := #[]
    consts := #[]
    composites := #[]
    mappings := mappings.map (fun m => (m.identifier, m))
    storageVariables := #[]
    functions := functions.map (fun f => (f.identifier, f))
    interfaces := #[]
    constructor := some constructor
  }
  .ok {
    imports := #[]
    scopes := #[(module.name.toLower, scope)]
  }

/-- Convenience: emit and print in one step. -/
def renderModule (module : Module) : Except AST.LowerError String := do
  let p ← emitModule module
  ProofForge.Compiler.Leo.Printer.printProgram p

end ProofForge.Compiler.Leo.Emit
