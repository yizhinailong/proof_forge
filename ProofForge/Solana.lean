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
  extraMetadata : Array TargetMetadata := #[]
  deriving Repr

inductive AllocatorKind where
  | bump
  | noAllocator
  deriving BEq, DecidableEq, Repr

def AllocatorKind.id : AllocatorKind -> String
  | .bump => "bump"
  | .noAllocator => "none"

structure AllocatorConfig where
  name : String := "runtime"
  kind : AllocatorKind := .bump
  heapStart : String := "0x300000000"
  heapBytes : Nat := 32768
  deriving Repr

inductive MemoryOp where
  | memcpy
  | memmove
  | memcmp
  | memset
  deriving BEq, DecidableEq, Repr

def MemoryOp.id : MemoryOp -> String
  | .memcpy => "memcpy"
  | .memmove => "memmove"
  | .memcmp => "memcmp"
  | .memset => "memset"

inductive CryptoHashOp where
  | sha256
  | keccak256
  deriving BEq, DecidableEq, Repr

def CryptoHashOp.id : CryptoHashOp -> String
  | .sha256 => "sha256"
  | .keccak256 => "keccak256"

inductive SysvarKind where
  | rent
  deriving BEq, DecidableEq, Repr

def SysvarKind.id : SysvarKind -> String
  | .rent => "rent"

inductive SysvarField where
  | rentLamportsPerByteYear
  deriving BEq, DecidableEq, Repr

def SysvarField.id : SysvarField -> String
  | .rentLamportsPerByteYear => "lamports_per_byte_year"

def SysvarField.kind : SysvarField -> SysvarKind
  | .rentLamportsPerByteYear => .rent

structure MemoryAction where
  name : String
  op : MemoryOp
  dstState? : Option String := none
  srcState? : Option String := none
  lhsState? : Option String := none
  rhsState? : Option String := none
  resultState? : Option String := none
  bytes : Nat
  value? : Option Nat := none
  deriving Repr

structure CryptoHashAction where
  name : String
  op : CryptoHashOp := .sha256
  inputState : String
  bytes : Nat
  outputStates : Array String
  deriving Repr

structure SysvarReadAction where
  name : String
  kind : SysvarKind := .rent
  field : SysvarField := .rentLamportsPerByteYear
  outputState : String
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

def seedPrefixValue? (marker seed : String) : Option String :=
  if seed.startsWith marker then
    some (seed.drop marker.length |>.toString)
  else
    none

def seedDescriptorValue (seed : String) : String :=
  match seedPrefixValue? "literal:" seed with
  | some value => value
  | none =>
      match seedPrefixValue? "utf8:" seed with
      | some value => value
      | none =>
          match seedPrefixValue? "account:" seed with
          | some value => value
          | none =>
              match seedPrefixValue? "bump:" seed with
              | some value => value
              | none =>
                  match seedPrefixValue? "param:" seed with
                  | some value => value
                  | none =>
                      match seedPrefixValue? "instruction:" seed with
                      | some value => value
                      | none => seed

def literalSeed (value : String) : String :=
  "literal:" ++ value

def utf8Seed (value : String) : String :=
  "utf8:" ++ value

def accountSeed (account : String) : String :=
  "account:" ++ account

def bumpSeed (source : String) : String :=
  "bump:" ++ source

def instructionSeed (param : String) : String :=
  "param:" ++ param

def paramSeed (param : String) : String :=
  instructionSeed param

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
    kv "solana.pda.seeds" (joinWith "," (binding.seeds.map seedDescriptorValue)),
    kv "solana.pda.seed_descriptors" (joinWith "," binding.seeds),
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
  maybeKv "solana.cpi.data_layout" call.dataLayout? ++
  call.extraMetadata

def AllocatorConfig.metadata (config : AllocatorConfig) : Array TargetMetadata :=
  #[
    kv "solana.extension" "allocator",
    kv "solana.allocator.name" config.name,
    kv "solana.allocator.kind" config.kind.id,
    kv "solana.allocator.heap_start" config.heapStart,
    kv "solana.allocator.heap_bytes" (toString config.heapBytes),
    kv "solana.allocator.model" (
      match config.kind with
      | .bump => "downward-bump"
      | .noAllocator => "deny-dynamic"
    )
  ]

def natKv (key : String) (value : Nat) : TargetMetadata :=
  kv key (toString value)

def maybeNatKv (key : String) : Option Nat -> Array TargetMetadata
  | some value => #[natKv key value]
  | none => #[]

def MemoryAction.metadata (action : MemoryAction) : Array TargetMetadata :=
  #[
    kv "solana.extension" "memory",
    kv "solana.memory.name" action.name,
    kv "solana.memory.op" action.op.id,
    natKv "solana.memory.bytes" action.bytes
  ] ++
  maybeKv "solana.memory.dst_state" action.dstState? ++
  maybeKv "solana.memory.src_state" action.srcState? ++
  maybeKv "solana.memory.lhs_state" action.lhsState? ++
  maybeKv "solana.memory.rhs_state" action.rhsState? ++
  maybeKv "solana.memory.result_state" action.resultState? ++
  maybeNatKv "solana.memory.value" action.value?

def CryptoHashAction.metadata (action : CryptoHashAction) : Array TargetMetadata :=
  #[
    kv "solana.extension" "crypto",
    kv "solana.crypto.name" action.name,
    kv "solana.crypto.op" action.op.id,
    kv "solana.crypto.input_state" action.inputState,
    natKv "solana.crypto.bytes" action.bytes,
    kv "solana.crypto.output_states" (joinWith "," action.outputStates)
  ]

def SysvarReadAction.metadata (action : SysvarReadAction) : Array TargetMetadata :=
  #[
    kv "solana.extension" "sysvar",
    kv "solana.sysvar.name" action.name,
    kv "solana.sysvar.kind" action.kind.id,
    kv "solana.sysvar.field" action.field.id,
    kv "solana.sysvar.output_state" action.outputState
  ]

def systemProgram : String :=
  "system_program"

def splTokenProgram : String :=
  "spl_token"

def splToken2022Program : String :=
  "spl_token_2022"

def associatedTokenProgram : String :=
  "associated_token"

def tokenProtocolForProgram (tokenProgram : String) : String :=
  if tokenProgram == splToken2022Program then
    "token-2022"
  else
    "spl-token"

def signerForSeeds (name : String) (access : AccountAccess) (signerSeeds : Array String) : AccountMeta :=
  if signerSeeds.isEmpty then
    signerAccount name access
  else
    pdaSignerAccount name access

def systemMetadata : Array TargetMetadata :=
  #[
    kv "solana.cpi.protocol" "system"
  ]

def tokenMetadata (tokenProgram : String) : Array TargetMetadata :=
  #[
    kv "solana.cpi.protocol" (tokenProtocolForProgram tokenProgram)
  ]

def systemTransferCall (name fromAccount to lamportsSource : String)
    (signerSeeds : Array String := #[]) : CpiCall := {
  name := name
  program := systemProgram
  instruction := "transfer"
  accounts := #[
    signerForSeeds fromAccount .writable signerSeeds,
    writableAccount to
  ]
  signerSeeds := signerSeeds
  dataLayout? := some "system.transfer"
  extraMetadata := systemMetadata ++ #[
    kv "solana.cpi.lamports_source" lamportsSource
  ]
}

def systemCreateAccountCall (name payer newAccount lamportsSource spaceSource owner : String)
    (signerSeeds : Array String := #[]) : CpiCall := {
  name := name
  program := systemProgram
  instruction := "create_account"
  accounts := #[
    writableSignerAccount payer,
    signerForSeeds newAccount .writable signerSeeds
  ]
  signerSeeds := signerSeeds
  dataLayout? := some "system.create_account"
  extraMetadata := systemMetadata ++ #[
    kv "solana.cpi.lamports_source" lamportsSource,
    kv "solana.cpi.space_source" spaceSource,
    kv "solana.cpi.owner" owner
  ]
}

def splTokenTransferCheckedCall (name source mint destination authority amountSource : String)
    (decimals : Nat) (tokenProgram : String := splTokenProgram)
    (signerSeeds : Array String := #[]) : CpiCall := {
  name := name
  program := tokenProgram
  instruction := "transfer_checked"
  accounts := #[
    writableAccount source,
    readonlyAccount mint,
    writableAccount destination,
    signerForSeeds authority .readOnly signerSeeds
  ]
  signerSeeds := signerSeeds
  dataLayout? := some "spl-token.transfer_checked"
  extraMetadata := tokenMetadata tokenProgram ++ #[
    kv "solana.cpi.amount_source" amountSource,
    kv "solana.cpi.decimals" (toString decimals)
  ]
}

def splTokenMintToCall (name mint destination authority amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) : CpiCall := {
  name := name
  program := tokenProgram
  instruction := "mint_to"
  accounts := #[
    writableAccount mint,
    writableAccount destination,
    signerForSeeds authority .readOnly signerSeeds
  ]
  signerSeeds := signerSeeds
  dataLayout? := some "spl-token.mint_to"
  extraMetadata := tokenMetadata tokenProgram ++ #[
    kv "solana.cpi.amount_source" amountSource
  ]
}

def splTokenBurnCall (name source mint authority amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) : CpiCall := {
  name := name
  program := tokenProgram
  instruction := "burn"
  accounts := #[
    writableAccount source,
    writableAccount mint,
    signerForSeeds authority .readOnly signerSeeds
  ]
  signerSeeds := signerSeeds
  dataLayout? := some "spl-token.burn"
  extraMetadata := tokenMetadata tokenProgram ++ #[
    kv "solana.cpi.amount_source" amountSource
  ]
}

def splTokenApproveCall (name source delegate owner amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) : CpiCall := {
  name := name
  program := tokenProgram
  instruction := "approve"
  accounts := #[
    writableAccount source,
    readonlyAccount delegate,
    signerForSeeds owner .readOnly signerSeeds
  ]
  signerSeeds := signerSeeds
  dataLayout? := some "spl-token.approve"
  extraMetadata := tokenMetadata tokenProgram ++ #[
    kv "solana.cpi.amount_source" amountSource
  ]
}

def splTokenRevokeCall (name source owner : String) (tokenProgram : String := splTokenProgram)
    (signerSeeds : Array String := #[]) : CpiCall := {
  name := name
  program := tokenProgram
  instruction := "revoke"
  accounts := #[
    writableAccount source,
    signerForSeeds owner .readOnly signerSeeds
  ]
  signerSeeds := signerSeeds
  dataLayout? := some "spl-token.revoke"
  extraMetadata := tokenMetadata tokenProgram
}

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

def allocator (config : AllocatorConfig) : ProofForge.Contract.Builder.ModuleM Unit := do
  ProofForge.Contract.Builder.capability .runtimeAllocator "solana.runtime.allocator"
    (source? := some config.name)
    (metadata := config.metadata)

def bumpAllocator (name : String := "runtime") (heapStart : String := "0x300000000")
    (heapBytes : Nat := 32768) : ProofForge.Contract.Builder.ModuleM Unit :=
  allocator {
    name := name
    kind := .bump
    heapStart := heapStart
    heapBytes := heapBytes
  }

def noAllocator (name : String := "runtime") : ProofForge.Contract.Builder.ModuleM Unit :=
  allocator {
    name := name
    kind := .noAllocator
    heapBytes := 0
  }

def memoryEntry (action : MemoryAction) : ProofForge.Contract.Builder.EntryM Unit := do
  ProofForge.Contract.Builder.entryCapability .runtimeMemory
    ("solana.memory." ++ action.op.id)
    (source? := some action.name)
    (metadata := action.metadata)

def memcpyState (name dstState srcState : String) (bytes : Nat) :
    ProofForge.Contract.Builder.EntryM Unit :=
  memoryEntry {
    name := name
    op := .memcpy
    dstState? := some dstState
    srcState? := some srcState
    bytes := bytes
  }

def memmoveState (name dstState srcState : String) (bytes : Nat) :
    ProofForge.Contract.Builder.EntryM Unit :=
  memoryEntry {
    name := name
    op := .memmove
    dstState? := some dstState
    srcState? := some srcState
    bytes := bytes
  }

def memcmpState (name lhsState rhsState resultState : String) (bytes : Nat) :
    ProofForge.Contract.Builder.EntryM Unit :=
  memoryEntry {
    name := name
    op := .memcmp
    lhsState? := some lhsState
    rhsState? := some rhsState
    resultState? := some resultState
    bytes := bytes
  }

def memsetState (name dstState : String) (value bytes : Nat) :
    ProofForge.Contract.Builder.EntryM Unit :=
  memoryEntry {
    name := name
    op := .memset
    dstState? := some dstState
    bytes := bytes
    value? := some value
  }

def cryptoHashEntry (action : CryptoHashAction) : ProofForge.Contract.Builder.EntryM Unit := do
  ProofForge.Contract.Builder.entryCapability .cryptoHash
    ("solana.crypto." ++ action.op.id)
    (source? := some action.name)
    (metadata := action.metadata)

def sha256StateToStates (name inputState : String) (bytes : Nat)
    (outputStates : Array String) : ProofForge.Contract.Builder.EntryM Unit :=
  cryptoHashEntry {
    name := name
    op := .sha256
    inputState := inputState
    bytes := bytes
    outputStates := outputStates
  }

def keccak256StateToStates (name inputState : String) (bytes : Nat)
    (outputStates : Array String) : ProofForge.Contract.Builder.EntryM Unit :=
  cryptoHashEntry {
    name := name
    op := .keccak256
    inputState := inputState
    bytes := bytes
    outputStates := outputStates
  }

def sysvarEntry (action : SysvarReadAction) : ProofForge.Contract.Builder.EntryM Unit := do
  ProofForge.Contract.Builder.entryCapability .storageScalar
    "solana.sysvar.output_state"
    (source? := some action.outputState)
    (metadata := action.metadata)
  ProofForge.Contract.Builder.entryCapability .envBlock
    ("solana.sysvar." ++ action.kind.id ++ "." ++ action.field.id)
    (source? := some action.name)
    (metadata := action.metadata)

def rentLamportsPerByteYearToState (name outputState : String) :
    ProofForge.Contract.Builder.EntryM Unit :=
  sysvarEntry {
    name := name
    kind := .rent
    field := .rentLamportsPerByteYear
    outputState := outputState
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
    (dataLayout? : Option String := none) (extraMetadata : Array TargetMetadata := #[]) :
    ProofForge.Contract.Builder.ModuleM Unit :=
  cpi {
    name := name
    program := program
    instruction := instruction
    accounts := accounts
    dataLayout? := dataLayout?
    extraMetadata := extraMetadata
  }

def cpiInvokeSigned (name program instruction : String) (accounts : Array AccountMeta)
    (signerSeeds : Array String) (dataLayout? : Option String := none)
    (extraMetadata : Array TargetMetadata := #[]) : ProofForge.Contract.Builder.ModuleM Unit :=
  cpi {
    name := name
    program := program
    instruction := instruction
    accounts := accounts
    signerSeeds := signerSeeds
    dataLayout? := dataLayout?
    extraMetadata := extraMetadata
  }

def invokeCpi (name program instruction : String) (accounts : Array AccountMeta := #[])
    (dataLayout? : Option String := none) (extraMetadata : Array TargetMetadata := #[]) :
    ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry {
    name := name
    program := program
    instruction := instruction
    accounts := accounts
    dataLayout? := dataLayout?
    extraMetadata := extraMetadata
  }

def invokeSignedCpi (name program instruction : String) (accounts : Array AccountMeta)
    (signerSeeds : Array String) (dataLayout? : Option String := none)
    (extraMetadata : Array TargetMetadata := #[]) : ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry {
    name := name
    program := program
    instruction := instruction
    accounts := accounts
    signerSeeds := signerSeeds
    dataLayout? := dataLayout?
    extraMetadata := extraMetadata
  }

def systemTransfer (name fromAccount to lamportsSource : String) (signerSeeds : Array String := #[]) :
    ProofForge.Contract.Builder.ModuleM Unit :=
  cpi (systemTransferCall name fromAccount to lamportsSource (signerSeeds := signerSeeds))

def invokeSystemTransfer (name fromAccount to lamportsSource : String) (signerSeeds : Array String := #[]) :
    ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry (systemTransferCall name fromAccount to lamportsSource (signerSeeds := signerSeeds))

def systemCreateAccount (name payer newAccount lamportsSource spaceSource owner : String)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Builder.ModuleM Unit :=
  cpi (systemCreateAccountCall name payer newAccount lamportsSource spaceSource owner
    (signerSeeds := signerSeeds))

def invokeSystemCreateAccount (name payer newAccount lamportsSource spaceSource owner : String)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry (systemCreateAccountCall name payer newAccount lamportsSource spaceSource owner
    (signerSeeds := signerSeeds))

def splTokenTransferChecked (name source mint destination authority amountSource : String)
    (decimals : Nat) (tokenProgram : String := splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Builder.ModuleM Unit :=
  cpi (splTokenTransferCheckedCall name source mint destination authority amountSource decimals
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds))

def invokeSplTokenTransferChecked (name source mint destination authority amountSource : String)
    (decimals : Nat) (tokenProgram : String := splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry (splTokenTransferCheckedCall name source mint destination authority amountSource decimals
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds))

def splTokenMintTo (name mint destination authority amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) :
    ProofForge.Contract.Builder.ModuleM Unit :=
  cpi (splTokenMintToCall name mint destination authority amountSource
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds))

def invokeSplTokenMintTo (name mint destination authority amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) :
    ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry (splTokenMintToCall name mint destination authority amountSource
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds))

def splTokenBurn (name source mint authority amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) :
    ProofForge.Contract.Builder.ModuleM Unit :=
  cpi (splTokenBurnCall name source mint authority amountSource
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds))

def invokeSplTokenBurn (name source mint authority amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) :
    ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry (splTokenBurnCall name source mint authority amountSource
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds))

def splTokenApprove (name source delegate owner amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) :
    ProofForge.Contract.Builder.ModuleM Unit :=
  cpi (splTokenApproveCall name source delegate owner amountSource
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds))

def invokeSplTokenApprove (name source delegate owner amountSource : String)
    (tokenProgram : String := splTokenProgram) (signerSeeds : Array String := #[]) :
    ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry (splTokenApproveCall name source delegate owner amountSource
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds))

def splTokenRevoke (name source owner : String) (tokenProgram : String := splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Builder.ModuleM Unit :=
  cpi (splTokenRevokeCall name source owner (tokenProgram := tokenProgram)
    (signerSeeds := signerSeeds))

def invokeSplTokenRevoke (name source owner : String) (tokenProgram : String := splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Builder.EntryM Unit :=
  cpiEntry (splTokenRevokeCall name source owner (tokenProgram := tokenProgram)
    (signerSeeds := signerSeeds))

end ProofForge.Solana
