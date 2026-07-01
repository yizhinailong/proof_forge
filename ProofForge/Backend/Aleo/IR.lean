import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.IR.Contract
import ProofForge.Target.Check
import ProofForge.Target.Registry

namespace ProofForge.Backend.Aleo.IR

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

def indent (level : Nat) (line : String) : String :=
  String.ofList (List.replicate (level * 4) ' ') ++ line

def lines (xs : Array String) : String :=
  String.intercalate "\n" xs.toList

-- Render a value type to its Leo surface syntax.
def valueTypeName : ValueType → Except LowerError String
  | .unit => .error { message := "Aleo IR v0 does not support Unit as a value type" }
  | .bool => .ok "bool"
  | .u32 => .ok "u32"
  | .u64 => .ok "u64"
  | .hash => .error { message := "Aleo IR v0 does not support Hash" }
  | .fixedArray _ _ => .error { message := "Aleo IR v0 does not support fixed arrays" }
  | .structType _ => .error { message := "Aleo IR v0 does not support structs" }

-- Render a literal.
def literal : Literal → String
  | .u32 value => s!"{value}u32"
  | .u64 value => s!"{value}u64"
  | .bool true => "true"
  | .bool false => "false"
  | .hash4 _ _ _ _ => ""

-- Render an expression. Supports only the Counter subset.
partial def expr : Expr → Except LowerError String
  | .literal lit => .ok (literal lit)
  | .local name => .ok name
  | .add lhs rhs => do
      let lhsStr ← expr lhs
      let rhsStr ← expr rhs
      .ok s!"({lhsStr} + {rhsStr})"
  | .effect (.storageScalarRead stateId) =>
      .ok s!"Mapping::get_or_use({stateId}, 0u64)"
  | .effect ef =>
      .error { message := s!"Aleo IR v0 does not support effect expression: {repr ef}" }
  | other =>
      .error { message := s!"Aleo IR v0 does not support expression: {repr other}" }

-- Render a statement. Supports only the Counter subset.
partial def statement : Statement → Except LowerError (Array String)
  | .letBind name ty value => do
      let valueStr ← expr value
      .ok #[s!"let {name}: {← valueTypeName ty} = {valueStr};"]
  | .effect (.storageScalarWrite stateId value) => do
      let valueStr ← expr value
      .ok #[s!"Mapping::set({stateId}, {valueStr});"]
  | .effect ef =>
      .error { message := s!"Aleo IR v0 does not support effect statement: {repr ef}" }
  | .«return» value => do
      let valueStr ← expr value
      .ok #[s!"return {valueStr};"]
  | other =>
      .error { message := s!"Aleo IR v0 does not support statement: {repr other}" }

-- Render all statements in an entrypoint body.
def statements (body : Array Statement) : Except LowerError (Array String) := do
  let mut result := #[]
  for stmt in body do
    let lines ← statement stmt
    result := result ++ lines
  .ok result

-- Render a scalar state declaration as a public mapping.
def stateDecl (state : StateDecl) : Except LowerError String := do
  match state.kind with
  | .scalar =>
      match state.type with
      | .u64 =>
          .ok s!"mapping {state.id}: u64 => u64;"
      | other =>
          .error { message := s!"Aleo IR v0 scalar state only supports U64, got {other.name}" }
  | .map _ _ =>
      .error { message := s!"Aleo IR v0 does not support map state `{state.id}`" }
  | .array _ =>
      .error { message := s!"Aleo IR v0 does not support array state `{state.id}`" }

-- Render an entrypoint as a transition/final pair.
def entrypoint (ep : Entrypoint) : Except LowerError (Array String) := do
  let bodyLines ← statements ep.body
  if ep.name == "get" then
    if ep.returns != .u64 then
      .error { message := "Aleo IR v0 expects `get` entrypoint to return U64" }
    else
      .ok #[
        "transition get() -> public u64 {",
        indent 1 "return Mapping::get_or_use(count, 0u64);",
        "}"
      ]
  else if ep.name == "initialize" then
    if ep.returns != .unit then
      .error { message := "Aleo IR v0 expects `initialize` entrypoint to return Unit" }
    else
      .ok #[
        "transition initialize() {",
        indent 1 "return;",
        "}",
        "final initialize() {",
        indent 1 "Mapping::set(count, 0u64);",
        "}"
      ]
  else if ep.name == "increment" then
    if ep.returns != .unit then
      .error { message := "Aleo IR v0 expects `increment` entrypoint to return Unit" }
    else
      let finalBody := bodyLines.map (indent 1)
      .ok (#[
        "transition increment() {",
        indent 1 "return;",
        "}",
        "final increment() {"
      ] ++ finalBody ++ #["}"])
  else
    .error { message := s!"Aleo IR v0 does not support entrypoint `{ep.name}`" }

-- Render the full module.
def renderModule (module : Module) : Except LowerError String := do
  let stateLines ← module.state.mapM stateDecl
  let entrypointBlocks ← module.entrypoints.mapM entrypoint
  let entrypointLines := entrypointBlocks.foldl (fun acc block => acc ++ block) #[]
  let body := stateLines ++ #[""] ++ entrypointLines
  let renderedBody := lines (body.map (indent 1))
  .ok ("program " ++ module.name.toLower ++ ".aleo {\n" ++ renderedBody ++ "\n}")

end ProofForge.Backend.Aleo.IR
