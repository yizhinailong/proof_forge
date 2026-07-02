/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Solana Instruction Manifest

Generate the `manifest.toml` sidecar that describes instruction dispatch tags
and account constraints for the `solana-sbpf-asm` target.

See `docs/targets/solana-sbpf-asm.md` (D-026).
-/

import ProofForge.IR.Contract
import ProofForge.Target.Plan
import ProofForge.Backend.Solana.Extension

namespace ProofForge.Backend.Solana.Manifest

open ProofForge.IR
open ProofForge.Backend.Solana.Extension

/-- A single account entry in the instruction manifest. -/
structure AccountEntry where
  name : String
  index : Nat
  signer : Bool
  writable : Bool
  owner : String
  deriving Repr, Inhabited

/-- A scalar instruction parameter in the Solana instruction-data ABI.
Offset is relative to the start of `instruction_data`; byte 0 is reserved for
the ProofForge entrypoint tag. -/
structure InstructionParamEntry where
  name : String
  typeName : String
  offset : Nat
  byteSize : Nat
  encoding : String
  deriving Repr, Inhabited

/-- One instruction table entry. -/
structure InstructionEntry where
  name : String
  tag : Nat
  handler : String
  accounts : Array AccountEntry
  params : Array InstructionParamEntry := #[]
  minDataLen : Nat := 1
  deriving Repr, Inhabited

def AccountEntry.render (a : AccountEntry) : String :=
  "  { name = \"" ++ a.name ++ "\", index = " ++ toString a.index ++
  ", signer = " ++ toString a.signer ++ ", writable = " ++ toString a.writable ++
  ", owner = \"" ++ a.owner ++ "\" }"

def tomlString (value : String) : String :=
  let escapeChar : Char → String
    | '"' => "\\\""
    | '\\' => "\\\\"
    | '\n' => "\\n"
    | '\r' => "\\r"
    | '\t' => "\\t"
    | ch => ch.toString
  "\"" ++ String.intercalate "" (value.toList.map escapeChar) ++ "\""

def instructionParamByteSize? : ValueType → Option Nat
  | .u64 => some 8
  | .u32 => some 4
  | .bool => some 1
  | _ => none

def instructionParamEncoding : ValueType → String
  | .u64 => "le-u64"
  | .u32 => "le-u32"
  | .bool => "u8-bool"
  | _ => "unsupported"

def buildInstructionParams (ep : Entrypoint) : Array InstructionParamEntry := Id.run do
  let mut params := #[]
  let mut payloadOff := 1
  for param in ep.params do
    let (name, type) := param
    let byteSize := (instructionParamByteSize? type).getD 0
    params := params.push {
      name := name
      typeName := type.name
      offset := payloadOff
      byteSize := byteSize
      encoding := instructionParamEncoding type
    }
    payloadOff := payloadOff + byteSize
  return params

def instructionParamPayloadSize (ep : Entrypoint) : Nat :=
  (buildInstructionParams ep).foldl (fun acc param => acc + param.byteSize) 0

def instructionDataMinLen (ep : Entrypoint) : Nat :=
  1 + instructionParamPayloadSize ep

def InstructionParamEntry.render (param : InstructionParamEntry) : String :=
  "  { name = " ++ tomlString param.name ++
  ", type = " ++ tomlString param.typeName ++
  ", offset = " ++ toString param.offset ++
  ", byte_size = " ++ toString param.byteSize ++
  ", encoding = " ++ tomlString param.encoding ++ " }"

def InstructionEntry.render (ie : InstructionEntry) : String :=
  let accountLines := ie.accounts.mapIdx fun idx account =>
    AccountEntry.render account ++
      (if idx + 1 == ie.accounts.size then "" else ",")
  let accountsBlock :=
    if accountLines.isEmpty then "accounts = []"
    else "accounts = [\n" ++ String.intercalate "\n" accountLines.toList ++ "\n]"
  let paramLines := ie.params.mapIdx fun idx param =>
    InstructionParamEntry.render param ++
      (if idx + 1 == ie.params.size then "" else ",")
  let paramsBlock :=
    if paramLines.isEmpty then "params = []"
    else "params = [\n" ++ String.intercalate "\n" paramLines.toList ++ "\n]"
  "[[instruction]]\n" ++
  "name = \"" ++ ie.name ++ "\"\n" ++
  "tag = " ++ toString ie.tag ++ "\n" ++
  "handler = \"" ++ ie.handler ++ "\"\n" ++
  "min_data_len = " ++ toString ie.minDataLen ++ "\n" ++
  accountsBlock ++ "\n" ++
  paramsBlock

def defaultStateAccountName (module : Module) : String :=
  match module.state[0]? with
  | some state => state.id
  | none => "data"

def defaultStateAccount (module : Module) : AccountEntry := {
  name := defaultStateAccountName module
  index := 0
  signer := false
  writable := true
  owner := "program"
}

def mergeOwner (existing incoming : String) : String :=
  if existing == incoming then
    existing
  else if existing == "any" then
    incoming
  else if incoming == "any" then
    existing
  else
    existing

def AccountEntry.merge (existing incoming : AccountEntry) : AccountEntry := {
  existing with
  signer := existing.signer || incoming.signer
  writable := existing.writable || incoming.writable
  owner := mergeOwner existing.owner incoming.owner
}

def pushAccount (accounts : Array AccountEntry) (account : AccountEntry) : Array AccountEntry :=
  if accounts.any (fun existing => existing.name == account.name) then
    accounts.map fun existing =>
      if existing.name == account.name then
        existing.merge account
      else
        existing
  else
    accounts.push { account with index := accounts.size }

def pdaInstructionAccount (pda : PdaDerive) : AccountEntry := {
  name := pda.account?.getD pda.name
  index := 0
  signer := false
  writable := true
  owner := "program"
}

def cpiInstructionSigner (account : AccountMeta) : Bool :=
  account.signer == "signer"

def cpiInstructionAccount (account : AccountMeta) : AccountEntry := {
  name := account.name
  index := 0
  signer := cpiInstructionSigner account
  writable := account.access == "writable"
  owner := "any"
}

def cpiProgramAccount (cpi : CpiInvoke) : AccountEntry := {
  name := cpi.program
  index := 0
  signer := false
  writable := false
  owner := "executable"
}

def pdaByName? (extensions : ProgramExtensions) (name : String) : Option PdaDerive :=
  extensions.pdas.find? (fun pda => pda.name == name)

def cpiByName? (extensions : ProgramExtensions) (name : String) : Option CpiInvoke :=
  extensions.cpis.find? (fun cpi => cpi.name == name)

def pushEntrypointPdaAccounts (extensions : ProgramExtensions) (entrypoint : String)
    (accounts : Array AccountEntry) : Array AccountEntry :=
  extensions.pdaActions.foldl
    (fun accounts action =>
      if action.entrypoint == entrypoint then
        match pdaByName? extensions action.name with
        | some pda => pushAccount accounts (pdaInstructionAccount pda)
        | none => accounts
      else
        accounts)
    accounts

def pushEntrypointCpiAccounts (extensions : ProgramExtensions) (entrypoint : String)
    (accounts : Array AccountEntry) : Array AccountEntry :=
  extensions.cpiActions.foldl
    (fun accounts action =>
      if action.entrypoint == entrypoint then
        match cpiByName? extensions action.name with
        | some cpi =>
            let accounts :=
              cpi.accounts.foldl
                (fun accounts account => pushAccount accounts (cpiInstructionAccount account))
                accounts
            pushAccount accounts (cpiProgramAccount cpi)
        | none => accounts
      else
        accounts)
    accounts

def pushCpiAccounts (accounts : Array AccountEntry) (cpi : CpiInvoke) : Array AccountEntry :=
  let accounts :=
    cpi.accounts.foldl
      (fun accounts account => pushAccount accounts (cpiInstructionAccount account))
      accounts
  pushAccount accounts (cpiProgramAccount cpi)

def buildInstructionAccounts (module : Module) (extensions : ProgramExtensions)
    (entrypoint : String) : Array AccountEntry :=
  let accounts := pushAccount #[] (defaultStateAccount module)
  let accounts := pushEntrypointPdaAccounts extensions entrypoint accounts
  pushEntrypointCpiAccounts extensions entrypoint accounts

def buildModuleAccounts (module : Module) (extensions : ProgramExtensions) : Array AccountEntry :=
  let accounts := pushAccount #[] (defaultStateAccount module)
  let accounts :=
    extensions.pdas.foldl
      (fun accounts pda => pushAccount accounts (pdaInstructionAccount pda))
      accounts
  extensions.cpis.foldl pushCpiAccounts accounts

def tomlBool (value : Bool) : String :=
  if value then "true" else "false"

def tomlStringArray (values : Array String) : String :=
  "[" ++ String.intercalate ", " (values.toList.map tomlString) ++ "]"

def renderPdaSeed (seed : PdaSeed) : String :=
  "  { kind = " ++ tomlString seed.kind.id ++
  ", value = " ++ tomlString seed.value ++ " }"

def renderPdaSeeds (seeds : Array PdaSeed) : String :=
  if seeds.isEmpty then
    "[]"
  else
    "[\n" ++ String.intercalate ",\n" (seeds.toList.map renderPdaSeed) ++ "\n]"

def renderExtensionAccount (account : AccountMeta) : String :=
  "  { name = " ++ tomlString account.name ++
  ", access = " ++ tomlString account.access ++
  ", signer = " ++ tomlString account.signer ++ " }"

def renderCpiMetadataField (cpi : CpiInvoke) (metadataKey tomlKey : String) : String :=
  match metadataValue? cpi.metadata metadataKey with
  | some value => s!"{tomlKey} = {tomlString value}\n"
  | none => ""

def renderAllocator (allocator : RuntimeAllocator) : String :=
  "[[solana.allocator]]\n" ++
  "name = " ++ tomlString allocator.name ++ "\n" ++
  "kind = " ++ tomlString allocator.kind ++ "\n" ++
  "model = " ++ tomlString allocator.model ++ "\n" ++
  "heap_start = " ++ tomlString allocator.heapStart ++ "\n" ++
  "heap_bytes = " ++ allocator.heapBytes ++ "\n"

def renderPda (pda : PdaDerive) : String :=
  let optionalFields :=
    (match pda.bump? with
    | some bump => s!"bump = {tomlString bump}\n"
    | none => "") ++
    (match pda.account? with
    | some account => s!"account = {tomlString account}\n"
    | none => "")
  "[[solana.pda]]\n" ++
  "name = " ++ tomlString pda.name ++ "\n" ++
  "seeds = " ++ tomlStringArray pda.seedValues ++ "\n" ++
  "typed_seeds = " ++ renderPdaSeeds pda.effectiveSeeds ++ "\n" ++
  optionalFields ++
  "signer = " ++ tomlBool pda.signer ++ "\n"

def renderCpi (cpi : CpiInvoke) : String :=
  let accountLines := cpi.accounts.mapIdx fun idx account =>
    renderExtensionAccount account ++
      (if idx + 1 == cpi.accounts.size then "" else ",")
  let accountsBlock :=
    if accountLines.isEmpty then
      "accounts = []"
    else
      "accounts = [\n" ++ String.intercalate "\n" accountLines.toList ++ "\n]"
  let optionalFields :=
    (match cpi.protocol? with
    | some protocol => s!"protocol = {tomlString protocol}\n"
    | none => "") ++
    (match cpi.dataLayout? with
    | some dataLayout => s!"data_layout = {tomlString dataLayout}\n"
    | none => "") ++
    renderCpiMetadataField cpi "solana.cpi.lamports_source" "lamports_source" ++
    renderCpiMetadataField cpi "solana.cpi.space_source" "space_source" ++
    renderCpiMetadataField cpi "solana.cpi.owner" "owner_source" ++
    renderCpiMetadataField cpi "solana.cpi.amount_source" "amount_source" ++
    renderCpiMetadataField cpi "solana.cpi.decimals" "decimals"
  "[[solana.cpi]]\n" ++
  "name = " ++ tomlString cpi.name ++ "\n" ++
  "program = " ++ tomlString cpi.program ++ "\n" ++
  "instruction = " ++ tomlString cpi.instruction ++ "\n" ++
  "signed = " ++ tomlBool cpi.signed ++ "\n" ++
  accountsBlock ++ "\n" ++
  "signer_seeds = " ++ tomlStringArray cpi.signerSeeds ++ "\n" ++
  optionalFields

def renderPdaAction (action : PdaAction) : String :=
  "[[solana.entrypoint_pda]]\n" ++
  "entrypoint = " ++ tomlString action.entrypoint ++ "\n" ++
  "pda = " ++ tomlString action.name ++ "\n"

def renderCpiAction (action : CpiAction) : String :=
  "[[solana.entrypoint_cpi]]\n" ++
  "entrypoint = " ++ tomlString action.entrypoint ++ "\n" ++
  "cpi = " ++ tomlString action.name ++ "\n"

def renderActions (extensions : ProgramExtensions) : String :=
  if !hasEntrypointActions extensions then
    ""
  else
    "\n# Solana SDK entrypoint actions\n" ++
    String.intercalate "\n" (extensions.pdaActions.map renderPdaAction).toList ++
    (if extensions.pdaActions.size > 0 && extensions.cpiActions.size > 0 then "\n" else "") ++
    String.intercalate "\n" (extensions.cpiActions.map renderCpiAction).toList

def renderExtensions (extensions : ProgramExtensions) : String :=
  if !hasExtensions extensions then
    ""
  else
    "\n# Solana SDK target extension metadata\n" ++
    String.intercalate "\n" (extensions.allocators.map renderAllocator).toList ++
    (if extensions.allocators.size > 0 && (extensions.pdas.size > 0 || extensions.cpis.size > 0) then "\n" else "") ++
    String.intercalate "\n" (extensions.pdas.map renderPda).toList ++
    (if extensions.pdas.size > 0 && extensions.cpis.size > 0 then "\n" else "") ++
    String.intercalate "\n" (extensions.cpis.map renderCpi).toList ++
    renderActions extensions

/-- Default account schema for portable IR modules without Solana SDK target
extensions: a single writable account owned by the current program. -/
def buildDefaultAccounts (module : Module) : Array AccountEntry :=
  #[defaultStateAccount module]

/-- Build instruction entries from the IR module. -/
def buildInstructions (module : Module) : Array InstructionEntry :=
  let accounts := buildDefaultAccounts module
  module.entrypoints.mapIdx fun idx ep =>
    {
      name := ep.name
      tag := idx
      handler := "sol_" ++ ep.name
      accounts := accounts
      params := buildInstructionParams ep
      minDataLen := instructionDataMinLen ep
    }

def buildInstructionsWithExtensions (module : Module) (extensions : ProgramExtensions) :
    Array InstructionEntry :=
  -- The current dispatcher still uses a fixed instruction-data offset, so SDK
  -- modules use the union of all declared accounts for every entrypoint.
  let accounts := buildModuleAccounts module extensions
  module.entrypoints.mapIdx fun idx ep =>
    {
      name := ep.name
      tag := idx
      handler := "sol_" ++ ep.name
      accounts := accounts
      params := buildInstructionParams ep
      minDataLen := instructionDataMinLen ep
    }

def buildInstructionsWithPlan (module : Module) (plan : ProofForge.Target.CapabilityPlan) :
    Array InstructionEntry :=
  buildInstructionsWithExtensions module (ProgramExtensions.fromPlan plan)

def renderManifestWithInstructions (module : Module) (instructions : Array InstructionEntry) : String :=
  let programName := module.name.toLower
  let instructionBlocks := instructions.map InstructionEntry.render
  String.intercalate "\n" #[
    "# ProofForge generated Solana instruction manifest",
    "target = \"solana-sbpf-asm\"",
    "",
    "[program]",
    "id = \"REPLACE_WITH_PROGRAM_ID\"",
    "name = \"" ++ programName ++ "\"",
    ""
  ].toList ++ "\n" ++ String.intercalate "\n\n" instructionBlocks.toList

/-- Render the full manifest.toml contents. -/
def renderManifest (module : Module) : String :=
  renderManifestWithInstructions module (buildInstructions module)

def renderManifestWithPlan (module : Module) (plan : ProofForge.Target.CapabilityPlan) : String :=
  let extensions := ProgramExtensions.fromPlan plan
  renderManifestWithInstructions module (buildInstructionsWithExtensions module extensions) ++
    renderExtensions extensions

end ProofForge.Backend.Solana.Manifest
