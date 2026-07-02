import ProofForge.Contract.Builder
import ProofForge.Solana
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Tests.SolanaSdk

open ProofForge.Target
open ProofForge.Contract.Builder
open ProofForge.Solana

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def hasCapability (plan : CapabilityPlan) (capability : Capability) : Bool :=
  plan.capabilities.any (fun c => c == capability)

def callByOperation? (plan : CapabilityPlan) (operation : String) : Option CapabilityCall :=
  plan.calls.find? (fun call => call.operation == operation)

def metadataValue? (call : CapabilityCall) (key : String) : Option String :=
  call.metadata.foldl
    (fun found metadata =>
      match found with
      | some _ => found
      | none =>
          if metadata.key == key then
            some metadata.value
          else
            none)
    none

def requireMetadata (call : CapabilityCall) (key expected : String) : IO Unit :=
  require (metadataValue? call key == some expected)
    s!"metadata `{key}` mismatch for operation `{call.operation}`"

def scopedCall? (plan : CapabilityPlan) (operation entrypoint : String) : Option CapabilityCall :=
  plan.calls.find? fun call =>
    call.operation == operation && metadataValue? call "proof_forge.entrypoint" == some entrypoint

def extensionSpec : ProofForge.Contract.ContractSpec :=
  build "SolanaVault" do
    pdaAccount "vault" #["vault", "authority"]
      (bump? := some "vault_bump")
      (account? := some "vault_account")
      (isSigner := true)

    cpiInvokeSigned
      "token_transfer"
      "spl_token"
      "transfer_checked"
      #[
        writableAccount "source",
        writableAccount "destination",
        signerAccount "authority"
      ]
      #["vault", "vault_bump"]
      (dataLayout? := some "spl-token.transfer_checked")

    entry "touch" do
      derivePda "vault" #["vault", "authority"]
        (bump? := some "vault_bump")
        (account? := some "vault_account")
        (isSigner := true)
      invokeSignedCpi
        "token_transfer"
        "spl_token"
        "transfer_checked"
        #[
          writableAccount "source",
          writableAccount "destination",
          signerAccount "authority"
        ]
        #["vault", "vault_bump"]
        (dataLayout? := some "spl-token.transfer_checked")

def requireSolanaPlan (plan : CapabilityPlan) : IO Unit := do
  require (plan.targetId == solanaSbpfAsm.id) "Solana SDK plan target id mismatch"
  require (hasCapability plan .accountExplicit) "Solana SDK plan missing account.explicit"
  require (hasCapability plan .storagePda) "Solana SDK plan missing storage.pda"
  require (hasCapability plan .crosscallCpi) "Solana SDK plan missing crosscall.cpi"

  let pdaCall ←
    match callByOperation? plan "solana.pda.derive" with
    | some call => pure call
    | none => throw <| IO.userError "Solana SDK plan missing solana.pda.derive operation"
  requireMetadata pdaCall "solana.extension" "pda"
  requireMetadata pdaCall "solana.pda.name" "vault"
  requireMetadata pdaCall "solana.pda.seeds" "vault,authority"
  requireMetadata pdaCall "solana.pda.bump" "vault_bump"
  requireMetadata pdaCall "solana.pda.account" "vault_account"
  requireMetadata pdaCall "solana.pda.signer" "true"

  let cpiCall ←
    match callByOperation? plan "solana.cpi.invoke_signed" with
    | some call => pure call
    | none => throw <| IO.userError "Solana SDK plan missing solana.cpi.invoke_signed operation"
  requireMetadata cpiCall "solana.extension" "cpi"
  requireMetadata cpiCall "solana.cpi.name" "token_transfer"
  requireMetadata cpiCall "solana.cpi.program" "spl_token"
  requireMetadata cpiCall "solana.cpi.instruction" "transfer_checked"
  requireMetadata cpiCall "solana.cpi.accounts" "source:writable:none,destination:writable:none,authority:readonly:signer"
  requireMetadata cpiCall "solana.cpi.signer_seeds" "vault,vault_bump"
  requireMetadata cpiCall "solana.cpi.data_layout" "spl-token.transfer_checked"

  let pdaAction ←
    match scopedCall? plan "solana.pda.derive" "touch" with
    | some call => pure call
    | none => throw <| IO.userError "Solana SDK plan missing touch-scoped PDA action"
  requireMetadata pdaAction "solana.pda.name" "vault"
  requireMetadata pdaAction "proof_forge.entrypoint" "touch"

  let cpiAction ←
    match scopedCall? plan "solana.cpi.invoke_signed" "touch" with
    | some call => pure call
    | none => throw <| IO.userError "Solana SDK plan missing touch-scoped CPI action"
  requireMetadata cpiAction "solana.cpi.name" "token_transfer"
  requireMetadata cpiAction "proof_forge.entrypoint" "touch"

def main : IO UInt32 := do
  let plan ←
    match resolveSpec solanaSbpfAsm extensionSpec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError s!"Solana SDK routing failed: {err.render}"
  requireSolanaPlan plan

  let expected :=
    "target `evm` does not support capability `storage.pda`: " ++
    "capability is not present in the target profile"
  match resolveSpec evm extensionSpec with
  | .ok _ => throw <| IO.userError "EVM unexpectedly accepted Solana PDA/CPI extension"
  | .error err =>
      require (err.render == expected) s!"unexpected EVM diagnostic: {err.render}"

  IO.println "solana-sdk: ok"
  return 0

end ProofForge.Tests.SolanaSdk

def main : IO UInt32 :=
  ProofForge.Tests.SolanaSdk.main
