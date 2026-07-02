/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Solana Instruction Manifest

Generate the `manifest.toml` sidecar that describes instruction dispatch tags
and account constraints for the `solana-sbpf-asm` target.

See `docs/targets/solana-sbpf-asm.md` (D-026).
-/

import ProofForge.IR.Contract

namespace ProofForge.Backend.Solana.Manifest

open ProofForge.IR

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

end ProofForge.Backend.Solana.Manifest