import Init.Notation
import Lean
import Lean.Elab.Frontend
import Lean.Util.Path
import ProofForge.Backend.Evm.IR
import ProofForge.Backend.Psy.IR
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Backend.Solana.Manifest
import ProofForge.Backend.Solana.Package
import ProofForge.Backend.Solana.Extension
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
import ProofForge.IR.Examples.ControlFlowAssertProbe
import ProofForge.IR.Examples.Counter
import ProofForge.IR.Examples.CrosscallProbe
import ProofForge.IR.Examples.EventProbe
import ProofForge.IR.Examples.EvmAbiAggregateProbe
import ProofForge.IR.Examples.EvmArrayValueProbe
import ProofForge.IR.Examples.EvmAssignOpProbe
import ProofForge.IR.Examples.EvmCrosscallProbe
import ProofForge.IR.Examples.EvmContextProbe
import ProofForge.IR.Examples.EvmExpressionProbe
import ProofForge.IR.Examples.EvmHashProbe
import ProofForge.IR.Examples.EvmLoopProbe
import ProofForge.IR.Examples.EvmMapProbe
import ProofForge.IR.Examples.EvmStorageArrayProbe
import ProofForge.IR.Examples.EvmStorageStructProbe
import ProofForge.IR.Examples.EvmStructArrayValueProbe
import ProofForge.IR.Examples.EvmStructValueProbe
import ProofForge.IR.Examples.EvmTypedMapProbe
import ProofForge.IR.Examples.EvmTypedStorageProbe
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
import ProofForge.Target
import ProofForge.Solana.Examples.Vault
import ProofForge.Solana.Examples.SystemCpi
import ProofForge.Solana.Examples.SystemCreateAccountCpi
import ProofForge.Solana.Examples.SplTokenTransferCheckedCpi

open Lean
open System

namespace ProofForge.Cli

abbrev MethodSpec := Lean.Compiler.LCNF.EmitYul.MethodSpec

structure ConstructorParamSpec where
  name : String
  abiType : String
  deriving Repr

structure ConstructorValueSpec where
  name : String
  value : String
  deriving Repr

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
  | evmAssignOpIrYul
  | evmAssignOpIrBytecode
  | conditionalIrYul
  | conditionalIrBytecode
  | contextIrYul
  | contextIrBytecode
  | evmEventIrYul
  | evmEventIrBytecode
  | evmCrosscallIrYul
  | evmCrosscallIrBytecode
  | evmExpressionIrYul
  | evmExpressionIrBytecode
  | evmHashIrYul
  | evmHashIrBytecode
  | evmLoopIrYul
  | evmLoopIrBytecode
  | evmMapIrYul
  | evmMapIrBytecode
  | evmStorageArrayIrYul
  | evmStorageArrayIrBytecode
  | evmStorageStructIrYul
  | evmStorageStructIrBytecode
  | evmTypedMapIrYul
  | evmTypedMapIrBytecode
  | evmTypedStorageIrYul
  | evmTypedStorageIrBytecode
  | evmArrayValueIrYul
  | evmArrayValueIrBytecode
  | evmStructArrayValueIrYul
  | evmStructArrayValueIrBytecode
  | evmStructValueIrYul
  | evmStructValueIrBytecode
  | evmAbiAggregateIrYul
  | evmAbiAggregateIrBytecode
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
  | counterIrSbpf
  | controlIrSbpf
  | solanaSdkSbpf
  | solanaElf
  | solanaSystemCpiElf
  | solanaSystemCreateAccountCpiElf
  | solanaSplTokenTransferCpiElf
  | sbpfAsm
  deriving BEq, Inhabited

def EmitMode.emitsEvmDeployManifest : EmitMode → Bool
  | .evmBytecode
  | .counterIrBytecode
  | .abiScalarIrBytecode
  | .assertIrBytecode
  | .assignmentIrBytecode
  | .evmAssignOpIrBytecode
  | .conditionalIrBytecode
  | .contextIrBytecode
  | .evmEventIrBytecode
  | .evmCrosscallIrBytecode
  | .evmExpressionIrBytecode
  | .evmHashIrBytecode
  | .evmLoopIrBytecode
  | .evmMapIrBytecode
  | .evmStorageArrayIrBytecode
  | .evmStorageStructIrBytecode
  | .evmTypedMapIrBytecode
  | .evmTypedStorageIrBytecode
  | .evmArrayValueIrBytecode
  | .evmStructArrayValueIrBytecode
  | .evmStructValueIrBytecode
  | .evmAbiAggregateIrBytecode => true
  | _ => false

def EmitMode.hasBuiltInFixture : EmitMode → Bool
  | .counterIrYul
  | .counterIrBytecode
  | .abiScalarIrYul
  | .abiScalarIrBytecode
  | .assertIrYul
  | .assertIrBytecode
  | .assignmentIrYul
  | .assignmentIrBytecode
  | .evmAssignOpIrYul
  | .evmAssignOpIrBytecode
  | .conditionalIrYul
  | .conditionalIrBytecode
  | .contextIrYul
  | .contextIrBytecode
  | .evmEventIrYul
  | .evmEventIrBytecode
  | .evmCrosscallIrYul
  | .evmCrosscallIrBytecode
  | .evmExpressionIrYul
  | .evmExpressionIrBytecode
  | .evmHashIrYul
  | .evmHashIrBytecode
  | .evmLoopIrYul
  | .evmLoopIrBytecode
  | .evmMapIrYul
  | .evmMapIrBytecode
  | .evmStorageArrayIrYul
  | .evmStorageArrayIrBytecode
  | .evmStorageStructIrYul
  | .evmStorageStructIrBytecode
  | .evmTypedMapIrYul
  | .evmTypedMapIrBytecode
  | .evmTypedStorageIrYul
  | .evmTypedStorageIrBytecode
  | .evmArrayValueIrYul
  | .evmArrayValueIrBytecode
  | .evmStructArrayValueIrYul
  | .evmStructArrayValueIrBytecode
  | .evmStructValueIrYul
  | .evmStructValueIrBytecode
  | .evmAbiAggregateIrYul
  | .evmAbiAggregateIrBytecode
  | .counterIrPsy
  | .eventIrPsy
  | .crosscallIrPsy
  | .expressionPredicateIrPsy
  | .genericEntrypointIrPsy
  | .arithmeticIrPsy
  | .bitwiseIrPsy
  | .boolStorageArrayIrPsy
  | .boolStorageScalarIrPsy
  | .conditionalIrPsy
  | .contextIrPsy
  | .hashIrPsy
  | .hashStorageIrPsy
  | .mapIrPsy
  | .assertIrPsy
  | .loopIrPsy
  | .arrayIrPsy
  | .structIrPsy
  | .structArrayIrPsy
  | .abiAggregateIrPsy
  | .nestedAggregateIrPsy
  | .storageNestedAggregateIrPsy
  | .u32ArithmeticIrPsy
  | .u32HashPackingIrPsy
  | .u32StorageScalarIrPsy
  | .u32StorageArrayIrPsy
  | .counterIrSbpf
  | .controlIrSbpf
  | .solanaSdkSbpf
  | .solanaElf
  | .solanaSystemCpiElf
  | .solanaSystemCreateAccountCpiElf
  | .solanaSplTokenTransferCpiElf
  | .sbpfAsm => true
  | _ => false

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
  evmChainProfile? : Option String := none
  evmConstructorArgsHex : String := ""
  evmConstructorArgsSource : String := "--evm-constructor-args-hex"
  evmConstructorParams : Array ConstructorParamSpec := #[]
  evmConstructorValues : Array ConstructorValueSpec := #[]
  solanaSbpfArch : String := "v3"
  mode : EmitMode := .yul
  deriving Inhabited

def usage : String :=
  String.intercalate "\n" [
    "Usage:",
    "  proof-forge [--root DIR] [--module Mod.Name] [-o output.yul] [--method selector:fn:argc:view|update] input.lean",
    "  proof-forge --evm-bytecode [--root DIR] [--module Mod.Name] [--methods-file file] [--yul-output file] [--artifact-output file] [--evm-chain-profile id] [--evm-constructor-param name:type] [--evm-constructor-arg name=value] [--evm-constructor-args-hex hex] [-o output.bin] input.lean",
    "  proof-forge --emit-counter-ir-yul [-o output.yul]",
    "  proof-forge --emit-counter-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-abi-scalar-ir-yul [-o output.yul]",
    "  proof-forge --emit-abi-scalar-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-assert-ir-yul [-o output.yul]",
    "  proof-forge --emit-assert-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-assignment-ir-yul [-o output.yul]",
    "  proof-forge --emit-assignment-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-assign-op-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-assign-op-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-conditional-ir-yul [-o output.yul]",
    "  proof-forge --emit-conditional-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-context-ir-yul [-o output.yul]",
    "  proof-forge --emit-context-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-event-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-event-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-crosscall-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-crosscall-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-expression-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-expression-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-hash-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-hash-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-loop-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-loop-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-map-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-map-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-storage-array-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-storage-array-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-storage-struct-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-storage-struct-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-typed-map-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-typed-map-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-typed-storage-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-typed-storage-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-array-value-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-array-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-struct-array-value-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-struct-array-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-struct-value-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-struct-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
    "  proof-forge --emit-evm-abi-aggregate-ir-yul [-o output.yul]",
    "  proof-forge --emit-evm-abi-aggregate-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]",
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
    "  proof-forge --emit-counter-ir-sbpf [-o output.s] [--artifact-output file]",
    "  proof-forge --emit-control-ir-sbpf [-o output.s] [--artifact-output file]",
    "  proof-forge --emit-solana-sdk-sbpf [-o output.s] [--artifact-output file]",
    "  proof-forge --solana-elf [-o output.so] [--artifact-output file] [--solana-sbpf-arch v0|v3]",
    "  proof-forge --solana-system-cpi-elf [-o output.so] [--artifact-output file] [--solana-sbpf-arch v0|v3]",
    "  proof-forge --solana-system-create-account-cpi-elf [-o output.so] [--artifact-output file] [--solana-sbpf-arch v0|v3]",
    "  proof-forge --solana-spl-token-transfer-cpi-elf [-o output.so] [--artifact-output file] [--solana-sbpf-arch v0|v3]",
    "  proof-forge --emit-sbpf-asm [-o output.s] [--artifact-output file]",
    "",
    "EVM bytecode mode reads <contract>.evm-methods by default and uses Foundry `cast sig` plus `solc --strict-assembly`.",
    "`--evm-chain-profile <id>` records deployment profile metadata in the EVM deploy manifest without broadcasting transactions.",
    "`--evm-constructor-param name:type` records static-word constructor ABI schema metadata for an ABI-encoded constructor args blob.",
    "`--evm-constructor-arg name=value` ABI-encodes one typed constructor value using the declared constructor schema.",
    "`--evm-constructor-args-hex <hex>` appends ABI-encoded constructor arguments to generated EVM initcode.",
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
  if s.startsWith "0x" || s.startsWith "0X" then (s.drop 2).toString else s

def lowerHexString (s : String) : String :=
  String.intercalate "" <| s.toList.map fun ch =>
    match ch with
    | 'A' => "a"
    | 'B' => "b"
    | 'C' => "c"
    | 'D' => "d"
    | 'E' => "e"
    | 'F' => "f"
    | _ => ch.toString

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

def repeatString : Nat → String → String
  | 0, _ => ""
  | n+1, s => s ++ repeatString n s

def hexDigit (value : Nat) : String :=
  match value with
  | 0 => "0"
  | 1 => "1"
  | 2 => "2"
  | 3 => "3"
  | 4 => "4"
  | 5 => "5"
  | 6 => "6"
  | 7 => "7"
  | 8 => "8"
  | 9 => "9"
  | 10 => "a"
  | 11 => "b"
  | 12 => "c"
  | 13 => "d"
  | 14 => "e"
  | _ => "f"

partial def natToHex (value : Nat) : String :=
  if value < 16 then
    hexDigit value
  else
    natToHex (value / 16) ++ hexDigit (value % 16)

def byteLimit : Nat → Nat
  | 0 => 1
  | n+1 => 256 * byteLimit n

def fixedHexBytes (byteCount value : Nat) : String :=
  let raw := natToHex value
  repeatString (byteCount * 2 - raw.length) "0" ++ raw

def normalizeConstructorArgsHex (value : String) : Except String String :=
  let hex := stripHexPrefix (trimAsciiString value)
  if hex.isEmpty then
    .ok ""
  else if hex.length % 2 != 0 then
    .error "--evm-constructor-args-hex must have an even number of hex digits"
  else if !hex.all isHexChar then
    .error "--evm-constructor-args-hex must contain only hex digits"
  else
    .ok (lowerHexString hex)

def supportedConstructorAbiTypes : Array String :=
  #["uint256", "uint64", "uint32", "bool", "bytes32", "address"]

def constructorAbiTypeSupported (abiType : String) : Bool :=
  supportedConstructorAbiTypes.contains abiType

def parseConstructorParamSpec (s : String) : Except String ConstructorParamSpec := do
  match s.splitOn ":" with
  | [name, abiType] =>
      let name := trimAsciiString name
      let abiType := trimAsciiString abiType
      if name.isEmpty then
        .error s!"invalid constructor parameter spec '{s}': name is empty"
      else if abiType.isEmpty then
        .error s!"invalid constructor parameter spec '{s}': type is empty"
      else if !constructorAbiTypeSupported abiType then
        let supported := String.intercalate ", " supportedConstructorAbiTypes.toList
        .error s!"unsupported constructor ABI type '{abiType}'; supported static-word types: {supported}"
      else
        .ok { name := name, abiType := abiType }
  | _ =>
      .error s!"invalid constructor parameter spec '{s}', expected name:type"

def parseConstructorValueSpec (s : String) : Except String ConstructorValueSpec := do
  match s.splitOn "=" with
  | [name, value] =>
      let name := trimAsciiString name
      let value := trimAsciiString value
      if name.isEmpty then
        .error s!"invalid constructor argument spec '{s}': name is empty"
      else if value.isEmpty then
        .error s!"invalid constructor argument spec '{s}': value is empty"
      else
        .ok { name := name, value := value }
  | _ =>
      .error s!"invalid constructor argument spec '{s}', expected name=value"

def hexCharValue! : Char → Nat
  | '0' => 0
  | '1' => 1
  | '2' => 2
  | '3' => 3
  | '4' => 4
  | '5' => 5
  | '6' => 6
  | '7' => 7
  | '8' => 8
  | '9' => 9
  | 'a' | 'A' => 10
  | 'b' | 'B' => 11
  | 'c' | 'C' => 12
  | 'd' | 'D' => 13
  | 'e' | 'E' => 14
  | _ => 15

def parseHexNat (value name : String) : Except String Nat :=
  let hex := stripHexPrefix (trimAsciiString value)
  if hex.isEmpty then
    .error s!"{name} must not be empty"
  else if !hex.all isHexChar then
    .error s!"{name} must contain only hex digits"
  else
    .ok (hex.toList.foldl (fun acc ch => acc * 16 + hexCharValue! ch) 0)

def parseUnsignedNat (value name : String) : Except String Nat :=
  let value := trimAsciiString value
  if value.startsWith "0x" || value.startsWith "0X" then
    parseHexNat value name
  else
    match value.toNat? with
    | some n => .ok n
    | none => .error s!"{name} must be an unsigned decimal integer or 0x-prefixed hex integer"

def normalizeExactHexBytes (value name : String) (bytes : Nat) : Except String String :=
  let hex := stripHexPrefix (trimAsciiString value)
  if hex.length != bytes * 2 then
    .error s!"{name} must be exactly {bytes} byte(s)"
  else if !hex.all isHexChar then
    .error s!"{name} must contain only hex digits"
  else
    .ok (lowerHexString hex)

def encodeUintConstructorArg (name value : String) (bytes : Nat) : Except String String := do
  let n ← parseUnsignedNat value s!"constructor argument `{name}`"
  if n < byteLimit bytes then
    .ok (fixedHexBytes 32 n)
  else
    .error s!"constructor argument `{name}` does not fit in uint{bytes * 8}"

def encodeBoolConstructorArg (name value : String) : Except String String :=
  match trimAsciiString value with
  | "true" | "True" | "TRUE" | "1" => .ok (fixedHexBytes 32 1)
  | "false" | "False" | "FALSE" | "0" => .ok (fixedHexBytes 32 0)
  | _ => .error s!"constructor argument `{name}` must be true, false, 1, or 0"

def encodeConstructorValue (param : ConstructorParamSpec) (value : String) : Except String String := do
  match param.abiType with
  | "uint256" => encodeUintConstructorArg param.name value 32
  | "uint64" => encodeUintConstructorArg param.name value 8
  | "uint32" => encodeUintConstructorArg param.name value 4
  | "bool" => encodeBoolConstructorArg param.name value
  | "bytes32" => normalizeExactHexBytes value s!"constructor argument `{param.name}`" 32
  | "address" =>
      let address ← normalizeExactHexBytes value s!"constructor argument `{param.name}`" 20
      .ok (repeatString 24 "0" ++ address)
  | abiType => .error s!"unsupported constructor ABI type '{abiType}'"

def constructorParamExists (params : Array ConstructorParamSpec) (name : String) : Bool :=
  params.any (fun param => param.name == name)

def constructorValueCount (values : Array ConstructorValueSpec) (name : String) : Nat :=
  values.foldl (fun count value => if value.name == name then count + 1 else count) 0

def findConstructorValue? (values : Array ConstructorValueSpec) (name : String) : Option String :=
  values.foldl
    (fun found value =>
      match found with
      | some _ => found
      | none => if value.name == name then some value.value else none)
    none

def validateConstructorValues (params : Array ConstructorParamSpec) (values : Array ConstructorValueSpec) : Except String Unit := do
  for value in values do
    if constructorValueCount values value.name > 1 then
      .error s!"duplicate --evm-constructor-arg for `{value.name}`"
    else if !constructorParamExists params value.name then
      .error s!"--evm-constructor-arg `{value.name}` has no matching --evm-constructor-param"
    else
      pure ()

def encodeConstructorValues (params : Array ConstructorParamSpec) (values : Array ConstructorValueSpec) : Except String String := do
  if params.isEmpty then
    .error "--evm-constructor-arg requires at least one --evm-constructor-param"
  validateConstructorValues params values
  let mut words : Array String := #[]
  for param in params do
    match findConstructorValue? values param.name with
    | some value =>
        let word ← encodeConstructorValue param value
        words := words.push word
    | none =>
        .error s!"missing --evm-constructor-arg for constructor parameter `{param.name}`"
  .ok (String.intercalate "" words.toList)

def validateConstructorSchemaAndArgs (params : Array ConstructorParamSpec) (constructorArgsHex : String) : Except String Unit := do
  let argsHex ← normalizeConstructorArgsHex constructorArgsHex
  if params.isEmpty then
    .ok ()
  else if argsHex.isEmpty then
    .error "--evm-constructor-param requires --evm-constructor-args-hex or matching --evm-constructor-arg values"
  else
    let expectedBytes := params.size * 32
    let actualBytes := argsHex.length / 2
    if actualBytes == expectedBytes then
      .ok ()
    else
      .error s!"constructor ABI schema expects {expectedBytes} bytes ({params.size} static-word parameter(s)), but --evm-constructor-args-hex has {actualBytes} byte(s)"

def finalizeConstructorOptions (opts : CliOptions) : Except String CliOptions := do
  let argsHex ← normalizeConstructorArgsHex opts.evmConstructorArgsHex
  if !opts.evmConstructorValues.isEmpty then
    if !argsHex.isEmpty then
      .error "--evm-constructor-arg cannot be combined with --evm-constructor-args-hex"
    else
      let encoded ← encodeConstructorValues opts.evmConstructorParams opts.evmConstructorValues
      validateConstructorSchemaAndArgs opts.evmConstructorParams encoded
      .ok { opts with
        evmConstructorArgsHex := encoded,
        evmConstructorArgsSource := "--evm-constructor-arg"
      }
  else
    validateConstructorSchemaAndArgs opts.evmConstructorParams argsHex
    .ok { opts with
      evmConstructorArgsHex := argsHex,
      evmConstructorArgsSource := "--evm-constructor-args-hex"
    }

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
          signature? := some sig
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

def sha256HexBytes (hex : String) : IO String := do
  let script := "import hashlib, sys; print(hashlib.sha256(bytes.fromhex(sys.argv[1])).hexdigest())"
  let digest := trimAsciiString (← runProcess "python3" #["-c", script, hex])
  if digest.length == 64 && digest.all isHexChar then
    return digest
  else
    throw <| IO.userError s!"python3 returned invalid SHA-256 digest for constructor args: {digest}"

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

def jsonStringOption : Option String → String
  | some value => jsonString value
  | none => "null"

def defaultArtifactOutput (bytecodeOutput : FilePath) : FilePath :=
  let fileName := FilePath.mk "proof-forge-artifact.json"
  match bytecodeOutput.parent with
  | some parent => parent / fileName
  | none => fileName

def defaultDeployManifestOutput (metadataOutput : FilePath) : FilePath :=
  let fileName := metadataOutput.fileName.getD metadataOutput.toString
  let deployName :=
    if fileName == "proof-forge-artifact.json" then
      "proof-forge-deploy.json"
    else if fileName.endsWith ".proof-forge-artifact.json" then
      s!"{dropEndString fileName ".proof-forge-artifact.json".length}.proof-forge-deploy.json"
    else
      s!"{fileName}.proof-forge-deploy.json"
  let deployFile := FilePath.mk deployName
  match metadataOutput.parent with
  | some parent => parent / deployFile
  | none => deployFile

def defaultInitCodeOutput (bytecodeOutput : FilePath) : FilePath :=
  bytecodeOutput.withExtension "init.bin"

def artifactEntryJson (path : FilePath) : IO String := do
  let (digest, bytes) ← fileDigestAndBytes path
  return jsonObject #[
    ("path", jsonString path.toString),
    ("sha256", jsonString digest),
    ("bytes", toString bytes)
  ]

def optionalArtifactEntryJson : Option FilePath → IO (Option String)
  | some path => do
      let artifact ← artifactEntryJson path
      return some artifact
  | none => return none

def dedupStrings (values : Array String) : Array String :=
  values.foldl (init := #[]) fun acc value =>
    if acc.contains value then acc else acc.push value

partial def pushByteWidthFrom (value width : Nat) : Option Nat :=
  if width > 32 then
    none
  else if value < byteLimit width then
    some width
  else
    pushByteWidthFrom value (width + 1)

def pushByteWidth (value : Nat) : Option Nat :=
  pushByteWidthFrom value 1

def pushDataHex (value : Nat) : Except String String := do
  let some width := pushByteWidth value
    | .error s!"EVM initcode value {value} is too large for PUSH32"
  .ok (fixedHexBytes 1 (0x5f + width) ++ fixedHexBytes width value)

partial def initCodeOffsetWidth (sizePushWidth offsetWidth : Nat) : Except String Nat := do
  let headerBytes := 9 + 2 * sizePushWidth + offsetWidth
  let some requiredWidth := pushByteWidth headerBytes
    | .error s!"EVM initcode header offset {headerBytes} is too large for PUSH32"
  if requiredWidth == offsetWidth then
    .ok offsetWidth
  else
    initCodeOffsetWidth sizePushWidth requiredWidth

def deploymentInitCodeHex (runtimeBytecode constructorArgsHex : String) : Except String String := do
  let runtime := stripHexPrefix (trimAsciiString runtimeBytecode)
  let constructorArgs ← normalizeConstructorArgsHex constructorArgsHex
  if runtime.isEmpty then
    .error "EVM runtime bytecode must be non-empty before initcode generation"
  else if runtime.length % 2 != 0 then
    .error "EVM runtime bytecode hex must have an even number of digits before initcode generation"
  else if !runtime.all isHexChar then
    .error "EVM runtime bytecode must contain only hex digits before initcode generation"
  else
    let runtimeBytes := runtime.length / 2
    let some sizePushWidth := pushByteWidth runtimeBytes
      | .error s!"EVM runtime bytecode length {runtimeBytes} is too large for PUSH32 initcode"
    let offsetWidth ← initCodeOffsetWidth sizePushWidth 1
    let headerBytes := 9 + 2 * sizePushWidth + offsetWidth
    let sizePush ← pushDataHex runtimeBytes
    let offsetPush ← pushDataHex headerBytes
    .ok (sizePush ++ offsetPush ++ "600039" ++ sizePush ++ "6000f3" ++ runtime ++ constructorArgs)

def writeEvmInitCode (bytecodeOutput : FilePath) (constructorArgsHex : String) : IO FilePath := do
  let runtimeBytecode ← IO.FS.readFile bytecodeOutput
  let initCode ←
    match deploymentInitCodeHex runtimeBytecode constructorArgsHex with
    | .ok initCode => pure initCode
    | .error msg => throw <| IO.userError msg
  let initCodeOutput := defaultInitCodeOutput bytecodeOutput
  if let some parent := initCodeOutput.parent then
    IO.FS.createDirAll parent
  IO.FS.writeFile initCodeOutput (initCode ++ "\n")
  IO.println s!"wrote {initCodeOutput} ({initCode.length} hex chars)"
  return initCodeOutput

def moduleCapabilityIds (module : ProofForge.IR.Module) : Array String :=
  dedupStrings (module.capabilities.map fun capability => capability.id)

def valueTypeJson (type : ProofForge.IR.ValueType) : String :=
  jsonString type.name

def entrypointAbiScalarTypeName
    (context : String)
    (type : ProofForge.IR.ValueType) : Except String String :=
  match type with
  | .u32 => .ok "uint32"
  | .u64 => .ok "uint256"
  | .bool => .ok "bool"
  | .hash => .ok "bytes32"
  | .unit | .fixedArray _ _ | .structType _ =>
      .error s!"{context} has unsupported EVM ABI word type `{type.name}`; entrypoint ABI words support U32, U64, Bool, or Hash"

partial def entrypointAbiType
    (module : ProofForge.IR.Module)
    (context : String)
    (type : ProofForge.IR.ValueType) : Except String String := do
  match type with
  | .u32 | .u64 | .bool | .hash =>
      entrypointAbiScalarTypeName context type
  | .unit =>
      .error s!"{context} uses Unit; EVM entrypoint parameters and non-Unit returns must use U32, U64, Bool, Hash, fixed arrays, or flat structs"
  | .fixedArray elementType length => do
      if length == 0 then
        .error s!"{context} uses Array<{elementType.name},0>; EVM entrypoint ABI fixed arrays must have non-zero length"
      let elementAbiType ← entrypointAbiType module s!"{context} fixed-array element" elementType
      .ok s!"{elementAbiType}[{length}]"
  | .structType typeName => do
      let some decl := module.structs.find? fun decl => decl.name == typeName
        | .error s!"{context} uses unknown struct `{typeName}`"
      if decl.fields.isEmpty then
        .error s!"{context} uses empty struct `{typeName}`; EVM entrypoint ABI structs must have at least one field"
      let mut parts := #[]
      for field in decl.fields do
        parts := parts.push (← entrypointAbiScalarTypeName s!"{context} struct `{typeName}` field `{field.id}`" field.type)
      .ok ("(" ++ String.intercalate "," parts.toList ++ ")")

partial def entrypointAbiWordTypes
    (module : ProofForge.IR.Module)
    (context : String)
    (type : ProofForge.IR.ValueType) : Except String (Array String) := do
  match type with
  | .u32 | .u64 | .bool | .hash =>
      .ok #[← entrypointAbiScalarTypeName context type]
  | .unit =>
      .error s!"{context} uses Unit; EVM entrypoint ABI values must use U32, U64, Bool, Hash, fixed arrays, or flat structs"
  | .fixedArray elementType length => do
      if length == 0 then
        .error s!"{context} uses Array<{elementType.name},0>; EVM entrypoint ABI fixed arrays must have non-zero length"
      let elementWords ← entrypointAbiWordTypes module s!"{context} fixed-array element" elementType
      let mut words : Array String := #[]
      for _h : _idx in [0:length] do
        words := words ++ elementWords
      .ok words
  | .structType typeName => do
      let some decl := module.structs.find? fun decl => decl.name == typeName
        | .error s!"{context} uses unknown struct `{typeName}`"
      if decl.fields.isEmpty then
        .error s!"{context} uses empty struct `{typeName}`; EVM entrypoint ABI structs must have at least one field"
      let mut words : Array String := #[]
      for field in decl.fields do
        words := words.push (← entrypointAbiScalarTypeName s!"{context} struct `{typeName}` field `{field.id}`" field.type)
      .ok words

def entrypointAbiValueJson
    (name? : Option String)
    (type : ProofForge.IR.ValueType)
    (abiType : String)
    (wordTypes : Array String) : String :=
  let encoding :=
    if type == .unit then "none" else "abi-static-words"
  let nameFields :=
    match name? with
    | some name => #[("name", jsonString name)]
    | none => #[]
  jsonObject (nameFields ++ #[
    ("type", valueTypeJson type),
    ("irType", valueTypeJson type),
    ("abiType", jsonString abiType),
    ("encoding", jsonString encoding),
    ("wordTypes", jsonStringArray wordTypes),
    ("wordCount", toString wordTypes.size)
  ])

def entrypointParamJson
    (module : ProofForge.IR.Module)
    (entrypointName : String)
    (param : String × ProofForge.IR.ValueType) : Except String (String × Nat × String) := do
  let abiType ← entrypointAbiType module s!"entrypoint `{entrypointName}` parameter `{param.fst}`" param.snd
  let wordTypes ← entrypointAbiWordTypes module s!"entrypoint `{entrypointName}` parameter `{param.fst}`" param.snd
  .ok (abiType, wordTypes.size, entrypointAbiValueJson (some param.fst) param.snd abiType wordTypes)

def entrypointReturnJson
    (module : ProofForge.IR.Module)
    (entrypointName : String)
    (type : ProofForge.IR.ValueType) : Except String (Nat × String) := do
  match type with
  | .unit =>
      .ok (0, entrypointAbiValueJson none type "void" #[])
  | _ => do
      let abiType ← entrypointAbiType module s!"entrypoint `{entrypointName}` return" type
      let wordTypes ← entrypointAbiWordTypes module s!"entrypoint `{entrypointName}` return" type
      .ok (wordTypes.size, entrypointAbiValueJson none type abiType wordTypes)

def entrypointJson (module : ProofForge.IR.Module) (entrypoint : ProofForge.IR.Entrypoint) : Except String String := do
  let mut params := #[]
  let mut paramAbiTypes := #[]
  let mut calldataWords := 0
  for param in entrypoint.params do
    let (abiType, wordCount, paramJson) ← entrypointParamJson module entrypoint.name param
    params := params.push paramJson
    paramAbiTypes := paramAbiTypes.push abiType
    calldataWords := calldataWords + wordCount
  let (returnWords, returnValue) ← entrypointReturnJson module entrypoint.name entrypoint.returns
  let signature := s!"{entrypoint.name}({String.intercalate "," paramAbiTypes.toList})"
  let selectorValue :=
    match entrypoint.selector? with
    | some selector => jsonString selector
    | none => "null"
  .ok <| jsonObject #[
    ("name", jsonString entrypoint.name),
    ("selector", selectorValue),
    ("signature", jsonString signature),
    ("params", jsonArray params),
    ("returns", valueTypeJson entrypoint.returns),
    ("returnValue", returnValue),
    ("calldataWords", toString calldataWords),
    ("returnWords", toString returnWords)
  ]

structure EventAbiField where
  name : String
  irType : ProofForge.IR.ValueType
  abiType : String
  indexed : Bool
  wordTypes : Array String
  deriving BEq, Repr

structure EventAbi where
  name : String
  signature : String
  topic0 : String
  indexedFields : Array EventAbiField
  dataFields : Array EventAbiField
  deriving BEq, Repr

def lowerExceptString (result : Except ProofForge.Backend.Evm.IR.LowerError α) : Except String α :=
  match result with
  | .ok value => .ok value
  | .error err => .error err.render

def liftExceptString (result : Except String α) : IO α :=
  match result with
  | .ok value => pure value
  | .error msg => throw <| IO.userError msg

def eventAbiWordTypeName : ProofForge.IR.ValueType → Except String String
  | .u32 => .ok "uint32"
  | .u64 => .ok "uint64"
  | .bool => .ok "bool"
  | .hash => .ok "bytes32"
  | type => .error s!"event ABI word type must be scalar, got `{type.name}`"

def eventAbiField
    (module : ProofForge.IR.Module)
    (env : ProofForge.Backend.Evm.IR.TypeEnv)
    (eventName : String)
    (indexed : Bool)
    (field : String × ProofForge.IR.Expr) : Except String EventAbiField := do
  let irType ← lowerExceptString <|
    ProofForge.Backend.Evm.IR.inferExprType module env field.snd
  let abiType ← lowerExceptString <|
    ProofForge.Backend.Evm.IR.eventSignatureFieldType module eventName field.fst irType
  let wordTypes ← lowerExceptString <|
    ProofForge.Backend.Evm.IR.abiValueWordTypes module s!"event `{eventName}` field `{field.fst}`" irType
  let mut wordTypeNames : Array String := #[]
  for wordType in wordTypes do
    wordTypeNames := wordTypeNames.push (← eventAbiWordTypeName wordType)
  .ok {
    name := field.fst,
    irType := irType,
    abiType := abiType,
    indexed := indexed,
    wordTypes := wordTypeNames
  }

def eventAbiFieldJson (field : EventAbiField) : String :=
  let encoding :=
    if field.indexed then
      if field.wordTypes.size == 1 then
        "indexed-word"
      else
        "indexed-keccak256"
    else
      "abi-static-words"
  jsonObject #[
    ("name", jsonString field.name),
    ("type", jsonString field.abiType),
    ("irType", valueTypeJson field.irType),
    ("indexed", jsonBool field.indexed),
    ("encoding", jsonString encoding),
    ("wordTypes", jsonStringArray field.wordTypes),
    ("wordCount", toString field.wordTypes.size)
  ]

def eventFieldsWordCount (fields : Array EventAbiField) : Nat :=
  fields.foldl (fun count field => count + field.wordTypes.size) 0

def eventTopic0For (cast signature : String) : IO String := do
  let stdout ← runProcess cast #["keccak", signature]
  let topic := stripHexPrefix (trimAsciiString stdout)
  if topic.length == 64 && isHexString topic then
    return "0x" ++ lowerHexString topic
  else
    throw <| IO.userError s!"cast returned invalid event topic for {signature}: {trimAsciiString stdout}"

def eventAbi
    (cast : String)
    (module : ProofForge.IR.Module)
    (env : ProofForge.Backend.Evm.IR.TypeEnv)
    (name : String)
    (indexedFields dataFields : Array (String × ProofForge.IR.Expr)) : IO EventAbi := do
  let signature ← liftExceptString <| lowerExceptString <|
    ProofForge.Backend.Evm.IR.eventSignature module env name (indexedFields ++ dataFields)
  let topic0 ← eventTopic0For cast signature
  let indexed ← liftExceptString <| indexedFields.foldlM (init := #[]) fun acc field => do
    .ok (acc.push (← eventAbiField module env name true field))
  let data ← liftExceptString <| dataFields.foldlM (init := #[]) fun acc field => do
    .ok (acc.push (← eventAbiField module env name false field))
  return {
    name := name,
    signature := signature,
    topic0 := topic0,
    indexedFields := indexed,
    dataFields := data
  }

def eventAbiJson (event : EventAbi) : String :=
  jsonObject #[
    ("name", jsonString event.name),
    ("signature", jsonString event.signature),
    ("topic0", jsonString event.topic0),
    ("anonymous", "false"),
    ("indexedFields", jsonArray (event.indexedFields.map eventAbiFieldJson)),
    ("dataFields", jsonArray (event.dataFields.map eventAbiFieldJson)),
    ("topics", toString (event.indexedFields.size + 1)),
    ("dataWords", toString (eventFieldsWordCount event.dataFields))
  ]

def mergeEventAbis (left right : Array EventAbi) : Except String (Array EventAbi) :=
  right.foldlM (init := left) fun acc event => do
    match acc.find? (fun existing => existing.signature == event.signature) with
    | none => .ok (acc.push event)
    | some existing =>
        if existing == event then
          .ok acc
        else
          .error s!"conflicting EVM event ABI metadata for signature `{event.signature}`"

mutual
  partial def eventAbisInStatements
      (cast : String)
      (module : ProofForge.IR.Module)
      (env : ProofForge.Backend.Evm.IR.TypeEnv)
      (statements : Array ProofForge.IR.Statement) :
      IO (Array EventAbi × ProofForge.Backend.Evm.IR.TypeEnv) := do
    let mut events : Array EventAbi := #[]
    let mut currentEnv := env
    for statement in statements do
      let (statementEvents, nextEnv) ← eventAbisInStatement cast module currentEnv statement
      events ← liftExceptString <| mergeEventAbis events statementEvents
      currentEnv := nextEnv
    return (events, currentEnv)

  partial def eventAbisInStatement
      (cast : String)
      (module : ProofForge.IR.Module)
      (env : ProofForge.Backend.Evm.IR.TypeEnv) :
      ProofForge.IR.Statement → IO (Array EventAbi × ProofForge.Backend.Evm.IR.TypeEnv)
    | .letBind name type _ => do
        let nextEnv ← liftExceptString <| lowerExceptString <|
          ProofForge.Backend.Evm.IR.addLocal env name type false
        return (#[], nextEnv)
    | .letMutBind name type _ => do
        let nextEnv ← liftExceptString <| lowerExceptString <|
          ProofForge.Backend.Evm.IR.addLocal env name type true
        return (#[], nextEnv)
    | .assign _ _ | .assignOp _ _ _ | .assert _ _ | .assertEq _ _ _ | .return _ =>
        return (#[], env)
    | .effect (.eventEmit name fields) => do
        let event ← eventAbi cast module env name #[] fields
        return (#[event], env)
    | .effect (.eventEmitIndexed name indexedFields dataFields) => do
        let event ← eventAbi cast module env name indexedFields dataFields
        return (#[event], env)
    | .effect _ =>
        return (#[], env)
    | .ifElse _ thenBody elseBody => do
        let (thenEvents, _) ← eventAbisInStatements cast module env thenBody
        let (elseEvents, _) ← eventAbisInStatements cast module env elseBody
        let events ← liftExceptString <| mergeEventAbis thenEvents elseEvents
        return (events, env)
    | .boundedFor indexName _ _ body => do
        let loopEnv ← liftExceptString <| lowerExceptString <|
          ProofForge.Backend.Evm.IR.addLocal env indexName .u32 false
        let (events, _) ← eventAbisInStatements cast module loopEnv body
        return (events, env)
end

def eventAbisForModule (cast : String) (module : ProofForge.IR.Module) : IO (Array EventAbi) := do
  let mut events : Array EventAbi := #[]
  for entrypoint in module.entrypoints do
    let (entrypointEvents, _) ←
      eventAbisInStatements cast module (ProofForge.Backend.Evm.IR.entrypointTypeEnv entrypoint) entrypoint.body
    events ← liftExceptString <| mergeEventAbis events entrypointEvents
  return events

def methodSpecJson (method : MethodSpec) : String :=
  jsonObject #[
    ("selector", jsonString method.selector),
    ("signature", jsonStringOption method.signature?),
    ("fnName", jsonString method.fnName),
    ("argCount", toString method.argCount),
    ("returnsValue", jsonBool method.returnsValue)
  ]

def constructorParamJson (param : ConstructorParamSpec) : String :=
  jsonObject #[
    ("name", jsonString param.name),
    ("type", jsonString param.abiType),
    ("encoding", jsonString "abi-static-word"),
    ("slotBytes", "32")
  ]

def constructorAbiJson (params : Array ConstructorParamSpec) : String :=
  jsonObject #[
    ("params", jsonArray (params.map constructorParamJson)),
    ("encoding", jsonString "abi")
  ]

def targetMetadataJson (metadata : ProofForge.Target.TargetMetadata) : String :=
  jsonObject #[
    ("key", jsonString metadata.key),
    ("value", jsonString metadata.value)
  ]

def capabilityCallJson (call : ProofForge.Target.CapabilityCall) : String :=
  let sourceValue :=
    match call.source? with
    | some source => jsonString source
    | none => "null"
  jsonObject #[
    ("capability", jsonString call.capability.id),
    ("operation", jsonString call.operation),
    ("source", sourceValue),
    ("metadata", jsonArray (call.metadata.map targetMetadataJson))
  ]

def capabilityPlanJson (plan : ProofForge.Target.CapabilityPlan) : String :=
  jsonObject #[
    ("targetId", jsonString plan.targetId),
    ("capabilities", jsonStringArray (dedupStrings (plan.capabilities.map fun capability => capability.id))),
    ("calls", jsonArray (plan.calls.map capabilityCallJson)),
    ("metadata", jsonArray (plan.metadata.map targetMetadataJson))
  ]

def solanaExtensionAccountJson (account : ProofForge.Backend.Solana.Extension.AccountMeta) : String :=
  jsonObject #[
    ("name", jsonString account.name),
    ("access", jsonString account.access),
    ("signer", jsonString account.signer)
  ]

def solanaPdaSeedJson (seed : ProofForge.Backend.Solana.Extension.PdaSeed) : String :=
  jsonObject #[
    ("kind", jsonString seed.kind.id),
    ("value", jsonString seed.value)
  ]

def solanaPdaJson (pda : ProofForge.Backend.Solana.Extension.PdaDerive) : String :=
  jsonObject #[
    ("name", jsonString pda.name),
    ("seeds", jsonStringArray pda.seedValues),
    ("typedSeeds", jsonArray (pda.effectiveSeeds.map solanaPdaSeedJson)),
    ("bump", match pda.bump? with | some bump => jsonString bump | none => "null"),
    ("account", match pda.account? with | some account => jsonString account | none => "null"),
    ("signer", jsonBool pda.signer)
  ]

def solanaCpiJson (cpi : ProofForge.Backend.Solana.Extension.CpiInvoke) : String :=
  jsonObject #[
    ("name", jsonString cpi.name),
    ("program", jsonString cpi.program),
    ("instruction", jsonString cpi.instruction),
    ("accounts", jsonArray (cpi.accounts.map solanaExtensionAccountJson)),
    ("signerSeeds", jsonStringArray cpi.signerSeeds),
    ("protocol", match cpi.protocol? with | some protocol => jsonString protocol | none => "null"),
    ("dataLayout", match cpi.dataLayout? with | some layout => jsonString layout | none => "null"),
    ("lamportsSource",
      match ProofForge.Backend.Solana.Extension.metadataValue? cpi.metadata "solana.cpi.lamports_source" with
      | some value => jsonString value
      | none => "null"),
    ("spaceSource",
      match ProofForge.Backend.Solana.Extension.metadataValue? cpi.metadata "solana.cpi.space_source" with
      | some value => jsonString value
      | none => "null"),
    ("ownerSource",
      match ProofForge.Backend.Solana.Extension.metadataValue? cpi.metadata "solana.cpi.owner" with
      | some value => jsonString value
      | none => "null"),
    ("amountSource",
      match ProofForge.Backend.Solana.Extension.metadataValue? cpi.metadata "solana.cpi.amount_source" with
      | some value => jsonString value
      | none => "null"),
    ("decimals",
      match ProofForge.Backend.Solana.Extension.metadataValue? cpi.metadata "solana.cpi.decimals" with
      | some value => jsonString value
      | none => "null"),
    ("signed", jsonBool cpi.signed)
  ]

def solanaAllocatorJson (allocator : ProofForge.Backend.Solana.Extension.RuntimeAllocator) : String :=
  jsonObject #[
    ("name", jsonString allocator.name),
    ("kind", jsonString allocator.kind),
    ("model", jsonString allocator.model),
    ("heapStart", jsonString allocator.heapStart),
    ("heapBytes", jsonString allocator.heapBytes)
  ]

def solanaPdaActionJson (action : ProofForge.Backend.Solana.Extension.PdaAction) : String :=
  jsonObject #[
    ("entrypoint", jsonString action.entrypoint),
    ("pda", jsonString action.name)
  ]

def solanaCpiActionJson (action : ProofForge.Backend.Solana.Extension.CpiAction) : String :=
  jsonObject #[
    ("entrypoint", jsonString action.entrypoint),
    ("cpi", jsonString action.name)
  ]

def solanaInstructionAccountJson (account : ProofForge.Backend.Solana.Manifest.AccountEntry) : String :=
  jsonObject #[
    ("name", jsonString account.name),
    ("index", toString account.index),
    ("signer", jsonBool account.signer),
    ("writable", jsonBool account.writable),
    ("owner", jsonString account.owner)
  ]

def solanaInstructionParamJson
    (param : ProofForge.Backend.Solana.Manifest.InstructionParamEntry) : String :=
  jsonObject #[
    ("name", jsonString param.name),
    ("type", jsonString param.typeName),
    ("offset", toString param.offset),
    ("byteSize", toString param.byteSize),
    ("encoding", jsonString param.encoding)
  ]

def solanaInstructionJson (instruction : ProofForge.Backend.Solana.Manifest.InstructionEntry) : String :=
  jsonObject #[
    ("name", jsonString instruction.name),
    ("tag", toString instruction.tag),
    ("handler", jsonString instruction.handler),
    ("minDataLen", toString instruction.minDataLen),
    ("accounts", jsonArray (instruction.accounts.map solanaInstructionAccountJson)),
    ("params", jsonArray (instruction.params.map solanaInstructionParamJson))
  ]

def solanaInstructionsJson (module : ProofForge.IR.Module)
    (plan : ProofForge.Target.CapabilityPlan) : String :=
  jsonArray ((ProofForge.Backend.Solana.Manifest.buildInstructionsWithPlan module plan).map solanaInstructionJson)

def solanaExtensionsJson (plan : ProofForge.Target.CapabilityPlan) : String :=
  let extensions := ProofForge.Backend.Solana.Extension.ProgramExtensions.fromPlan plan
  jsonObject #[
    ("allocators", jsonArray (extensions.allocators.map solanaAllocatorJson)),
    ("pdas", jsonArray (extensions.pdas.map solanaPdaJson)),
    ("cpis", jsonArray (extensions.cpis.map solanaCpiJson)),
    ("pdaActions", jsonArray (extensions.pdaActions.map solanaPdaActionJson)),
    ("cpiActions", jsonArray (extensions.cpiActions.map solanaCpiActionJson))
  ]

def contractNameForFixture (fixture : String) : String :=
  if fixture.endsWith ".lean" then
    dropEndString fixture ".lean".length
  else
    fixture

def resolveEvmChainProfile? (profileId? : Option String) : IO (Option ProofForge.Target.EvmChainProfile) := do
  match profileId? with
  | none => return none
  | some profileId =>
      match ProofForge.Target.findEvmChainProfile? profileId with
      | some profile => return some profile
      | none =>
          let known := String.intercalate ", " ProofForge.Target.knownEvmChainProfileIds.toList
          throw <| IO.userError s!"unknown EVM chain profile `{profileId}`; known profiles: {known}"

def evmChainProfileJson (profile : ProofForge.Target.EvmChainProfile) : String :=
  jsonObject #[
    ("id", jsonString profile.id),
    ("targetId", jsonString profile.targetId),
    ("networkName", jsonString profile.networkName),
    ("chainId", toString profile.chainId),
    ("nativeCurrencySymbol", jsonString profile.nativeCurrencySymbol),
    ("rollupFamily", jsonStringOption profile.rollupFamily),
    ("dataAvailability", jsonStringOption profile.dataAvailability),
    ("rpcUrls", jsonStringArray profile.rpcUrls),
    ("websocketUrls", jsonStringArray profile.websocketUrls),
    ("sequencerUrls", jsonStringArray profile.sequencerUrls),
    ("blockExplorerUrl", jsonStringOption profile.blockExplorerUrl),
    ("verifier", jsonStringOption profile.verifier),
    ("verifierUrl", jsonStringOption profile.verifierUrl),
    ("notes", jsonStringArray profile.notes)
  ]

def evmChainProfileFieldJson (profile? : Option ProofForge.Target.EvmChainProfile) : String :=
  match profile? with
  | some profile => evmChainProfileJson profile
  | none => "null"

def constructorArgsJson (constructorArgsHex source : String) : IO String := do
  let normalized ←
    match normalizeConstructorArgsHex constructorArgsHex with
    | .ok hex => pure hex
    | .error msg => throw <| IO.userError msg
  if normalized.isEmpty then
    return jsonArray #[]
  else
    let digest ← sha256HexBytes normalized
    return jsonArray #[
      jsonObject #[
        ("encoding", jsonString "abi-encoded"),
        ("hex", jsonString s!"0x{normalized}"),
        ("bytes", toString (normalized.length / 2)),
        ("sha256", jsonString digest),
        ("source", jsonString source)
      ]
    ]

def evmDeploymentJson (profile? : Option ProofForge.Target.EvmChainProfile) : String :=
  let (profileId, chainId, networkName, rpcUrls, blockExplorerUrl, verifier, verifierUrl, reason) :=
    match profile? with
    | some profile =>
        (jsonString profile.id,
          toString profile.chainId,
          jsonString profile.networkName,
          jsonStringArray profile.rpcUrls,
          jsonStringOption profile.blockExplorerUrl,
          jsonStringOption profile.verifier,
          jsonStringOption profile.verifierUrl,
          jsonString "ProofForge emitted a chain-profile-aware deployment plan, but transaction signing and broadcast artifacts are not generated yet.")
    | none =>
        ("null",
          "null",
          "null",
          jsonArray #[],
          "null",
          "null",
          "null",
          jsonString "ProofForge EVM bytecode modes emit deployable initcode and runtime bytecode artifacts, but no EVM chain profile was selected and transaction broadcasting is not generated yet.")
  jsonObject #[
    ("profileId", profileId),
    ("chainId", chainId),
    ("networkName", networkName),
    ("rpcUrls", rpcUrls),
    ("blockExplorerUrl", blockExplorerUrl),
    ("verifier", verifier),
    ("verifierUrl", verifierUrl),
    ("address", "null"),
    ("broadcast", jsonString "not-generated"),
    ("broadcastArtifact", "null"),
    ("reason", reason),
    ("reference", jsonString "scripts/evm/foundry-smoke.sh")
  ]

def writeEvmDeployManifest
    (deployOutput : FilePath)
    (fixture sourceKind sourceModule : String)
    (capabilities : Array String)
    (entrypoints : Array String)
    (events : Array String)
    (methods : Array String)
    (chainProfile? : Option ProofForge.Target.EvmChainProfile)
    (constructorParams : Array ConstructorParamSpec)
    (sourceArtifact? : Option String)
    (yulArtifact bytecodeArtifact initCodeArtifact constructorArgs : String) : IO Unit := do
  let mut inputFields : Array (String × String) := #[
    ("yul", yulArtifact),
    ("bytecode", bytecodeArtifact),
    ("initCode", initCodeArtifact)
  ]
  if let some sourceArtifact := sourceArtifact? then
    inputFields := inputFields.push ("source", sourceArtifact)
  let manifest := jsonObject #[
    ("schemaVersion", "1"),
    ("kind", jsonString "proof-forge-evm-deploy-manifest"),
    ("target", jsonString "evm"),
    ("targetFamily", jsonString "evm"),
    ("artifactKind", jsonString "evm-initcode-deploy"),
    ("fixture", jsonString fixture),
    ("contractName", jsonString (contractNameForFixture fixture)),
    ("sourceKind", jsonString sourceKind),
    ("irVersion", if sourceKind == "portable-ir" then jsonString "portable-ir-v0" else "null"),
    ("sourceModule", jsonString sourceModule),
    ("chainProfile", evmChainProfileFieldJson chainProfile?),
    ("capabilities", jsonStringArray (dedupStrings capabilities)),
    ("abi", jsonObject #[
      ("constructor", constructorAbiJson constructorParams),
      ("entrypoints", jsonArray entrypoints),
      ("events", jsonArray events),
      ("methods", jsonArray methods)
    ]),
    ("creation", jsonObject #[
      ("mode", jsonString "init-code"),
      ("constructorArgs", constructorArgs),
      ("initCode", initCodeArtifact),
      ("runtimeBytecode", bytecodeArtifact)
    ]),
    ("inputs", jsonObject inputFields),
    ("deployment", evmDeploymentJson chainProfile?)
  ]
  if let some parent := deployOutput.parent then
    IO.FS.createDirAll parent
  IO.FS.writeFile deployOutput (manifest ++ "\n")

def writeEvmArtifactMetadata
    (opts : CliOptions)
    (fixture sourceKind sourceModule : String)
    (capabilities : Array String)
    (entrypoints : Array String)
    (events : Array String)
    (methods : Array String)
    (source? : Option FilePath)
    (yulOutput bytecodeOutput : FilePath) : IO Unit := do
  let metadataOutput := opts.artifactOutput?.getD (defaultArtifactOutput bytecodeOutput)
  let deployOutput := defaultDeployManifestOutput metadataOutput
  let chainProfile? ← resolveEvmChainProfile? opts.evmChainProfile?
  let constructorArgs ← constructorArgsJson opts.evmConstructorArgsHex opts.evmConstructorArgsSource
  let initCodeOutput ← writeEvmInitCode bytecodeOutput opts.evmConstructorArgsHex
  let yulArtifact ← artifactEntryJson yulOutput
  let bytecodeArtifact ← artifactEntryJson bytecodeOutput
  let initCodeArtifact ← artifactEntryJson initCodeOutput
  let sourceArtifact? ← optionalArtifactEntryJson source?
  writeEvmDeployManifest
    deployOutput
    fixture
    sourceKind
    sourceModule
    capabilities
    entrypoints
    events
    methods
    chainProfile?
    opts.evmConstructorParams
    sourceArtifact?
    yulArtifact
    bytecodeArtifact
    initCodeArtifact
    constructorArgs
  let mut artifactFields : Array (String × String) := #[
    ("yul", yulArtifact),
    ("bytecode", bytecodeArtifact),
    ("initCode", initCodeArtifact),
    ("deployManifest", ← artifactEntryJson deployOutput)
  ]
  if let some sourceArtifact := sourceArtifact? then
    artifactFields := artifactFields.push ("source", sourceArtifact)
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
      ("constructor", constructorAbiJson opts.evmConstructorParams),
      ("entrypoints", jsonArray entrypoints),
      ("events", jsonArray events),
      ("methods", jsonArray methods)
    ]),
    ("artifacts", jsonObject artifactFields),
    ("validation", jsonObject #[
      ("solcStrictAssembly", jsonString "passed"),
      ("bytecodeGeneration", jsonString "passed"),
      ("initCodeGeneration", jsonString "passed"),
      ("deployManifest", jsonString "passed")
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
    (yulOutput bytecodeOutput : FilePath) : IO Unit := do
  let events ← eventAbisForModule opts.cast module
  let mut entrypoints := #[]
  for entrypoint in module.entrypoints do
    entrypoints := entrypoints.push (← liftExceptString (entrypointJson module entrypoint))
  writeEvmArtifactMetadata
    opts
    fixture
    "portable-ir"
    sourceModule
    (moduleCapabilityIds module)
    entrypoints
    (events.map eventAbiJson)
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
    #[]
    (methods.map methodSpecJson)
    (some input)
    yulOutput
    bytecodeOutput

partial def parseArgs : List String → CliOptions → Except String CliOptions
  | [], opts =>
      let hasRunnableInput := opts.input?.isSome || opts.mode.hasBuiltInFixture
      if opts.evmChainProfile?.isSome && !opts.mode.emitsEvmDeployManifest then
        .error "--evm-chain-profile only applies to EVM bytecode modes that emit proof-forge-deploy.json"
      else if !opts.evmConstructorArgsHex.isEmpty && !opts.mode.emitsEvmDeployManifest then
        .error "--evm-constructor-args-hex only applies to EVM bytecode modes that emit proof-forge-deploy.json"
      else if !opts.evmConstructorParams.isEmpty && !opts.mode.emitsEvmDeployManifest then
        .error "--evm-constructor-param only applies to EVM bytecode modes that emit proof-forge-deploy.json"
      else if !opts.evmConstructorValues.isEmpty && !opts.mode.emitsEvmDeployManifest then
        .error "--evm-constructor-arg only applies to EVM bytecode modes that emit proof-forge-deploy.json"
      else
        match finalizeConstructorOptions opts with
        | .ok opts => if hasRunnableInput then .ok opts else .error usage
        | .error msg => .error msg
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
  | "--evm-chain-profile" :: profile :: rest, opts =>
      parseArgs rest { opts with evmChainProfile? := some profile }
  | "--evm-constructor-args-hex" :: hex :: rest, opts => do
      let normalized ← normalizeConstructorArgsHex hex
      parseArgs rest { opts with evmConstructorArgsHex := normalized }
  | "--evm-constructor-param" :: param :: rest, opts => do
      let spec ← parseConstructorParamSpec param
      parseArgs rest { opts with evmConstructorParams := opts.evmConstructorParams.push spec }
  | "--evm-constructor-arg" :: value :: rest, opts => do
      let spec ← parseConstructorValueSpec value
      parseArgs rest { opts with evmConstructorValues := opts.evmConstructorValues.push spec }
  | "--solana-sbpf-arch" :: arch :: rest, opts =>
      if arch == "v0" || arch == "v3" then
        parseArgs rest { opts with solanaSbpfArch := arch }
      else
        .error s!"invalid --solana-sbpf-arch '{arch}', expected v0 or v3"
  | "--solana-sbpf-arch" :: [], _ =>
      .error "missing value for --solana-sbpf-arch, expected v0 or v3"
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
  | "--emit-evm-assign-op-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmAssignOpIrYul }
  | "--emit-evm-assign-op-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmAssignOpIrBytecode }
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
  | "--emit-evm-expression-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmExpressionIrYul }
  | "--emit-evm-expression-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmExpressionIrBytecode }
  | "--emit-evm-hash-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmHashIrYul }
  | "--emit-evm-hash-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmHashIrBytecode }
  | "--emit-evm-loop-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmLoopIrYul }
  | "--emit-evm-loop-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmLoopIrBytecode }
  | "--emit-evm-map-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmMapIrYul }
  | "--emit-evm-map-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmMapIrBytecode }
  | "--emit-evm-storage-array-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmStorageArrayIrYul }
  | "--emit-evm-storage-array-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmStorageArrayIrBytecode }
  | "--emit-evm-storage-struct-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmStorageStructIrYul }
  | "--emit-evm-storage-struct-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmStorageStructIrBytecode }
  | "--emit-evm-typed-map-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmTypedMapIrYul }
  | "--emit-evm-typed-map-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmTypedMapIrBytecode }
  | "--emit-evm-typed-storage-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmTypedStorageIrYul }
  | "--emit-evm-typed-storage-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmTypedStorageIrBytecode }
  | "--emit-evm-array-value-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmArrayValueIrYul }
  | "--emit-evm-array-value-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmArrayValueIrBytecode }
  | "--emit-evm-struct-array-value-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmStructArrayValueIrYul }
  | "--emit-evm-struct-array-value-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmStructArrayValueIrBytecode }
  | "--emit-evm-struct-value-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmStructValueIrYul }
  | "--emit-evm-struct-value-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmStructValueIrBytecode }
  | "--emit-evm-abi-aggregate-ir-yul" :: rest, opts =>
      parseArgs rest { opts with mode := .evmAbiAggregateIrYul }
  | "--emit-evm-abi-aggregate-ir-bytecode" :: rest, opts =>
      parseArgs rest { opts with mode := .evmAbiAggregateIrBytecode }
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
  | "--emit-counter-ir-sbpf" :: rest, opts =>
      parseArgs rest { opts with mode := .counterIrSbpf }
  | "--emit-control-ir-sbpf" :: rest, opts =>
      parseArgs rest { opts with mode := .controlIrSbpf }
  | "--emit-solana-sdk-sbpf" :: rest, opts =>
      parseArgs rest { opts with mode := .solanaSdkSbpf }
  | "--solana-elf" :: rest, opts =>
      parseArgs rest { opts with mode := .solanaElf }
  | "--solana-system-cpi-elf" :: rest, opts =>
      parseArgs rest { opts with mode := .solanaSystemCpiElf }
  | "--solana-system-create-account-cpi-elf" :: rest, opts =>
      parseArgs rest { opts with mode := .solanaSystemCreateAccountCpiElf }
  | "--solana-spl-token-transfer-cpi-elf" :: rest, opts =>
      parseArgs rest { opts with mode := .solanaSplTokenTransferCpiElf }
  | "--emit-sbpf-asm" :: rest, opts =>
      parseArgs rest { opts with mode := .sbpfAsm }
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

def compileEvmAssignOpIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmAssignOpProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmAssignOpProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmAssignOpIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmAssignOpProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmAssignOpIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmAssignOpProbe.yul")
  let yul ← renderEvmAssignOpIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmAssignOpProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmAssignOpProbe" "ProofForge.IR.Examples.EvmAssignOpProbe" ProofForge.IR.Examples.EvmAssignOpProbe.module yulOutput output
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
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmContextProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderContextIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmContextProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileContextIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/ContextProbe.yul")
  let yul ← renderContextIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/ContextProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "ContextProbe" "ProofForge.IR.Examples.EvmContextProbe" ProofForge.IR.Examples.EvmContextProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmEventIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EventProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EventProbe.evmModule with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmEventIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EventProbe.evmModule with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmEventIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EventProbe.yul")
  let yul ← renderEvmEventIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EventProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EventProbe" "ProofForge.IR.Examples.EventProbe.evmModule" ProofForge.IR.Examples.EventProbe.evmModule yulOutput output
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

def compileEvmExpressionIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmExpressionProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmExpressionProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmExpressionIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmExpressionProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmExpressionIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmExpressionProbe.yul")
  let yul ← renderEvmExpressionIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmExpressionProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmExpressionProbe" "ProofForge.IR.Examples.EvmExpressionProbe" ProofForge.IR.Examples.EvmExpressionProbe.module yulOutput output
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

def compileEvmLoopIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmLoopProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmLoopProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmLoopIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmLoopProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmLoopIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmLoopProbe.yul")
  let yul ← renderEvmLoopIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmLoopProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmLoopProbe" "ProofForge.IR.Examples.EvmLoopProbe" ProofForge.IR.Examples.EvmLoopProbe.module yulOutput output
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

def compileEvmStorageArrayIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmStorageArrayProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmStorageArrayProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmStorageArrayIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmStorageArrayProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmStorageArrayIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmStorageArrayProbe.yul")
  let yul ← renderEvmStorageArrayIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmStorageArrayProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmStorageArrayProbe" "ProofForge.IR.Examples.EvmStorageArrayProbe" ProofForge.IR.Examples.EvmStorageArrayProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmStorageStructIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmStorageStructProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmStorageStructProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmStorageStructIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmStorageStructProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmStorageStructIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmStorageStructProbe.yul")
  let yul ← renderEvmStorageStructIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmStorageStructProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmStorageStructProbe" "ProofForge.IR.Examples.EvmStorageStructProbe" ProofForge.IR.Examples.EvmStorageStructProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmTypedMapIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmTypedMapProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmTypedMapProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmTypedMapIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmTypedMapProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmTypedMapIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmTypedMapProbe.yul")
  let yul ← renderEvmTypedMapIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmTypedMapProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmTypedMapProbe" "ProofForge.IR.Examples.EvmTypedMapProbe" ProofForge.IR.Examples.EvmTypedMapProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmTypedStorageIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmTypedStorageProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmTypedStorageProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmTypedStorageIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmTypedStorageProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmTypedStorageIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmTypedStorageProbe.yul")
  let yul ← renderEvmTypedStorageIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmTypedStorageProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmTypedStorageProbe" "ProofForge.IR.Examples.EvmTypedStorageProbe" ProofForge.IR.Examples.EvmTypedStorageProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmArrayValueIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmArrayValueProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmArrayValueProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmArrayValueIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmArrayValueProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmArrayValueIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmArrayValueProbe.yul")
  let yul ← renderEvmArrayValueIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmArrayValueProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmArrayValueProbe" "ProofForge.IR.Examples.EvmArrayValueProbe" ProofForge.IR.Examples.EvmArrayValueProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmStructArrayValueIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmStructArrayValueProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmStructArrayValueProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmStructArrayValueIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmStructArrayValueProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmStructArrayValueIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmStructArrayValueProbe.yul")
  let yul ← renderEvmStructArrayValueIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmStructArrayValueProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmStructArrayValueProbe" "ProofForge.IR.Examples.EvmStructArrayValueProbe" ProofForge.IR.Examples.EvmStructArrayValueProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmStructValueIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmStructValueProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmStructValueProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmStructValueIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmStructValueProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmStructValueIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmStructValueProbe.yul")
  let yul ← renderEvmStructValueIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmStructValueProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmStructValueProbe" "ProofForge.IR.Examples.EvmStructValueProbe" ProofForge.IR.Examples.EvmStructValueProbe.module yulOutput output
  IO.println s!"wrote {output} ({bytecode.length} hex chars)"
  return 0

def compileEvmAbiAggregateIrYul (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmAbiAggregateProbe.yul")
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmAbiAggregateProbe.module with
  | .ok yul =>
      writeTextFile output yul
      IO.println s!"wrote {output}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def renderEvmAbiAggregateIrYul : IO String := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.IR.Examples.EvmAbiAggregateProbe.module with
  | .ok yul => return yul
  | .error err => throw <| IO.userError err.render

def compileEvmAbiAggregateIrBytecode (opts : CliOptions) : IO UInt32 := do
  let yulOutput := opts.yulOutput?.getD (FilePath.mk "build/ir/EvmAbiAggregateProbe.yul")
  let yul ← renderEvmAbiAggregateIrYul
  writeTextFile yulOutput yul
  let bytecode ← solcBytecode opts.solc yulOutput
  let output := opts.output?.getD (FilePath.mk "build/ir/EvmAbiAggregateProbe.bin")
  writeTextFile output (bytecode ++ "\n")
  writeEvmIrArtifactMetadata opts "EvmAbiAggregateProbe" "ProofForge.IR.Examples.EvmAbiAggregateProbe" ProofForge.IR.Examples.EvmAbiAggregateProbe.module yulOutput output
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

/-- Write the Solana instruction manifest.toml alongside the emitted .s file.
Returns the path that was written. -/
def writeSbpfManifest (output : FilePath) (module : ProofForge.IR.Module) : IO FilePath := do
  let manifestOutput := match output.parent with
    | some parent => parent / "manifest.toml"
    | none => FilePath.mk "manifest.toml"
  let manifest := ProofForge.Backend.Solana.Manifest.renderManifest module
  IO.FS.writeFile manifestOutput (manifest ++ "\n")
  return manifestOutput

def writeSbpfManifestWithPlan (output : FilePath) (module : ProofForge.IR.Module)
    (plan : ProofForge.Target.CapabilityPlan) : IO FilePath := do
  let manifestOutput := match output.parent with
    | some parent => parent / "manifest.toml"
    | none => FilePath.mk "manifest.toml"
  let manifest := ProofForge.Backend.Solana.Manifest.renderManifestWithPlan module plan
  IO.FS.writeFile manifestOutput (manifest ++ "\n")
  return manifestOutput

def packagePath (root : FilePath) (rel : String) : FilePath :=
  rel.splitOn "/" |>.foldl (init := root) fun acc part =>
    if part.isEmpty then acc else acc / part

def compileCounterIrSbpf (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/solana/Counter.s")
  match ProofForge.Backend.Solana.SbpfAsm.renderModule ProofForge.IR.Examples.Counter.module with
  | .ok source =>
      if let some parent := output.parent then
        IO.FS.createDirAll parent
      writeTextFile output source
      IO.println s!"wrote {output}"
      let manifestOutput ← writeSbpfManifest output ProofForge.IR.Examples.Counter.module
      IO.println s!"wrote {manifestOutput}"
      let metadataOutput := opts.artifactOutput?.getD (defaultArtifactOutput output)
      if let some parent := metadataOutput.parent then
        IO.FS.createDirAll parent
      let sourceArtifact ← artifactEntryJson output
      let manifestArtifact ← artifactEntryJson manifestOutput
      let metadata := jsonObject #[
        ("schemaVersion", "1"),
        ("target", jsonString ProofForge.Backend.Solana.SbpfAsm.targetId),
        ("targetFamily", jsonString "solana"),
        ("artifactKind", jsonString ProofForge.Backend.Solana.SbpfAsm.artifactKind),
        ("fixture", jsonString "counter-ir-sbpf"),
        ("sourceKind", jsonString "portable-ir"),
        ("irVersion", jsonString ProofForge.Backend.Solana.SbpfAsm.irVersion),
        ("sourceModule", jsonString "Counter"),
        ("capabilities", jsonStringArray #["storage.scalar", "account.explicit", "control.conditional"]),
        ("toolchain", jsonObject #[
          ("sbpf", jsonObject #[
            ("path", jsonString "sbpf"),
            ("version", "null")
          ])
        ]),
        ("artifacts", jsonObject #[
          ("sbpfAsm", sourceArtifact),
          ("manifestToml", manifestArtifact)
        ]),
        ("validation", jsonObject #[
          ("sbpfBuild", jsonString "pending"),
          ("sbpfDisassembleRoundtrip", jsonString "pending"),
          ("manifestGeneration", jsonString "passed")
        ])
      ]
      IO.FS.writeFile metadataOutput (metadata ++ "\n")
      IO.println s!"wrote {metadataOutput}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileControlIrSbpf (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/solana/ControlFlowAssertProbe.s")
  match ProofForge.Backend.Solana.SbpfAsm.renderModule ProofForge.IR.Examples.ControlFlowAssertProbe.module with
  | .ok source =>
      if let some parent := output.parent then
        IO.FS.createDirAll parent
      writeTextFile output source
      IO.println s!"wrote {output}"
      let manifestOutput ← writeSbpfManifest output ProofForge.IR.Examples.ControlFlowAssertProbe.module
      IO.println s!"wrote {manifestOutput}"
      let metadataOutput := opts.artifactOutput?.getD (defaultArtifactOutput output)
      if let some parent := metadataOutput.parent then
        IO.FS.createDirAll parent
      let sourceArtifact ← artifactEntryJson output
      let manifestArtifact ← artifactEntryJson manifestOutput
      let metadata := jsonObject #[
        ("schemaVersion", "1"),
        ("target", jsonString ProofForge.Backend.Solana.SbpfAsm.targetId),
        ("targetFamily", jsonString "solana"),
        ("artifactKind", jsonString ProofForge.Backend.Solana.SbpfAsm.artifactKind),
        ("fixture", jsonString "control-ir-sbpf"),
        ("sourceKind", jsonString "portable-ir"),
        ("irVersion", jsonString ProofForge.Backend.Solana.SbpfAsm.irVersion),
        ("sourceModule", jsonString "ControlFlowAssertProbe"),
        ("capabilities", jsonStringArray #["storage.scalar", "account.explicit", "control.conditional", "assertions.check"]),
        ("toolchain", jsonObject #[
          ("sbpf", jsonObject #[
            ("path", jsonString "sbpf"),
            ("version", "null")
          ])
        ]),
        ("artifacts", jsonObject #[
          ("sbpfAsm", sourceArtifact),
          ("manifestToml", manifestArtifact)
        ]),
        ("validation", jsonObject #[
          ("sbpfBuild", jsonString "pending"),
          ("sbpfDisassembleRoundtrip", jsonString "pending"),
          ("manifestGeneration", jsonString "passed"),
          ("molluskRuntime", jsonObject #[
            ("lifecycle", jsonString "pending"),
            ("guardedIncrementSuccess", jsonString "pending"),
            ("guardedIncrementRevert", jsonString "pending"),
            ("equalityGuardSuccess", jsonString "pending"),
            ("equalityGuardRevert", jsonString "pending")
          ])
        ])
      ]
      IO.FS.writeFile metadataOutput (metadata ++ "\n")
      IO.println s!"wrote {metadataOutput}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileSolanaSdkSbpf (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/solana/SolanaVault.s")
  let spec := ProofForge.Solana.Examples.Vault.spec
  let plan ←
    match ProofForge.Target.resolveSpec ProofForge.Target.solanaSbpfAsm spec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError err.render
  match ProofForge.Backend.Solana.SbpfAsm.renderModuleWithPlan spec.module plan with
  | .ok source =>
      if let some parent := output.parent then
        IO.FS.createDirAll parent
      writeTextFile output source
      IO.println s!"wrote {output}"
      let manifestOutput ← writeSbpfManifestWithPlan output spec.module plan
      IO.println s!"wrote {manifestOutput}"
      let metadataOutput := opts.artifactOutput?.getD (defaultArtifactOutput output)
      if let some parent := metadataOutput.parent then
        IO.FS.createDirAll parent
      let sourceArtifact ← artifactEntryJson output
      let manifestArtifact ← artifactEntryJson manifestOutput
      let metadata := jsonObject #[
        ("schemaVersion", "1"),
        ("target", jsonString ProofForge.Backend.Solana.SbpfAsm.targetId),
        ("targetFamily", jsonString "solana"),
        ("artifactKind", jsonString ProofForge.Backend.Solana.SbpfAsm.artifactKind),
        ("fixture", jsonString "solana-sdk-vault-sbpf"),
        ("sourceKind", jsonString "contract-sdk"),
        ("irVersion", jsonString ProofForge.Backend.Solana.SbpfAsm.irVersion),
        ("sourceModule", jsonString spec.name),
        ("capabilities", jsonStringArray (dedupStrings (plan.capabilities.map fun capability => capability.id))),
        ("capabilityPlan", capabilityPlanJson plan),
        ("solanaInstructions", solanaInstructionsJson spec.module plan),
        ("solanaExtensions", solanaExtensionsJson plan),
        ("toolchain", jsonObject #[
          ("sbpf", jsonObject #[
            ("path", jsonString "sbpf"),
            ("version", "null")
          ])
        ]),
        ("artifacts", jsonObject #[
          ("sbpfAsm", sourceArtifact),
          ("manifestToml", manifestArtifact)
        ]),
        ("validation", jsonObject #[
          ("targetRouting", jsonString "passed"),
          ("manifestGeneration", jsonString "passed"),
          ("sbpfBuild", jsonString "pending"),
          ("cpiLowering", jsonString "helper-emitted"),
          ("pdaLowering", jsonString "helper-emitted")
        ])
      ]
      IO.FS.writeFile metadataOutput (metadata ++ "\n")
      IO.println s!"wrote {metadataOutput}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileSolanaElf (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/solana/Counter.so")
  let projectName := match output.fileName with
    | some n => (n.splitOn ".").headD "counter"
    | none => "counter"
  let projectDir := match output.parent with
    | some parent => parent / s!"{projectName}-sbpf-project"
    | none => FilePath.mk s!"{projectName}-sbpf-project"

  match ProofForge.Backend.Solana.Package.renderPackage projectName ProofForge.IR.Examples.Counter.module with
  | .ok pkg =>
      for file in pkg.files do
        let path := packagePath projectDir file.path
        writeTextFile path file.contents
        IO.println s!"wrote {path}"

      let asmSrc := packagePath projectDir pkg.asmPath
      let manifestOutput := packagePath projectDir pkg.manifestPath

      -- Invoke the sbpf toolchain to assemble and link the ELF.
      let _ ← runProcess "sbpf" #["build", "--arch", opts.solanaSbpfArch] (cwd? := some projectDir)

      let builtElf := projectDir / "deploy" / s!"{projectName}.so"
      if ! (← builtElf.pathExists) then
        throw <| IO.userError s!"sbpf build did not produce {builtElf}"

      let elfBytes ← IO.FS.readBinFile builtElf
      if let some parent := output.parent then
        IO.FS.createDirAll parent
      IO.FS.writeBinFile output elfBytes
      IO.println s!"wrote {output}"

      let metadataOutput := opts.artifactOutput?.getD (defaultArtifactOutput output)
      if let some parent := metadataOutput.parent then
        IO.FS.createDirAll parent
      let sourceArtifact ← artifactEntryJson asmSrc
      let manifestArtifact ← artifactEntryJson manifestOutput
      let elfArtifact ← artifactEntryJson output
      let metadata := jsonObject #[
        ("schemaVersion", "1"),
        ("target", jsonString ProofForge.Backend.Solana.SbpfAsm.targetId),
        ("targetFamily", jsonString "solana"),
        ("artifactKind", jsonString ProofForge.Backend.Solana.SbpfAsm.artifactKind),
        ("fixture", jsonString "counter-elf"),
        ("sourceKind", jsonString "portable-ir"),
        ("irVersion", jsonString ProofForge.Backend.Solana.SbpfAsm.irVersion),
        ("sourceModule", jsonString "Counter"),
        ("capabilities", jsonStringArray #["storage.scalar", "account.explicit", "control.conditional"]),
        ("toolchain", jsonObject #[
          ("sbpf", jsonObject #[
            ("path", jsonString "sbpf"),
            ("version", "null"),
            ("arch", jsonString opts.solanaSbpfArch)
          ])
        ]),
        ("artifacts", jsonObject #[
          ("sbpfAsm", sourceArtifact),
          ("manifestToml", manifestArtifact),
          ("solanaElf", elfArtifact)
        ]),
        ("validation", jsonObject #[
          ("sbpfBuild", jsonString "passed"),
          ("sbpfDisassembleRoundtrip", jsonString "pending"),
          ("manifestGeneration", jsonString "passed")
        ])
      ]
      IO.FS.writeFile metadataOutput (metadata ++ "\n")
      IO.println s!"wrote {metadataOutput}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileSolanaSpecElf (opts : CliOptions) (defaultOutput : FilePath)
    (fallbackProjectName fixture : String) (spec : ProofForge.Contract.ContractSpec) :
    IO UInt32 := do
  let output := opts.output?.getD defaultOutput
  let projectName := match output.fileName with
    | some n => (n.splitOn ".").headD fallbackProjectName
    | none => fallbackProjectName
  let projectDir := match output.parent with
    | some parent => parent / s!"{projectName}-sbpf-project"
    | none => FilePath.mk s!"{projectName}-sbpf-project"
  let plan ←
    match ProofForge.Target.resolveSpec ProofForge.Target.solanaSbpfAsm spec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError err.render

  match ProofForge.Backend.Solana.Package.renderPackageForSpec projectName spec with
  | .ok pkg =>
      for file in pkg.files do
        let path := packagePath projectDir file.path
        writeTextFile path file.contents
        IO.println s!"wrote {path}"

      let asmSrc := packagePath projectDir pkg.asmPath
      let manifestOutput := packagePath projectDir pkg.manifestPath
      let _ ← runProcess "sbpf" #["build", "--arch", opts.solanaSbpfArch] (cwd? := some projectDir)

      let builtElf := projectDir / "deploy" / s!"{projectName}.so"
      if ! (← builtElf.pathExists) then
        throw <| IO.userError s!"sbpf build did not produce {builtElf}"

      let elfBytes ← IO.FS.readBinFile builtElf
      if let some parent := output.parent then
        IO.FS.createDirAll parent
      IO.FS.writeBinFile output elfBytes
      IO.println s!"wrote {output}"

      let metadataOutput := opts.artifactOutput?.getD (defaultArtifactOutput output)
      if let some parent := metadataOutput.parent then
        IO.FS.createDirAll parent
      let sourceArtifact ← artifactEntryJson asmSrc
      let manifestArtifact ← artifactEntryJson manifestOutput
      let elfArtifact ← artifactEntryJson output
      let metadata := jsonObject #[
        ("schemaVersion", "1"),
        ("target", jsonString ProofForge.Backend.Solana.SbpfAsm.targetId),
        ("targetFamily", jsonString "solana"),
        ("artifactKind", jsonString ProofForge.Backend.Solana.SbpfAsm.artifactKind),
        ("fixture", jsonString fixture),
        ("sourceKind", jsonString "contract-sdk"),
        ("irVersion", jsonString ProofForge.Backend.Solana.SbpfAsm.irVersion),
        ("sourceModule", jsonString spec.name),
        ("capabilities", jsonStringArray (dedupStrings (plan.capabilities.map fun capability => capability.id))),
        ("capabilityPlan", capabilityPlanJson plan),
        ("solanaInstructions", solanaInstructionsJson spec.module plan),
        ("solanaExtensions", solanaExtensionsJson plan),
        ("toolchain", jsonObject #[
          ("sbpf", jsonObject #[
            ("path", jsonString "sbpf"),
            ("version", "null"),
            ("arch", jsonString opts.solanaSbpfArch)
          ])
        ]),
        ("artifacts", jsonObject #[
          ("sbpfAsm", sourceArtifact),
          ("manifestToml", manifestArtifact),
          ("solanaElf", elfArtifact)
        ]),
        ("validation", jsonObject #[
          ("targetRouting", jsonString "passed"),
          ("manifestGeneration", jsonString "passed"),
          ("sbpfBuild", jsonString "passed"),
          ("liveCpi", jsonString "pending")
        ])
      ]
      IO.FS.writeFile metadataOutput (metadata ++ "\n")
      IO.println s!"wrote {metadataOutput}"
      return 0
  | .error err =>
      throw <| IO.userError err.render

def compileSolanaSystemCpiElf (opts : CliOptions) : IO UInt32 :=
  compileSolanaSpecElf opts
    (FilePath.mk "build/solana/SystemCpi.so")
    "system-cpi"
    "solana-system-cpi-elf"
    ProofForge.Solana.Examples.SystemCpi.spec

def compileSolanaSystemCreateAccountCpiElf (opts : CliOptions) : IO UInt32 :=
  compileSolanaSpecElf opts
    (FilePath.mk "build/solana/SystemCreateAccountCpi.so")
    "system-create-account-cpi"
    "solana-system-create-account-cpi-elf"
    ProofForge.Solana.Examples.SystemCreateAccountCpi.spec

def compileSolanaSplTokenTransferCpiElf (opts : CliOptions) : IO UInt32 :=
  compileSolanaSpecElf opts
    (FilePath.mk "build/solana/SplTokenTransferCheckedCpi.so")
    "spl-token-transfer-cpi"
    "solana-spl-token-transfer-cpi-elf"
    ProofForge.Solana.Examples.SplTokenTransferCheckedCpi.spec

def compileSbpfAsm (opts : CliOptions) : IO UInt32 := do
  let output := opts.output?.getD (FilePath.mk "build/solana/entrypoint.s")
  match ProofForge.Backend.Solana.SbpfAsm.renderCannedEntrypoint with
  | .ok source =>
      if let some parent := output.parent then
        IO.FS.createDirAll parent
      writeTextFile output source
      IO.println s!"wrote {output}"
      let metadataOutput := opts.artifactOutput?.getD (defaultArtifactOutput output)
      if let some parent := metadataOutput.parent then
        IO.FS.createDirAll parent
      let sourceArtifact ← artifactEntryJson output
      let metadata := jsonObject #[
        ("schemaVersion", "1"),
        ("target", jsonString ProofForge.Backend.Solana.SbpfAsm.targetId),
        ("targetFamily", jsonString "solana"),
        ("artifactKind", jsonString ProofForge.Backend.Solana.SbpfAsm.artifactKind),
        ("fixture", jsonString "sbpf-asm-phase0-canned-entrypoint"),
        ("sourceKind", jsonString "portable-ir"),
        ("irVersion", jsonString ProofForge.Backend.Solana.SbpfAsm.irVersion),
        ("capabilities", jsonStringArray #[]),
        ("toolchain", jsonObject #[
          ("sbpf", jsonObject #[
            ("path", jsonString "sbpf"),
            ("version", "null")
          ])
        ]),
        ("artifacts", jsonObject #[
          ("sbpfAsm", sourceArtifact)
        ]),
        ("validation", jsonObject #[
          ("sbpfBuild", jsonString "pending"),
          ("sbpfDisassembleRoundtrip", jsonString "pending")
        ])
      ]
      IO.FS.writeFile metadataOutput (metadata ++ "\n")
      IO.println s!"wrote {metadataOutput}"
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
  | .evmAssignOpIrYul => compileEvmAssignOpIrYul opts
  | .evmAssignOpIrBytecode => compileEvmAssignOpIrBytecode opts
  | .conditionalIrYul => compileConditionalIrYul opts
  | .conditionalIrBytecode => compileConditionalIrBytecode opts
  | .contextIrYul => compileContextIrYul opts
  | .contextIrBytecode => compileContextIrBytecode opts
  | .evmEventIrYul => compileEvmEventIrYul opts
  | .evmEventIrBytecode => compileEvmEventIrBytecode opts
  | .evmCrosscallIrYul => compileEvmCrosscallIrYul opts
  | .evmCrosscallIrBytecode => compileEvmCrosscallIrBytecode opts
  | .evmExpressionIrYul => compileEvmExpressionIrYul opts
  | .evmExpressionIrBytecode => compileEvmExpressionIrBytecode opts
  | .evmHashIrYul => compileEvmHashIrYul opts
  | .evmHashIrBytecode => compileEvmHashIrBytecode opts
  | .evmLoopIrYul => compileEvmLoopIrYul opts
  | .evmLoopIrBytecode => compileEvmLoopIrBytecode opts
  | .evmMapIrYul => compileEvmMapIrYul opts
  | .evmMapIrBytecode => compileEvmMapIrBytecode opts
  | .evmStorageArrayIrYul => compileEvmStorageArrayIrYul opts
  | .evmStorageArrayIrBytecode => compileEvmStorageArrayIrBytecode opts
  | .evmStorageStructIrYul => compileEvmStorageStructIrYul opts
  | .evmStorageStructIrBytecode => compileEvmStorageStructIrBytecode opts
  | .evmTypedMapIrYul => compileEvmTypedMapIrYul opts
  | .evmTypedMapIrBytecode => compileEvmTypedMapIrBytecode opts
  | .evmTypedStorageIrYul => compileEvmTypedStorageIrYul opts
  | .evmTypedStorageIrBytecode => compileEvmTypedStorageIrBytecode opts
  | .evmArrayValueIrYul => compileEvmArrayValueIrYul opts
  | .evmArrayValueIrBytecode => compileEvmArrayValueIrBytecode opts
  | .evmStructArrayValueIrYul => compileEvmStructArrayValueIrYul opts
  | .evmStructArrayValueIrBytecode => compileEvmStructArrayValueIrBytecode opts
  | .evmStructValueIrYul => compileEvmStructValueIrYul opts
  | .evmStructValueIrBytecode => compileEvmStructValueIrBytecode opts
  | .evmAbiAggregateIrYul => compileEvmAbiAggregateIrYul opts
  | .evmAbiAggregateIrBytecode => compileEvmAbiAggregateIrBytecode opts
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
  | .counterIrSbpf => compileCounterIrSbpf opts
  | .controlIrSbpf => compileControlIrSbpf opts
  | .solanaSdkSbpf => compileSolanaSdkSbpf opts
  | .solanaElf => compileSolanaElf opts
  | .solanaSystemCpiElf => compileSolanaSystemCpiElf opts
  | .solanaSystemCreateAccountCpiElf => compileSolanaSystemCreateAccountCpiElf opts
  | .solanaSplTokenTransferCpiElf => compileSolanaSplTokenTransferCpiElf opts
  | .sbpfAsm => compileSbpfAsm opts

end ProofForge.Cli

unsafe def main (args : List String) : IO UInt32 := do
  match ProofForge.Cli.parseArgs args {} with
  | .ok opts => do
      if opts.evmChainProfile?.isSome then
        discard <| ProofForge.Cli.resolveEvmChainProfile? opts.evmChainProfile?
      ProofForge.Cli.compileFile opts
  | .error msg =>
      IO.eprintln msg
      return 1
