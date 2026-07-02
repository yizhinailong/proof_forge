import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.LastRestartSlot

open ProofForge.Contract.Builder

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaLastRestartSlot" do
    scalarState "last_restart_slot" .u64

    entrySelector "record_last_restart_slot" "11" do
      ProofForge.Solana.lastRestartSlotToState
        "read_last_restart_slot"
        "last_restart_slot"

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.LastRestartSlot
