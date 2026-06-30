import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.IR.Contract
import ProofForge.Target.Check
import ProofForge.Target.Registry

namespace ProofForge.Backend.Psy.IR

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

def indent (level : Nat) (line : String) : String :=
  String.ofList (List.replicate (level * 4) ' ') ++ line

def lines (xs : Array String) : String :=
  String.intercalate "\n" xs.toList

def capitalizedRefName (module : Module) : String :=
  s!"{module.name}Ref"

def testFunctionName (module : Module) : String :=
  if module.name == "HashProbe" then
    "test_hash_probe_fixture"
  else if module.name == "ContextProbe" then
    "test_context_probe_fixture"
  else if module.name == "Counter" then
    "test_counter_lifecycle"
  else
    s!"test_{module.name}_fixture"

def valueTypeName : ValueType → Except LowerError String
  | .unit => .ok "()"
  | .bool => .ok "bool"
  | .u64 => .ok "Felt"
  | .hash => .ok "Hash"

def literal : Literal → String
  | .u64 value => toString value
  | .bool true => "true"
  | .bool false => "false"
  | .hash4 a b c d => s!"[{a}, {b}, {c}, {d}]"

def contextFunction : ContextField → String
  | .userId => "get_user_id()"
  | .contractId => "get_contract_id()"
  | .checkpointId => "get_checkpoint_id()"

def stateDecl (state : StateDecl) : Except LowerError String := do
  match state.kind with
  | .scalar =>
      .ok s!"pub {state.id}: {← valueTypeName state.type},"

def stateExists (module : Module) (stateId : String) : Bool :=
  module.state.any fun state => state.id == stateId

mutual
  partial def lowerExpr (module : Module) : Expr → Except LowerError String
    | .literal value => .ok (literal value)
    | .local name => .ok name
    | .add lhs rhs => do
        .ok s!"{← lowerExpr module lhs} + {← lowerExpr module rhs}"
    | .hash preimage => do
        .ok s!"hash({← lowerExpr module preimage})"
    | .hashTwoToOne lhs rhs => do
        .ok s!"hash_two_to_one({← lowerExpr module lhs}, {← lowerExpr module rhs})"
    | .effect effect => lowerEffectExpr module effect

  partial def lowerEffectExpr (module : Module) : Effect → Except LowerError String
    | .storageScalarRead stateId => do
        if stateExists module stateId then
          .ok s!"c.{stateId}.get()"
        else
          .error { message := s!"unknown scalar state `{stateId}`" }
    | .storageScalarWrite _ _ =>
        .error { message := "storage.scalar.write is a statement effect, not an expression" }
    | .contextRead field =>
        .ok (contextFunction field)
end

def lowerEffectStmt (module : Module) : Effect → Except LowerError (Array String)
  | .storageScalarRead _ =>
      .error { message := "storage.scalar.read must be used as an expression" }
  | .storageScalarWrite stateId value => do
      if !stateExists module stateId then
        .error { message := s!"unknown scalar state `{stateId}`" }
      .ok #[s!"c.{stateId} = {← lowerExpr module value};"]
  | .contextRead _ =>
      .error { message := "context.read must be used as an expression" }

def lowerStatement (module : Module) : Statement → Except LowerError (Array String)
  | .letBind name type value => do
      .ok #[s!"let {name}: {← valueTypeName type} = {← lowerExpr module value};"]
  | .effect effect =>
      lowerEffectStmt module effect
  | .return value => do
      .ok #[s!"return {← lowerExpr module value};"]

def lowerBody (module : Module) (body : Array Statement) : Except LowerError (Array String) := do
  body.foldlM (init := #[]) fun acc stmt => do
    .ok (acc ++ (← lowerStatement module stmt))

def paramDecl (param : String × ValueType) : Except LowerError String := do
  .ok s!"{param.fst}: {← valueTypeName param.snd}"

def lowerEntrypoint (module : Module) (entrypoint : Entrypoint) : Except LowerError String := do
  let refName := capitalizedRefName module
  let returnSuffix ←
    match entrypoint.returns with
    | .unit => .ok ""
    | other => .ok s!" -> {← valueTypeName other}"
  let paramList ← entrypoint.params.mapM paramDecl
  let body ← lowerBody module entrypoint.body
  let header := indent 1 "#[contract_method]"
  let signature := indent 1 (s!"pub fn {entrypoint.name}({String.intercalate ", " paramList.toList}){returnSuffix} " ++ "{")
  let newRef := indent 2 s!"let c = {refName}::new(ContractMetadata::current());"
  let bodyLines := body.map (indent 2)
  lines (#[header, signature, newRef] ++ bodyLines ++ #[indent 1 "}"]) |> .ok

def validateState (module : Module) : Except LowerError Unit := do
  for state in module.state do
    match state.kind, state.type with
    | .scalar, .u64 => pure ()
    | .scalar, other =>
        .error { message := s!"state `{state.id}` has unsupported Psy IR v0 type `{other.name}`" }

def validateCapabilities (module : Module) : Except LowerError Unit :=
  match requireCapabilities Target.psyDpn module.capabilities with
  | .ok () => .ok ()
  | .error err => .error (capabilityError err)

def testBody (module : Module) : Except LowerError (Array String) := do
  let refName := capitalizedRefName module
  let hasCounterShape :=
    module.state.size == 1 &&
    module.state.any (fun state => state.id == "count" && state.kind == .scalar && state.type == .u64) &&
    module.entrypoints.any (fun entry => entry.name == "initialize") &&
    module.entrypoints.any (fun entry => entry.name == "increment") &&
    module.entrypoints.any (fun entry => entry.name == "get")
  if hasCounterShape then
    .ok #[
      s!"let c = {refName}::new(ContractMetadata::current());",
      s!"{refName}::initialize();",
      "assert_eq(c.count, 0, \"counter starts at zero\");",
      s!"{refName}::increment();",
      s!"assert_eq({refName}::get(), 1, \"counter increments once\");",
      s!"{refName}::increment();",
      s!"assert_eq({refName}::get(), 2, \"counter increments twice\");"
    ]
  else if module.name == "ContextProbe" &&
    module.entrypoints.any (fun entry => entry.name == "sum_context" && entry.params.size == 2 && entry.returns == .u64) then
    .ok #[
      s!"assert_eq({refName}::sum_context(2, 3), 2 + 3 + get_user_id() + get_contract_id() + get_checkpoint_id(), \"context sum follows current context\");"
    ]
  else if module.name == "HashProbe" &&
    module.entrypoints.any (fun entry => entry.name == "poseidon_hash" && entry.params.isEmpty && entry.returns == .hash) &&
    module.entrypoints.any (fun entry => entry.name == "poseidon_pair_hash" && entry.params.isEmpty && entry.returns == .hash) then
    .ok #[
      s!"let left: Hash = [1, 2, 3, 4];",
      s!"let right: Hash = [5, 6, 7, 8];",
      s!"assert_eq({refName}::poseidon_hash(), hash(left), \"hash probe matches Poseidon hash\");",
      s!"assert_eq({refName}::poseidon_pair_hash(), hash_two_to_one(left, right), \"pair hash probe matches Poseidon two-to-one hash\");"
    ]
  else
    .error { message := "Psy IR v0 only generates smoke tests for known fixtures" }

def renderModule (module : Module) : Except LowerError String := do
  validateCapabilities module
  validateState module
  let stateLines ← module.state.mapM stateDecl
  let entrypoints ← module.entrypoints.mapM (lowerEntrypoint module)
  let testLines := (← testBody module).map (indent 1)
  .ok <| lines <| #[
    s!"// Generated by ProofForge from the portable {module.name} IR.",
    "// This is Psy source intended for the official Dargo/Psy compiler toolchain.",
    "",
    "#[contract]",
    "#[derive(Storage)]",
    s!"pub struct {module.name} " ++ "{"
  ] ++ stateLines.map (indent 1) ++ #[
    "}",
    "",
    s!"impl {capitalizedRefName module} " ++ "{",
    lines entrypoints,
    "}",
    "",
    "#[test]",
    s!"fn {testFunctionName module}() " ++ "{"
  ] ++ testLines ++ #[
    "}",
    ""
  ]

end ProofForge.Backend.Psy.IR
