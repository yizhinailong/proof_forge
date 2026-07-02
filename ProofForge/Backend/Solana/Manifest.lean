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

/-- One instruction table entry. -/
structure InstructionEntry where
  name : String
  tag : Nat
  handler : String
  accounts : Array AccountEntry
  deriving Repr, Inhabited

def AccountEntry.render (a : AccountEntry) : String :=
  "  { name = \"" ++ a.name ++ "\", index = " ++ toString a.index ++
  ", signer = " ++ toString a.signer ++ ", writable = " ++ toString a.writable ++
  ", owner = \"" ++ a.owner ++ "\" }"

def InstructionEntry.render (ie : InstructionEntry) : String :=
  let accountLines := ie.accounts.map AccountEntry.render
  let accountsBlock :=
    if accountLines.isEmpty then "accounts = []"
    else "accounts = [\n" ++ String.intercalate "\n" accountLines.toList ++ "\n]"
  "[[instruction]]\n" ++
  "name = \"" ++ ie.name ++ "\"\n" ++
  "tag = " ++ toString ie.tag ++ "\n" ++
  "handler = \"" ++ ie.handler ++ "\"\n" ++
  accountsBlock ++ "\n"

def tomlString (value : String) : String :=
  let escapeChar : Char → String
    | '"' => "\\\""
    | '\\' => "\\\\"
    | '\n' => "\\n"
    | '\r' => "\\r"
    | '\t' => "\\t"
    | ch => ch.toString
  "\"" ++ String.intercalate "" (value.toList.map escapeChar) ++ "\""

def tomlBool (value : Bool) : String :=
  if value then "true" else "false"

def tomlStringArray (values : Array String) : String :=
  "[" ++ String.intercalate ", " (values.toList.map tomlString) ++ "]"

def renderExtensionAccount (account : AccountMeta) : String :=
  "  { name = " ++ tomlString account.name ++
  ", access = " ++ tomlString account.access ++
  ", signer = " ++ tomlString account.signer ++ " }"

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
  "seeds = " ++ tomlStringArray pda.seeds ++ "\n" ++
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
    match cpi.dataLayout? with
    | some dataLayout => s!"data_layout = {tomlString dataLayout}\n"
    | none => ""
  "[[solana.cpi]]\n" ++
  "name = " ++ tomlString cpi.name ++ "\n" ++
  "program = " ++ tomlString cpi.program ++ "\n" ++
  "instruction = " ++ tomlString cpi.instruction ++ "\n" ++
  "signed = " ++ tomlBool cpi.signed ++ "\n" ++
  accountsBlock ++ "\n" ++
  "signer_seeds = " ++ tomlStringArray cpi.signerSeeds ++ "\n" ++
  optionalFields

def renderExtensions (extensions : ProgramExtensions) : String :=
  if !hasExtensions extensions then
    ""
  else
    "\n# Solana SDK target extension metadata\n" ++
    String.intercalate "\n" (extensions.pdas.map renderPda).toList ++
    (if extensions.pdas.size > 0 && extensions.cpis.size > 0 then "\n" else "") ++
    String.intercalate "\n" (extensions.cpis.map renderCpi).toList

/-- Phase 1 default: every instruction uses a single writable account owned by
 the program, with signer=false. Multi-account schemas will move into the
IR/source layer in Phase 2+. -/
def buildDefaultAccounts (module : Module) : Array AccountEntry :=
  let defaultName := match module.state[0]? with | some s => s.id | none => "data"
  #[{ name := defaultName, index := 0, signer := false, writable := true, owner := "program" }]

/-- Build instruction entries from the IR module. -/
def buildInstructions (module : Module) : Array InstructionEntry :=
  let accounts := buildDefaultAccounts module
  module.entrypoints.mapIdx fun idx ep =>
    { name := ep.name, tag := idx, handler := "sol_" ++ ep.name, accounts := accounts }

/-- Render the full manifest.toml contents. -/
def renderManifest (module : Module) : String :=
  let programName := module.name.toLower
  let instructionBlocks := (buildInstructions module).map InstructionEntry.render
  String.intercalate "\n" #[
    "# ProofForge generated Solana instruction manifest",
    "target = \"solana-sbpf-asm\"",
    "",
    "[program]",
    "id = \"REPLACE_WITH_PROGRAM_ID\"",
    "name = \"" ++ programName ++ "\"",
    ""
  ].toList ++ "\n" ++ String.intercalate "\n" instructionBlocks.toList ++ "\n"

def renderManifestWithPlan (module : Module) (plan : ProofForge.Target.CapabilityPlan) : String :=
  renderManifest module ++ renderExtensions (ProgramExtensions.fromPlan plan)

end ProofForge.Backend.Solana.Manifest
