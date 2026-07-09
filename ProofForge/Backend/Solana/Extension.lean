import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Backend.Solana.Asm
import ProofForge.Backend.Solana.Extension.Common
import ProofForge.Backend.Solana.Extension.Cpi
import ProofForge.Backend.Solana.Extension.Helpers
import ProofForge.Backend.Solana.Extension.Parse
import ProofForge.Backend.Solana.Extension.Pda
import ProofForge.Backend.Solana.StateLayout
import ProofForge.Backend.Solana.Syscalls
import ProofForge.Target.Plan

namespace ProofForge.Backend.Solana.Extension

open ProofForge.Backend.Solana.Asm
open ProofForge.Backend.Solana.StateLayout
open ProofForge.Target

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

def lowerAccountReallocAction (action : AccountReallocAction) : Array AstNode :=
  #[
    .comment s!"solana.account.realloc.action {action.name}"
  ] ++ callHelperPreservingInput action.label "error_realloc"

def lowerTransferHookExtraAccountMetaListAction
    (action : TransferHookExtraAccountMetaListAction) : Array AstNode :=
  #[
    .comment s!"solana.transfer_hook.extra_account_meta_list.action {action.name}"
  ] ++ callHelperPreservingInput action.label "error_transfer_hook_extra_meta"

def lowerEntrypointActions (extensions : ProgramExtensions) (entrypoint : String) : Array AstNode :=
  let pdaActions := extensions.pdaActions.filter (fun action => action.entrypoint == entrypoint)
  let cpiActions := extensions.cpiActions.filter (fun action => action.entrypoint == entrypoint)
  let memoryActions := extensions.memoryActions.filter (fun action => action.entrypoint == entrypoint)
  let cryptoHashActions := extensions.cryptoHashActions.filter (fun action => action.entrypoint == entrypoint)
  let sysvarActions := extensions.sysvarActions.filter (fun action => action.entrypoint == entrypoint)
  let returnDataActions := extensions.returnDataActions.filter (fun action => action.entrypoint == entrypoint)
  let returnDataReadActions := extensions.returnDataReadActions.filter (fun action => action.entrypoint == entrypoint)
  let computeUnitsActions := extensions.computeUnitsActions.filter (fun action => action.entrypoint == entrypoint)
  let computeUnitsLogActions := extensions.computeUnitsLogActions.filter (fun action => action.entrypoint == entrypoint)
  let pubkeyLogActions := extensions.pubkeyLogActions.filter (fun action => action.entrypoint == entrypoint)
  let dataLogActions := extensions.dataLogActions.filter (fun action => action.entrypoint == entrypoint)
  let accountReallocActions := extensions.accountReallocActions.filter (fun action => action.entrypoint == entrypoint)
  let transferHookExtraAccountMetaListActions :=
    extensions.transferHookExtraAccountMetaListActions.filter (fun action => action.entrypoint == entrypoint)
  if pdaActions.isEmpty && cpiActions.isEmpty && memoryActions.isEmpty && cryptoHashActions.isEmpty &&
      sysvarActions.isEmpty && returnDataActions.isEmpty && returnDataReadActions.isEmpty &&
      computeUnitsActions.isEmpty && computeUnitsLogActions.isEmpty && pubkeyLogActions.isEmpty &&
      dataLogActions.isEmpty && accountReallocActions.isEmpty &&
      transferHookExtraAccountMetaListActions.isEmpty then
    #[]
  else
    #[.comment s!"Solana SDK target extension actions for {entrypoint}"] ++
    pdaActions.foldl (fun acc action => acc ++ lowerPdaAction action) #[] ++
    cpiActions.foldl (fun acc action => acc ++ lowerCpiAction action) #[] ++
    memoryActions.foldl (fun acc action => acc ++ lowerMemoryAction action) #[] ++
    cryptoHashActions.foldl (fun acc action => acc ++ lowerCryptoHashAction action) #[] ++
    sysvarActions.foldl (fun acc action => acc ++ lowerSysvarAction action) #[] ++
    returnDataActions.foldl (fun acc action => acc ++ lowerReturnDataAction action) #[] ++
    returnDataReadActions.foldl (fun acc action => acc ++ lowerReturnDataReadAction action) #[] ++
    computeUnitsActions.foldl (fun acc action => acc ++ lowerComputeUnitsAction action) #[] ++
    computeUnitsLogActions.foldl (fun acc action => acc ++ lowerComputeUnitsLogAction action) #[] ++
    pubkeyLogActions.foldl (fun acc action => acc ++ lowerPubkeyLogAction action) #[] ++
    dataLogActions.foldl (fun acc action => acc ++ lowerDataLogAction action) #[] ++
    accountReallocActions.foldl (fun acc action => acc ++ lowerAccountReallocAction action) #[] ++
    transferHookExtraAccountMetaListActions.foldl
      (fun acc action => acc ++ lowerTransferHookExtraAccountMetaListAction action) #[]

/-- Extension-only trap labels. `error_cpi` lives in `SbpfAsm.lowerModuleCoreWithSeed`
so portable crosscall materialization can jump to it without Source.Solana
extensions present (and so plan-driven modules do not emit the label twice). -/
def lowerExtensionErrors : Array AstNode := #[
  .blankLine,
  .label "error_pda",
  .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 7) },
  .instruction { opcode := .exit },
  .blankLine,
  .label "error_crypto",
  .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 11) },
  .instruction { opcode := .exit },
  .blankLine,
  .label "error_sysvar",
  .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 12) },
  .instruction { opcode := .exit },
  .blankLine,
  .label "error_realloc",
  .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 13) },
  .instruction { opcode := .exit },
  .blankLine,
  .label "error_transfer_hook_extra_meta",
  .instruction { opcode := .mov64, dst := some .r0, imm := some (.num 14) },
  .instruction { opcode := .exit }
]

def lowerRuntimeAllocator (allocator : RuntimeAllocator) : Array AstNode := #[
  .blankLine,
  .comment s!"solana.allocator {allocator.name}: kind={allocator.kind} model={allocator.model} heap_start={allocator.heapStart} heap_bytes={allocator.heapBytes}"
]

def lowerRuntimeAllocators (extensions : ProgramExtensions) : Array AstNode :=
  extensions.allocators.foldl (fun acc allocator => acc ++ lowerRuntimeAllocator allocator) #[]

/-- Preflight: PDA/CPI seeds must resolve — never silent zero seeds. -/
def validatePdaSeedBindings (accountBindings : Array CpiAccountBinding)
    (valueBindings : Array CpiValueBinding) (pda : PdaDerive) : Except String Unit := do
  for seed in pda.effectiveSeeds do
    match seed.kind with
    | .literal => pure ()
    | .account =>
        if (cpiAccountBinding? accountBindings seed.value).isNone then
          throw s!"Solana PDA `{pda.name}`: seed account `{seed.value}` is not bound in the account schema"
    | .bump =>
        match seed.value.toNat? with
        | some n =>
            if n >= 256 then
              throw s!"Solana PDA `{pda.name}`: bump literal {n} out of range (need 0..255)"
        | none =>
            if (cpiValueBinding? valueBindings seed.value).isNone then
              throw s!"Solana PDA `{pda.name}`: bump source `{seed.value}` is not bound (declare it as an entry param)"
    | .instructionParam =>
        if (cpiValueBinding? valueBindings seed.value).isNone then
          throw s!"Solana PDA `{pda.name}`: instruction-param seed `{seed.value}` is not bound (declare it as an entry param)"
  match pda.account? with
  | none => pure ()
  | some acc =>
      if (cpiAccountBinding? accountBindings acc).isNone then
        throw s!"Solana PDA `{pda.name}`: result account `{acc}` is not bound"

def validateCpiSignerSeedBindings (accountBindings : Array CpiAccountBinding)
    (valueBindings : Array CpiValueBinding) (cpi : CpiInvoke) : Except String Unit := do
  for raw in cpi.signerSeeds do
    let seed := parsePdaSeed raw
    match seed.kind with
    | .literal => pure ()
    | .account =>
        if (cpiAccountBinding? accountBindings seed.value).isNone then
          throw s!"Solana CPI `{cpi.name}`: signer seed account `{seed.value}` is not bound"
    | .bump =>
        match seed.value.toNat? with
        | some n =>
            if n >= 256 then
              throw s!"Solana CPI `{cpi.name}`: signer bump literal {n} out of range"
        | none =>
            if (cpiValueBinding? valueBindings seed.value).isNone then
              throw s!"Solana CPI `{cpi.name}`: signer bump `{seed.value}` is not bound (declare it as an entry param)"
    | .instructionParam =>
        if (cpiValueBinding? valueBindings seed.value).isNone then
          throw s!"Solana CPI `{cpi.name}`: signer instruction-param `{seed.value}` is not bound (declare it as an entry param)"

/-- Named CPI value sources (amount_source, etc.) must resolve to entry/state bindings. -/
def validateCpiValueSources (valueBindings : Array CpiValueBinding) (cpi : CpiInvoke) :
    Except String Unit := do
  for key in #["solana.cpi.amount_source", "solana.cpi.lamports_source", "solana.cpi.fee_source"] do
    match metadataValue? cpi.metadata key with
    | none => pure ()
    | some source =>
        if source.toNat?.isSome then pure ()
        else if (cpiValueBinding? valueBindings source).isNone then
          throw s!"Solana CPI `{cpi.name}`: value source `{source}` ({key}) is not bound (declare it as an entry param)"

def validateProgramExtensionBindings (accountBindings : Array CpiAccountBinding)
    (valueBindings : Array CpiValueBinding) (extensions : ProgramExtensions) :
    Except String Unit := do
  for pda in extensions.pdas do
    validatePdaSeedBindings accountBindings valueBindings pda
  for cpi in extensions.cpis do
    validateCpiSignerSeedBindings accountBindings valueBindings cpi
    validateCpiValueSources valueBindings cpi

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
    (uniqueMemoryHelpers extensions).foldl (fun acc action => acc ++ lowerMemoryHelper valueBindings action) #[] ++
    (uniqueCryptoHashHelpers extensions).foldl (fun acc action => acc ++ lowerCryptoHashHelper valueBindings action) #[] ++
    (uniqueSysvarHelpers extensions).foldl (fun acc action => acc ++ lowerSysvarHelper valueBindings action) #[] ++
    (uniqueReturnDataHelpers extensions).foldl (fun acc action => acc ++ lowerReturnDataHelper valueBindings action) #[] ++
    (uniqueReturnDataReadHelpers extensions).foldl (fun acc action => acc ++ lowerReturnDataReadHelper valueBindings action) #[] ++
    (uniqueComputeUnitsHelpers extensions).foldl (fun acc action => acc ++ lowerComputeUnitsHelper valueBindings action) #[] ++
    (uniqueComputeUnitsLogHelpers extensions).foldl (fun acc action => acc ++ lowerComputeUnitsLogHelper action) #[] ++
    (uniquePubkeyLogHelpers extensions).foldl (fun acc action => acc ++ lowerPubkeyLogHelper accountBindings action) #[] ++
    (uniqueDataLogHelpers extensions).foldl (fun acc action => acc ++ lowerDataLogHelper valueBindings action) #[] ++
    (uniqueAccountReallocHelpers extensions).foldl (fun acc action => acc ++ lowerAccountReallocHelper accountBindings action) #[] ++
    extensions.transferHookExtraAccountMetaListActions.foldl
      (fun acc action => acc ++ lowerTransferHookExtraAccountMetaListHelper accountBindings action) #[] ++
    lowerExtensionErrors

/-- Like `lowerProgramExtensionsWithBindings`, but preflight-rejects unresolved
PDA/CPI seed bindings (never silent zero-seed codegen). -/
def lowerProgramExtensionsWithBindingsChecked
    (accountBindings : Array CpiAccountBinding) (valueBindings : Array CpiValueBinding)
    (extensions : ProgramExtensions) : Except String (Array AstNode) := do
  validateProgramExtensionBindings accountBindings valueBindings extensions
  pure (lowerProgramExtensionsWithBindings accountBindings valueBindings extensions)

def lowerProgramExtensionsWithAccountBindings
    (bindings : Array CpiAccountBinding) (extensions : ProgramExtensions) : Array AstNode :=
  lowerProgramExtensionsWithBindings bindings #[] extensions

def lowerProgramExtensions (extensions : ProgramExtensions) : Array AstNode :=
  lowerProgramExtensionsWithAccountBindings #[] extensions

def lowerPlan (plan : CapabilityPlan) : Array AstNode :=
  lowerProgramExtensions (ProgramExtensions.fromPlan plan)

end ProofForge.Backend.Solana.Extension
