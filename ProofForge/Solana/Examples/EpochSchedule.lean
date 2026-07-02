import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.EpochSchedule

open ProofForge.Contract.Builder

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaEpochSchedule" do
    scalarState "slots_per_epoch" .u64

    entrySelector "record_epoch_schedule" "10" do
      ProofForge.Solana.epochScheduleSlotsPerEpochToState
        "read_epoch_schedule"
        "slots_per_epoch"

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.EpochSchedule
