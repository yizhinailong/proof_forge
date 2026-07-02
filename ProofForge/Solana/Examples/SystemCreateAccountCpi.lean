import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.SystemCreateAccountCpi

open ProofForge.Contract.Builder
open ProofForge.Solana

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaSystemCreateAccountCpi" do
    scalarState "last_created_lamports" .u64
    scalarState "last_created_space" .u64

    systemCreateAccount
      "create_program_account"
      "payer"
      "new_account"
      "lamports"
      "space"
      "program"

    entrySelectorWithParams "create" "02" #[("lamports", .u64), ("space", .u64)] .unit do
      invokeSystemCreateAccount
        "create_program_account"
        "payer"
        "new_account"
        "lamports"
        "space"
        "program"
      effect (storageScalarWrite "last_created_lamports" (localVar "lamports"))
      effect (storageScalarWrite "last_created_space" (localVar "space"))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.SystemCreateAccountCpi
