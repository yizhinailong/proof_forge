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
  if module.name == "StructProbe" then
    "test_struct_probe_fixture"
  else if module.name == "ArrayProbe" then
    "test_array_probe_fixture"
  else if module.name == "LoopProbe" then
    "test_loop_probe_fixture"
  else if module.name == "AssertProbe" then
    "test_assert_probe_fixture"
  else if module.name == "MapProbe" then
    "test_map_probe_fixture"
  else if module.name == "HashProbe" then
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
  | .fixedArray element length => do
      if length == 0 then
        .error { message := "Psy IR v0 fixed arrays must have non-zero length" }
      .ok s!"[{← valueTypeName element}; {length}]"
  | .structType name => .ok name

def literal : Literal → String
  | .u64 value => toString value
  | .bool true => "true"
  | .bool false => "false"
  | .hash4 a b c d => s!"[{a}, {b}, {c}, {d}]"

def stringLiteral (value : String) : String :=
  let escapeChar : Char → String
    | '"' => "\\\""
    | '\\' => "\\\\"
    | '\n' => "\\n"
    | '\r' => "\\r"
    | '\t' => "\\t"
    | ch => ch.toString
  "\"" ++ String.intercalate "" (value.toList.map escapeChar) ++ "\""

def contextFunction : ContextField → String
  | .userId => "get_user_id()"
  | .contractId => "get_contract_id()"
  | .checkpointId => "get_checkpoint_id()"

def fieldVisibility (isPublic : Bool) : String :=
  if isPublic then "pub " else ""

def structFieldDecl (field : StructField) : Except LowerError String := do
  .ok s!"{fieldVisibility field.isPublic}{field.id}: {← valueTypeName field.type},"

def structDecl (decl : StructDecl) : Except LowerError String := do
  let deriveLines := if decl.deriveStorage then #["#[derive(Storage)]"] else #[]
  let fields ← decl.fields.mapM structFieldDecl
  .ok <| lines <|
    deriveLines ++ #[
      s!"{fieldVisibility decl.isPublic}struct {decl.name} " ++ "{"
    ] ++ fields.map (indent 1) ++ #[
      "}"
    ]

def stateDecl (state : StateDecl) : Except LowerError (Array String) := do
  match state.kind with
  | .scalar =>
      match state.type with
      | .structType _ =>
          .ok #[
            "#[ref]",
            s!"pub {state.id}: {← valueTypeName state.type},"
          ]
      | _ =>
          .ok #[s!"pub {state.id}: {← valueTypeName state.type},"]
  | .map keyType capacity =>
      .ok #[s!"pub {state.id}: Map<{← valueTypeName keyType}, {← valueTypeName state.type}, {capacity}u32>,"]
  | .array length =>
      .ok #[s!"pub {state.id}: [{← valueTypeName state.type}; {length}],"]

def findState? (module : Module) (stateId : String) : Option StateDecl :=
  module.state.find? fun state => state.id == stateId

def findStruct? (module : Module) (name : String) : Option StructDecl :=
  module.structs.find? fun decl => decl.name == name

def requireScalarState (module : Module) (stateId : String) : Except LowerError Unit :=
  match findState? module stateId with
  | some state =>
      match state.kind with
      | .scalar => .ok ()
      | .map _ _ => .error { message := s!"state `{stateId}` is a map, not scalar storage" }
      | .array _ => .error { message := s!"state `{stateId}` is an array, not scalar storage" }
  | none => .error { message := s!"unknown scalar state `{stateId}`" }

def requireMapState (module : Module) (stateId : String) : Except LowerError Unit :=
  match findState? module stateId with
  | some state =>
      match state.kind with
      | .map _ _ => .ok ()
      | .scalar => .error { message := s!"state `{stateId}` is scalar storage, not a map" }
      | .array _ => .error { message := s!"state `{stateId}` is array storage, not a map" }
  | none => .error { message := s!"unknown map state `{stateId}`" }

def requireArrayState (module : Module) (stateId : String) : Except LowerError Unit :=
  match findState? module stateId with
  | some state =>
      match state.kind with
      | .array _ => .ok ()
      | .scalar => .error { message := s!"state `{stateId}` is scalar storage, not an array" }
      | .map _ _ => .error { message := s!"state `{stateId}` is map storage, not an array" }
  | none => .error { message := s!"unknown array state `{stateId}`" }

def requireStructScalarState (module : Module) (stateId fieldName : String) : Except LowerError Unit :=
  match findState? module stateId with
  | some state =>
      match state.kind, state.type with
      | .scalar, .structType typeName => do
          let some decl := findStruct? module typeName
            | .error { message := s!"state `{stateId}` references unknown struct `{typeName}`" }
          if decl.fields.any (fun field => field.id == fieldName) then
            .ok ()
          else
            .error { message := s!"struct `{typeName}` has no field `{fieldName}`" }
      | .scalar, other =>
          .error { message := s!"state `{stateId}` has scalar type `{other.name}`, not struct storage" }
      | .map _ _, _ =>
          .error { message := s!"state `{stateId}` is map storage, not struct scalar storage" }
      | .array _, _ =>
          .error { message := s!"state `{stateId}` is array storage, not struct scalar storage" }
  | none => .error { message := s!"unknown struct state `{stateId}`" }

mutual
  partial def lowerExpr (module : Module) : Expr → Except LowerError String
    | .literal value => .ok (literal value)
    | .local name => .ok name
    | .arrayLit elementType values => do
        if values.isEmpty then
          .error { message := s!"empty fixed array literals are not supported by Psy IR v0 for `{← valueTypeName elementType}`" }
        let items ← values.mapM (lowerExpr module)
        .ok s!"[{String.intercalate ", " items.toList}]"
    | .arrayGet array index => do
        .ok s!"{← lowerExpr module array}[{← lowerExpr module index}]"
    | .structLit typeName fields => do
        if fields.isEmpty then
          .error { message := s!"struct literal `{typeName}` must have at least one field" }
        let items ← fields.mapM fun field => do
          .ok s!"{field.fst}: {← lowerExpr module field.snd}"
        .ok (s!"new {typeName} " ++ "{" ++ s!" {String.intercalate ", " items.toList} " ++ "}")
    | .field base fieldName => do
        .ok s!"{← lowerExpr module base}.{fieldName}"
    | .add lhs rhs => do
        .ok s!"{← lowerExpr module lhs} + {← lowerExpr module rhs}"
    | .hash preimage => do
        .ok s!"hash({← lowerExpr module preimage})"
    | .hashTwoToOne lhs rhs => do
        .ok s!"hash_two_to_one({← lowerExpr module lhs}, {← lowerExpr module rhs})"
    | .effect effect => lowerEffectExpr module effect

  partial def lowerEffectExpr (module : Module) : Effect → Except LowerError String
    | .storageScalarRead stateId => do
        requireScalarState module stateId
        .ok s!"c.{stateId}.get()"
    | .storageScalarWrite _ _ =>
        .error { message := "storage.scalar.write is a statement effect, not an expression" }
    | .storageMapContains stateId key => do
        requireMapState module stateId
        .ok s!"c.{stateId}.contains({← lowerExpr module key})"
    | .storageMapGet stateId key => do
        requireMapState module stateId
        .ok s!"c.{stateId}.get({← lowerExpr module key})"
    | .storageMapInsert stateId key value => do
        requireMapState module stateId
        .ok s!"c.{stateId}.insert({← lowerExpr module key}, {← lowerExpr module value})"
    | .storageMapSet _ _ _ =>
        .error { message := "storage.map.set is a statement effect, not an expression" }
    | .storageArrayRead stateId index => do
        requireArrayState module stateId
        .ok s!"c.{stateId}[{← lowerExpr module index}].get()"
    | .storageArrayWrite _ _ _ =>
        .error { message := "storage.array.write is a statement effect, not an expression" }
    | .storageStructFieldRead stateId fieldName => do
        requireStructScalarState module stateId fieldName
        .ok s!"c.{stateId}.{fieldName}.get()"
    | .storageStructFieldWrite _ _ _ =>
        .error { message := "storage.struct.field.write is a statement effect, not an expression" }
    | .contextRead field =>
        .ok (contextFunction field)
end

def lowerEffectStmt (module : Module) : Effect → Except LowerError (Array String)
  | .storageScalarRead _ =>
      .error { message := "storage.scalar.read must be used as an expression" }
  | .storageScalarWrite stateId value => do
      requireScalarState module stateId
      .ok #[s!"c.{stateId} = {← lowerExpr module value};"]
  | .storageMapContains _ _ =>
      .error { message := "storage.map.contains must be used as an expression" }
  | .storageMapGet _ _ =>
      .error { message := "storage.map.get must be used as an expression" }
  | .storageMapInsert stateId key value => do
      requireMapState module stateId
      .ok #[s!"c.{stateId}.insert({← lowerExpr module key}, {← lowerExpr module value});"]
  | .storageMapSet stateId key value => do
      requireMapState module stateId
      .ok #[s!"c.{stateId}.set({← lowerExpr module key}, {← lowerExpr module value});"]
  | .storageArrayRead _ _ =>
      .error { message := "storage.array.read must be used as an expression" }
  | .storageArrayWrite stateId index value => do
      requireArrayState module stateId
      .ok #[s!"c.{stateId}[{← lowerExpr module index}] = {← lowerExpr module value};"]
  | .storageStructFieldRead _ _ =>
      .error { message := "storage.struct.field.read must be used as an expression" }
  | .storageStructFieldWrite stateId fieldName value => do
      requireStructScalarState module stateId fieldName
      .ok #[s!"c.{stateId}.{fieldName} = {← lowerExpr module value};"]
  | .contextRead _ =>
      .error { message := "context.read must be used as an expression" }

mutual
  partial def lowerStatement (module : Module) : Statement → Except LowerError (Array String)
    | .letBind name type value => do
        .ok #[s!"let {name}: {← valueTypeName type} = {← lowerExpr module value};"]
    | .effect effect =>
        lowerEffectStmt module effect
    | .assert condition message => do
        .ok #[s!"assert({← lowerExpr module condition}, {stringLiteral message});"]
    | .assertEq lhs rhs message => do
        .ok #[s!"assert_eq({← lowerExpr module lhs}, {← lowerExpr module rhs}, {stringLiteral message});"]
    | .boundedFor indexName start stopExclusive body => do
        if stopExclusive <= start then
          .error { message := s!"bounded loop `{indexName}` must have stop greater than start" }
        let bodyLines ← lowerBody module body
        .ok <|
          #[s!"for {indexName} in {start}u32..{stopExclusive}u32 " ++ "{"] ++
          bodyLines.map (indent 1) ++
          #["}"]
    | .return value => do
        .ok #[s!"return {← lowerExpr module value};"]

  partial def lowerBody (module : Module) (body : Array Statement) : Except LowerError (Array String) := do
    body.foldlM (init := #[]) fun acc stmt => do
      .ok (acc ++ (← lowerStatement module stmt))
end

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

partial def validateValueType (module : Module) (type : ValueType) : Except LowerError Unit := do
  match type with
  | .unit => .error { message := "Psy IR v0 does not support Unit as a stored or structured value type" }
  | .bool | .u64 | .hash => pure ()
  | .fixedArray element length =>
      if length == 0 then
        .error { message := "Psy IR v0 fixed arrays must have non-zero length" }
      validateValueType module element
  | .structType name =>
      match findStruct? module name with
      | some _ => pure ()
      | none => .error { message := s!"unknown struct type `{name}`" }

def validateStructs (module : Module) : Except LowerError Unit := do
  for decl in module.structs do
    if decl.fields.isEmpty then
      .error { message := s!"struct `{decl.name}` must declare at least one field" }
    for field in decl.fields do
      validateValueType module field.type

def validateState (module : Module) : Except LowerError Unit := do
  for state in module.state do
    match state.kind, state.type with
    | .scalar, .u64 => pure ()
    | .scalar, .structType typeName =>
        match findStruct? module typeName with
        | some decl =>
            if decl.deriveStorage then
              pure ()
            else
              .error { message := s!"state `{state.id}` uses struct `{typeName}`, but the struct is not marked deriveStorage" }
        | none =>
            .error { message := s!"state `{state.id}` references unknown struct `{typeName}`" }
    | .scalar, other =>
        .error { message := s!"state `{state.id}` has unsupported Psy IR v0 type `{other.name}`" }
    | .map .hash capacity, .hash =>
        if capacity == 0 then
          .error { message := s!"map state `{state.id}` must have non-zero capacity" }
        else
          pure ()
    | .map keyType _, valueType =>
        .error { message := s!"map state `{state.id}` has unsupported Psy IR v0 type Map<{keyType.name}, {valueType.name}>; only Map<Hash, Hash, N> is supported" }
    | .array length, .u64 =>
        if length == 0 then
          .error { message := s!"array state `{state.id}` must have non-zero length" }
        else
          pure ()
    | .array length, .hash =>
        if length == 0 then
          .error { message := s!"array state `{state.id}` must have non-zero length" }
        else
          pure ()
    | .array _, valueType =>
        .error { message := s!"array state `{state.id}` has unsupported Psy IR v0 element type `{valueType.name}`; only Felt and Hash arrays are supported" }

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
  else if module.name == "MapProbe" &&
    module.state.any (fun state => state.id == "balances") &&
    module.entrypoints.any (fun entry => entry.name == "map_lifecycle" && entry.params.isEmpty && entry.returns == .hash) &&
    module.entrypoints.any (fun entry => entry.name == "has_seed_balance" && entry.params.isEmpty && entry.returns == .bool) &&
    module.entrypoints.any (fun entry => entry.name == "get_seed_balance" && entry.params.isEmpty && entry.returns == .hash) then
    .ok #[
      s!"let c = {refName}::new(ContractMetadata::current());",
      "let key: Hash = [1001, 0, 0, 0];",
      "let value1: Hash = [55, 66, 77, 88];",
      s!"assert_eq({refName}::has_seed_balance(), false, \"seed balance starts absent\");",
      s!"assert_eq({refName}::map_lifecycle(), value1, \"map lifecycle returns the updated value\");",
      s!"assert_eq({refName}::has_seed_balance(), true, \"seed balance exists after lifecycle\");",
      s!"assert_eq({refName}::get_seed_balance(), value1, \"seed getter reads the lifecycle value\");",
      "assert_eq(c.before, 111, \"map lifecycle preserves before field\");",
      "assert_eq(c.after, 222, \"map lifecycle preserves after field\");",
      "assert_eq(c.balances.contains(key), true, \"raw map contains follows generated entrypoint\");"
    ]
  else if module.name == "AssertProbe" &&
    module.entrypoints.any (fun entry => entry.name == "checked_sum" && entry.params.size == 2 && entry.returns == .u64) then
    .ok #[
      s!"assert_eq({refName}::checked_sum(5, 7), 12, \"checked_sum returns the asserted value\");"
    ]
  else if module.name == "LoopProbe" &&
    module.entrypoints.any (fun entry => entry.name == "count_to_three" && entry.params.isEmpty && entry.returns == .u64) then
    .ok #[
      s!"assert_eq({refName}::count_to_three(), 3, \"bounded loop runs exactly three iterations\");"
    ]
  else if module.name == "ArrayProbe" &&
    module.entrypoints.any (fun entry => entry.name == "sum_literal" && entry.params.isEmpty && entry.returns == .u64) &&
    module.entrypoints.any (fun entry => entry.name == "storage_lifecycle" && entry.params.isEmpty && entry.returns == .u64) then
    .ok #[
      s!"assert_eq({refName}::sum_literal(), 60, \"fixed array literal indexes add up\");",
      s!"assert_eq({refName}::storage_lifecycle(), 31, \"storage array indexes read after writes\");"
    ]
  else if module.name == "StructProbe" &&
    module.entrypoints.any (fun entry => entry.name == "local_sum" && entry.params.isEmpty && entry.returns == .u64) &&
    module.entrypoints.any (fun entry => entry.name == "storage_lifecycle" && entry.params.isEmpty && entry.returns == .u64) then
    .ok #[
      s!"assert_eq({refName}::local_sum(), 30, \"struct literal fields add up\");",
      s!"assert_eq({refName}::storage_lifecycle(), 26, \"storage struct fields read after writes\");"
    ]
  else
    .error { message := "Psy IR v0 only generates smoke tests for known fixtures" }

def renderModule (module : Module) : Except LowerError String := do
  validateCapabilities module
  validateStructs module
  validateState module
  let structBlocks ← module.structs.mapM structDecl
  let stateDecls ← module.state.mapM stateDecl
  let stateLines := stateDecls.foldl (fun acc lines => acc ++ lines) #[]
  let entrypoints ← module.entrypoints.mapM (lowerEntrypoint module)
  let testLines := (← testBody module).map (indent 1)
  let structLines :=
    if structBlocks.isEmpty then
      #[]
    else
      #[String.intercalate "\n\n" structBlocks.toList, ""]
  .ok <| lines <| #[
    s!"// Generated by ProofForge from the portable {module.name} IR.",
    "// This is Psy source intended for the official Dargo/Psy compiler toolchain.",
    ""
  ] ++ structLines ++ #[
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
