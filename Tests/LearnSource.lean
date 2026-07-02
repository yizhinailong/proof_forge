import ProofForge.Backend.Solana.Package
import ProofForge.Contract.Examples.Counter
import ProofForge.Contract.Examples.ValueVault
import ProofForge.Contract.Learn

namespace ProofForge.Tests.LearnSource

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def requireExcept {α : Type} (label : String) : Except String α → IO α
  | .ok value => pure value
  | .error err => throw <| IO.userError s!"{label}: {err}"

def reprModule (module : ProofForge.IR.Module) : String :=
  toString (repr module)

def parseSpec (path : System.FilePath) : IO ProofForge.Contract.ContractSpec := do
  requireExcept s!"parse/lower {path}" (← ProofForge.Contract.Learn.parseAndLowerFile path)

def requireSameModule (label : String)
    (actual expected : ProofForge.IR.Module) : IO Unit := do
  let actualRepr := reprModule actual
  let expectedRepr := reprModule expected
  require (actualRepr == expectedRepr)
    s!"{label} Learn source did not lower to the expected IR module\nactual:\n{actualRepr}\nexpected:\n{expectedRepr}"

def requireValueVaultSolanaRender (spec : ProofForge.Contract.ContractSpec) : IO Unit := do
  match ProofForge.Backend.Solana.Package.renderPackageForSpec "learn-value-vault" spec with
  | .ok pkg =>
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "Learn ValueVault Solana package missing manifest.toml"
      let manifest := manifestFile.contents
      require (manifest.contains "name = \"deposit\"")
        "Learn ValueVault manifest missing deposit instruction"
      require (manifest.contains "name = \"charge_fee\"")
        "Learn ValueVault manifest missing charge_fee instruction"
      require (manifest.contains "name = \"snapshot\"")
        "Learn ValueVault manifest missing snapshot instruction"
  | .error err =>
      throw <| IO.userError s!"Learn ValueVault Solana render failed: {err.render}"

def main : IO UInt32 := do
  let counter ← parseSpec "Examples/Learn/Counter.learn"
  requireSameModule "Counter" counter.module ProofForge.Contract.Examples.Counter.module
  let valueVault ← parseSpec "Examples/Learn/ValueVault.learn"
  requireSameModule "ValueVault" valueVault.module ProofForge.Contract.Examples.ValueVault.module
  requireValueVaultSolanaRender valueVault
  IO.println "learn-source: ok"
  return 0

end ProofForge.Tests.LearnSource

def main : IO UInt32 :=
  ProofForge.Tests.LearnSource.main
