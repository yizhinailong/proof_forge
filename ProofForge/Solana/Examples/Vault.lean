import ProofForge.Contract.Source
import ProofForge.Solana.Surface

namespace ProofForge.Solana.Examples.Vault

open ProofForge.Contract.Source
open ProofForge.Solana.Surface

namespace Local

binding_decl amount : .u64
binding_decl vault_bump : .u64

end Local

namespace Account

account_ref vault_account
account_ref source
account_ref mint
account_ref destination
account_ref authority
account_ref spl_token

end Account

namespace Pda

pda_ref vault

end Pda

namespace Cpi

cpi_ref token_transfer

end Cpi

def vaultSeeds : Array String :=
  #[ProofForge.Solana.Surface.literalSeed "vault",
    ProofForge.Solana.Surface.accountSeed Account.authority]

def vaultSignerSeeds : Array String :=
  #[ProofForge.Solana.Surface.pdaName Pda.vault,
    ProofForge.Solana.Surface.bindingName Local.vault_bump]

contract_source SolanaVault do
  state nonce : .u64
  use ProofForge.Solana.Surface.bumpAllocator
  use ProofForge.Solana.Surface.writableAccount Account.vault_account (owner := "program")
  use ProofForge.Solana.Surface.writableAccount Account.source
  use ProofForge.Solana.Surface.readonlyAccount Account.mint
  use ProofForge.Solana.Surface.writableAccount Account.destination
  use ProofForge.Solana.Surface.readonlyAccount Account.authority
  use ProofForge.Solana.Surface.readonlyAccount Account.spl_token (owner := "executable")

  use ProofForge.Solana.Surface.pdaAccount Pda.vault vaultSeeds
      (bump? := some Local.vault_bump)
      (account? := some Account.vault_account)
      (isSigner := true)

  use ProofForge.Solana.Surface.splTokenTransferChecked
      Cpi.token_transfer
      Account.source
      Account.mint
      Account.destination
      Account.authority
      Local.amount
      9
      (signerSeeds := vaultSignerSeeds)

  entry «initialize» do
    nonce := u64 0;

  entry touch do
    do ProofForge.Solana.Surface.derivePda Pda.vault vaultSeeds
        (bump? := some Local.vault_bump)
        (account? := some Account.vault_account)
        (isSigner := true);
    do ProofForge.Solana.Surface.invokeSplTokenTransferChecked
        Cpi.token_transfer
        Account.source
        Account.mint
        Account.destination
        Account.authority
        Local.amount
        9
        (signerSeeds := vaultSignerSeeds);
    let n : .u64 := nonce;
    nonce := n +! u64 1;

end ProofForge.Solana.Examples.Vault
