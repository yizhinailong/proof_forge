import ProofForge.Contract.Token.Examples.SoulboundToken
import ProofForge.Target.Registry

namespace ProofForge.Tests.TokenPlanEmit

open ProofForge.Contract.Token
open ProofForge.Target

private def jsonString (value : String) : String :=
  let escapeChar : Char → String
    | '"' => "\\\""
    | '\\' => "\\\\"
    | '\n' => "\\n"
    | '\r' => "\\r"
    | '\t' => "\\t"
    | ch => ch.toString
  "\"" ++ String.intercalate "" (value.toList.map escapeChar) ++ "\""

private def jsonBool (value : Bool) : String :=
  if value then "true" else "false"

private def jsonObject (fields : Array (String × String)) : String :=
  "{" ++ String.intercalate "," (fields.toList.map fun field => jsonString field.fst ++ ":" ++ field.snd) ++ "}"

private def jsonArray (values : Array String) : String :=
  "[" ++ String.intercalate "," values.toList ++ "]"

private def jsonStringArray (values : Array String) : String :=
  jsonArray (values.map jsonString)

private def jsonStringOption : Option String → String
  | some value => jsonString value
  | none => "null"

private def jsonNatOption : Option Nat → String
  | some value => toString value
  | none => "null"

private def dedupStrings (values : Array String) : Array String :=
  values.foldl (fun acc value => if acc.contains value then acc else acc.push value) #[]

private def tokenSpecJson (id : String) (spec : TokenSpec) : String :=
  jsonObject #[
    ("id", jsonString id),
    ("name", jsonString spec.name),
    ("symbol", jsonString spec.symbol),
    ("decimals", toString spec.decimals),
    ("initialSupply", jsonNatOption spec.initialSupply?),
    ("features", jsonStringArray (spec.features.map fun feature => feature.id))
  ]

private def tokenSolanaAccountJson (account : SolanaTokenAccountPlan) : String :=
  jsonObject #[
    ("name", jsonString account.name),
    ("role", jsonString account.role),
    ("ownerProgram", jsonStringOption account.ownerProgram?),
    ("signer", jsonBool account.signer),
    ("writable", jsonBool account.writable),
    ("derivation", jsonStringOption account.derivation?)
  ]

private def tokenSolanaInstructionParamJson (param : SolanaTokenInstructionParam) : String :=
  jsonObject #[
    ("name", jsonString param.name),
    ("type", jsonString param.type),
    ("source", jsonString param.source)
  ]

private def tokenSolanaInstructionJson (instruction : SolanaTokenInstructionPlan) : String :=
  jsonObject #[
    ("order", toString instruction.order),
    ("name", jsonString instruction.name),
    ("operation", jsonString instruction.operation),
    ("programId", jsonString instruction.programId),
    ("accounts", jsonStringArray instruction.accounts),
    ("params", jsonArray (instruction.params.map tokenSolanaInstructionParamJson)),
    ("feature", jsonStringOption instruction.feature?),
    ("token2022Only", jsonBool instruction.token2022Only)
  ]

private def tokenSolanaExtensionJson (extension : SolanaTokenExtensionPlan) : String :=
  jsonObject #[
    ("feature", jsonString extension.feature),
    ("extension", jsonString extension.extension),
    ("scope", jsonString extension.scope),
    ("initInstruction", jsonString extension.initInstruction),
    ("requiresConfig", jsonBool extension.requiresConfig),
    ("notes", jsonStringArray extension.notes)
  ]

private def tokenSolanaAuthorityChangeJson (change : SolanaTokenAuthorityChangePlan) : String :=
  jsonObject #[
    ("name", jsonString change.name),
    ("authorityType", jsonString change.authorityType),
    ("currentAuthority", jsonString change.currentAuthority),
    ("newAuthority", jsonString change.newAuthority),
    ("operation", jsonString change.operation),
    ("reason", jsonString change.reason)
  ]

private def tokenSolanaReferenceJson (reference : SolanaTokenReference) : String :=
  jsonObject #[
    ("label", jsonString reference.label),
    ("url", jsonString reference.url)
  ]

private def tokenSolanaDeploymentPlanJson (deployment : SolanaTokenDeploymentPlan) : String :=
  jsonObject #[
    ("standard", jsonString deployment.standard.id),
    ("programs", jsonObject #[
      ("token", jsonString deployment.tokenProgramId),
      ("associatedToken", jsonString deployment.associatedTokenProgramId),
      ("system", jsonString deployment.systemProgramId),
      ("rentSysvar", jsonString deployment.rentSysvarId)
    ]),
    ("accounts", jsonArray (deployment.accounts.map tokenSolanaAccountJson)),
    ("instructions", jsonArray (deployment.instructions.map tokenSolanaInstructionJson)),
    ("extensions", jsonArray (deployment.extensions.map tokenSolanaExtensionJson)),
    ("authorityChanges", jsonArray (deployment.authorityChanges.map tokenSolanaAuthorityChangeJson)),
    ("references", jsonArray (deployment.references.map tokenSolanaReferenceJson))
  ]

private def tokenPlanJson (id sourcePath sourceKind : String)
    (profile : TargetProfile)
    (plan : TokenPlan)
    (spec : TokenSpec)
    (deployment : SolanaTokenDeploymentPlan) : String :=
  jsonObject #[
    ("format", jsonString "proof-forge-token-plan-v0"),
    ("sourceKind", jsonString sourceKind),
    ("token", tokenSpecJson id spec),
    ("target", jsonString profile.id),
    ("targetFamily", jsonString profile.family.id),
    ("standard", jsonString plan.standard.id),
    ("artifactKind", jsonString plan.artifactKind.id),
    ("capabilities", jsonStringArray
      (dedupStrings (plan.capabilities.map fun capability => capability.id))),
    ("operations", jsonStringArray plan.operations),
    ("notes", jsonStringArray plan.notes),
    ("solana", tokenSolanaDeploymentPlanJson deployment),
    ("artifacts", jsonObject #[
      ("source", jsonObject #[
        ("path", jsonString sourcePath)
      ])
    ]),
    ("validation", jsonObject #[
      ("leanTokenSource", jsonString "passed"),
      ("targetRouting", jsonString "passed"),
      ("planGeneration", jsonString "passed")
    ])
  ]

private def writePlan (output : System.FilePath) (id sourcePath : String)
    (spec : TokenSpec) : IO Unit := do
  let profile := solanaSbpfAsm
  let plan ←
    match planForTarget profile spec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError err
  let deployment ←
    match solanaTokenDeploymentPlan spec with
    | .ok deployment => pure deployment
    | .error err => throw <| IO.userError err
  if let some parent := output.parent then
    IO.FS.createDirAll parent
  IO.FS.writeFile output
    (tokenPlanJson id sourcePath "lean-token-source" profile plan spec deployment ++ "\n")

def run (args : List String) : IO UInt32 := do
  match args with
  | ["soulbound", output] =>
      writePlan (System.FilePath.mk output)
        ProofForge.Contract.Token.Examples.SoulboundToken.id
        "ProofForge/Contract/Token/Examples/SoulboundToken.lean"
        ProofForge.Contract.Token.Examples.SoulboundToken.spec
      IO.println s!"wrote {output}"
      return 0
  | _ =>
      throw <| IO.userError "usage: lean --run Tests/TokenPlanEmit.lean soulbound <output.json>"

end ProofForge.Tests.TokenPlanEmit

def main (args : List String) : IO UInt32 :=
  ProofForge.Tests.TokenPlanEmit.run args
