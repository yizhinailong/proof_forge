import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.ReturnDataCompute

open ProofForge.Contract.Builder
open ProofForge.Solana

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaReturnDataCompute" do
    scalarState "result" .u64
    scalarState "remaining" .u64

    entrySelectorWithParams "set_result" "12" #[("value", .u64)] .unit do
      effect (storageScalarWrite "result" (localVar "value"))
      effect (storageScalarWrite "remaining" (u64 0))

    entrySelector "publish_result" "13" do
      setReturnDataFromState "publish_result_data" "result" 8

    entrySelector "record_compute" "14" do
      remainingComputeUnitsToState "record_remaining" "remaining"

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.ReturnDataCompute
