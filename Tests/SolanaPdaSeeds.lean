import ProofForge.Backend.Solana.Package
import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Tests.SolanaPdaSeeds

open ProofForge.Contract.Builder
open ProofForge.Solana

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

def pdaOnlySpec : ProofForge.Contract.ContractSpec :=
  build "SolanaPdaSeedProbe" do
    scalarState "nonce" .u64

    pdaAccount "vault" #[literalSeed "vault", accountSeed "authority"]
      (bump? := some "vault_bump")
      (account? := some "vault_account")

    entrySelectorWithParams "touch" "04" #[("vault_bump", .u64)] .unit do
      derivePda "vault" #[literalSeed "vault", accountSeed "authority"]
        (bump? := some "vault_bump")
        (account? := some "vault_account")
      effect (storageScalarWrite "nonce" (localVar "vault_bump"))

def main : IO UInt32 := do
  match ProofForge.Backend.Solana.Package.renderPackageForSpec "pda-seeds" pdaOnlySpec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "pda-seeds package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "pda-seeds package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "{ name = \"nonce\", index = 0, signer = false, writable = true, owner = \"program\" },")
        "manifest missing state account schema"
      require (contains manifest "{ name = \"vault_account\", index = 1, signer = false, writable = true, owner = \"program\" },")
        "manifest missing PDA account schema"
      require (contains manifest "{ name = \"authority\", index = 2, signer = false, writable = false, owner = \"any\" }")
        "manifest missing PDA account-seed source account schema"
      require (contains manifest "typed_seeds = [")
        "manifest missing PDA typed seed descriptors"
      require (contains manifest "{ kind = \"account\", value = \"authority\" },")
        "manifest missing authority account seed descriptor"
      require (contains manifest "{ kind = \"bump\", value = \"vault_bump\" }")
        "manifest missing vault_bump seed descriptor"
      require (contains manifest "{ name = \"vault_bump\", type = \"U64\", offset = 1, byte_size = 8, encoding = \"le-u64\" }")
        "manifest missing vault_bump instruction parameter schema"
      require (contains asm "solana.pda.seed vault[1] account authority pubkey")
        "assembly missing authority pubkey PDA seed packing"
      require (!contains asm "account authority missing placeholder=zero")
        "authority account seed should not fall back to zero placeholder"
      require (contains asm "solana.pda.seed vault[2] bump vault_bump from instruction param")
        "assembly missing instruction-parameter bump seed packing"
      require (!contains asm "bump vault_bump missing placeholder=255")
        "vault_bump should bind to instruction parameter, not placeholder"
      require (contains asm "mov64 r7, r9")
        "assembly missing saved instruction-data pointer use for bump seed"
      require (contains asm "ldxb r3, [r7+")
        "assembly missing byte load for instruction-parameter bump seed"
      require (contains asm "stxb [r5+0], r3")
        "assembly missing bump byte copy into PDA seed buffer"
      require (contains asm "solana.pda.validate vault account vault_account")
        "assembly missing PDA account pubkey validation"
  | .error err =>
      throw <| IO.userError s!"Solana PDA seed package render failed: {err.render}"

  IO.println "solana-pda-seeds: ok"
  return 0

end ProofForge.Tests.SolanaPdaSeeds

def main : IO UInt32 :=
  ProofForge.Tests.SolanaPdaSeeds.main
