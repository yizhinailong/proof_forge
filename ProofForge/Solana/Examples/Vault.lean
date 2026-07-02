import ProofForge.Contract.Surface
import ProofForge.Solana.Surface

namespace ProofForge.Solana.Examples.Vault

open ProofForge.Contract.Surface
open ProofForge.Solana.Surface

namespace State

state_ref nonce : .u64

end State

namespace Local

binding_ref amount : .u64
binding_ref vault_bump : .u64
binding_ref n : .u64

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

namespace Method

method_ref «initialize» : #[]
method_ref touch : #[]

end Method

def vaultSeeds : Array String :=
  #[ProofForge.Solana.Surface.literalSeed "vault",
    ProofForge.Solana.Surface.accountSeed Account.authority]

def vaultSignerSeeds : Array String :=
  #[ProofForge.Solana.Surface.pdaName Pda.vault,
    ProofForge.Solana.Surface.bindingName Local.vault_bump]

def spec : ProofForge.Contract.ContractSpec :=
  contract "SolanaVault" do
    scalar State.nonce
    ProofForge.Solana.Surface.bumpAllocator
    ProofForge.Solana.Surface.writableAccount Account.vault_account (owner := "program")
    ProofForge.Solana.Surface.writableAccount Account.source
    ProofForge.Solana.Surface.readonlyAccount Account.mint
    ProofForge.Solana.Surface.writableAccount Account.destination
    ProofForge.Solana.Surface.readonlyAccount Account.authority
    ProofForge.Solana.Surface.readonlyAccount Account.spl_token (owner := "executable")

    ProofForge.Solana.Surface.pdaAccount Pda.vault vaultSeeds
      (bump? := some Local.vault_bump)
      (account? := some Account.vault_account)
      (isSigner := true)

    ProofForge.Solana.Surface.splTokenTransferChecked
      Cpi.token_transfer
      Account.source
      Account.mint
      Account.destination
      Account.authority
      Local.amount
      9
      (signerSeeds := vaultSignerSeeds)

    entry Method.«initialize» do
      write State.nonce (u64 0)

    entry Method.touch do
      ProofForge.Solana.Surface.derivePda Pda.vault vaultSeeds
        (bump? := some Local.vault_bump)
        (account? := some Account.vault_account)
        (isSigner := true)
      ProofForge.Solana.Surface.invokeSplTokenTransferChecked
        Cpi.token_transfer
        Account.source
        Account.mint
        Account.destination
        Account.authority
        Local.amount
        9
        (signerSeeds := vaultSignerSeeds)
      bind Local.n (read State.nonce)
      write State.nonce (add (ref Local.n) (u64 1))

def module : ProofForge.IR.Module :=
  spec.module

end ProofForge.Solana.Examples.Vault
