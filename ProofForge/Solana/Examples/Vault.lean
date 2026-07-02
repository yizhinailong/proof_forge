import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.Vault

open ProofForge.Contract.Builder
open ProofForge.Solana

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaVault" do
    scalarState "nonce" .u64
    bumpAllocator

    pdaAccount "vault" #[literalSeed "vault", accountSeed "authority"]
      (bump? := some "vault_bump")
      (account? := some "vault_account")
      (isSigner := true)

    splTokenTransferChecked
      "token_transfer"
      "source"
      "mint"
      "destination"
      "authority"
      "amount"
      9
      (signerSeeds := #["vault", "vault_bump"])

    entrySelector "initialize" "afaf6d1f" do
      effect (storageScalarWrite "nonce" (u64 0))

    entrySelector "touch" "62de7396" do
      derivePda "vault" #[literalSeed "vault", accountSeed "authority"]
        (bump? := some "vault_bump")
        (account? := some "vault_account")
        (isSigner := true)
      invokeSplTokenTransferChecked
        "token_transfer"
        "source"
        "mint"
        "destination"
        "authority"
        "amount"
        9
        (signerSeeds := #["vault", "vault_bump"])
      letBind "n" .u64 (storageScalarRead "nonce")
      effect (storageScalarWrite "nonce" (add (localVar "n") (u64 1)))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.Vault
