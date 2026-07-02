import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Contract.Builder

namespace ProofForge.Solana

open ProofForge.Target

inductive AccountAccess where
  | readOnly
  | writable
  deriving BEq, DecidableEq, Repr

def AccountAccess.id : AccountAccess -> String
  | .readOnly => "readonly"
  | .writable => "writable"

inductive SignerPolicy where
  | none
  | signer
  | pdaSigner
  deriving BEq, DecidableEq, Repr

def SignerPolicy.id : SignerPolicy -> String
  | .none => "none"
  | .signer => "signer"
  | .pdaSigner => "pda-signer"

structure AccountMeta where
  name : String
  access : AccountAccess := .readOnly
  signer : SignerPolicy := .none
  deriving Repr

structure PdaBinding where
  name : String
  seeds : Array String := #[]
  bump? : Option String := none
  account? : Option String := none
  isSigner : Bool := false
  deriving Repr

structure CpiCall where
  name : String
  program : String
  instruction : String
  accounts : Array AccountMeta := #[]
  signerSeeds : Array String := #[]
  dataLayout? : Option String := none
  deriving Repr

def kv (key value : String) : TargetMetadata := {
  key := key
  value := value
}

def joinWith (separator : String) (values : Array String) : String :=
  values.foldl
    (fun acc value =>
      if acc == "" then
        value
      else
        acc ++ separator ++ value)
    ""

def maybeKv (key : String) : Option String -> Array TargetMetadata
  | some value => #[kv key value]
  | none => #[]

def boolValue (value : Bool) : String :=
  if value then "true" else "false"

def AccountMeta.encode (account : AccountMeta) : String :=
  account.name ++ ":" ++ account.access.id ++ ":" ++ account.signer.id

def account (name : String) (access : AccountAccess := .readOnly)
    (signerPolicy : SignerPolicy := .none) : AccountMeta := {
  name := name
  access := access
  signer := signerPolicy
}

def readonlyAccount (name : String) : AccountMeta :=
  account name .readOnly .none

def writableAccount (name : String) : AccountMeta :=
  account name .writable .none

def signerAccount (name : String) (access : AccountAccess := .readOnly) : AccountMeta :=
  account name access .signer

def writableSignerAccount (name : String) : AccountMeta :=
  account name .writable .signer

def pdaSignerAccount (name : String) (access : AccountAccess := .readOnly) : AccountMeta :=
  account name access .pdaSigner

def PdaBinding.metadata (binding : PdaBinding) : Array TargetMetadata :=
  #[
    kv "solana.extension" "pda",
    kv "solana.pda.name" binding.name,
    kv "solana.pda.seeds" (joinWith "," binding.seeds),
    kv "solana.pda.signer" (boolValue binding.isSigner)
  ] ++
  maybeKv "solana.pda.bump" binding.bump? ++
  maybeKv "solana.pda.account" binding.account?

def CpiCall.metadata (call : CpiCall) : Array TargetMetadata :=
  #[
    kv "solana.extension" "cpi",
    kv "solana.cpi.name" call.name,
    kv "solana.cpi.program" call.program,
    kv "solana.cpi.instruction" call.instruction,
    kv "solana.cpi.accounts" (joinWith "," (call.accounts.map AccountMeta.encode)),
    kv "solana.cpi.signer_seeds" (joinWith "," call.signerSeeds)
  ] ++
  maybeKv "solana.cpi.data_layout" call.dataLayout?

def pda (binding : PdaBinding) : ProofForge.Contract.Builder.ModuleM Unit := do
  ProofForge.Contract.Builder.capability .accountExplicit "solana.account.pda" (source? := some binding.name)
    (metadata := binding.metadata)
  ProofForge.Contract.Builder.capability .storagePda "solana.pda.derive" (source? := some binding.name)
    (metadata := binding.metadata)

def pdaEntry (binding : PdaBinding) : ProofForge.Contract.Builder.EntryM Unit := do
  ProofForge.Contract.Builder.entryCapability .accountExplicit "solana.account.pda" (source? := some binding.name)
    (metadata := binding.metadata)
  ProofForge.Contract.Builder.entryCapability .storagePda "solana.pda.derive" (source? := some binding.name)
    (metadata := binding.metadata)

def pdaAccount (name : String) (seeds : Array String) (bump? : Option String := none)
    (account? : Option String := none) (isSigner : Bool := false) : ProofForge.Contract.Builder.ModuleM Unit :=
  pda {
    name := name
    seeds := seeds
    bump? := bump?
    account? := account?
    isSigner := isSigner
  }

def derivePda (name : String) (seeds : Array String) (bump? : Option String := none)
    (account? : Option String := none) (isSigner : Bool := false) : ProofForge.Contract.Builder.EntryM Unit :=
  pdaEntry {
    name := name
    seeds := seeds
    bump? := bump?
    account? := account?
    isSigner := isSigner
  }

def cpi (call : CpiCall) : ProofForge.Contract.Builder.ModuleM Unit := do
  if call.accounts.size > 0 then
    ProofForge.Contract.Builder.capability .accountExplicit "solana.cpi.accounts" (source? := some call.name)
      (metadata := call.metadata)
  let operation :=
    if call.signerSeeds.size == 0 then
      "solana.cpi.invoke"
    else
      "solana.cpi.invoke_signed"
  ProofForge.Contract.Builder.capability .crosscallCpi operation (source? := some call.name)
    (metadata := call.metadata)

def cpiEntry (call : CpiCall) : ProofForge.Contract.Builder.EntryM Unit := do
  if call.accounts.size > 0 then
    ProofForge.Contract.Builder.entryCapability .accountExplicit "solana.cpi.accounts" (source? := some call.name)
      (metadata := call.metadata)
  let operation :=
    if call.signerSeeds.size == 0 then
      "solana.cpi.invoke"
    else
      "solana.cpi.invoke_signed"
  ProofForge.Contract.Builder.entryCapability .crosscallCpi operation (source? := some call.name)
    (metadata := call.metadata)

def cpiInvoke (name program instruction : String) (accounts : Array AccountMeta := #[])
    (dataLayout? : Option String := none) : ProofForge.Contract.Builder.ModuleM Unit :=
  cpi {
    name := name
    program := program
    instruction := instruction
    accounts := accounts
    dataLayout? := dataLayout?
  }

def cpiInvokeSigned (name program instruction : String) (accounts : Array AccountMeta)
    (signerSeeds : Array String) (dataLayout? : Option String := none) : ProofForge.Contract.Builder.ModuleM Unit :=
  cpi {
    name := name
    program := program
    instruction := instruction
    accounts := accounts
    signerSeeds := signerSeeds
    dataLayout? := dataLayout?
  }

def invokeCpi (name program instruction : String) (accounts : Array AccountMeta := #[])
    (dataLayout? : Option String := none) : ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry {
    name := name
    program := program
    instruction := instruction
    accounts := accounts
    dataLayout? := dataLayout?
  }

def invokeSignedCpi (name program instruction : String) (accounts : Array AccountMeta)
    (signerSeeds : Array String) (dataLayout? : Option String := none) : ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry {
    name := name
    program := program
    instruction := instruction
    accounts := accounts
    signerSeeds := signerSeeds
    dataLayout? := dataLayout?
  }

end ProofForge.Solana
