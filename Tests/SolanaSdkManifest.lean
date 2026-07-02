import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.Package
import ProofForge.Solana.Examples.Vault
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Tests.SolanaSdkManifest

open ProofForge.Target

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

def main : IO UInt32 := do
  let spec := ProofForge.Solana.Examples.Vault.spec
  let plan ←
    match resolveSpec solanaSbpfAsm spec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError s!"Solana Vault SDK routing failed: {err.render}"

  let manifest := ProofForge.Backend.Solana.Manifest.renderManifestWithPlan spec.module plan
  require (contains manifest "[[solana.pda]]") "manifest missing Solana PDA section"
  require (contains manifest "name = \"vault\"") "manifest missing PDA name"
  require (contains manifest "seeds = [\"vault\", \"authority\"]") "manifest missing PDA seeds"
  require (contains manifest "bump = \"vault_bump\"") "manifest missing PDA bump"
  require (contains manifest "account = \"vault_account\"") "manifest missing PDA account"
  require (contains manifest "[[solana.cpi]]") "manifest missing Solana CPI section"
  require (contains manifest "program = \"spl_token\"") "manifest missing CPI program"
  require (contains manifest "instruction = \"transfer_checked\"") "manifest missing CPI instruction"
  require (contains manifest "signed = true") "manifest missing signed CPI marker"
  require (contains manifest "{ name = \"source\", access = \"writable\", signer = \"none\" }")
    "manifest missing writable source account"
  require (contains manifest "{ name = \"source\", access = \"writable\", signer = \"none\" },")
    "manifest missing comma after non-final CPI account"
  require (contains manifest "signer_seeds = [\"vault\", \"vault_bump\"]")
    "manifest missing CPI signer seeds"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "solana-vault" spec with
  | .ok pkg =>
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "package missing manifest.toml"
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "package missing sBPF assembly"
      require (contains manifestFile.contents "[[solana.pda]]")
        "package manifest missing Solana PDA section"
      require (contains manifestFile.contents "[[solana.cpi]]")
        "package manifest missing Solana CPI section"
      require (contains asmFile.contents "sol_pda_derive_vault:")
        "package assembly missing PDA helper label"
      require (contains asmFile.contents "call sol_create_program_address")
        "package assembly missing PDA syscall"
      require (contains asmFile.contents "sol_cpi_token_transfer:")
        "package assembly missing CPI helper label"
      require (contains asmFile.contents "call sol_invoke_signed_c")
        "package assembly missing CPI syscall"
  | .error err =>
      throw <| IO.userError s!"Solana SDK package render failed: {err.render}"

  IO.println "solana-sdk-manifest: ok"
  return 0

end ProofForge.Tests.SolanaSdkManifest

def main : IO UInt32 :=
  ProofForge.Tests.SolanaSdkManifest.main
