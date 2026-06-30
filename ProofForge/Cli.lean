import Init.Notation
import Lean
import Lean.Elab.Frontend
import Lean.Util.Path
import ProofForge.Compiler.LCNF.EmitYul

open Lean
open System

namespace ProofForge.Cli

abbrev MethodSpec := Lean.Compiler.LCNF.EmitYul.MethodSpec

structure CliOptions where
  input? : Option FilePath := none
  output? : Option FilePath := none
  root? : Option FilePath := none
  moduleName? : Option Name := none
  methods : Array MethodSpec := #[]
  deriving Inhabited

def usage : String :=
  "Usage: proof-forge [--root DIR] [--module Mod.Name] [-o output.yul] [--method selector:fn:argc:view|update] input.lean"

def parseModuleName (s : String) : Name :=
  s.splitOn "." |>.foldl (init := Name.anonymous) fun acc part =>
    if part.isEmpty then acc else acc.str part

def stripHexPrefix (s : String) : String :=
  if s.startsWith "0x" then (s.drop 2).toString else s

def parseReturnsValue (s : String) : Except String Bool :=
  match s with
  | "view" | "pure" | "return" | "returns" | "true" => .ok true
  | "update" | "void" | "false" => .ok false
  | _ => .error s!"unknown method return mode '{s}', expected view or update"

/-- Parse `selector:fnName:argCount:view|update`.

`fnName` is the generated Yul function name, for example `f_Counter_get`.
The build scripts accept `.evm-methods` sidecars and convert exported Lean
symbols such as `l_Counter_get` to this form.
-/
def parseMethodSpec (s : String) : Except String MethodSpec := do
  match s.splitOn ":" with
  | [selector, fnName, argCount, returnMode] =>
      let some argc := argCount.toNat?
        | .error s!"invalid method arg count '{argCount}'"
      let returnsValue ← parseReturnsValue returnMode
      .ok {
        selector := stripHexPrefix selector
        fnName := fnName
        argCount := argc
        returnsValue := returnsValue
      }
  | _ =>
      .error s!"invalid method spec '{s}'\n{usage}"

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
  | "--method" :: method :: rest, opts => do
      let spec ← parseMethodSpec method
      parseArgs rest { opts with methods := opts.methods.push spec }
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
  let env? ← Elab.runFrontend
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
  let emit := if opts.methods.isEmpty then
    Lean.Compiler.LCNF.EmitYul.emitYul modName
  else
    Lean.Compiler.LCNF.EmitYul.emitYulContract modName opts.methods
  let yul ← emit
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
