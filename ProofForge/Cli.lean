import Init.Notation
import Lean
import Lean.Elab.Frontend
import Lean.Util.Path
import ProofForge.Backend.Evm.IR
import ProofForge.Backend.Psy.IR
import ProofForge.Compiler.LCNF.EmitYul
import ProofForge.IR.Examples.AbiAggregateProbe
import ProofForge.IR.Examples.AbiScalarProbe
import ProofForge.IR.Examples.ArrayProbe
import ProofForge.IR.Examples.ArithmeticProbe
import ProofForge.IR.Examples.AssertProbe
import ProofForge.IR.Examples.AssignmentProbe
import ProofForge.IR.Examples.BitwiseProbe
import ProofForge.IR.Examples.BoolStorageArrayProbe
import ProofForge.IR.Examples.BoolStorageScalarProbe
import ProofForge.IR.Examples.ContextProbe
import ProofForge.IR.Examples.ConditionalProbe
import ProofForge.IR.Examples.Counter
import ProofForge.IR.Examples.CrosscallProbe
import ProofForge.IR.Examples.EventProbe
import ProofForge.IR.Examples.EvmCrosscallProbe
import ProofForge.IR.Examples.EvmHashProbe
import ProofForge.IR.Examples.EvmMapProbe
import ProofForge.IR.Examples.ExpressionPredicateProbe
import ProofForge.IR.Examples.GenericEntrypointProbe
import ProofForge.IR.Examples.HashProbe
import ProofForge.IR.Examples.HashStorageProbe
import ProofForge.IR.Examples.LoopProbe
import ProofForge.IR.Examples.MapProbe
import ProofForge.IR.Examples.NestedAggregateProbe
import ProofForge.IR.Examples.StorageNestedAggregateProbe
import ProofForge.IR.Examples.StructArrayProbe
import ProofForge.IR.Examples.StructProbe
import ProofForge.IR.Examples.U32ArithmeticProbe
import ProofForge.IR.Examples.U32HashPackingProbe
import ProofForge.IR.Examples.U32StorageArrayProbe
import ProofForge.IR.Examples.U32StorageScalarProbe

open Lean
open System

namespace ProofForge.Cli

abbrev MethodSpec := Lean.Compiler.LCNF.EmitYul.MethodSpec

inductive EmitMode where
  | yul
  | evmBytecode
  | counterIrYul
  | counterIrBytecode
  | abiScalarIrYul
  | abiScalarIrBytecode
  | assertIrYul
  | assertIrBytecode
  | assignmentIrYul
  | assignmentIrBytecode
  | conditionalIrYul
  | conditionalIrBytecode
  | contextIrYul
  | contextIrBytecode
  | evmEventIrYul
  | evmEventIrBytecode
  | evmCrosscallIrYul
  | evmCrosscallIrBytecode
  | evmHashIrYul
  | evmHashIrBytecode
  | evmMapIrYul
  | evmMapIrBytecode
  | counterIrPsy
  | eventIrPsy
  | crosscallIrPsy
  | expressionPredicateIrPsy
  | genericEntrypointIrPsy
  | arithmeticIrPsy
  | bitwiseIrPsy
  | boolStorageArrayIrPsy
  | boolStorageScalarIrPsy
  | conditionalIrPsy
  | contextIrPsy
  | hashIrPsy
  | hashStorageIrPsy
  | mapIrPsy
  | assertIrPsy
  | loopIrPsy
  | arrayIrPsy
  | structIrPsy
  | structArrayIrPsy
  | abiAggregateIrPsy
  | nestedAggregateIrPsy
  | storageNestedAggregateIrPsy
  | u32ArithmeticIrPsy
  | u32HashPackingIrPsy
  | u32StorageScalarIrPsy
  | u32StorageArrayIrPsy
  deriving BEq, Inhabited

structure CliOptions where
  input? : Option FilePath := none
  output? : Option FilePath := none
  root? : Option FilePath := none
  moduleName? : Option Name := none
  methods : Array MethodSpec := #[]
  methodsFile? : Option FilePath := none
  yulOutput? : Option FilePath := none
  artifactOutput? : Option FilePath := none
  solc : String := "solc"
  cast : String := "cast"
  mode : EmitMode := .yul
  deriving Inhabited

def usage : String :=
  String.intercalate "\n" [
    "Usage:",
    "  proof-forge [--root DIR] [--module Mod.Name] [-o output.yul] [--method selector:fn:argc:view|update] input.lean",
    "  proof-forge --evm-bytecode [--root DIR] [--module Mod.Name] [--methods-file file] [--yul-output file] [--artifact-output file] [-o output.bin] input.lean",
    "  proof-forge --emit-counter-ir-yul [-o output.yul]",
    "  proof-forge --emit-counter-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-abi-scalar-ir-yul [-o output.yul]",
    "  proof-forge --emit-abi-scalar-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-assert-ir-yul [-o output.yul]",
    "  proof-forge --emit-assert-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-assignment-ir-yul [-o output.yul]",
    "  proof-forge --emit-assignment-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-conditional-ir-yul [-o output.yul]",
    "  proof-forge --emit-conditional-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-context-ir-yul [-o output.yul]",
    "  proof-forge --emit-context-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-event-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-event-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-crosscall-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-crosscall-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-hash-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-hash-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-map-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-map-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-counter-ir-psy [-o output.psy]",
    "  proof-forge --emit-event-ir-psy [-o output.psy]",
    "  proof-forge --emit-crosscall-ir-psy [-o output.psy]",
    "  proof-forge --emit-expression-predicate-ir-psy [-o output.psy]",
    "  proof-forge --emit-generic-entrypoint-ir-psy [-o output.psy]",
    "  proof-forge --emit-arithmetic-ir-psy [-o output.psy]",
    "  proof-forge --emit-bitwise-ir-psy [-o output.psy]",
    "  proof-forge --emit-bool-storage-array-ir-psy [-o output.psy]",
    "  proof-forge --emit-bool-storage-scalar-ir-psy [-o output.psy]",
    "  proof-forge --emit-conditional-ir-psy [-o output.psy]",
    "  proof-forge --emit-context-ir-psy [-o output.psy]",
    "  proof-forge --emit-hash-ir-psy [-o output.psy]",
    "  proof-forge --emit-hash-storage-ir-psy [-o output.psy]",
    "  proof-forge --emit-map-ir-psy [-o output.psy]",
    "  proof-forge --emit-assert-ir-psy [-o output.psy]",
    "  proof-forge --emit-loop-ir-psy [-o output.psy]",
    "  proof-forge --emit-array-ir-psy [-o output.psy]",
    "  proof-forge --emit-struct-ir-psy [-o output.psy]",
    "  proof-forge --emit-struct-array-ir-psy [-o output.psy]",
    "  proof-forge --emit-abi-aggregate-ir-psy [-o output.psy]",
    "  proof-forge --emit-nested-aggregate-ir-psy [-o output.psy]",
    "  proof-forge --emit-storage-nested-aggregate-ir-psy [-o output.psy]",
    "  proof-forge --emit-u32-arithmetic-ir-psy [-o output.psy]",
    "  proof-forge --emit-u32-hash-packing-ir-psy [-o output.psy]",
    "  proof-forge --emit-u32-storage-scalar-ir-psy [-o output.psy]",
    "  proof-forge --emit-u32-storage-array-ir-psy [-o output.psy]",
    "",
    "EVM bytecode mode reads <contract>.evm-methods by default and uses Foundry `cast sig` plus `solc --strict-assembly`.",
    "IR fixture modes render hand-written portable IR fixtures to target source or bytecode."
  ]

def parseModuleName (s : String) : Name :=
  s.splitOn "." |>.foldl (init := Name.anonymous) fun acc part =>
    if part.isEmpty then acc else acc.str part

def trimAsciiString (s : String) : String :=
  s.trimAscii.toString

def dropEndString (s : String) (n : Nat) : String :=
  (s.dropEnd n).toString

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

def leanBaseName (input : FilePath) : String :=
  let fileName := input.fileName.getD input.toString
  if fileName.endsWith ".lean" then
    dropEndString fileName ".lean".length
  else
    fileName

def siblingPath (input : FilePath) (fileName : String) : FilePath :=
  let child := FilePath.mk fileName
  match input.parent with
  | some parent => parent / child
  | none => child

def defaultMethodsFile (input : FilePath) : FilePath :=
  siblingPath input s!"{leanBaseName input}.evm-methods"

def defaultYulOutput (input : FilePath) : FilePath :=
  siblingPath input s!".{leanBaseName input}.yul"

def methodArgCount (sig : String) : Except String Nat := do
  match sig.splitOn "(" with
  | [_name, rest] =>
      if !rest.endsWith ")" then
        .error s!"invalid method signature '{sig}'"
      else
        let args := trimAsciiString (dropEndString rest 1)
        if args.isEmpty then
          .ok 0
        else
          .ok (args.splitOn ",").length
  | _ =>
      .error s!"invalid method signature '{sig}'"

def yulFunctionName (symbol : String) : String :=
  let name :=
    if symbol.startsWith "l_" then
      (symbol.drop 2).toString
    else
      symbol
  s!"f_{name}"

def parseMethodTarget (target : String) : Except String (String × Bool) := do
  match (trimAsciiString target).splitOn "[" with
  | [symbol] =>
      .ok (trimAsciiString symbol, false)
  | [symbol, modeWithBracket] =>
      if !modeWithBracket.endsWith "]" then
        .error s!"invalid method target '{target}'"
      else
        let mode := trimAsciiString (dropEndString modeWithBracket 1)
        let returnsValue ← parseReturnsValue mode
        .ok (trimAsciiString symbol, returnsValue)
  | _ =>
      .error s!"invalid method target '{target}'"

def parseMethodsLine (line : String) : Except String (Option (String × String × Bool × Nat)) := do
  let line := trimAsciiString line
  if line.isEmpty || line.startsWith "#" then
    .ok none
  else
    match line.splitOn "=" with
    | [sig, target] =>
        let sig := trimAsciiString sig
        let (symbol, returnsValue) ← parseMethodTarget target
        let argc ← methodArgCount sig
        .ok (some (sig, yulFunctionName symbol, returnsValue, argc))
    | _ =>
        .error s!"invalid .evm-methods line '{line}', expected signature=symbol[view|update]"

def isHexChar (c : Char) : Bool :=
  c.isDigit || "abcdefABCDEF".contains c

def isHexString (s : String) : Bool :=
  !s.isEmpty && s.all isHexChar

def runProcess (cmd : String) (args : Array String) (cwd? : Option FilePath := none) : IO String := do
  let output ← IO.Process.output { cmd := cmd, args := args, cwd := cwd? }
  if output.exitCode != 0 then
    let stderr := trimAsciiString output.stderr
    let detail := if stderr.isEmpty then trimAsciiString output.stdout else stderr
    throw <| IO.userError s!"{cmd} failed with exit code {output.exitCode}: {detail}"
  return output.stdout

def selectorFor (cast : String) (sig : String) : IO String := do
  let stdout ← runProcess cast #["sig", sig]
  let selector := stripHexPrefix (trimAsciiString stdout)
  if selector.length != 8 || !isHexString selector then
    throw <| IO.userError s!"cast returned invalid selector for {sig}: {trimAsciiString stdout}"
  return selector

def readMethodsFile (cast : String) (path : FilePath) : IO (Array MethodSpec) := do
  if !(← path.pathExists) then
    throw <| IO.userError s!"methods file not found: {path}"
  let contents ← IO.FS.readFile path
  let mut methods := #[]
  for line in contents.splitOn "\n" do
    match parseMethodsLine line with
    | .ok none => pure ()
    | .ok (some (sig, fnName, returnsValue, argCount)) =>
        let selector ← selectorFor cast sig
        methods := methods.push {
          selector := selector
          fnName := fnName
          argCount := argCount
          returnsValue := returnsValue
        }
    | .error msg =>
        throw <| IO.userError s!"{path}: {msg}"
  return methods

def solcBytecode (solc : String) (yulFile : FilePath) : IO String := do
  let stdout ← runProcess solc #["--strict-assembly", yulFile.toString, "--bin"]
  for line in stdout.splitOn "\n" do
    let line := trimAsciiString line
    if isHexString line then
      return line
  throw <| IO.userError s!"solc did not emit bytecode for {yulFile}"

def solcVersion? (solc : String) : IO (Option String) := do
  try
    return some (trimAsciiString (← runProcess solc #["--version"]))
  catch _ =>
    return none

def fileDigestAndBytes (path : FilePath) : IO (String × Nat) := do
  let script := "import hashlib, pathlib, sys; data = pathlib.Path(sys.argv[1]).read_bytes(); print(hashlib.sha256(data).hexdigest(), len(data))"
  let stdout ← runProcess "python3" #["-c", script, path.toString]
  match (trimAsciiString stdout).splitOn " " with
  | [digest, byteCount] =>
      let some bytes := byteCount.toNat?
        | throw <| IO.userError s!"python3 returned invalid byte count for {path}: {byteCount}"
      return (digest, bytes)
  | _ =>
      throw <| IO.userError s!"python3 returned invalid digest output for {path}: {trimAsciiString stdout}"

def jsonString (value : String) : String :=
  let escapeChar : Char → String
    | '"' => "\\\""
    | '\\' => "\\\\"
    | '\n' => "\\n"
    | '\r' => "\\r"
    | '\t' => "\\t"
    | ch => ch.toString
  "\"" ++ String.intercalate "" (value.toList.map escapeChar) ++ "\""

def jsonBool (value : Bool) : String :=
  if value then "true" else "false"

def jsonObject (fields : Array (String × String)) : String :=
  "{" ++ String.intercalate "," (fields.toList.map fun field => jsonString field.fst ++ ":" ++ field.snd) ++ "}"

def jsonArray (values : Array String) : String :=
  "[" ++ String.intercalate "," values.toList ++ "]"

def jsonStringArray (values : Array String) : String :=
  jsonArray (values.map jsonString)

def defaultArtifactOutput (bytecodeOutput : FilePath) : FilePath :=
  let fileName := FilePath.mk "proof-forge-artifact.json"
  match bytecodeOutput.parent with
  | some parent => parent / fileName
  | none => fileName

def artifactEntryJson (path : FilePath) : IO String := do
  let (digest, bytes) ← fileDigestAndBytes path
  return jsonObject #[
    ("path", jsonString path.toString),
    ("sha256", jsonString digest),
    ("bytes", toString bytes)
  ]

def dedupStrings (values : Array String) : Array String :=
  values.foldl (init := #[]) fun acc value =>
    if acc.contains value then acc else acc.push value

def moduleCapabilityIds (module : ProofForge.IR.Module) : Array String :=
  dedupStrings (module.capabilities.map fun capability => capability.id)

def valueTypeJson (type : ProofForge.IR.ValueType) : String :=
  jsonString type.name

def entrypointJson (entrypoint : ProofForge.IR.Entrypoint) : String :=
  let params := entrypoint.params.map fun param =>
    jsonObject #[
      ("name", jsonString param.fst),
      ("type", valueTypeJson param.snd)
    ]
  let selectorValue :=
    match entrypoint.selector? with
    | some selector => jsonString selector
    | none => "null"
  jsonObject #[
    ("name", jsonString entrypoint.name),
    ("selector", selectorValue),
    ("params", jsonArray params),
    ("returns", valueTypeJson entrypoint.returns)
  ]

def methodSpecJson (method : MethodSpec) : String :=
  jsonObject #[
    ("selector", jsonString method.selector),
    ("fnName", jsonString method.fnName),
    ("argCount", toString method.argCount),
    ("returnsValue", jsonBool method.returnsValue)
  ]

def writeEvmArtifactMetadata
    (opts : CliOptions)
    (fixture sourceKind sourceModule : String)
    (capabilities : Array String)
    (entrypoints : Array String)
    (methods : Array String)
    (source? : Option FilePath)
    (yulOutput bytecodeOutput : FilePath) : IO Unit := do
  let metadataOutput := opts.artifactOutput?.getD (defaultArtifactOutput bytecodeOutput)
  let mut artifactFields : Array (String × String) := #[
    ("yul", ← artifactEntryJson yulOutput),
    ("bytecode", ← artifactEntryJson bytecodeOutput)
  ]
  if let some source := source? then
    artifactFields := artifactFields.push ("source", ← artifactEntryJson source)
  let solcVersionValue :=
    match (← solcVersion? opts.solc) with
    | some version => jsonString version
    | none => "null"
  let metadata := jsonObject #[
    ("schemaVersion", "1"),
    ("target", jsonString "evm"),
    ("targetFamily", jsonString "evm"),
    ("artifactKind", jsonString "evm-bytecode"),
    ("fixture", jsonString fixture),
    ("sourceKind", jsonString sourceKind),
    ("irVersion", if sourceKind == "portable-ir" then jsonString "portable-ir-v0" else "null"),
    ("sourceModule", jsonString sourceModule),
    ("capabilities", jsonStringArray (dedupStrings capabilities)),
    ("toolchain", jsonObject #[
      ("solc", jsonObject #[
        ("path", jsonString opts.solc),
        ("version", solcVersionValue)
      ])
    ]),
    ("abi", jsonObject #[
      ("entrypoints", jsonArray entrypoints),
      ("methods", jsonArray methods)
    ]),
    ("artifacts", jsonObject artifactFields),
    ("validation", jsonObject #[
      ("solcStrictAssembly", jsonString "passed"),
      ("bytecodeGeneration", jsonString "passed")
    ])
  ]
  if let some parent := metadataOutput.parent then
    IO.FS.createDirAll parent
  IO.FS.writeFile metadataOutput (metadata ++ "\n")
  IO.println s!"wrote {metadataOutput}"

def writeEvmIrArtifactMetadata
    (opts : CliOptions)
    (fixture sourceModule : String)
    (module : ProofForge.IR.Module)
    (yulOutput bytecodeOutput : FilePath) : IO Unit :=
  writeEvmArtifactMetadata
    opts
    fixture
    "portable-ir"
    sourceModule
    (moduleCapabilityIds module)
    (module.entrypoints.map entrypointJson)
    #[]
    none
    yulOutput
    bytecodeOutput

def writeEvmSdkArtifactMetadata
    (opts : CliOptions)
    (sourceModule : String)
    (input yulOutput bytecodeOutput : FilePath)
    (methods : Array MethodSpec) : IO Unit :=
  writeEvmArtifactMetadata
    opts
    (input.fileName.getD input.toString)
    "lean-sdk"
    sourceModule
    #[]
    #[]
    (methods.map methodSpecJson)
    (some input)
    yulOutput
    bytecodeOutput

partial def parseArgs : List String → CliOptions → Except String CliOptions
  | [], opts =>
      if opts.input?.isSome || opts.mode == .counterIrYul || opts.mode == .counterIrBytecode || opts.mode == .abiScalarIrYul || opts.mode == .abiScalarIrBytecode || opts.mode == .assertIrYul || opts.mode == .assertIrBytecode || opts.mode == .assignmentIrYul || opts.mode == .assignmentIrBytecode || opts.mode == .conditionalIrYul || opts.mode == .conditionalIrBytecode || opts.mode == .contextIrYul || opts.mode == .contextIrBytecode || opts.mode == .evmEventIrYul || opts.mode == .evmEventIrBytecode || opts.mode == .evmCrosscallIrYul || opts.mode == .evmCrosscallIrBytecode || opts.mode == .evmHashIrYul || opts.mode == .evmHashIrBytecode || opts.mode == .evmMapIrYul || opts.mode == .evmMapIrBytecode || opts.mode == .counterIrPsy || opts.mode == .eventIrPsy || opts.mode == .crosscallIrPsy || opts.mode == .expressionPredicateIrPsy || opts.mode == .genericEntrypointIrPsy || opts.mode == .arithmeticIrPsy || opts.mode == .bitwiseIrPsy || opts.mode == .boolStorageArrayIrPsy || opts.mode == .boolStorageScalarIrPsy || opts.mode == .conditionalIrPsy || opts.mode == .contextIrPsy || opts.mode == .hashIrPsy || opts.mode == .hashStorageIrPsy || opts.mode == .mapIrPsy || opts.mode == .assertIrPsy || opts.mode == .loopIrPsy || opts.mode == .arrayIrPsy || opts.mode == .structIrPsy || opts.mode == .structArrayIrPsy || opts.mode == .abiAggregateIrPsy || opts.mode == .nestedAggregateIrPsy || opts.mode == .storageNestedAggregateIrPsy || opts.mode == .u32ArithmeticIrPsy || opts.mode == .u32HashPackingIrPsy || opts.mode == .u32StorageScalarIrPsy || opts.mode == .u32StorageArrayIrPsy then
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
  | "--methods-file" :: path :: rest, opts =>
      parseArgs rest { opts with methodsFile? := some (FilePath.mk path) }
  | "--yul-output" :: path :: rest, opts =>
      parseArgs rest { opts with yulOutput? := some (FilePath.mk path) }
  | "--artifact-output" :: path :: rest, opts =>
      parseArgs rest { opts with artifactOutput? := some (FilePath.mk path) }
  | "--solc" :: path :: rest, opts =>
      parseArgs rest { opts with solc := path }
  | "--cast" :: path :: rest, opts =>
      parseArgs rest { opts with cast := path }
  | "--evm-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmBytecode }
  | "--bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmBytecode }
  | "--emit-counter-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .counterIrYul }
  | "--emit-counter-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .counterIrBytecode }
  | "--emit-abi-scalar-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .abiScalarIrYul }
  | "--emit-abi-scalar-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .abiScalarIrBytecode }
  | "--emit-assert-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .assertIrYul }
  | "--emit-assert-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .assertIrBytecode }
  | "--emit-assignment-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .assignmentIrYul }
  | "--emit-assignment-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .assignmentIrBytecode }
  | "--emit-conditional-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .conditionalIrYul }
  | "--emit-conditional-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .conditionalIrBytecode }
  | "--emit-context-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .contextIrYul }
  | "--emit-context-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .contextIrBytecode }
  | "--emit-evm-event-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmEventIrYul }
  | "--emit-evm-event-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmEventIrBytecode }
  | "--emit-evm-crosscall-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmCrosscallIrYul }
  | "--emit-evm-crosscall-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmCrosscallIrBytecode }
  | "--emit-evm-hash-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmHashIrYul }
  | "--emit-evm-hash-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmHashIrBytecode }
  | "--emit-evm-map-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmMapIrYul }
  | "--emit-evm-map-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmMapIrBytecode }
  | "--emit-counter-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .counterIrPsy }
  | "--emit-event-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .eventIrPsy }
  | "--emit-crosscall-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .crosscallIrPsy }
  | "--emit-expression-predicate-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .expressionPredicateIrPsy }
  | "--emit-generic-entrypoint-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .genericEntrypointIrPsy }
  | "--emit-arithmetic-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .arithmeticIrPsy }
  | "--emit-bitwise-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .bitwiseIrPsy }
  | "--emit-bool-storage-array-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .boolStorageArrayIrPsy }
  | "--emit-bool-storage-scalar-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .boolStorageScalarIrPsy }
  | "--emit-conditional-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .conditionalIrPsy }
  | "--emit-context-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .contextIrPsy }
  | "--emit-hash-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .hashIrPsy }
  | "--emit-hash-storage-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .hashStorageIrPsy }
  | "--emit-map-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .mapIrPsy }
  | "--emit-assert-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .assertIrPsy }
  | "--emit-loop-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .loopIrPsy }
  | "--emit-array-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .arrayIrPsy }
  | "--emit-struct-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .structIrPsy }
  | "--emit-struct-array-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .structArrayIrPsy }
  | "--emit-abi-aggregate-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .abiAggregateIrPsy }
  | "--emit-nested-aggregate-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .nestedAggregateIrPsy }
  | "--emit-storage-nested-aggregate-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .storageNestedAggregateIrPsy }
  | "--emit-u32-arithmetic-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .u32ArithmeticIrPsy }
  | "--emit-u32-hash-packing-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .u32HashPackingIrPsy }
  | "--emit-u32-storage-scalar-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .u32StorageScalarIrPsy }
  | "--emit-u32-storage-array-ir-psy" :: rest, opts =>
      parseArgs rest { opts with mode := .u32StorageArrayIrPsy }
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

def resolveMethods (opts : CliOptions) (input : FilePath) : IO (Array MethodSpec) := do
  if !opts.methods.isEmpty then
    return opts.methods
  else if opts.mode == .evmBytecode then
    let methodsFile := opts.methodsFile?.getD (defaultMethodsFile input)
    readMethodsFile opts.cast methodsFile
  else
    return #[]

def writeTextFile (path : FilePath) (contents : String) : IO Unit := do
  if let some parent := path.parent then
    IO.FS.createDirAll parent
  IO.FS.writeFile path contents

unsafe def emitYulFile (opts : CliOptions) (input output : FilePath) (methods : Array MethodSpec) : IO Unit := do
  enableInitializersExecution
  initSearchPath (← findSysroot "lean")
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
    | throw <| IO.userError "frontend failed"
  let emit := if methods.isEmpty then
    Lean.Compiler.LCNF.EmitYul.emitYul modName
  else
    Lean.Compiler.LCNF.EmitYul.emitYulContract modName methods
  let yul ← emit
    |>.toIO' { fileName := input.toString, fileMap := default } { env := env }
  writeTextFile output yul

unsafe def compileYul (opts : CliOptions) : IO UInt32 := do
  let some input := opts.input?
    | IO.eprintln usage
      return 1
  let methods ← resolveMethods opts input
  let output := opts.output?.getD (input.withExtension "yul")
  emitYulFile opts input output methods
  IO.println s!"wrote {output}"
  return 0

def compileCounterIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/Counter.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.Counter.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderCounterIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.Counter.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileCounterIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/Counter.yul")
  let yul ← renderCounterIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/Counter.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "Counter" "ProofForge.IR.Examples.Counter" ProofForge.IR.Examples.Counter.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileAbiScalarIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/AbiScalarProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.AbiScalarProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderAbiScalarIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.AbiScalarProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileAbiScalarIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/AbiScalarProbe.yul")
  let yul ← renderAbiScalarIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/AbiScalarProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "AbiScalarProbe" "ProofForge.IR.Examples.AbiScalarProbe" ProofForge.IR.Examples.AbiScalarProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileAssertIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/AssertProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.AssertProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderAssertIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.AssertProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileAssertIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/AssertProbe.yul")
  let yul ← renderAssertIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/AssertProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "AssertProbe" "ProofForge.IR.Examples.AssertProbe" ProofForge.IR.Examples.AssertProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileAssignmentIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/AssignmentProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.AssignmentProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderAssignmentIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.AssignmentProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileAssignmentIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/AssignmentProbe.yul")
  let yul ← renderAssignmentIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/AssignmentProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "AssignmentProbe" "ProofForge.IR.Examples.AssignmentProbe" ProofForge.IR.Examples.AssignmentProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileConditionalIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/ConditionalProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.ConditionalProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderConditionalIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.ConditionalProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileConditionalIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/ConditionalProbe.yul")
  let yul ← renderConditionalIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/ConditionalProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "ConditionalProbe" "ProofForge.IR.Examples.ConditionalProbe" ProofForge.IR.Examples.ConditionalProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileContextIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/ContextProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.ContextProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderContextIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.ContextProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileContextIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/ContextProbe.yul")
  let yul ← renderContextIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/ContextProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "ContextProbe" "ProofForge.IR.Examples.ContextProbe" ProofForge.IR.Examples.ContextProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmEventIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EventProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EventProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmEventIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EventProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmEventIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EventProbe.yul")
  let yul ← renderEvmEventIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EventProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EventProbe" "ProofForge.IR.Examples.EventProbe" ProofForge.IR.Examples.EventProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmCrosscallIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmCrosscallProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmCrosscallProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmCrosscallIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmCrosscallProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmCrosscallIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmCrosscallProbe.yul")
  let yul ← renderEvmCrosscallIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmCrosscallProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmCrosscallProbe" "ProofForge.IR.Examples.EvmCrosscallProbe" ProofForge.IR.Examples.EvmCrosscallProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmHashIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmHashProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmHashProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmHashIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmHashProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmHashIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmHashProbe.yul")
  let yul ← renderEvmHashIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmHashProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmHashProbe" "ProofForge.IR.Examples.EvmHashProbe" ProofForge.IR.Examples.EvmHashProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmMapIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmMapProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmMapProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmMapIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmMapProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmMapIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmMapProbe.yul")
  let yul ← renderEvmMapIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmMapProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmMapProbe" "ProofForge.IR.Examples.EvmMapProbe" ProofForge.IR.Examples.EvmMapProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileCounterIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/Counter.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.Counter.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileEventIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/EventProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.EventProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileCrosscallIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/CrosscallProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.CrosscallProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileExpressionPredicateIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/ExpressionPredicateProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.ExpressionPredicateProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileGenericEntrypointIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/GenericEntrypointProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.GenericEntrypointProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileArithmeticIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/ArithmeticProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.ArithmeticProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileBitwiseIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/BitwiseProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.BitwiseProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileBoolStorageArrayIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/BoolStorageArrayProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.BoolStorageArrayProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileBoolStorageScalarIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/BoolStorageScalarProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.BoolStorageScalarProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileConditionalIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/ConditionalProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.ConditionalProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileContextIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/ContextProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.ContextProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileHashIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/HashProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.HashProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileHashStorageIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/HashStorageProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.HashStorageProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileMapIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/MapProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.MapProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileAssertIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/AssertProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.AssertProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileLoopIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/LoopProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.LoopProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileArrayIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/ArrayProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.ArrayProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileStructIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/StructProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.StructProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileStructArrayIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/StructArrayProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.StructArrayProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileAbiAggregateIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/AbiAggregateProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.AbiAggregateProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileNestedAggregateIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/NestedAggregateProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.NestedAggregateProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileStorageNestedAggregateIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/StorageNestedAggregateProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.StorageNestedAggregateProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileU32ArithmeticIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/U32ArithmeticProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.U32ArithmeticProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileU32HashPackingIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/U32HashPackingProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.U32HashPackingProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileU32StorageScalarIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/U32StorageScalarProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.U32StorageScalarProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileU32StorageArrayIrPsy (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/psy/U32StorageArrayProbe.psy")
  match ProofForge.Backend.Psy.IR.renderModule ProofForge.IR.Examples.U32StorageArrayProbe.module with
  | .ok source =>
      writeTextFile output source
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

unsafe def compileEvmBytecode (opts : CliOptions) : IO UInt32 := do
  let some input := opts.input?
    | IO.eprintln usage
      return 1
  let methods ← resolveMethods opts input
  if methods.isEmpty then
    throw <| IO.userError "EVM bytecode mode requires at least one method"
  let yulOutput := opts.yulOutput?.getD (defaultYulOutput input)
  emitYulFile opts input yulOutput methods
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (input.withExtension "bin")
  writeTextFile output (bytecode ++ "\n")
  let sourceModule :=
    match opts.moduleName? with
    | some name => toString name
    | none => leanBaseName input
  writeEvmSdkArtifactMetadata opts sourceModule input yulOutput output methods
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

unsafe def compileFile (opts : CliOptions) : IO UInt32 := do
  match opts.mode with
  | .yul => compileYul opts
  | .evmBytecode => compileEvmBytecode opts
  | .counterIrYul => compileCounterIrYul opts
  | .counterIrBytecode => compileCounterIrBytecode opts
  | .abiScalarIrYul => compileAbiScalarIrYul opts
  | .abiScalarIrBytecode => compileAbiScalarIrBytecode opts
  | .assertIrYul => compileAssertIrYul opts
  | .assertIrBytecode => compileAssertIrBytecode opts
  | .assignmentIrYul => compileAssignmentIrYul opts
  | .assignmentIrBytecode => compileAssignmentIrBytecode opts
  | .conditionalIrYul => compileConditionalIrYul opts
  | .conditionalIrBytecode => compileConditionalIrBytecode opts
  | .contextIrYul => compileContextIrYul opts
  | .contextIrBytecode => compileContextIrBytecode opts
  | .evmEventIrYul => compileEvmEventIrYul opts
  | .evmEventIrBytecode => compileEvmEventIrBytecode opts
  | .evmCrosscallIrYul => compileEvmCrosscallIrYul opts
  | .evmCrosscallIrBytecode => compileEvmCrosscallIrBytecode opts
  | .evmHashIrYul => compileEvmHashIrYul opts
  | .evmHashIrBytecode => compileEvmHashIrBytecode opts
  | .evmMapIrYul => compileEvmMapIrYul opts
  | .evmMapIrBytecode => compileEvmMapIrBytecode opts
  | .counterIrPsy => compileCounterIrPsy opts
  | .eventIrPsy => compileEventIrPsy opts
  | .crosscallIrPsy => compileCrosscallIrPsy opts
  | .expressionPredicateIrPsy => compileExpressionPredicateIrPsy opts
  | .genericEntrypointIrPsy => compileGenericEntrypointIrPsy opts
  | .arithmeticIrPsy => compileArithmeticIrPsy opts
  | .bitwiseIrPsy => compileBitwiseIrPsy opts
  | .boolStorageArrayIrPsy => compileBoolStorageArrayIrPsy opts
  | .boolStorageScalarIrPsy => compileBoolStorageScalarIrPsy opts
  | .conditionalIrPsy => compileConditionalIrPsy opts
  | .contextIrPsy => compileContextIrPsy opts
  | .hashIrPsy => compileHashIrPsy opts
  | .hashStorageIrPsy => compileHashStorageIrPsy opts
  | .mapIrPsy => compileMapIrPsy opts
  | .assertIrPsy => compileAssertIrPsy opts
  | .loopIrPsy => compileLoopIrPsy opts
  | .arrayIrPsy => compileArrayIrPsy opts
  | .structIrPsy => compileStructIrPsy opts
  | .structArrayIrPsy => compileStructArrayIrPsy opts
  | .abiAggregateIrPsy => compileAbiAggregateIrPsy opts
  | .nestedAggregateIrPsy => compileNestedAggregateIrPsy opts
  | .storageNestedAggregateIrPsy => compileStorageNestedAggregateIrPsy opts
  | .u32ArithmeticIrPsy => compileU32ArithmeticIrPsy opts
  | .u32HashPackingIrPsy => compileU32HashPackingIrPsy opts
  | .u32StorageScalarIrPsy => compileU32StorageScalarIrPsy opts
  | .u32StorageArrayIrPsy => compileU32StorageArrayIrPsy opts

end ProofForge.Cli

unsafe def main (args : List String) : IO UInt32 := do
  match ProofForge.Cli.parseArgs args {} with
  | .ok opts => ProofForge.Cli.compileFile opts
  | .error msg =>
      IO.eprintln msg
      return 1
