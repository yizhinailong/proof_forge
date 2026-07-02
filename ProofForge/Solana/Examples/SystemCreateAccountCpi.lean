import ProofForge.Contract.Source

namespace ProofForge.Solana.Examples.SystemCreateAccountCpi

open ProofForge.Contract.Source

contract_source SolanaSystemCreateAccountCpi do
  state last_created_lamports : .u64
  state last_created_space : .u64

  cpi create_program_account system_create_account(
    payer,
    new_account,
    lamports,
    space
  ) owner "program"

  entry create(lamports : .u64, space : .u64) do
    invoke create_program_account system_create_account(
      payer,
      new_account,
      lamports,
      space
    ) owner "program";
    last_created_lamports := lamports;
    last_created_space := space;

end ProofForge.Solana.Examples.SystemCreateAccountCpi
