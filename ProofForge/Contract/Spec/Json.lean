import ProofForge.Contract.Spec
import ProofForge.IR.Contract

namespace ProofForge.Contract.Spec.Json

open ProofForge.IR

def jsonString (value : String) : String :=
  let escapeChar : Char → String
    | '"' => "\\\""
    | '\\' => "\\\\"
    | '\n' => "\\n"
    | '\r' => "\\r"
    | '\t' => "\\t"
    | ch => ch.toString
  "\"" ++ String.intercalate "" (value.toList.map escapeChar) ++ "\""

def jsonBool (value : Bool) : String :=
  if value then "true" else "false"

def jsonArray (items : Array String) : String :=
  "[" ++ String.intercalate ", " items.toList ++ "]"

def jsonObject (fields : Array (String × String)) : String :=
  "{" ++
    String.intercalate ", " (fields.toList.map fun field =>
      jsonString field.fst ++ ": " ++ field.snd) ++
  "}"

def jsonStringOption : Option String → String
  | some value => jsonString value
  | none => "null"

def jsonStringArray (values : Array String) : String :=
  jsonArray (values.map jsonString)

def valueTypeJson (type : ValueType) : String := jsonString type.name

def paramJson (param : String × ValueType) : String :=
  jsonObject #[
    ("name", jsonString param.fst),
    ("type", valueTypeJson param.snd)
  ]

def entrypointJson (entrypoint : Entrypoint) : String :=
  jsonObject #[
    ("name", jsonString entrypoint.name),
    ("selector", jsonStringOption entrypoint.selector?),
    ("returns", valueTypeJson entrypoint.returns),
    ("params", jsonArray (entrypoint.params.map paramJson))
  ]

def stateJson (state : StateDecl) : String :=
  jsonObject #[
    ("id", jsonString state.id),
    ("kind", jsonString (match state.kind with
      | .scalar => "scalar"
      | .map _ _ => "map"
      | .array _ => "array")),
    ("type", valueTypeJson state.type)
  ]

def intentKindJson : ProofForge.Contract.IntentKind → String
  | .module => jsonString "module"
  | .state => jsonString "state"
  | .entrypoint => jsonString "entrypoint"
  | .capability => jsonString "capability"

def intentJson (intent : ProofForge.Contract.Intent) : String :=
  jsonObject #[
    ("kind", intentKindJson intent.kind),
    ("label", jsonString intent.label)
  ]

def render (spec : ContractSpec) : String :=
  jsonObject #[
    ("schema", jsonString "proof-forge.contract-spec.v0"),
    ("name", jsonString spec.name),
    ("irVersion", jsonString "portable-ir-v0"),
    ("state", jsonArray (spec.module.state.map stateJson)),
    ("entrypoints", jsonArray (spec.module.entrypoints.map entrypointJson)),
    ("capabilities", jsonStringArray (spec.module.capabilities.map fun c => c.id)),
    ("intents", jsonArray (spec.intents.map intentJson))
  ]

end ProofForge.Contract.Spec.Json
