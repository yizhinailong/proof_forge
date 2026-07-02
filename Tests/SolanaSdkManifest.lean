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
  require (contains manifest "[[solana.allocator]]") "manifest missing Solana allocator section"
  require (contains manifest "kind = \"bump\"") "manifest missing bump allocator kind"
  require (contains manifest "model = \"downward-bump\"") "manifest missing bump allocator model"
  require (contains manifest "heap_start = \"0x300000000\"") "manifest missing allocator heap start"
  require (contains manifest "heap_bytes = 32768") "manifest missing allocator heap size"
  require (contains manifest "{ name = \"nonce\", index = 0, signer = false, writable = true, owner = \"program\" },")
    "manifest missing state account schema"
  require (contains manifest "{ name = \"vault_account\", index = 1, signer = false, writable = true, owner = \"program\" },")
    "manifest missing PDA account schema"
  require (contains manifest "{ name = \"source\", index = 2, signer = false, writable = true, owner = \"any\" },")
    "manifest missing source account schema"
  require (contains manifest "{ name = \"mint\", index = 3, signer = false, writable = false, owner = \"any\" },")
    "manifest missing mint account schema"
  require (contains manifest "{ name = \"destination\", index = 4, signer = false, writable = true, owner = \"any\" },")
    "manifest missing destination account schema"
  require (contains manifest "{ name = \"authority\", index = 5, signer = false, writable = false, owner = \"any\" },")
    "manifest missing authority account schema"
  require (contains manifest "{ name = \"spl_token\", index = 6, signer = false, writable = false, owner = \"executable\" }")
    "manifest missing SPL Token program account schema"
  require (contains manifest "[[solana.pda]]") "manifest missing Solana PDA section"
  require (contains manifest "name = \"vault\"") "manifest missing PDA name"
  require (contains manifest "seeds = [\"vault\", \"authority\"]") "manifest missing PDA seeds"
  require (contains manifest "bump = \"vault_bump\"") "manifest missing PDA bump"
  require (contains manifest "account = \"vault_account\"") "manifest missing PDA account"
  require (contains manifest "[[solana.cpi]]") "manifest missing Solana CPI section"
  require (contains manifest "program = \"spl_token\"") "manifest missing CPI program"
  require (contains manifest "protocol = \"spl-token\"") "manifest missing CPI protocol"
  require (contains manifest "instruction = \"transfer_checked\"") "manifest missing CPI instruction"
  require (contains manifest "signed = true") "manifest missing signed CPI marker"
  require (contains manifest "data_layout = \"spl-token.transfer_checked\"")
    "manifest missing CPI data layout"
  require (contains manifest "{ name = \"source\", access = \"writable\", signer = \"none\" }")
    "manifest missing writable source account"
  require (contains manifest "{ name = \"source\", access = \"writable\", signer = \"none\" },")
    "manifest missing comma after non-final CPI account"
  require (contains manifest "{ name = \"mint\", access = \"readonly\", signer = \"none\" },")
    "manifest missing readonly mint account"
  require (contains manifest "{ name = \"authority\", access = \"readonly\", signer = \"pda-signer\" }")
    "manifest missing PDA signer authority account"
  require (contains manifest "signer_seeds = [\"vault\", \"vault_bump\"]")
    "manifest missing CPI signer seeds"
  require (contains manifest "[[solana.entrypoint_pda]]")
    "manifest missing entrypoint PDA action section"
  require (contains manifest "entrypoint = \"touch\"")
    "manifest missing touch entrypoint action"
  require (contains manifest "pda = \"vault\"")
    "manifest missing touch PDA action"
  require (contains manifest "[[solana.entrypoint_cpi]]")
    "manifest missing entrypoint CPI action section"
  require (contains manifest "cpi = \"token_transfer\"")
    "manifest missing touch CPI action"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "solana-vault" spec with
  | .ok pkg =>
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "package missing manifest.toml"
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "package missing sBPF assembly"
      require (contains manifestFile.contents "[[solana.pda]]")
        "package manifest missing Solana PDA section"
      require (contains manifestFile.contents "[[solana.allocator]]")
        "package manifest missing Solana allocator section"
      require (contains manifestFile.contents "heap_start = \"0x300000000\"")
        "package manifest missing allocator heap start"
      require (contains manifestFile.contents "[[solana.cpi]]")
        "package manifest missing Solana CPI section"
      require (contains manifestFile.contents "protocol = \"spl-token\"")
        "package manifest missing CPI protocol"
      require (contains manifestFile.contents "{ name = \"vault_account\", index = 1, signer = false, writable = true, owner = \"program\" },")
        "package manifest missing PDA account schema"
      require (contains manifestFile.contents "{ name = \"spl_token\", index = 6, signer = false, writable = false, owner = \"executable\" }")
        "package manifest missing SPL Token program account schema"
      require (contains asmFile.contents "solana.allocator runtime: kind=bump model=downward-bump heap_start=0x300000000 heap_bytes=32768")
        "package assembly missing runtime allocator metadata"
      require (contains asmFile.contents "account.validation[1:vault_account]: owner=program")
        "package assembly missing PDA owner validation"
      require (contains asmFile.contents "account.validation[2:source]: writable=true")
        "package assembly missing source writable validation"
      require (contains asmFile.contents "account.validation[4:destination]: writable=true")
        "package assembly missing destination writable validation"
      require (contains asmFile.contents "sol_pda_derive_vault:")
        "package assembly missing PDA helper label"
      require (contains asmFile.contents "solana.pda.seed vault[0] \"vault\"")
        "package assembly missing static vault PDA seed packing"
      require (contains asmFile.contents "stb [r5+0], 118")
        "package assembly missing vault seed byte store"
      require (contains asmFile.contents "solana.pda.seed vault[1] \"authority\"")
        "package assembly missing authority PDA seed packing"
      require (contains asmFile.contents "stxdw [r6+0], r5")
        "package assembly missing PDA seed slice ptr store"
      require (contains asmFile.contents "stxdw [r6+8], r3")
        "package assembly missing PDA seed slice length store"
      require (contains asmFile.contents "add64 r3, INSTRUCTION_DATA_LEN")
        "package assembly missing dynamic program id pointer calculation"
      require (contains asmFile.contents "call sol_create_program_address")
        "package assembly missing PDA syscall"
      require (contains asmFile.contents "PDA result stored at stack offset 64")
        "package assembly missing PDA result buffer marker"
      require (contains asmFile.contents "call sol_pda_derive_vault")
        "package assembly missing entrypoint PDA helper call"
      require (contains asmFile.contents "sol_cpi_token_transfer:")
        "package assembly missing CPI helper label"
      require (contains asmFile.contents "solana.cpi.program_id spl_token account[6] from input account")
        "package assembly missing CPI program account binding"
      require (contains asmFile.contents "solana.cpi.account_meta source key_ptr account[2]")
        "package assembly missing source account meta binding"
      require (contains asmFile.contents "solana.cpi.account_info source account[2]")
        "package assembly missing source account info binding"
      require (contains asmFile.contents "solana.cpi.account_info destination account[4]")
        "package assembly missing destination account info binding"
      require (contains asmFile.contents "call sol_invoke_signed_c")
        "package assembly missing CPI syscall"
      require (contains asmFile.contents "call sol_cpi_token_transfer")
        "package assembly missing entrypoint CPI helper call"
  | .error err =>
      throw <| IO.userError s!"Solana SDK package render failed: {err.render}"

  IO.println "solana-sdk-manifest: ok"
  return 0

end ProofForge.Tests.SolanaSdkManifest

def main : IO UInt32 :=
  ProofForge.Tests.SolanaSdkManifest.main
