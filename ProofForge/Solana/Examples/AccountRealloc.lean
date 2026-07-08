import ProofForge.Contract.Source.Solana
import ProofForge.Solana.Surface

namespace ProofForge.Solana.Examples.AccountRealloc

open ProofForge.Contract.Source

contract_source SolanaAccountRealloc do
  state marker : .u64
  account buffer writable owner "program"

  entry grow do
    realloc buffer to 64;
    marker := u64 1;

end ProofForge.Solana.Examples.AccountRealloc
