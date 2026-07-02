import ProofForge.Backend.Solana.Package
import ProofForge.Contract.Examples.Counter
import ProofForge.Contract.Examples.ValueVault
import ProofForge.Contract.Learn
import ProofForge.Solana.Examples.LogEvent
import ProofForge.Solana.Examples.ReturnDataCompute
import ProofForge.Solana.Examples.SplTokenOpsCpi
import ProofForge.Solana.Examples.SystemCpi
import ProofForge.Solana.Examples.SystemCreateAccountCpi
import ProofForge.Solana.Examples.Vault

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

def requireSameText (label actual expected : String) : IO Unit :=
  require (actual == expected)
    s!"{label} mismatch\nactual:\n{actual}\nexpected:\n{expected}"

def packageFile (label path : String)
    (spec : ProofForge.Contract.ContractSpec) : IO String := do
  match ProofForge.Backend.Solana.Package.renderPackageForSpec label spec with
  | .ok pkg =>
      let some file := pkg.files.find? (fun file => file.path == path)
        | throw <| IO.userError s!"{label} package missing {path}"
      pure file.contents
  | .error err =>
      throw <| IO.userError s!"{label} Solana render failed: {err.render}"

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
  let solanaVault ← parseSpec "Examples/Learn/SolanaVault.learn"
  requireSameModule "SolanaVault" solanaVault.module ProofForge.Solana.Examples.Vault.module
  let learnManifest ← packageFile "learn-solana-vault" "manifest.toml" solanaVault
  let sourceManifest ← packageFile "source-solana-vault" "manifest.toml" ProofForge.Solana.Examples.Vault.spec
  requireSameText "SolanaVault Learn manifest" learnManifest sourceManifest
  let systemCpi ← parseSpec "Examples/Learn/SystemCpi.learn"
  requireSameModule "SystemCpi" systemCpi.module ProofForge.Solana.Examples.SystemCpi.module
  let learnSystemManifest ← packageFile "learn-system-cpi" "manifest.toml" systemCpi
  let sourceSystemManifest ← packageFile "source-system-cpi" "manifest.toml"
    ProofForge.Solana.Examples.SystemCpi.spec
  requireSameText "SystemCpi Learn manifest" learnSystemManifest sourceSystemManifest
  let systemCreateAccount ← parseSpec "Examples/Learn/SystemCreateAccountCpi.learn"
  requireSameModule "SystemCreateAccountCpi" systemCreateAccount.module
    ProofForge.Solana.Examples.SystemCreateAccountCpi.module
  let learnCreateAccountManifest ← packageFile "learn-system-create-account-cpi" "manifest.toml"
    systemCreateAccount
  let sourceCreateAccountManifest ← packageFile "source-system-create-account-cpi" "manifest.toml"
    ProofForge.Solana.Examples.SystemCreateAccountCpi.spec
  requireSameText "SystemCreateAccountCpi Learn manifest"
    learnCreateAccountManifest sourceCreateAccountManifest
  let splTokenOps ← parseSpec "Examples/Learn/SplTokenOpsCpi.learn"
  requireSameModule "SplTokenOpsCpi" splTokenOps.module
    ProofForge.Solana.Examples.SplTokenOpsCpi.module
  let learnTokenOpsManifest ← packageFile "learn-spl-token-ops-cpi" "manifest.toml" splTokenOps
  let sourceTokenOpsManifest ← packageFile "source-spl-token-ops-cpi" "manifest.toml"
    ProofForge.Solana.Examples.SplTokenOpsCpi.spec
  requireSameText "SplTokenOpsCpi Learn manifest" learnTokenOpsManifest sourceTokenOpsManifest
  let logEvent ← parseSpec "Examples/Learn/LogEvent.learn"
  requireSameModule "LogEvent" logEvent.module ProofForge.Solana.Examples.LogEvent.module
  let learnLogEventManifest ← packageFile "learn-log-event" "manifest.toml" logEvent
  let sourceLogEventManifest ← packageFile "source-log-event" "manifest.toml"
    ProofForge.Solana.Examples.LogEvent.spec
  requireSameText "LogEvent Learn manifest" learnLogEventManifest sourceLogEventManifest
  let returnDataCompute ← parseSpec "Examples/Learn/ReturnDataCompute.learn"
  requireSameModule "ReturnDataCompute" returnDataCompute.module
    ProofForge.Solana.Examples.ReturnDataCompute.module
  let learnReturnDataComputeManifest ← packageFile "learn-return-data-compute" "manifest.toml"
    returnDataCompute
  let sourceReturnDataComputeManifest ← packageFile "source-return-data-compute" "manifest.toml"
    ProofForge.Solana.Examples.ReturnDataCompute.spec
  requireSameText "ReturnDataCompute Learn manifest" learnReturnDataComputeManifest
    sourceReturnDataComputeManifest
  IO.println "learn-source: ok"
  return 0

end ProofForge.Tests.LearnSource

def main : IO UInt32 :=
  ProofForge.Tests.LearnSource.main
