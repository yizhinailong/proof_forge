import ProofForge.Contract.Builder

namespace ProofForge.Solana.Examples.LogEvent

open ProofForge.Contract.Builder

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaLogEvent" do
    scalarState "last_logged_amount" .u64

    entrySelectorWithParams "emit" "08" #[("amount", .u64)] .unit do
      effect (eventEmit "AmountEvent" #[("amount", localVar "amount")])
      effect (storageScalarWrite "last_logged_amount" (localVar "amount"))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.LogEvent
