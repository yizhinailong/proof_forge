import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Backend.Solana.Asm
import ProofForge.Backend.Solana.StateLayout
import ProofForge.Backend.Solana.Syscalls
import ProofForge.Target.Plan

namespace ProofForge.Backend.Solana.Extension

open ProofForge.Backend.Solana.Asm
open ProofForge.Backend.Solana.StateLayout
open ProofForge.Target

structure AccountMeta where
  name : String
  access : String
  signer : String
  deriving Repr, Inhabited

structure PdaDerive where
  name : String
  seeds : Array String := #[]
  bump? : Option String := none
  account? : Option String := none
  signer : Bool := false
  entrypoint? : Option String := none
  deriving Repr, Inhabited

inductive PdaSeedKind where
  | literal
  | account
  | bump
  | instructionParam
  deriving BEq, DecidableEq, Repr, Inhabited

def PdaSeedKind.id : PdaSeedKind -> String
  | .literal => "literal"
  | .account => "account"
  | .bump => "bump"
  | .instructionParam => "instruction-param"

structure PdaSeed where
  kind : PdaSeedKind
  value : String
  raw : String
  deriving Repr, Inhabited

structure CpiInvoke where
  name : String
  program : String
  instruction : String
  accounts : Array AccountMeta := #[]
  signerSeeds : Array String := #[]
  protocol? : Option String := none
  dataLayout? : Option String := none
  metadata : Array TargetMetadata := #[]
  signed : Bool := false
  entrypoint? : Option String := none
  deriving Repr, Inhabited

structure RuntimeAllocator where
  name : String
  kind : String
  heapStart : String
  heapBytes : String
  model : String
  entrypoint? : Option String := none
  deriving Repr, Inhabited

structure PdaAction where
  name : String
  entrypoint : String
  deriving Repr, Inhabited

structure CpiAction where
  name : String
  entrypoint : String
  deriving Repr, Inhabited

structure ProgramExtensions where
  allocators : Array RuntimeAllocator := #[]
  pdas : Array PdaDerive := #[]
  cpis : Array CpiInvoke := #[]
  pdaActions : Array PdaAction := #[]
  cpiActions : Array CpiAction := #[]
  deriving Repr, Inhabited

structure CpiAccountBinding where
  name : String
  layout : AccountInputLayout
  deriving Repr, Inhabited

structure CpiValueBinding where
  name : String
  absOff : Nat
  byteSize : Nat := 8
  sourceKind : String := "state"
  relativeToInstructionData : Bool := false
  deriving Repr, Inhabited

def metadataValue? (metadata : Array TargetMetadata) (key : String) : Option String :=
  metadata.foldl
    (fun found item =>
      match found with
      | some _ => found
      | none => if item.key == key then some item.value else none)
    none

def splitComma (value : String) : Array String :=
  value.splitOn "," |>.foldl
    (fun acc part => if part.isEmpty then acc else acc.push part)
    #[]

def parseSeedWithPrefix? (kind : PdaSeedKind) (marker raw : String) : Option PdaSeed :=
  if raw.startsWith marker then
    some { kind, value := raw.drop marker.length |>.toString, raw }
  else
    none

def parsePdaSeed (raw : String) : PdaSeed :=
  match parseSeedWithPrefix? .literal "literal:" raw with
  | some seed => seed
  | none =>
      match parseSeedWithPrefix? .literal "utf8:" raw with
      | some seed => seed
      | none =>
          match parseSeedWithPrefix? .account "account:" raw with
          | some seed => seed
          | none =>
              match parseSeedWithPrefix? .bump "bump:" raw with
              | some seed => seed
              | none =>
                  match parseSeedWithPrefix? .instructionParam "param:" raw with
                  | some seed => seed
                  | none =>
                      match parseSeedWithPrefix? .instructionParam "instruction:" raw with
                      | some seed => seed
                      | none => { kind := .literal, value := raw, raw }

def pdaMetadataSeeds (call : CapabilityCall) : Array String :=
  match metadataValue? call.metadata "solana.pda.seed_descriptors" with
  | some value => splitComma value
  | none => metadataValue? call.metadata "solana.pda.seeds" |>.map splitComma |>.getD #[]

def parseAccountMeta (encoded : String) : AccountMeta :=
  match encoded.splitOn ":" with
  | name :: access :: signer :: _ => { name, access, signer }
  | name :: access :: [] => { name, access, signer := "none" }
  | name :: [] => { name, access := "readonly", signer := "none" }
  | [] => { name := "", access := "readonly", signer := "none" }

def parseAccountMetas (encoded : String) : Array AccountMeta :=
  splitComma encoded |>.map parseAccountMeta

def boolFromString (value : String) : Bool :=
  value == "true"

def entrypoint? (call : CapabilityCall) : Option String :=
  metadataValue? call.metadata "proof_forge.entrypoint"

def PdaDerive.definition (pda : PdaDerive) : PdaDerive :=
  { pda with entrypoint? := none }

def CpiInvoke.definition (cpi : CpiInvoke) : CpiInvoke :=
  { cpi with
    entrypoint? := none
    metadata := cpi.metadata.filter (fun item => item.key != "proof_forge.entrypoint") }

def RuntimeAllocator.definition (allocator : RuntimeAllocator) : RuntimeAllocator :=
  { allocator with entrypoint? := none }

def ProgramExtensions.pushAllocatorDefinition (acc : ProgramExtensions)
    (allocator : RuntimeAllocator) : ProgramExtensions :=
  if acc.allocators.any (fun existing => existing.name == allocator.name) then
    acc
  else
    { acc with allocators := acc.allocators.push allocator.definition }

def ProgramExtensions.pushPdaDefinition (acc : ProgramExtensions) (pda : PdaDerive) : ProgramExtensions :=
  if acc.pdas.any (fun existing => existing.name == pda.name) then
    acc
  else
    { acc with pdas := acc.pdas.push pda.definition }

def ProgramExtensions.pushCpiDefinition (acc : ProgramExtensions) (cpi : CpiInvoke) : ProgramExtensions :=
  if acc.cpis.any (fun existing => existing.name == cpi.name) then
    acc
  else
    { acc with cpis := acc.cpis.push cpi.definition }

def ProgramExtensions.pushPdaAction (acc : ProgramExtensions) (action : PdaAction) : ProgramExtensions :=
  if acc.pdaActions.any (fun existing => existing.name == action.name && existing.entrypoint == action.entrypoint) then
    acc
  else
    { acc with pdaActions := acc.pdaActions.push action }

def ProgramExtensions.pushCpiAction (acc : ProgramExtensions) (action : CpiAction) : ProgramExtensions :=
  if acc.cpiActions.any (fun existing => existing.name == action.name && existing.entrypoint == action.entrypoint) then
    acc
  else
    { acc with cpiActions := acc.cpiActions.push action }

def ProgramExtensions.addPda (acc : ProgramExtensions) (pda : PdaDerive) : ProgramExtensions :=
  let acc := acc.pushPdaDefinition pda
  match pda.entrypoint? with
  | some entrypoint => acc.pushPdaAction { name := pda.name, entrypoint := entrypoint }
  | none => acc

def ProgramExtensions.addCpi (acc : ProgramExtensions) (cpi : CpiInvoke) : ProgramExtensions :=
  let acc := acc.pushCpiDefinition cpi
  match cpi.entrypoint? with
  | some entrypoint => acc.pushCpiAction { name := cpi.name, entrypoint := entrypoint }
  | none => acc

def ProgramExtensions.addAllocator (acc : ProgramExtensions)
    (allocator : RuntimeAllocator) : ProgramExtensions :=
  acc.pushAllocatorDefinition allocator

def allocatorFromCall? (call : CapabilityCall) : Option RuntimeAllocator :=
  if call.capability == .runtimeAllocator then
    some {
      name := metadataValue? call.metadata "solana.allocator.name" |>.getD "runtime"
      kind := metadataValue? call.metadata "solana.allocator.kind" |>.getD "bump"
      heapStart := metadataValue? call.metadata "solana.allocator.heap_start" |>.getD "0x300000000"
      heapBytes := metadataValue? call.metadata "solana.allocator.heap_bytes" |>.getD "32768"
      model := metadataValue? call.metadata "solana.allocator.model" |>.getD "downward-bump"
      entrypoint? := entrypoint? call
    }
  else
    none

def pdaFromCall? (call : CapabilityCall) : Option PdaDerive :=
  if call.operation == "solana.pda.derive" then
    let name := metadataValue? call.metadata "solana.pda.name" |>.getD call.operation
    some {
      name := name
      seeds := pdaMetadataSeeds call
      bump? := metadataValue? call.metadata "solana.pda.bump"
      account? := metadataValue? call.metadata "solana.pda.account"
      signer := metadataValue? call.metadata "solana.pda.signer" |>.map boolFromString |>.getD false
      entrypoint? := entrypoint? call
    }
  else
    none

def cpiFromCall? (call : CapabilityCall) : Option CpiInvoke :=
  if call.capability == .crosscallCpi then
    let name := metadataValue? call.metadata "solana.cpi.name" |>.getD call.operation
    let program := metadataValue? call.metadata "solana.cpi.program" |>.getD ""
    let instruction := metadataValue? call.metadata "solana.cpi.instruction" |>.getD ""
    some {
      name := name
      program := program
      instruction := instruction
      accounts := metadataValue? call.metadata "solana.cpi.accounts" |>.map parseAccountMetas |>.getD #[]
      signerSeeds := metadataValue? call.metadata "solana.cpi.signer_seeds" |>.map splitComma |>.getD #[]
      protocol? := metadataValue? call.metadata "solana.cpi.protocol"
      dataLayout? := metadataValue? call.metadata "solana.cpi.data_layout"
      metadata := call.metadata
      signed := call.operation == "solana.cpi.invoke_signed"
      entrypoint? := entrypoint? call
    }
  else
    none

def ProgramExtensions.fromPlan (plan : CapabilityPlan) : ProgramExtensions :=
  plan.calls.foldl
    (fun acc call =>
      let acc :=
        match allocatorFromCall? call with
        | some allocator => acc.addAllocator allocator
        | none => acc
      let acc :=
        match pdaFromCall? call with
        | some pda => acc.addPda pda
        | none => acc
      match cpiFromCall? call with
      | some cpi => acc.addCpi cpi
      | none => acc)
    {}

def hasExtensions (extensions : ProgramExtensions) : Bool :=
  extensions.allocators.size > 0 || extensions.pdas.size > 0 || extensions.cpis.size > 0

def hasSyscallExtensions (extensions : ProgramExtensions) : Bool :=
  extensions.pdas.size > 0 || extensions.cpis.size > 0

def hasEntrypointActions (extensions : ProgramExtensions) : Bool :=
  extensions.pdaActions.size > 0 || extensions.cpiActions.size > 0

def labelPart (name : String) : String :=
  let chars := name.toList.map fun ch =>
    if ch.isAlphanum || ch == '_' then ch else '_'
  String.ofList chars

def PdaDerive.label (pda : PdaDerive) : String :=
  "sol_pda_derive_" ++ labelPart pda.name

def CpiInvoke.label (cpi : CpiInvoke) : String :=
  "sol_cpi_" ++ labelPart cpi.name

def callSyscall (name : String) : AstNode :=
  .instruction { opcode := .call, imm := some (.sym name) }

def callHelper (name : String) : AstNode :=
  .instruction { opcode := .call, imm := some (.sym name) }

def stackPtr (dst : Reg) (offset : Nat) : Array AstNode := #[
  .instruction { opcode := .mov64, dst := some dst, src := some .r10 },
  .instruction { opcode := .sub64, dst := some dst, imm := some (.num offset) }
]

def entryInputSaveOffset : Nat := 3520
def accountPtrTableOffset : Nat := 3328
def entryInstructionDataSaveOffset : Nat := 3584
def entryInstructionDataReg : Reg := .r9

def loadSavedInstructionDataPtr (dst : Reg) : Array AstNode :=
  if dst == entryInstructionDataReg then
    #[]
  else
    #[.instruction { opcode := .mov64, dst := some dst, src := some entryInstructionDataReg }]

def loadCurrentProgramIdPtr (dst scratch : Reg) : Array AstNode :=
  loadSavedInstructionDataPtr dst ++ #[
    .instruction { opcode := .mov64, dst := some scratch, src := some dst },
    .instruction { opcode := .sub64, dst := some scratch, imm := some (.num 8) },
    .instruction { opcode := .ldxdw, dst := some scratch, src := some scratch, off := some (.num 0) },
    .instruction { opcode := .add64, dst := some dst, src := some scratch }
  ]

def pdaResultOffset : Nat := 64
def pdaSeedTableOffset : Nat := 128
def pdaSeedDataOffset : Nat := 512
def pdaMaxSeedLen : Nat := 32
def pdaMaxSeeds : Nat := 16

def cpiInstructionOffset : Nat := 64
def cpiAccountMetaOffset : Nat := 128
def cpiInstructionDataOffset : Nat := 384
def cpiProgramIdOffset : Nat := 448
def cpiPlaceholderPubkeyOffset : Nat := 512
def cpiAccountInfoOffset : Nat := 1088
def cpiPlaceholderLamportsOffset : Nat := 2048
def cpiSignerEntriesOffset : Nat := 2240
def cpiSignerSeedTableOffset : Nat := 2304
def cpiSignerSeedDataOffset : Nat := 2816
def cpiMaxSeedLen : Nat := 32

def cpiAccountBinding? (bindings : Array CpiAccountBinding) (name : String) :
    Option CpiAccountBinding :=
  bindings.find? (fun binding => binding.name == name)

def cpiValueBinding? (bindings : Array CpiValueBinding) (name : String) :
    Option CpiValueBinding :=
  bindings.find? (fun binding => binding.name == name)

def inputPtr (dst : Reg) (off : Nat) : Array AstNode := #[
  .instruction { opcode := .mov64, dst := some dst, src := some .r1 },
  .instruction { opcode := .add64, dst := some dst, imm := some (.num off) }
]

def inputAccountPtr (dst : Reg) (idx : Nat) : Array AstNode :=
  stackPtr dst accountPtrTableOffset ++ #[
    .instruction { opcode := .ldxdw, dst := some dst, src := some dst, off := some (.num (idx * 8)) }
  ]

def inputAccountFieldPtr (dst : Reg) (layout : AccountInputLayout) (absOff : Nat) : Array AstNode :=
  inputAccountPtr dst layout.index ++ #[
    .instruction { opcode := .add64, dst := some dst, imm := some (.num (absOff - layout.accountStart)) }
  ]

def lowerAccountScanStep (labelPrefix : String) (idx : Nat) : Array AstNode :=
  let alignedLabel := s!"{labelPrefix}_account_scan_{idx}_aligned"
  stackPtr .r6 accountPtrTableOffset ++ #[
    .instruction { opcode := .stxdw, dst := some .r6, off := some (.num (idx * 8)), src := some .r3 },
    .instruction { opcode := .ldxdw, dst := some .r4, src := some .r3, off := some (.num 80) },
    .instruction { opcode := .add64, dst := some .r3, imm := some (.num 88) },
    .instruction { opcode := .add64, dst := some .r3, src := some .r4 },
    .instruction { opcode := .add64, dst := some .r3, imm := some (.num MAX_PERMITTED_DATA_INCREASE) },
    .instruction { opcode := .add64, dst := some .r3, imm := some (.num U64_SIZE) },
    .instruction { opcode := .mov64, dst := some .r5, src := some .r3 },
    .instruction { opcode := .and64, dst := some .r5, imm := some (.num 7) },
    .instruction { opcode := .jeq, dst := some .r5, imm := some (.num 0), off := some (.sym alignedLabel) },
    .instruction { opcode := .mov64, dst := some .r6, imm := some (.num 8) },
    .instruction { opcode := .sub64, dst := some .r6, src := some .r5 },
    .instruction { opcode := .add64, dst := some .r3, src := some .r6 },
    .label alignedLabel
  ]

def lowerAccountPtrTableSetup (labelPrefix : String) (accountCount : Nat) : Array AstNode :=
  let scanSteps :=
    (List.range accountCount).foldl (fun acc idx => acc ++ lowerAccountScanStep labelPrefix idx) #[]
  #[
    .comment "scan Solana input account pointers into current stack frame",
    .instruction { opcode := .mov64, dst := some .r3, src := some .r1 },
    .instruction { opcode := .add64, dst := some .r3, imm := some (.num U64_SIZE) }
  ] ++ scanSteps

def PdaDerive.explicitSeeds (pda : PdaDerive) : Array PdaSeed :=
  pda.seeds.map parsePdaSeed

def PdaDerive.effectiveSeeds (pda : PdaDerive) : Array PdaSeed :=
  let seeds := pda.explicitSeeds
  match pda.bump? with
  | some bump =>
      if seeds.any (fun seed => seed.kind == .bump && seed.value == bump) then
        seeds
      else
        seeds.push { kind := .bump, value := bump, raw := "bump:" ++ bump }
  | none => seeds

def PdaDerive.seedValues (pda : PdaDerive) : Array String :=
  pda.explicitSeeds.map (fun seed => seed.value)

def stringBytes (value : String) : Array Nat :=
  value.toList.foldl (fun acc ch => acc.push ch.toNat) #[]

def lowerSeedBytes (seed : String) (base : Reg) : Array AstNode :=
  stringBytes seed |>.mapIdx (fun idx byte =>
    .instruction {
      opcode := .stb,
      dst := some base,
      off := some (.num idx),
      imm := some (.num byte)
    })

def lowerPdaStackSeedPtr (idx : Nat) : Array AstNode :=
  stackPtr .r5 (pdaSeedDataOffset + idx * pdaMaxSeedLen)

def lowerPdaSeedTableEntry (idx len : Nat) : Array AstNode :=
  let tableOffset := pdaSeedTableOffset + idx * 16
  stackPtr .r6 tableOffset ++ #[
    .instruction { opcode := .stxdw, dst := some .r6, off := some (.num 0), src := some .r5 },
    .instruction { opcode := .mov64, dst := some .r3, imm := some (.num len) },
    .instruction { opcode := .stxdw, dst := some .r6, off := some (.num 8), src := some .r3 }
  ]

def lowerInputBytesToPdaSeed (binding : CpiValueBinding) (byteSize : Nat) : Array AstNode :=
  let base :=
    if binding.relativeToInstructionData then
      loadSavedInstructionDataPtr .r7
    else
      #[.instruction { opcode := .mov64, dst := some .r7, src := some .r1 }]
  base ++
  (List.range byteSize).foldl
    (fun acc idx =>
      acc ++ #[
        .instruction { opcode := .ldxb, dst := some .r3, src := some .r7, off := some (.num (binding.absOff + idx)) },
        .instruction { opcode := .stxb, dst := some .r5, off := some (.num idx), src := some .r3 }
      ])
    #[]

def lowerPdaZeroSeedBytes (byteSize : Nat) : Array AstNode :=
  (List.range byteSize).foldl
    (fun acc idx =>
      acc.push <| .instruction {
        opcode := .stb,
        dst := some .r5,
        off := some (.num idx),
        imm := some (.num 0)
      })
    #[]

def lowerPdaStaticSeed (pdaName : String) (idx : Nat) (seed : String) : Array AstNode :=
  let bytes := stringBytes seed
  #[
    .comment s!"solana.pda.seed {pdaName}[{idx}] \"{seed}\"",
  ] ++
  lowerPdaStackSeedPtr idx ++
  lowerSeedBytes seed .r5 ++
  lowerPdaSeedTableEntry idx bytes.size

def lowerPdaAccountSeed (bindings : Array CpiAccountBinding) (pdaName : String)
    (idx : Nat) (account : String) : Array AstNode :=
  match cpiAccountBinding? bindings account with
  | some binding =>
      #[
        .comment s!"solana.pda.seed {pdaName}[{idx}] account {account} pubkey"
      ] ++
      inputAccountFieldPtr .r5 binding.layout binding.layout.keyOff ++
      lowerPdaSeedTableEntry idx 32
  | none =>
      #[
        .comment s!"solana.pda.seed {pdaName}[{idx}] account {account} missing placeholder=zero"
      ] ++
      lowerPdaStackSeedPtr idx ++
      lowerPdaZeroSeedBytes 32 ++
      lowerPdaSeedTableEntry idx 32

def lowerPdaValueSeed (pdaName : String) (idx : Nat) (kind source : String)
    (binding : CpiValueBinding) (byteSize : Nat) : Array AstNode :=
  #[
    .comment s!"solana.pda.seed {pdaName}[{idx}] {kind} {source} from {binding.sourceKind}"
  ] ++
  lowerPdaStackSeedPtr idx ++
  lowerInputBytesToPdaSeed binding byteSize ++
  lowerPdaSeedTableEntry idx byteSize

def lowerPdaBumpSeed (bindings : Array CpiValueBinding) (pdaName : String)
    (idx : Nat) (source : String) : Array AstNode :=
  match source.toNat? with
  | some bump =>
      if bump < 256 then
        #[
          .comment s!"solana.pda.seed {pdaName}[{idx}] bump literal={bump}"
        ] ++
        lowerPdaStackSeedPtr idx ++ #[
          .instruction { opcode := .stb, dst := some .r5, off := some (.num 0), imm := some (.num bump) }
        ] ++
        lowerPdaSeedTableEntry idx 1
      else
        #[
          .comment s!"solana.pda.seed {pdaName}[{idx}] bump literal={bump} out-of-range placeholder=255"
        ] ++
        lowerPdaStackSeedPtr idx ++ #[
          .instruction { opcode := .stb, dst := some .r5, off := some (.num 0), imm := some (.num 255) }
        ] ++
        lowerPdaSeedTableEntry idx 1
  | none =>
      match cpiValueBinding? bindings source with
      | some binding => lowerPdaValueSeed pdaName idx "bump" source binding 1
      | none =>
          #[
            .comment s!"solana.pda.seed {pdaName}[{idx}] bump {source} missing placeholder=255"
          ] ++
          lowerPdaStackSeedPtr idx ++ #[
            .instruction { opcode := .stb, dst := some .r5, off := some (.num 0), imm := some (.num 255) }
          ] ++
          lowerPdaSeedTableEntry idx 1

def lowerPdaInstructionParamSeed (bindings : Array CpiValueBinding) (pdaName : String)
    (idx : Nat) (source : String) : Array AstNode :=
  match cpiValueBinding? bindings source with
  | some binding => lowerPdaValueSeed pdaName idx "instruction-param" source binding binding.byteSize
  | none =>
      #[
        .comment s!"solana.pda.seed {pdaName}[{idx}] instruction-param {source} missing placeholder=zero"
      ] ++
      lowerPdaStackSeedPtr idx ++
      lowerPdaZeroSeedBytes 1 ++
      lowerPdaSeedTableEntry idx 1

def lowerPdaSeed (accountBindings : Array CpiAccountBinding) (valueBindings : Array CpiValueBinding)
    (pdaName : String) (idx : Nat) (seed : PdaSeed) : Array AstNode :=
  match seed.kind with
  | .literal => lowerPdaStaticSeed pdaName idx seed.value
  | .account => lowerPdaAccountSeed accountBindings pdaName idx seed.value
  | .bump => lowerPdaBumpSeed valueBindings pdaName idx seed.value
  | .instructionParam => lowerPdaInstructionParamSeed valueBindings pdaName idx seed.value

def lowerPdaSeeds (accountBindings : Array CpiAccountBinding) (valueBindings : Array CpiValueBinding)
    (pda : PdaDerive) : Array AstNode :=
  pda.effectiveSeeds.mapIdx (fun idx seed => lowerPdaSeed accountBindings valueBindings pda.name idx seed)
    |>.foldl (fun acc nodes => acc ++ nodes) #[]

def lowerPdaResultAccountValidation (accountBindings : Array CpiAccountBinding)
    (pda : PdaDerive) : Array AstNode :=
  match pda.account? with
  | none => #[]
  | some account =>
      match cpiAccountBinding? accountBindings account with
      | none =>
          #[
            .comment s!"solana.pda.validate {pda.name} account {account} missing account binding"
          ]
      | some binding =>
          let compareWords :=
            (List.range 4).foldl
              (fun acc idx =>
                let off := idx * 8
                acc ++ #[
                  .instruction { opcode := .ldxdw, dst := some .r3, src := some .r5, off := some (.num off) },
                  .instruction { opcode := .ldxdw, dst := some .r8, src := some .r6, off := some (.num off) },
                  .instruction { opcode := .jne, dst := some .r3, src := some .r8, off := some (.sym "error_pda") }
                ])
              #[]
          #[
            .comment s!"solana.pda.validate {pda.name} account {account}"
          ] ++
          stackPtr .r5 pdaResultOffset ++
          inputAccountFieldPtr .r6 binding.layout binding.layout.keyOff ++
          compareWords

def callHelperPreservingInput (helperName errorLabel : String) : Array AstNode := #[
  .instruction { opcode := .stxdw, dst := some .r10, off := some (.num entryInputSaveOffset), src := some .r1 },
  callHelper helperName,
  .instruction { opcode := .ldxdw, dst := some .r1, src := some .r10, off := some (.num entryInputSaveOffset) },
  .instruction { opcode := .jne, dst := some .r0, imm := some (.num 0), off := some (.sym errorLabel) }
]

def lowerPdaDerive (accountBindings : Array CpiAccountBinding) (valueBindings : Array CpiValueBinding)
    (pda : PdaDerive) : Array AstNode :=
  #[
    .blankLine,
    .comment s!"solana.pda.derive {pda.name}",
    .label pda.label,
    .instruction { opcode := .mov64, dst := some .r7, src := some .r1 },
    .comment "pack PDA seed byte slices"
  ] ++
  lowerAccountPtrTableSetup pda.label accountBindings.size ++
  lowerPdaSeeds accountBindings valueBindings pda ++
  stackPtr .r1 pdaSeedTableOffset ++ #[
    .instruction { opcode := .mov64, dst := some .r2, imm := some (.num pda.effectiveSeeds.size) },
  ] ++
  loadCurrentProgramIdPtr .r3 .r5 ++
  stackPtr .r4 pdaResultOffset ++ #[
    .comment "r1=seeds_ptr r2=seeds_len r3=program_id_ptr r4=result_ptr",
    callSyscall ProofForge.Backend.Solana.Syscalls.sol_create_program_address,
    .instruction { opcode := .jne, dst := some .r0, imm := some (.num 0), off := some (.sym "error_pda") },
    .instruction { opcode := .mov64, dst := some .r1, src := some .r7 },
    .comment s!"PDA result stored at stack offset {pdaResultOffset}",
  ] ++
  lowerPdaResultAccountValidation accountBindings pda ++ #[
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
    .instruction { opcode := .exit }
  ]

def boolByte (value : Bool) : Nat :=
  if value then 1 else 0

def cpiAccountWritable (account : AccountMeta) : Nat :=
  boolByte (account.access == "writable")

def cpiAccountSigner (account : AccountMeta) : Nat :=
  boolByte (account.signer != "none")

def storeImm (opcode : Opcode) (base : Reg) (off value : Nat) : AstNode :=
  .instruction { opcode, dst := some base, off := some (.num off), imm := some (.num value) }

def storeReg (opcode : Opcode) (base : Reg) (off : Nat) (src : Reg) : AstNode :=
  .instruction { opcode, dst := some base, off := some (.num off), src := some src }

def zeroStackQuad (base : Reg) (off : Nat) : AstNode :=
  storeImm .stdw base off 0

def loadImm (dst : Reg) (value : Nat) : AstNode :=
  .instruction { opcode := .mov64, dst := some dst, imm := some (.num value) }

def cpiMetadataValue? (cpi : CpiInvoke) (key : String) : Option String :=
  metadataValue? cpi.metadata key

def copyInputPubkeyToStack (name : String) (srcOff stackOff : Nat) : Array AstNode :=
  #[
    .comment s!"solana.cpi.program_id {name} from input account"
  ] ++
  stackPtr .r8 stackOff ++
  inputPtr .r7 srcOff ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 0) },
    storeReg .stxdw .r8 0 .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 8) },
    storeReg .stxdw .r8 8 .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 16) },
    storeReg .stxdw .r8 16 .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 24) },
    storeReg .stxdw .r8 24 .r3
  ]

def copyInputAccountPubkeyToStack (name : String) (layout : AccountInputLayout)
    (stackOff : Nat) : Array AstNode :=
  #[
    .comment s!"solana.cpi.program_id {name} from input account"
  ] ++
  stackPtr .r8 stackOff ++
  inputAccountFieldPtr .r7 layout layout.keyOff ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 0) },
    storeReg .stxdw .r8 0 .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 8) },
    storeReg .stxdw .r8 8 .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 16) },
    storeReg .stxdw .r8 16 .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 24) },
    storeReg .stxdw .r8 24 .r3
  ]

def lowerZero32 (base : Reg) : Array AstNode := #[
  zeroStackQuad base 0,
  zeroStackQuad base 8,
  zeroStackQuad base 16,
  zeroStackQuad base 24
]

def lowerZero32At (base : Reg) (off : Nat) : Array AstNode := #[
  zeroStackQuad base off,
  zeroStackQuad base (off + 8),
  zeroStackQuad base (off + 16),
  zeroStackQuad base (off + 24)
]

def lowerCpiSystemProgramId : Array AstNode :=
  #[
    .comment "solana.cpi.program_id system_program (32 zero bytes)"
  ] ++
  stackPtr .r8 cpiProgramIdOffset ++
  lowerZero32 .r8

def splTokenProgramIdBytes : Array Nat :=
  #[6, 221, 246, 225, 215, 101, 161, 147,
    217, 203, 225, 70, 206, 235, 121, 172,
    28, 180, 133, 237, 95, 91, 55, 145,
    58, 140, 245, 133, 126, 255, 0, 169]

def storePubkeyBytes (base : Reg) (bytes : Array Nat) : Array AstNode :=
  bytes.mapIdx fun idx byte => storeImm .stb base idx byte

def lowerCpiSplTokenProgramId : Array AstNode :=
  #[
    .comment "solana.cpi.program_id spl_token TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
  ] ++
  stackPtr .r8 cpiProgramIdOffset ++
  storePubkeyBytes .r8 splTokenProgramIdBytes

def lowerCpiFallbackProgramId (program : String) : Array AstNode :=
  #[
    .comment s!"solana.cpi.program_id {program} fallback placeholder"
  ] ++
  stackPtr .r8 cpiProgramIdOffset ++
  lowerZero32 .r8

def lowerCpiProgramId (bindings : Array CpiAccountBinding) (cpi : CpiInvoke) : Array AstNode :=
  if cpi.program == "spl_token" then
    lowerCpiSplTokenProgramId
  else
    match cpiAccountBinding? bindings cpi.program with
    | some binding =>
        copyInputAccountPubkeyToStack s!"{cpi.program} account[{binding.layout.index}]"
          binding.layout cpiProgramIdOffset
    | none =>
        if cpi.program == "system_program" then
          lowerCpiSystemProgramId
        else
          lowerCpiFallbackProgramId cpi.program

def lowerCpiPlaceholderPubkey (idx : Nat) (name : String) : Array AstNode :=
  let offset := cpiPlaceholderPubkeyOffset + idx * 32
  #[
    .comment s!"solana.cpi.placeholder_pubkey {name}"
  ] ++
  stackPtr .r8 offset ++
  lowerZero32 .r8 ++ #[
    storeImm .stb .r8 31 (idx + 1)
  ]

def lowerCpiPlaceholderLamports (idx : Nat) : Array AstNode :=
  let offset := cpiPlaceholderLamportsOffset + idx * 8
  stackPtr .r8 offset ++ #[
    zeroStackQuad .r8 0
  ]

def lowerCpiFallbackPlaceholders (bindings : Array CpiAccountBinding) (cpi : CpiInvoke) : Array AstNode :=
  cpi.accounts.mapIdx (fun idx account =>
    match cpiAccountBinding? bindings account.name with
    | some _ => #[]
    | none =>
        lowerCpiPlaceholderPubkey idx account.name ++
        lowerCpiPlaceholderLamports idx)
    |>.foldl (fun acc nodes => acc ++ nodes) #[]

def lowerCpiAccountMeta (bindings : Array CpiAccountBinding) (idx : Nat)
    (account : AccountMeta) : Array AstNode :=
  let metaOffset := idx * 16
  let pubkeyOffset := cpiPlaceholderPubkeyOffset + idx * 32
  let pubkeyPtr :=
    match cpiAccountBinding? bindings account.name with
    | some binding =>
        #[
          .comment s!"solana.cpi.account_meta {account.name} key_ptr account[{binding.layout.index}]"
        ] ++
        inputAccountFieldPtr .r8 binding.layout binding.layout.keyOff
    | none =>
        #[
          .comment s!"solana.cpi.account_meta {account.name} placeholder"
        ] ++
        stackPtr .r8 pubkeyOffset
  stackPtr .r7 cpiAccountMetaOffset ++ #[
    .instruction { opcode := .add64, dst := some .r7, imm := some (.num metaOffset) }
  ] ++ pubkeyPtr ++ #[
    storeReg .stxdw .r7 0 .r8,
    storeImm .stb .r7 8 (cpiAccountWritable account),
    storeImm .stb .r7 9 (cpiAccountSigner account)
  ]

def lowerCpiAccountMetas (bindings : Array CpiAccountBinding) (cpi : CpiInvoke) : Array AstNode :=
  cpi.accounts.mapIdx (lowerCpiAccountMeta bindings)
    |>.foldl (fun acc nodes => acc ++ nodes) #[]

def lowerCpiAccountInfoFallback (idx : Nat) (account : AccountMeta) : Array AstNode :=
  let infoOffset := idx * 56
  let pubkeyOffset := cpiPlaceholderPubkeyOffset + idx * 32
  let lamportsOffset := cpiPlaceholderLamportsOffset + idx * 8
  #[
    .comment s!"solana.cpi.account_info {account.name} placeholder"
  ] ++
  stackPtr .r6 cpiAccountInfoOffset ++ #[
    .instruction { opcode := .add64, dst := some .r6, imm := some (.num infoOffset) }
  ] ++
  stackPtr .r8 pubkeyOffset ++ #[
    storeReg .stxdw .r6 0 .r8
  ] ++
  stackPtr .r8 lamportsOffset ++ #[
    storeReg .stxdw .r6 8 .r8,
    zeroStackQuad .r6 16,
    zeroStackQuad .r6 24
  ] ++
  stackPtr .r8 cpiProgramIdOffset ++ #[
    storeReg .stxdw .r6 32 .r8,
    zeroStackQuad .r6 40,
    storeImm .stb .r6 48 (cpiAccountSigner account),
    storeImm .stb .r6 49 (cpiAccountWritable account),
    storeImm .stb .r6 50 0
  ]

def lowerCpiAccountInfoBound (idx : Nat) (account : AccountMeta)
    (binding : CpiAccountBinding) : Array AstNode :=
  let infoOffset := idx * 56
  let layout := binding.layout
  #[
    .comment s!"solana.cpi.account_info {account.name} account[{layout.index}]"
  ] ++
  stackPtr .r6 cpiAccountInfoOffset ++ #[
    .instruction { opcode := .add64, dst := some .r6, imm := some (.num infoOffset) }
  ] ++
  inputAccountFieldPtr .r8 layout layout.keyOff ++ #[
    storeReg .stxdw .r6 0 .r8
  ] ++
  inputAccountFieldPtr .r8 layout layout.lamportsOff ++ #[
    storeReg .stxdw .r6 8 .r8
  ] ++
  inputAccountFieldPtr .r8 layout layout.dataLenOff ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r8, off := some (.num 0) },
    storeReg .stxdw .r6 16 .r3
  ] ++
  inputAccountFieldPtr .r8 layout layout.dataStart ++ #[
    storeReg .stxdw .r6 24 .r8
  ] ++
  inputAccountFieldPtr .r8 layout layout.ownerOff ++ #[
    storeReg .stxdw .r6 32 .r8
  ] ++
  inputAccountFieldPtr .r8 layout layout.rentEpochOff ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r8, off := some (.num 0) },
    storeReg .stxdw .r6 40 .r3
  ] ++
  inputAccountFieldPtr .r8 layout layout.signerOff ++ #[
    .instruction { opcode := .ldxb, dst := some .r3, src := some .r8, off := some (.num 0) },
    storeReg .stxb .r6 48 .r3
  ] ++
  inputAccountFieldPtr .r8 layout layout.writableOff ++ #[
    .instruction { opcode := .ldxb, dst := some .r3, src := some .r8, off := some (.num 0) },
    storeReg .stxb .r6 49 .r3
  ] ++
  inputAccountFieldPtr .r8 layout layout.executableOff ++ #[
    .instruction { opcode := .ldxb, dst := some .r3, src := some .r8, off := some (.num 0) },
    storeReg .stxb .r6 50 .r3
  ]

def lowerCpiAccountInfo (bindings : Array CpiAccountBinding) (idx : Nat)
    (account : AccountMeta) : Array AstNode :=
  match cpiAccountBinding? bindings account.name with
  | some binding => lowerCpiAccountInfoBound idx account binding
  | none => lowerCpiAccountInfoFallback idx account

def lowerCpiAccountInfos (bindings : Array CpiAccountBinding) (cpi : CpiInvoke) : Array AstNode :=
  cpi.accounts.mapIdx (lowerCpiAccountInfo bindings)
    |>.foldl (fun acc nodes => acc ++ nodes) #[]

def lowerCpiU64Field (bindings : Array CpiValueBinding) (cpi : CpiInvoke)
    (metadataKey fieldName : String) (fieldOff : Nat) : Array AstNode :=
  match cpiMetadataValue? cpi metadataKey with
  | some source =>
      match source.toNat? with
      | some value =>
          #[
            .comment s!"solana.cpi.value {fieldName} literal={value}",
            loadImm .r3 value,
            storeReg .stxdw .r8 fieldOff .r3
          ]
      | none =>
          match cpiValueBinding? bindings source with
          | some binding =>
              let loadValue :=
                if binding.relativeToInstructionData then
                  loadSavedInstructionDataPtr .r7 ++ #[
                    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num binding.absOff) }
                  ]
                else
                  #[
                    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r1, off := some (.num binding.absOff) }
                  ]
              #[
                .comment s!"solana.cpi.value {fieldName} from {binding.sourceKind} {source}",
              ] ++ loadValue ++ #[
                storeReg .stxdw .r8 fieldOff .r3
              ]
          | none =>
              #[
                .comment s!"solana.cpi.value {fieldName} source={source} placeholder=0",
                loadImm .r3 0,
                storeReg .stxdw .r8 fieldOff .r3
              ]
  | none =>
      #[
        .comment s!"solana.cpi.value {fieldName} missing placeholder=0",
        loadImm .r3 0,
        storeReg .stxdw .r8 fieldOff .r3
      ]

def lowerCurrentProgramIdToData (fieldOff : Nat) : Array AstNode := #[
  .comment "solana.cpi.value owner=current_program_id",
] ++ loadCurrentProgramIdPtr .r7 .r3 ++ #[
  .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 0) },
  storeReg .stxdw .r8 fieldOff .r3,
  .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 8) },
  storeReg .stxdw .r8 (fieldOff + 8) .r3,
  .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 16) },
  storeReg .stxdw .r8 (fieldOff + 16) .r3,
  .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 24) },
  storeReg .stxdw .r8 (fieldOff + 24) .r3
]

def lowerAccountKeyToData (source : String) (layout : AccountInputLayout) (fieldOff : Nat) : Array AstNode :=
  #[
    .comment s!"solana.cpi.value owner from account {source}",
  ] ++
  inputAccountFieldPtr .r7 layout layout.keyOff ++ #[
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 0) },
    storeReg .stxdw .r8 fieldOff .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 8) },
    storeReg .stxdw .r8 (fieldOff + 8) .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 16) },
    storeReg .stxdw .r8 (fieldOff + 16) .r3,
    .instruction { opcode := .ldxdw, dst := some .r3, src := some .r7, off := some (.num 24) },
    storeReg .stxdw .r8 (fieldOff + 24) .r3
  ]

def lowerCpiOwnerField (accountBindings : Array CpiAccountBinding) (cpi : CpiInvoke)
    (fieldOff : Nat) : Array AstNode :=
  match cpiMetadataValue? cpi "solana.cpi.owner" with
  | some "program" => lowerCurrentProgramIdToData fieldOff
  | some source =>
      match cpiAccountBinding? accountBindings source with
      | some binding => lowerAccountKeyToData source binding.layout fieldOff
      | none =>
          #[
            .comment s!"solana.cpi.value owner source={source} placeholder=zero",
          ] ++ lowerZero32At .r8 fieldOff
  | none =>
      #[
        .comment "solana.cpi.value owner missing placeholder=zero",
      ] ++ lowerZero32At .r8 fieldOff

def lowerCpiSignerSeed (cpiName : String) (idx : Nat) (seed : String) : Array AstNode :=
  let seedOffset := cpiSignerSeedDataOffset + idx * cpiMaxSeedLen
  let tableOffset := cpiSignerSeedTableOffset + idx * 16
  let bytes := stringBytes seed
  #[
    .comment s!"solana.cpi.signer_seed {cpiName}[{idx}] \"{seed}\""
  ] ++
  stackPtr .r8 seedOffset ++
  lowerSeedBytes seed .r8 ++
  stackPtr .r7 tableOffset ++ #[
    storeReg .stxdw .r7 0 .r8,
    loadImm .r3 bytes.size,
    storeReg .stxdw .r7 8 .r3
  ]

def lowerCpiSignerSeeds (cpi : CpiInvoke) : Array AstNode :=
  if cpi.signerSeeds.isEmpty then
    #[
      .comment "solana.cpi.signer_seeds none"
    ]
  else
    let seedTable :=
      cpi.signerSeeds.mapIdx (fun idx seed => lowerCpiSignerSeed cpi.name idx seed)
        |>.foldl (fun acc nodes => acc ++ nodes) #[]
    seedTable ++
    stackPtr .r8 cpiSignerEntriesOffset ++
    stackPtr .r7 cpiSignerSeedTableOffset ++ #[
      storeReg .stxdw .r8 0 .r7,
      loadImm .r3 cpi.signerSeeds.size,
      storeReg .stxdw .r8 8 .r3
    ]

def lowerCpiSignerArgs (cpi : CpiInvoke) : Array AstNode :=
  if cpi.signerSeeds.isEmpty then
    #[
      loadImm .r4 0,
      loadImm .r5 0
    ]
  else
    stackPtr .r4 cpiSignerEntriesOffset ++ #[
      loadImm .r5 1
    ]

def lowerSystemTransferData (valueBindings : Array CpiValueBinding) (cpi : CpiInvoke) : Array AstNode :=
  #[
    .comment "solana.cpi.data system.transfer: u32 discriminator=2, u64 lamports"
  ] ++
  stackPtr .r8 cpiInstructionDataOffset ++ #[
    loadImm .r3 2,
    storeReg .stxw .r8 0 .r3
  ] ++
  lowerCpiU64Field valueBindings cpi "solana.cpi.lamports_source" "lamports" 4

def lowerSystemCreateAccountData (accountBindings : Array CpiAccountBinding)
    (valueBindings : Array CpiValueBinding) (cpi : CpiInvoke) : Array AstNode :=
  #[
    .comment "solana.cpi.data system.create_account: u32 discriminator=0, u64 lamports, u64 space, pubkey owner"
  ] ++
  stackPtr .r8 cpiInstructionDataOffset ++ #[
    loadImm .r3 0,
    storeReg .stxw .r8 0 .r3
  ] ++
  lowerCpiU64Field valueBindings cpi "solana.cpi.lamports_source" "lamports" 4 ++
  lowerCpiU64Field valueBindings cpi "solana.cpi.space_source" "space" 12 ++
  lowerCpiOwnerField accountBindings cpi 20

def cpiDecimals (cpi : CpiInvoke) : Nat :=
  match cpiMetadataValue? cpi "solana.cpi.decimals" with
  | some value => value.toNat?.getD 0
  | none => 0

def lowerSplTokenAmountData (valueBindings : Array CpiValueBinding)
    (cpi : CpiInvoke) (layoutName : String) (tag dataLen : Nat)
    (includeDecimals : Bool := false) : Array AstNode :=
  #[
    .comment (s!"solana.cpi.data {layoutName}: u8 instruction={tag}, u64 amount" ++
      (if includeDecimals then s!", u8 decimals={cpiDecimals cpi}" else ""))
  ] ++
  stackPtr .r8 cpiInstructionDataOffset ++ #[
    storeImm .stb .r8 0 tag
  ] ++
  lowerCpiU64Field valueBindings cpi "solana.cpi.amount_source" "amount" 1 ++
  (if includeDecimals then
    #[storeImm .stb .r8 (dataLen - 1) (cpiDecimals cpi)]
  else
    #[])

def lowerSplTokenRevokeData : Array AstNode :=
  #[
    .comment "solana.cpi.data spl-token.revoke: u8 instruction=5"
  ] ++
  stackPtr .r8 cpiInstructionDataOffset ++ #[
    storeImm .stb .r8 0 5
  ]

def lowerCpiInstructionData (accountBindings : Array CpiAccountBinding)
    (valueBindings : Array CpiValueBinding) (cpi : CpiInvoke) : Array AstNode × Nat :=
  match cpi.dataLayout? with
  | some "system.transfer" =>
      (lowerSystemTransferData valueBindings cpi, 12)
  | some "system.create_account" =>
      (lowerSystemCreateAccountData accountBindings valueBindings cpi, 52)
  | some "spl-token.transfer_checked" =>
      (lowerSplTokenAmountData valueBindings cpi "spl-token.transfer_checked" 12 10 true, 10)
  | some "spl-token.mint_to" =>
      (lowerSplTokenAmountData valueBindings cpi "spl-token.mint_to" 7 9, 9)
  | some "spl-token.burn" =>
      (lowerSplTokenAmountData valueBindings cpi "spl-token.burn" 8 9, 9)
  | some "spl-token.approve" =>
      (lowerSplTokenAmountData valueBindings cpi "spl-token.approve" 4 9, 9)
  | some "spl-token.revoke" =>
      (lowerSplTokenRevokeData, 1)
  | _ =>
      (#[
        .comment "generic CPI instruction data empty; protocol-specific ABI packing pending"
      ], 0)

def lowerCpiInstructionRecord (cpi : CpiInvoke) (dataLen : Nat) : Array AstNode :=
  #[
    .comment "solana.cpi.instruction record: C SolInstruction"
  ] ++
  stackPtr .r5 cpiInstructionOffset ++
  stackPtr .r8 cpiProgramIdOffset ++ #[
    storeReg .stxdw .r5 0 .r8
  ] ++
  stackPtr .r7 cpiAccountMetaOffset ++ #[
    storeReg .stxdw .r5 8 .r7,
    loadImm .r3 cpi.accounts.size,
    storeReg .stxdw .r5 16 .r3
  ] ++
  stackPtr .r8 cpiInstructionDataOffset ++ #[
    storeReg .stxdw .r5 24 .r8,
    loadImm .r3 dataLen,
    storeReg .stxdw .r5 32 .r3
  ]

def lowerCpiCall (cpi : CpiInvoke) : Array AstNode :=
  stackPtr .r1 cpiInstructionOffset ++
  stackPtr .r2 cpiAccountInfoOffset ++ #[
    loadImm .r3 cpi.accounts.size
  ] ++
  lowerCpiSignerArgs cpi ++ #[
    .comment "r1=instruction_ptr r2=account_infos_ptr r3=num_accounts r4=signer_seeds_ptr r5=num_signers",
    callSyscall ProofForge.Backend.Solana.Syscalls.sol_invoke_signed_c,
    .instruction { opcode := .jne, dst := some .r0, imm := some (.num 0), off := some (.sym "error_cpi") },
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
    .instruction { opcode := .exit }
  ]

def lowerSystemTransferCpi (accountBindings : Array CpiAccountBinding)
    (valueBindings : Array CpiValueBinding) (cpi : CpiInvoke) : Array AstNode :=
  let (dataNodes, dataLen) := lowerCpiInstructionData accountBindings valueBindings cpi
  #[
    .comment "solana.cpi.pack system.transfer"
  ] ++
  lowerAccountPtrTableSetup cpi.label accountBindings.size ++
  lowerCpiProgramId accountBindings cpi ++
  lowerCpiFallbackPlaceholders accountBindings cpi ++
  lowerCpiAccountMetas accountBindings cpi ++
  dataNodes ++
  lowerCpiInstructionRecord cpi dataLen ++
  lowerCpiAccountInfos accountBindings cpi ++
  lowerCpiSignerSeeds cpi ++
  lowerCpiCall cpi

def lowerGenericCpiInvoke (accountBindings : Array CpiAccountBinding)
    (valueBindings : Array CpiValueBinding) (cpi : CpiInvoke) : Array AstNode :=
  let (dataNodes, dataLen) := lowerCpiInstructionData accountBindings valueBindings cpi
  #[
    .comment "generic CPI C ABI packing"
  ] ++
  lowerAccountPtrTableSetup cpi.label accountBindings.size ++
  lowerCpiProgramId accountBindings cpi ++
  lowerCpiFallbackPlaceholders accountBindings cpi ++
  lowerCpiAccountMetas accountBindings cpi ++
  dataNodes ++
  lowerCpiInstructionRecord cpi dataLen ++
  lowerCpiAccountInfos accountBindings cpi ++
  lowerCpiSignerSeeds cpi ++
  lowerCpiCall cpi

def lowerCpiInvoke (accountBindings : Array CpiAccountBinding)
    (valueBindings : Array CpiValueBinding) (cpi : CpiInvoke) : Array AstNode :=
  #[
    .blankLine,
    .comment s!"solana.cpi {cpi.name}: {cpi.program}.{cpi.instruction}",
    .label cpi.label
  ] ++
  if cpi.protocol? == some "system" && cpi.dataLayout? == some "system.transfer" then
    lowerSystemTransferCpi accountBindings valueBindings cpi
  else
    lowerGenericCpiInvoke accountBindings valueBindings cpi

def lowerPdaAction (action : PdaAction) : Array AstNode :=
  #[
    .comment s!"solana.pda.action {action.name}"
  ] ++ callHelperPreservingInput (PdaDerive.label { name := action.name }) "error_pda"

def lowerCpiAction (action : CpiAction) : Array AstNode :=
  #[
    .comment s!"solana.cpi.action {action.name}"
  ] ++ callHelperPreservingInput (CpiInvoke.label {
    name := action.name
    program := ""
    instruction := ""
  }) "error_cpi"

def lowerEntrypointActions (extensions : ProgramExtensions) (entrypoint : String) : Array AstNode :=
  let pdaActions := extensions.pdaActions.filter (fun action => action.entrypoint == entrypoint)
  let cpiActions := extensions.cpiActions.filter (fun action => action.entrypoint == entrypoint)
  if pdaActions.isEmpty && cpiActions.isEmpty then
    #[]
  else
    #[.comment s!"Solana SDK target extension actions for {entrypoint}"] ++
    pdaActions.foldl (fun acc action => acc ++ lowerPdaAction action) #[] ++
    cpiActions.foldl (fun acc action => acc ++ lowerCpiAction action) #[]

def lowerExtensionErrors : Array AstNode := #[
  .blankLine,
  .label "error_pda",
  .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 7) },
  .instruction { opcode := .exit },
  .blankLine,
  .label "error_cpi",
  .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 8) },
  .instruction { opcode := .exit }
]

def lowerRuntimeAllocator (allocator : RuntimeAllocator) : Array AstNode := #[
  .blankLine,
  .comment s!"solana.allocator {allocator.name}: kind={allocator.kind} model={allocator.model} heap_start={allocator.heapStart} heap_bytes={allocator.heapBytes}"
]

def lowerRuntimeAllocators (extensions : ProgramExtensions) : Array AstNode :=
  extensions.allocators.foldl (fun acc allocator => acc ++ lowerRuntimeAllocator allocator) #[]

def lowerProgramExtensionsWithBindings
    (accountBindings : Array CpiAccountBinding) (valueBindings : Array CpiValueBinding)
    (extensions : ProgramExtensions) : Array AstNode :=
  if !hasExtensions extensions then
    #[]
  else if !hasSyscallExtensions extensions then
    #[.blankLine, .comment "Solana SDK target extension metadata"] ++
    lowerRuntimeAllocators extensions
  else
    #[.blankLine, .comment "Solana SDK target extension syscall helpers"] ++
    lowerRuntimeAllocators extensions ++
    extensions.pdas.foldl (fun acc pda => acc ++ lowerPdaDerive accountBindings valueBindings pda) #[] ++
    extensions.cpis.foldl (fun acc cpi => acc ++ lowerCpiInvoke accountBindings valueBindings cpi) #[] ++
    lowerExtensionErrors

def lowerProgramExtensionsWithAccountBindings
    (bindings : Array CpiAccountBinding) (extensions : ProgramExtensions) : Array AstNode :=
  lowerProgramExtensionsWithBindings bindings #[] extensions

def lowerProgramExtensions (extensions : ProgramExtensions) : Array AstNode :=
  lowerProgramExtensionsWithAccountBindings #[] extensions

def lowerPlan (plan : CapabilityPlan) : Array AstNode :=
  lowerProgramExtensions (ProgramExtensions.fromPlan plan)

end ProofForge.Backend.Solana.Extension
