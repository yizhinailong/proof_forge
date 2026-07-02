import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.Vault

open ProofForge.Contract.Builder
open ProofForge.Solana

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaVault" do
    scalarState "nonce" .u64

    pdaAccount "vault" #["vault", "authority"]
      (bump? := some "vault_bump")
      (account? := some "vault_account")
      (isSigner := true)

    cpiInvokeSigned
      "token_transfer"
      "spl_token"
      "transfer_checked"
      #[
        writableAccount "source",
        writableAccount "destination",
        signerAccount "authority"
      ]
      #["vault", "vault_bump"]
      (dataLayout? := some "spl-token.transfer_checked")

    entrySelector "initialize" "afaf6d1f" do
      effect (storageScalarWrite "nonce" (u64 0))

    entrySelector "touch" "62de7396" do
      letBind "n" .u64 (storageScalarRead "nonce")
      effect (storageScalarWrite "nonce" (add (localVar "n") (u64 1)))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.Vault
