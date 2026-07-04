import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.IR.Semantics
import ProofForge.IR.Examples.Counter
import ProofForge.Compiler.Wasm.AST
import ProofForge.Contract.Examples.ValueVault

namespace ProofForge.Backend.WasmNear.Refinement

open ProofForge.IR

/-! Refinement scaffolding for the IR -> EmitWat/NEAR Wasm path.

This does not claim a full Wasm instruction semantics yet. It fixes the
observable boundary that later proofs should refine against: a sequence of
exported entrypoint calls and their returned values. The current theorems prove
that the scalar IR semantics produces the expected observable Counter trace and
that EmitWat exposes the entrypoint names used by that trace.
-/

inductive ObservableReturn where
  | none
  | bool (value : Bool)
  | u32 (value : Nat)
  | u64 (value : Nat)
  | hash (a b c d : Nat)
  deriving Repr, BEq, DecidableEq

structure ObservableStep where
  exportName : String
  returnValue : ObservableReturn
  deriving Repr, BEq, DecidableEq

structure TraceObligation where
  name : String
  module : Module
  entrypoints : Array Entrypoint
  expected : Array ObservableStep
  deriving Repr

def observableReturn (expectedType : ValueType) (value? : Option ProofForge.IR.Semantics.Value) :
    Except String ObservableReturn :=
  match expectedType, value? with
  | .unit, none => .ok .none
  | .unit, some .unit => .ok .none
  | .bool, some (.bool value) => .ok (.bool value)
  | .u32, some (.u32 value) => .ok (.u32 value)
  | .u64, some (.u64 value) => .ok (.u64 value)
  | .hash, some (.hash a b c d) => .ok (.hash a b c d)
  | _, none => .error s!"entrypoint expected `{expectedType.name}` but returned no value"
  | _, some _ => .error s!"entrypoint returned a value that does not match `{expectedType.name}`"

def runEntrypointObservable (state : ProofForge.IR.Semantics.State) (entrypoint : Entrypoint) :
    Except String (ProofForge.IR.Semantics.State × ObservableStep) := do
  let (nextState, result?) ← ProofForge.IR.Semantics.runEntrypoint state entrypoint
  let returnValue ← observableReturn entrypoint.returns result?
  .ok (nextState, { exportName := entrypoint.name, returnValue := returnValue })

def runTraceList : List Entrypoint → ProofForge.IR.Semantics.State →
    Except String (ProofForge.IR.Semantics.State × Array ObservableStep)
  | [], state => .ok (state, #[])
  | entrypoint :: rest, state => do
      let (nextState, step) ← runEntrypointObservable state entrypoint
      let (finalState, steps) ← runTraceList rest nextState
      .ok (finalState, #[step] ++ steps)

def runTrace (entrypoints : Array Entrypoint) : Except String (Array ObservableStep) := do
  let (_, steps) ← runTraceList entrypoints.toList ProofForge.IR.Semantics.State.empty
  .ok steps

def TraceObligation.irTraceOk (obligation : TraceObligation) : Bool :=
  match runTrace obligation.entrypoints with
  | .ok actual => actual == obligation.expected
  | .error _ => false

def hasWatExport (wat exportName : String) : Bool :=
  wat.contains s!"(export \"{exportName}\""

def TraceObligation.emitWatExportsOk (obligation : TraceObligation) : Bool :=
  match ProofForge.Backend.WasmNear.EmitWat.renderModule obligation.module with
  | .ok wat => obligation.entrypoints.all (fun entrypoint => hasWatExport wat entrypoint.name)
  | .error _ => false

/-! Artifact-surface obligations.

The first NEAR/Wasm refinement obligation only checked WAT export names.  The
next step toward artifact execution is to inspect the actual Wasm AST produced
by EmitWat and pin the host-boundary calls that the offline host will execute:
entrypoint prologues, storage helper calls, return helper calls, memory export,
and the storage-key data segment.  This is still not a full Wasm semantics, but
it is stronger than a text export check and gives later executable Wasm
obligations a stable AST boundary to refine.
-/

abbrev WasmModule := ProofForge.Compiler.Wasm.Module
abbrev WasmFunc := ProofForge.Compiler.Wasm.Func
abbrev WasmBlock := ProofForge.Compiler.Wasm.Block
abbrev WasmInsn := ProofForge.Compiler.Wasm.Insn

def stringArrayContains (values : Array String) (expected : String) : Bool :=
  values.any (fun value => value == expected)

def callsContainInOrderList : List String → List String → Bool
  | _, [] => true
  | [], _ :: _ => false
  | call :: restCalls, expected :: restExpected =>
      if call == expected then
        callsContainInOrderList restCalls restExpected
      else
        callsContainInOrderList restCalls (expected :: restExpected)

def callsContainInOrder (calls expected : Array String) : Bool :=
  callsContainInOrderList calls.toList expected.toList

mutual
partial def wasmInsnCalls : WasmInsn → Array String
  | .call name => #[name]
  | .block_ body => wasmBlockCalls body
  | .loop_ body => wasmBlockCalls body
  | .if_ thenBody elseBody => wasmBlockCalls thenBody ++ wasmBlockCalls elseBody
  | _ => #[]

partial def wasmBlockCalls (block : WasmBlock) : Array String :=
  block.insns.foldl (fun calls insn => calls ++ wasmInsnCalls insn) #[]
end

def WasmFunc.calls (func : WasmFunc) : Array String :=
  wasmBlockCalls func.body

def findFunc? (mod : WasmModule) (name : String) : Option WasmFunc :=
  mod.funcs.find? (fun func => func.name == name)

def findExportedFunc? (mod : WasmModule) (exportName : String) : Option WasmFunc :=
  mod.funcs.find? (fun func => func.exportName == some exportName)

def importedFunctionNames (mod : WasmModule) : Array String :=
  mod.imports.map (fun import_ => import_.name)

def hasMemoryExport (mod : WasmModule) (exportName : String) : Bool :=
  match mod.memory with
  | some memory => memory.exportName == some exportName
  | none => false

def hasDataSegment (mod : WasmModule) (offset : Nat) (bytes : String) : Bool :=
  mod.dataSegments.any (fun segment => segment.offset == offset && segment.bytes == bytes)

structure WasmCallExpectation where
  functionName : String
  expectedCalls : Array String

structure WasmExportExpectation where
  exportName : String
  expectedCalls : Array String

structure ArtifactSurfaceObligation where
  name : String
  module : Module
  requiredImports : Array String := #[]
  requiredExports : Array WasmExportExpectation := #[]
  requiredFunctions : Array WasmCallExpectation := #[]
  requiredDataSegments : Array (Nat × String) := #[]
  requiredMemoryExport : String := "memory"

def WasmExportExpectation.ok (mod : WasmModule) (expectation : WasmExportExpectation) :
    Bool :=
  match findExportedFunc? mod expectation.exportName with
  | some func => callsContainInOrder func.calls expectation.expectedCalls
  | none => false

def WasmCallExpectation.ok (mod : WasmModule) (expectation : WasmCallExpectation) :
    Bool :=
  match findFunc? mod expectation.functionName with
  | some func => callsContainInOrder func.calls expectation.expectedCalls
  | none => false

def ArtifactSurfaceObligation.ok (obligation : ArtifactSurfaceObligation) : Bool :=
  match ProofForge.Backend.WasmNear.EmitWat.lowerModule obligation.module with
  | .ok wasm =>
      let imports := importedFunctionNames wasm
      obligation.requiredImports.all (stringArrayContains imports) &&
      obligation.requiredExports.all (fun expectation => expectation.ok wasm) &&
      obligation.requiredFunctions.all (fun expectation => expectation.ok wasm) &&
      obligation.requiredDataSegments.all (fun segment => hasDataSegment wasm segment.fst segment.snd) &&
      hasMemoryExport wasm obligation.requiredMemoryExport
  | .error _ => false

/-! Offline-host execution-surface obligations.

The Rust offline host remains an external differential-testing boundary, not
part of the trusted Lean kernel.  This obligation pins the deterministic IO
surface that host execution must expose for a generated EmitWat artifact: the
Borsh/little-endian input bytes passed to each exported entrypoint and the
return fragment that the host prints after executing it.
-/

def hexDigit (value : Nat) : Char :=
  if value < 10 then Char.ofNat ('0'.toNat + value) else Char.ofNat ('a'.toNat + (value - 10))

def byteHex (value : Nat) : String :=
  String.ofList [hexDigit (value / 16 % 16), hexDigit (value % 16)]

def littleEndianHex (byteCount value : Nat) : String :=
  String.intercalate "" <|
    (List.range byteCount).map fun idx => byteHex ((value / (256 ^ idx)) % 256)

def borshValueHex : ProofForge.IR.Semantics.Value → Except String String
  | .unit => .ok ""
  | .bool value => .ok (if value then "01" else "00")
  | .u32 value => .ok (littleEndianHex 4 value)
  | .u64 value => .ok (littleEndianHex 8 value)
  | .hash a b c d =>
      .ok (littleEndianHex 8 a ++ littleEndianHex 8 b ++ littleEndianHex 8 c ++ littleEndianHex 8 d)
  | .array _ => .error "offline-host execution obligation does not yet encode aggregate Borsh input values"
  | .struct _ _ => .error "offline-host execution obligation does not yet encode struct Borsh input values"

def borshArgsHex (args : Array ProofForge.IR.Semantics.Value) : Except String String := do
  let parts ← args.mapM borshValueHex
  .ok (String.intercalate "" parts.toList)

def observableReturnHex : ObservableReturn → String
  | .none => ""
  | .bool value => if value then "01" else "00"
  | .u32 value => littleEndianHex 4 value
  | .u64 value => littleEndianHex 8 value
  | .hash a b c d =>
      littleEndianHex 8 a ++ littleEndianHex 8 b ++ littleEndianHex 8 c ++ littleEndianHex 8 d

def offlineHostReturnFragment : ObservableReturn → String
  | .none => "return=<none>"
  | .bool value => s!"return_hex={observableReturnHex (.bool value)} return_bool={value}"
  | .u32 value => s!"return_hex={observableReturnHex (.u32 value)} return_u32={value}"
  | .u64 value => s!"return_hex={observableReturnHex (.u64 value)} return_u64={value}"
  | .hash a b c d =>
      s!"return_hex={observableReturnHex (.hash a b c d)} return_len=32"

structure OfflineHostExecutionStep where
  exportName : String
  args : Array ProofForge.IR.Semantics.Value := #[]
  deriving Repr

structure OfflineHostIOExpectation where
  exportName : String
  inputHex : String
  returnLineFragment : String
  deriving Repr, BEq

structure OfflineHostExecutionObligation where
  name : String
  artifactSurface : ArtifactSurfaceObligation
  steps : Array OfflineHostExecutionStep
  expectedIO : Array OfflineHostIOExpectation

def findEntrypoint? (mod : Module) (name : String) : Option Entrypoint :=
  mod.entrypoints.find? (fun entrypoint => entrypoint.name == name)

def runOfflineHostExecutionStep
    (state : ProofForge.IR.Semantics.State)
    (mod : Module)
    (step : OfflineHostExecutionStep) :
    Except String (ProofForge.IR.Semantics.State × OfflineHostIOExpectation) := do
  let entrypoint ←
    match findEntrypoint? mod step.exportName with
    | some entrypoint => .ok entrypoint
    | none => .error s!"module `{mod.name}` has no exported entrypoint `{step.exportName}`"
  let inputHex ← borshArgsHex step.args
  let (nextState, result?) ← ProofForge.IR.Semantics.runEntrypointWithArgs state entrypoint step.args
  let returnValue ← observableReturn entrypoint.returns result?
  .ok (nextState, {
    exportName := step.exportName
    inputHex := inputHex
    returnLineFragment := s!"call 1:{step.exportName}: {offlineHostReturnFragment returnValue}"
  })

def runOfflineHostExecutionTraceList (mod : Module) :
    List OfflineHostExecutionStep → ProofForge.IR.Semantics.State →
    Except String (ProofForge.IR.Semantics.State × Array OfflineHostIOExpectation)
  | [], state => .ok (state, #[])
  | step :: rest, state => do
      let (nextState, ioStep) ← runOfflineHostExecutionStep state mod step
      let (finalState, ioSteps) ← runOfflineHostExecutionTraceList mod rest nextState
      .ok (finalState, #[ioStep] ++ ioSteps)

def runOfflineHostExecutionTrace
    (mod : Module)
    (steps : Array OfflineHostExecutionStep) :
    Except String (Array OfflineHostIOExpectation) := do
  let (_, ioSteps) ←
    runOfflineHostExecutionTraceList mod steps.toList ProofForge.IR.Semantics.State.empty
  .ok ioSteps

def OfflineHostExecutionObligation.ioSurfaceOk
    (obligation : OfflineHostExecutionObligation) : Bool :=
  match runOfflineHostExecutionTrace obligation.artifactSurface.module obligation.steps with
  | .ok actual => actual == obligation.expectedIO
  | .error _ => false

def OfflineHostExecutionObligation.ok (obligation : OfflineHostExecutionObligation) : Bool :=
  obligation.artifactSurface.ok && obligation.ioSurfaceOk

def counterTraceEntrypoints : Array Entrypoint := #[
  ProofForge.IR.Examples.Counter.initializeEntrypoint,
  ProofForge.IR.Examples.Counter.get,
  ProofForge.IR.Examples.Counter.increment,
  ProofForge.IR.Examples.Counter.get
]

def counterExpectedTrace : Array ObservableStep := #[
  { exportName := "initialize", returnValue := .none },
  { exportName := "get", returnValue := .u64 0 },
  { exportName := "increment", returnValue := .none },
  { exportName := "get", returnValue := .u64 1 }
]

def counterTraceObligation : TraceObligation := {
  name := "Counter.initialize-get-increment-get"
  module := ProofForge.IR.Examples.Counter.module
  entrypoints := counterTraceEntrypoints
  expected := counterExpectedTrace
}

def counterArtifactSurfaceObligation : ArtifactSurfaceObligation := {
  name := "Counter.EmitWat.artifact-surface"
  module := ProofForge.IR.Examples.Counter.module
  requiredImports := #[
    "input",
    "read_register",
    "storage_read",
    "storage_write",
    "value_return"
  ]
  requiredExports := #[
    { exportName := "initialize", expectedCalls := #["input", "read_register", "__pf_write_u64"] },
    { exportName := "increment", expectedCalls := #["input", "read_register", "__pf_read_u64", "__pf_write_u64"] },
    { exportName := "get", expectedCalls := #["input", "read_register", "__pf_read_u64", "__pf_return_u64"] }
  ]
  requiredFunctions := #[
    { functionName := "__pf_read_u64", expectedCalls := #["storage_read", "read_register"] },
    { functionName := "__pf_write_u64", expectedCalls := #["storage_write"] },
    { functionName := "__pf_return_u64", expectedCalls := #["value_return"] }
  ]
  requiredDataSegments := #[(0, "count")]
}

def counterOfflineHostExecutionObligation : OfflineHostExecutionObligation := {
  name := "Counter.EmitWat.offline-host-execution-surface"
  artifactSurface := counterArtifactSurfaceObligation
  steps := #[
    { exportName := "initialize" },
    { exportName := "get" },
    { exportName := "increment" },
    { exportName := "get" }
  ]
  expectedIO := #[
    {
      exportName := "initialize"
      inputHex := ""
      returnLineFragment := "call 1:initialize: return=<none>"
    },
    {
      exportName := "get"
      inputHex := ""
      returnLineFragment := "call 1:get: return_hex=0000000000000000 return_u64=0"
    },
    {
      exportName := "increment"
      inputHex := ""
      returnLineFragment := "call 1:increment: return=<none>"
    },
    {
      exportName := "get"
      inputHex := ""
      returnLineFragment := "call 1:get: return_hex=0100000000000000 return_u64=1"
    }
  ]
}

def valueVaultArtifactSurfaceObligation : ArtifactSurfaceObligation := {
  name := "ValueVault.EmitWat.artifact-surface"
  module := ProofForge.Contract.Examples.ValueVault.module
  requiredImports := #[
    "input",
    "read_register",
    "storage_read",
    "storage_write",
    "value_return",
    "log_utf8",
    "block_index"
  ]
  requiredExports := #[
    {
      exportName := "initialize"
      expectedCalls := #[
        "input", "read_register", "block_index", "__pf_write_u64",
        "__pf_write_u64", "__pf_write_u64", "__pf_write_u64",
        "__pf_write_u64", "__pf_write_u64", "__pf_evt_log"
      ]
    },
    {
      exportName := "deposit"
      expectedCalls := #[
        "input", "read_register", "__pf_read_u64", "__pf_read_u64",
        "__pf_write_u64", "__pf_write_u64", "__pf_write_u64",
        "__pf_evt_log"
      ]
    },
    {
      exportName := "charge_fee"
      expectedCalls := #[
        "input", "read_register", "__pf_read_u64", "__pf_read_u64",
        "__pf_read_u64", "__pf_write_u64", "__pf_write_u64",
        "__pf_write_u64", "__pf_write_u64", "__pf_evt_log"
      ]
    },
    {
      exportName := "release"
      expectedCalls := #[
        "input", "read_register", "__pf_read_u64", "__pf_read_u64",
        "__pf_read_u64", "__pf_write_u64", "__pf_write_u64",
        "__pf_write_u64", "__pf_write_u64", "__pf_evt_log"
      ]
    },
    {
      exportName := "snapshot"
      expectedCalls := #[
        "input", "read_register", "block_index", "__pf_read_u64",
        "__pf_read_u64", "__pf_read_u64", "__pf_write_u64",
        "__pf_evt_log", "__pf_return_u64"
      ]
    },
    {
      exportName := "get_balance"
      expectedCalls := #["input", "read_register", "__pf_read_u64", "__pf_return_u64"]
    },
    {
      exportName := "get_net_value"
      expectedCalls := #[
        "input", "read_register", "__pf_read_u64", "__pf_read_u64",
        "__pf_return_u64"
      ]
    }
  ]
  requiredFunctions := #[
    { functionName := "__pf_read_u64", expectedCalls := #["storage_read", "read_register"] },
    { functionName := "__pf_write_u64", expectedCalls := #["storage_write"] },
    { functionName := "__pf_return_u64", expectedCalls := #["value_return"] },
    { functionName := "__pf_evt_log", expectedCalls := #["log_utf8"] }
  ]
  requiredDataSegments := #[
    (0, "balance"),
    (8, "released"),
    (17, "fees"),
    (22, "last_value"),
    (33, "last_checkpoint"),
    (49, "operations"),
    (43000, "VaultInitialized"),
    (43036, "ValueDeposited"),
    (43077, "ValueCharged"),
    (43104, "ValueReleased"),
    (43127, "ValueSnapshot")
  ]
}

def valueVaultOfflineHostExecutionObligation : OfflineHostExecutionObligation := {
  name := "ValueVault.EmitWat.offline-host-execution-surface"
  artifactSurface := valueVaultArtifactSurfaceObligation
  steps := #[
    { exportName := "initialize", args := #[.u64 100] },
    { exportName := "get_balance" },
    { exportName := "deposit", args := #[.u64 25] },
    { exportName := "get_balance" },
    { exportName := "charge_fee", args := #[.u64 100, .u64 250] },
    { exportName := "get_balance" },
    { exportName := "get_net_value" },
    { exportName := "release", args := #[.u64 23] },
    { exportName := "get_balance" },
    { exportName := "snapshot" },
    { exportName := "get_net_value" }
  ]
  expectedIO := #[
    {
      exportName := "initialize"
      inputHex := "6400000000000000"
      returnLineFragment := "call 1:initialize: return=<none>"
    },
    {
      exportName := "get_balance"
      inputHex := ""
      returnLineFragment := "call 1:get_balance: return_hex=6400000000000000 return_u64=100"
    },
    {
      exportName := "deposit"
      inputHex := "1900000000000000"
      returnLineFragment := "call 1:deposit: return=<none>"
    },
    {
      exportName := "get_balance"
      inputHex := ""
      returnLineFragment := "call 1:get_balance: return_hex=7d00000000000000 return_u64=125"
    },
    {
      exportName := "charge_fee"
      inputHex := "6400000000000000fa00000000000000"
      returnLineFragment := "call 1:charge_fee: return=<none>"
    },
    {
      exportName := "get_balance"
      inputHex := ""
      returnLineFragment := "call 1:get_balance: return_hex=df00000000000000 return_u64=223"
    },
    {
      exportName := "get_net_value"
      inputHex := ""
      returnLineFragment := "call 1:get_net_value: return_hex=dd00000000000000 return_u64=221"
    },
    {
      exportName := "release"
      inputHex := "1700000000000000"
      returnLineFragment := "call 1:release: return=<none>"
    },
    {
      exportName := "get_balance"
      inputHex := ""
      returnLineFragment := "call 1:get_balance: return_hex=c800000000000000 return_u64=200"
    },
    {
      exportName := "snapshot"
      inputHex := ""
      returnLineFragment := "call 1:snapshot: return_hex=c800000000000000 return_u64=200"
    },
    {
      exportName := "get_net_value"
      inputHex := ""
      returnLineFragment := "call 1:get_net_value: return_hex=c600000000000000 return_u64=198"
    }
  ]
}

theorem counter_ir_observable_trace_ok :
    counterTraceObligation.irTraceOk = true := by
  native_decide

theorem counter_emitwat_exports_trace_entrypoints :
    counterTraceObligation.emitWatExportsOk = true := by
  native_decide

theorem counter_emitwat_artifact_surface_ok :
    counterArtifactSurfaceObligation.ok = true := by
  native_decide

theorem counter_emitwat_offline_host_execution_surface_ok :
    counterOfflineHostExecutionObligation.ok = true := by
  native_decide

theorem value_vault_emitwat_artifact_surface_ok :
    valueVaultArtifactSurfaceObligation.ok = true := by
  native_decide

theorem value_vault_emitwat_offline_host_execution_surface_ok :
    valueVaultOfflineHostExecutionObligation.ok = true := by
  native_decide

end ProofForge.Backend.WasmNear.Refinement
