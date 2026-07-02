import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Backend.Solana.Extension
import ProofForge.Backend.Solana.Manifest
import ProofForge.IR.Contract
import ProofForge.Target.Plan

namespace ProofForge.Backend.Solana.Idl

open ProofForge.IR
open ProofForge.Target
open ProofForge.Backend.Solana.Extension
open ProofForge.Backend.Solana.Manifest

def schema : String := "proof-forge.solana.idl.v0"
def targetId : String := "solana-sbpf-asm"
def irVersion : String := "portable-ir-v0"
def idlPath : String := "proof-forge-idl.json"

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

def jsonStringArray (values : Array String) : String :=
  jsonArray (values.map jsonString)

def jsonStringOption : Option String → String
  | some value => jsonString value
  | none => "null"

def pushUnique (values : Array String) (value : String) : Array String :=
  if values.any (fun existing => existing == value) then values else values.push value

def dedupStrings (values : Array String) : Array String :=
  values.foldl pushUnique #[]

def stateKindName : StateKind → String
  | .scalar => "scalar"
  | .map _ _ => "map"
  | .array _ => "array"

def stateKindJson : StateKind → String
  | .scalar =>
      jsonObject #[
        ("kind", jsonString "scalar")
      ]
  | .map keyType capacity =>
      jsonObject #[
        ("kind", jsonString "map"),
        ("keyType", jsonString keyType.name),
        ("capacity", toString capacity)
      ]
  | .array length =>
      jsonObject #[
        ("kind", jsonString "array"),
        ("length", toString length)
      ]

def structFieldJson (field : StructField) : String :=
  jsonObject #[
    ("name", jsonString field.id),
    ("type", jsonString field.type.name),
    ("public", jsonBool field.isPublic),
    ("ref", jsonBool field.isRef)
  ]

def structJson (decl : StructDecl) : String :=
  jsonObject #[
    ("name", jsonString decl.name),
    ("fields", jsonArray (decl.fields.map structFieldJson)),
    ("deriveStorage", jsonBool decl.deriveStorage),
    ("public", jsonBool decl.isPublic)
  ]

def stateJson (state : StateDecl) : String :=
  jsonObject #[
    ("name", jsonString state.id),
    ("type", jsonString state.type.name),
    ("kind", jsonString (stateKindName state.kind)),
    ("layout", stateKindJson state.kind)
  ]

def accountJson (account : AccountEntry) : String :=
  jsonObject #[
    ("name", jsonString account.name),
    ("index", toString account.index),
    ("signer", jsonBool account.signer),
    ("writable", jsonBool account.writable),
    ("owner", jsonString account.owner)
  ]

def paramJson (param : InstructionParamEntry) : String :=
  jsonObject #[
    ("name", jsonString param.name),
    ("type", jsonString param.typeName),
    ("offset", toString param.offset),
    ("byteSize", toString param.byteSize),
    ("encoding", jsonString param.encoding)
  ]

def entrypointReturnJson (module : Module) (name : String) : String :=
  match module.entrypoints.find? (fun ep => ep.name == name) with
  | some ep => jsonString ep.returns.name
  | none => jsonString "Unit"

def instructionJson (module : Module) (instruction : InstructionEntry) : String :=
  jsonObject #[
    ("name", jsonString instruction.name),
    ("tag", toString instruction.tag),
    ("handler", jsonString instruction.handler),
    ("minDataLen", toString instruction.minDataLen),
    ("accounts", jsonArray (instruction.accounts.map accountJson)),
    ("params", jsonArray (instruction.params.map paramJson)),
    ("returns", entrypointReturnJson module instruction.name)
  ]

def declaredAccountJson (account : DeclaredAccount) : String :=
  jsonObject #[
    ("name", jsonString account.name),
    ("access", jsonString account.access),
    ("signer", jsonString account.signer),
    ("owner", jsonString account.owner),
    ("entrypoint", jsonStringOption account.entrypoint?)
  ]

def pdaSeedJson (seed : PdaSeed) : String :=
  jsonObject #[
    ("kind", jsonString seed.kind.id),
    ("value", jsonString seed.value),
    ("raw", jsonString seed.raw)
  ]

def pdaJson (pda : PdaDerive) : String :=
  jsonObject #[
    ("name", jsonString pda.name),
    ("seeds", jsonStringArray pda.seedValues),
    ("typedSeeds", jsonArray (pda.effectiveSeeds.map pdaSeedJson)),
    ("bump", jsonStringOption pda.bump?),
    ("account", jsonStringOption pda.account?),
    ("signer", jsonBool pda.signer),
    ("entrypoint", jsonStringOption pda.entrypoint?)
  ]

def cpiAccountJson (account : AccountMeta) : String :=
  jsonObject #[
    ("name", jsonString account.name),
    ("access", jsonString account.access),
    ("signer", jsonString account.signer)
  ]

def cpiMetadataJson (cpi : CpiInvoke) (metadataKey fieldName : String) : String × String :=
  match metadataValue? cpi.metadata metadataKey with
  | some value => (fieldName, jsonString value)
  | none => (fieldName, "null")

def cpiJson (cpi : CpiInvoke) : String :=
  jsonObject #[
    ("name", jsonString cpi.name),
    ("program", jsonString cpi.program),
    ("instruction", jsonString cpi.instruction),
    ("accounts", jsonArray (cpi.accounts.map cpiAccountJson)),
    ("signerSeeds", jsonStringArray cpi.signerSeeds),
    ("protocol", jsonStringOption cpi.protocol?),
    ("dataLayout", jsonStringOption cpi.dataLayout?),
    cpiMetadataJson cpi "solana.cpi.lamports_source" "lamportsSource",
    cpiMetadataJson cpi "solana.cpi.space_source" "spaceSource",
    cpiMetadataJson cpi "solana.cpi.owner" "ownerSource",
    cpiMetadataJson cpi "solana.cpi.amount_source" "amountSource",
    cpiMetadataJson cpi "solana.cpi.decimals" "decimals",
    cpiMetadataJson cpi "solana.cpi.authority_type" "authorityType",
    cpiMetadataJson cpi "solana.cpi.new_authority" "newAuthority",
    ("signed", jsonBool cpi.signed),
    ("entrypoint", jsonStringOption cpi.entrypoint?)
  ]

def allocatorJson (allocator : RuntimeAllocator) : String :=
  jsonObject #[
    ("name", jsonString allocator.name),
    ("kind", jsonString allocator.kind),
    ("model", jsonString allocator.model),
    ("heapStart", jsonString allocator.heapStart),
    ("heapBytes", jsonString allocator.heapBytes),
    ("entrypoint", jsonStringOption allocator.entrypoint?)
  ]

def pdaActionJson (action : PdaAction) : String :=
  jsonObject #[
    ("entrypoint", jsonString action.entrypoint),
    ("pda", jsonString action.name)
  ]

def cpiActionJson (action : CpiAction) : String :=
  jsonObject #[
    ("entrypoint", jsonString action.entrypoint),
    ("cpi", jsonString action.name)
  ]

def actionsJson (extensions : ProgramExtensions) : String :=
  jsonObject #[
    ("pdas", jsonArray (extensions.pdaActions.map pdaActionJson)),
    ("cpis", jsonArray (extensions.cpiActions.map cpiActionJson))
  ]

def capabilitiesJson (plan : CapabilityPlan) : String :=
  jsonStringArray (dedupStrings (plan.capabilities.map fun capability => capability.id))

def renderWithInstructions (module : Module) (instructions : Array InstructionEntry)
    (extensions : ProgramExtensions) (capabilities : Array String := #[]) : String :=
  jsonObject #[
    ("schema", jsonString schema),
    ("name", jsonString module.name),
    ("target", jsonString targetId),
    ("irVersion", jsonString irVersion),
    ("capabilities", jsonStringArray (dedupStrings capabilities)),
    ("structs", jsonArray (module.structs.map structJson)),
    ("state", jsonArray (module.state.map stateJson)),
    ("instructions", jsonArray (instructions.map (instructionJson module))),
    ("accounts", jsonArray (buildModuleAccounts module extensions |>.map accountJson)),
    ("declaredAccounts", jsonArray (extensions.accounts.map declaredAccountJson)),
    ("allocators", jsonArray (extensions.allocators.map allocatorJson)),
    ("pdas", jsonArray (extensions.pdas.map pdaJson)),
    ("cpis", jsonArray (extensions.cpis.map cpiJson)),
    ("entrypointActions", actionsJson extensions)
  ]

def renderWithPlan (module : Module) (plan : CapabilityPlan) : String :=
  let extensions := ProgramExtensions.fromPlan plan
  renderWithInstructions
    module
    (buildInstructionsWithExtensions module extensions)
    extensions
    (plan.capabilities.map fun capability => capability.id)

def render (module : Module) : String :=
  let extensions : ProgramExtensions := {}
  renderWithInstructions
    module
    (buildInstructions module)
    extensions
    (module.capabilities.map fun capability => capability.id)

end ProofForge.Backend.Solana.Idl
