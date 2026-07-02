import ProofForge.Contract.Source

namespace ProofForge.Solana.Examples.SystemCpi

open ProofForge.Contract.Source

contract_source SolanaSystemCpi do
  state last_transfer_lamports : .u64

  cpi lamport_transfer system_transfer(payer, recipient, lamports)

  entry transfer(lamports : .u64) do
    invoke lamport_transfer system_transfer(payer, recipient, lamports);
    last_transfer_lamports := lamports;

end ProofForge.Solana.Examples.SystemCpi
