import Init.Notation
import Lean
import Lean.Elab.Frontend
import Lean.Util.Path
import ProofForge.Contract.Spec

namespace ProofForge.Cli.ContractLoader

open Lean

private def specConstName (modName : Name) : Name :=
  modName ++ `spec

private def candidateSpecNames (modName : Name) : List Name :=
  let lastComponent :=
    match modName.components.reverse with
    | last :: _ => last
    | [] => Name.anonymous
  [modName ++ `spec, lastComponent ++ `spec, `spec]

private def isContractSpecConst (env : Environment) (constName : Name) : Bool :=
  match env.find? constName with
  | some info =>
      match info.type with
      | Expr.const `ProofForge.Contract.ContractSpec _ => true
      | _ => false
  | none => false

private def resolveSpecConstName (env : Environment) (modName : Name) : Option Name :=
  (candidateSpecNames modName).find? fun candidate =>
    env.constants.contains candidate && isContractSpecConst env candidate

unsafe def loadSpecFromEnv (env : Environment) (modName : Name) : IO ProofForge.Contract.ContractSpec := do
  let some constName := resolveSpecConstName env modName
    | throw <| IO.userError
        s!"no `spec : ProofForge.Contract.ContractSpec` found while loading module `{modName}`; define one with `contract_source` or `def spec : ProofForge.Contract.ContractSpec`"
  match env.evalConstCheck ProofForge.Contract.ContractSpec {} `ProofForge.Contract.ContractSpec constName with
  | .ok spec => pure spec
  | .error msg => throw <| IO.userError msg

unsafe def loadSpec
    (input : System.FilePath) (root? : Option System.FilePath) (moduleName? : Option Name) :
    IO ProofForge.Contract.ContractSpec := do
  enableInitializersExecution
  initSearchPath (← findSysroot "lean")
  let source ← IO.FS.readFile input
  let modName ← match moduleName? with
    | some name => pure name
    | none => moduleNameOfFileName input root?
  let frontendOpts := Elab.async.set {} false
  let env? ← Elab.runFrontend
    source
    frontendOpts
    input.toString
    modName
    (trustLevel := 0)
    (oleanFileName? := none)
    (ileanFileName? := none)
    (jsonOutput := false)
    (errorOnKinds := #[])
    (plugins := #[])
    (printStats := false)
    (setup? := none)
  let some env := env?
    | throw <| IO.userError s!"Lean frontend failed for `{input.toString}`"
  loadSpecFromEnv env modName

end ProofForge.Cli.ContractLoader
