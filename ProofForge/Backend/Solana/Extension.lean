import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Backend.Solana.Asm
import ProofForge.Backend.Solana.Syscalls
import ProofForge.Target.Plan

namespace ProofForge.Backend.Solana.Extension

open ProofForge.Backend.Solana.Asm
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

structure CpiInvoke where
  name : String
  program : String
  instruction : String
  accounts : Array AccountMeta := #[]
  signerSeeds : Array String := #[]
  dataLayout? : Option String := none
  signed : Bool := false
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
  pdas : Array PdaDerive := #[]
  cpis : Array CpiInvoke := #[]
  pdaActions : Array PdaAction := #[]
  cpiActions : Array CpiAction := #[]
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
  { cpi with entrypoint? := none }

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

def pdaFromCall? (call : CapabilityCall) : Option PdaDerive :=
  if call.operation == "solana.pda.derive" then
    let name := metadataValue? call.metadata "solana.pda.name" |>.getD call.operation
    some {
      name := name
      seeds := metadataValue? call.metadata "solana.pda.seeds" |>.map splitComma |>.getD #[]
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
      dataLayout? := metadataValue? call.metadata "solana.cpi.data_layout"
      signed := call.operation == "solana.cpi.invoke_signed"
      entrypoint? := entrypoint? call
    }
  else
    none

def ProgramExtensions.fromPlan (plan : CapabilityPlan) : ProgramExtensions :=
  plan.calls.foldl
    (fun acc call =>
      let acc :=
        match pdaFromCall? call with
        | some pda => acc.addPda pda
        | none => acc
      match cpiFromCall? call with
      | some cpi => acc.addCpi cpi
      | none => acc)
    {}

def hasExtensions (extensions : ProgramExtensions) : Bool :=
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

def entryInputSaveOffset : Nat := 1024

def pdaResultOffset : Nat := 64
def pdaSeedTableOffset : Nat := 128
def pdaSeedDataOffset : Nat := 512
def pdaMaxSeedLen : Nat := 32
def pdaMaxSeeds : Nat := 16

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

def lowerPdaStaticSeed (pdaName : String) (idx : Nat) (seed : String) : Array AstNode :=
  let seedOffset := pdaSeedDataOffset + idx * pdaMaxSeedLen
  let tableOffset := pdaSeedTableOffset + idx * 16
  let bytes := stringBytes seed
  #[
    .comment s!"solana.pda.seed {pdaName}[{idx}] \"{seed}\"",
  ] ++
  stackPtr .r5 seedOffset ++
  lowerSeedBytes seed .r5 ++
  stackPtr .r6 tableOffset ++ #[
    .instruction { opcode := .stxdw, dst := some .r6, off := some (.num 0), src := some .r5 },
    .instruction { opcode := .mov64, dst := some .r3, imm := some (.num bytes.size) },
    .instruction { opcode := .stxdw, dst := some .r6, off := some (.num 8), src := some .r3 }
  ]

def lowerPdaStaticSeeds (pda : PdaDerive) : Array AstNode :=
  pda.seeds.mapIdx (fun idx seed => lowerPdaStaticSeed pda.name idx seed)
    |>.foldl (fun acc nodes => acc ++ nodes) #[]

def callHelperPreservingInput (helperName errorLabel : String) : Array AstNode := #[
  .instruction { opcode := .stxdw, dst := some .r10, off := some (.num entryInputSaveOffset), src := some .r1 },
  callHelper helperName,
  .instruction { opcode := .ldxdw, dst := some .r1, src := some .r10, off := some (.num entryInputSaveOffset) },
  .instruction { opcode := .jne, dst := some .r0, imm := some (.num 0), off := some (.sym errorLabel) }
]

def lowerPdaDerive (pda : PdaDerive) : Array AstNode :=
  #[
    .blankLine,
    .comment s!"solana.pda.derive {pda.name}",
    .label pda.label,
    .instruction { opcode := .mov64, dst := some .r7, src := some .r1 },
    .comment "pack static ASCII PDA seed byte slices"
  ] ++
  lowerPdaStaticSeeds pda ++
  stackPtr .r1 pdaSeedTableOffset ++ #[
    .instruction { opcode := .mov64, dst := some .r2, imm := some (.num pda.seeds.size) },
    .instruction { opcode := .mov64, dst := some .r3, src := some .r7 },
    .instruction { opcode := .add64, dst := some .r3, imm := some (.sym "INSTRUCTION_DATA_LEN") },
    .instruction { opcode := .ldxdw, dst := some .r5, src := some .r3, off := some (.num 0) },
    .instruction { opcode := .add64, dst := some .r3, imm := some (.num 8) },
    .instruction { opcode := .add64, dst := some .r3, src := some .r5 }
  ] ++
  stackPtr .r4 pdaResultOffset ++ #[
    .comment "r1=seeds_ptr r2=seeds_len r3=program_id_ptr r4=result_ptr",
    callSyscall ProofForge.Backend.Solana.Syscalls.sol_create_program_address,
    .instruction { opcode := .jne, dst := some .r0, imm := some (.num 0), off := some (.sym "error_pda") },
    .comment s!"PDA result stored at stack offset {pdaResultOffset}",
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
    .instruction { opcode := .exit }
  ]

def lowerCpiInvoke (cpi : CpiInvoke) : Array AstNode :=
  #[
    .blankLine,
    .comment s!"solana.cpi {cpi.name}: {cpi.program}.{cpi.instruction}",
    .label cpi.label
  ] ++
  stackPtr .r1 256 ++
  stackPtr .r2 512 ++ #[
    .instruction { opcode := .mov64, dst := some .r3, imm := some (.num cpi.accounts.size) }
  ] ++
  stackPtr .r4 768 ++ #[
    .instruction { opcode := .mov64, dst := some .r5, imm := some (.num cpi.signerSeeds.size) },
    .comment "r1=instruction_ptr r2=account_infos_ptr r3=num_accounts r4=signer_seeds_ptr r5=num_seeds",
    callSyscall ProofForge.Backend.Solana.Syscalls.sol_invoke_signed_c,
    .instruction { opcode := .jne, dst := some .r0, imm := some (.num 0), off := some (.sym "error_cpi") },
    .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 0) },
    .instruction { opcode := .exit }
  ]

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

def lowerProgramExtensions (extensions : ProgramExtensions) : Array AstNode :=
  if !hasExtensions extensions then
    #[]
  else
    #[.blankLine, .comment "Solana SDK target extension syscall helpers"] ++
    extensions.pdas.foldl (fun acc pda => acc ++ lowerPdaDerive pda) #[] ++
    extensions.cpis.foldl (fun acc cpi => acc ++ lowerCpiInvoke cpi) #[] ++
    lowerExtensionErrors

def lowerPlan (plan : CapabilityPlan) : Array AstNode :=
  lowerProgramExtensions (ProgramExtensions.fromPlan plan)

end ProofForge.Backend.Solana.Extension
