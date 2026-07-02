import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.EpochSchedule

open ProofForge.Contract.Builder

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaEpochSchedule" do
    scalarState "slots_per_epoch" .u64
    scalarState "leader_schedule_slot_offset" .u64
    scalarState "warmup" .u64
    scalarState "first_normal_epoch" .u64
    scalarState "first_normal_slot" .u64

    entrySelector "record_epoch_schedule" "10" do
      ProofForge.Solana.epochScheduleSlotsPerEpochToState
        "read_epoch_schedule"
        "slots_per_epoch"
      ProofForge.Solana.epochScheduleLeaderScheduleSlotOffsetToState
        "read_leader_schedule_slot_offset"
        "leader_schedule_slot_offset"
      ProofForge.Solana.epochScheduleWarmupToState
        "read_warmup"
        "warmup"
      ProofForge.Solana.epochScheduleFirstNormalEpochToState
        "read_first_normal_epoch"
        "first_normal_epoch"
      ProofForge.Solana.epochScheduleFirstNormalSlotToState
        "read_first_normal_slot"
        "first_normal_slot"

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.EpochSchedule
