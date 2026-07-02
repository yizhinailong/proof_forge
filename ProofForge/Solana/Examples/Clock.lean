import ProofForge.Contract.Builder

namespace ProofForge.Solana.Examples.Clock

open ProofForge.Contract.Builder

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaClock" do
    scalarState "last_slot" .u64

    entrySelector "record" "09" do
      letBind "slot" .u64 (contextRead .checkpointId)
      effect (storageScalarWrite "last_slot" (localVar "slot"))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.Clock
