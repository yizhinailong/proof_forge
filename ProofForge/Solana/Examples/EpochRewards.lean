import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Solana.Examples.EpochRewards

open ProofForge.Contract.Builder

def spec : ProofForge.Contract.ContractSpec :=
  build "SolanaEpochRewards" do
    scalarState "distribution_starting_block_height" .u64
    scalarState "num_partitions" .u64
    scalarState "parent_blockhash_word0" .u64
    scalarState "parent_blockhash_word1" .u64
    scalarState "parent_blockhash_word2" .u64
    scalarState "parent_blockhash_word3" .u64
    scalarState "total_points_low" .u64
    scalarState "total_points_high" .u64
    scalarState "total_rewards" .u64
    scalarState "distributed_rewards" .u64
    scalarState "active" .u64

    entrySelector "record_epoch_rewards" "12" do
      ProofForge.Solana.epochRewardsDistributionStartingBlockHeightToState
        "read_distribution_starting_block_height"
        "distribution_starting_block_height"
      ProofForge.Solana.epochRewardsNumPartitionsToState
        "read_num_partitions"
        "num_partitions"
      ProofForge.Solana.epochRewardsParentBlockhashWord0ToState
        "read_parent_blockhash_word0"
        "parent_blockhash_word0"
      ProofForge.Solana.epochRewardsParentBlockhashWord1ToState
        "read_parent_blockhash_word1"
        "parent_blockhash_word1"
      ProofForge.Solana.epochRewardsParentBlockhashWord2ToState
        "read_parent_blockhash_word2"
        "parent_blockhash_word2"
      ProofForge.Solana.epochRewardsParentBlockhashWord3ToState
        "read_parent_blockhash_word3"
        "parent_blockhash_word3"
      ProofForge.Solana.epochRewardsTotalPointsLowToState
        "read_total_points_low"
        "total_points_low"
      ProofForge.Solana.epochRewardsTotalPointsHighToState
        "read_total_points_high"
        "total_points_high"
      ProofForge.Solana.epochRewardsTotalRewardsToState
        "read_total_rewards"
        "total_rewards"
      ProofForge.Solana.epochRewardsDistributedRewardsToState
        "read_distributed_rewards"
        "distributed_rewards"
      ProofForge.Solana.epochRewardsActiveToState
        "read_active"
        "active"

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.EpochRewards
