import Init.Notation
import Lean
import Lean.Elab.Frontend
import Lean.Util.Path
import ProofForge

open Lean
open System

namespace ProofForge.Cli

structure CliOptions where
  input? : Option FilePath := none
  output? : Option FilePath := none
  root? : Option FilePath := none
  moduleName? : Option Name := none
  deriving Inhabited

def usage : String :=
  "Usage: proof-forge [--root DIR] [--module Mod.Name] [-o output.yul] input.lean"

def parseModuleName (s : String) : Name :=
  s.splitOn "." |>.foldl (init := Name.anonymous) fun acc part =>
    if part.isEmpty then acc else acc.str part

partial def parseArgs : List String → CliOptions → Except String CliOptions
  | [], opts =>
      if opts.input?.isSome then
        .ok opts
      else
        .error usage
  | "-o" :: out :: rest, opts =>
      parseArgs rest { opts with output? := some (FilePath.mk out) }
  | "--output" :: out :: rest, opts =>
      parseArgs rest { opts with output? := some (FilePath.mk out) }
  | "--root" :: root :: rest, opts =>
      parseArgs rest { opts with root? := some (FilePath.mk root) }
  | "--module" :: modName :: rest, opts =>
      parseArgs rest { opts with moduleName? := some (parseModuleName modName) }
  | "-h" :: _, _ =>
      .error usage
  | "--help" :: _, _ =>
      .error usage
  | arg :: rest, opts =>
      if arg.startsWith "-" then
        .error s!"unknown option: {arg}\n{usage}"
      else if opts.input?.isSome then
        .error s!"multiple input files provided\n{usage}"
      else
        parseArgs rest { opts with input? := some (FilePath.mk arg) }

unsafe def compileFile (opts : CliOptions) : IO UInt32 := do
  enableInitializersExecution
  initSearchPath (← findSysroot "lean")
  let some input := opts.input?
    | IO.eprintln usage
      return 1
  let source ← IO.FS.readFile input
  let modName ← match opts.moduleName? with
    | some name => pure name
    | none => moduleNameOfFileName input opts.root?
  let frontendOpts := Elab.async.set {} false
  let env? ← withImporting <| Elab.runFrontend
    source
    frontendOpts
    input.toString
    modName
    (trustLevel := 0)
    (oleanFileName? := none)
    (ileanFileName? := none)
    (jsonOutput := false)
    (errorOnKinds := #[])
    (plugins := #[])
    (printStats := false)
    (setup? := none)
  let some env := env?
    | return 1
  let yul ← Lean.Compiler.LCNF.EmitYul.emitYul modName
    |>.toIO' { fileName := input.toString, fileMap := default } { env := env }
  let output := opts.output?.getD (input.withExtension "yul")
  if let some parent := output.parent then
    IO.FS.createDirAll parent
  IO.FS.writeFile output yul
  IO.println s!"wrote {output}"
  return 0

end ProofForge.Cli

unsafe def main (args : List String) : IO UInt32 := do
  match ProofForge.Cli.parseArgs args {} with
  | .ok opts => ProofForge.Cli.compileFile opts
  | .error msg =>
      IO.eprintln msg
      return 1
