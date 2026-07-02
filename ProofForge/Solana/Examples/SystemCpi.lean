import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.SystemCpi

open ProofForge.Contract.Builder
open ProofForge.Solana

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaSystemCpi" do
    scalarState "last_transfer_lamports" .u64

    systemTransfer
      "lamport_transfer"
      "payer"
      "recipient"
      "lamports"

    entrySelectorWithParams "transfer" "01" #[("lamports", .u64)] .unit do
      invokeSystemTransfer
        "lamport_transfer"
        "payer"
        "recipient"
        "lamports"
      effect (storageScalarWrite "last_transfer_lamports" (localVar "lamports"))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.SystemCpi
