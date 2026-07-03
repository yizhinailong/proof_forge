import ProofForge.Backend.Evm.IR
import ProofForge.Backend.Evm.YulSemantics
import ProofForge.Contract.Examples.ValueVault
import ProofForge.IR.Examples.EvmAbiAggregateProbe
import ProofForge.IR.Examples.EvmExpressionProbe
import ProofForge.IR.Examples.EvmMapProbe
import ProofForge.IR.Examples.EvmStorageStructProbe
import ProofForge.IR.Examples.EvmTypedStorageProbe
import ProofForge.IR.Examples.Counter
import ProofForge.IR.Semantics

namespace ProofForge.Backend.Evm.Refinement

open ProofForge.IR

/-! Refinement scaffolding for the IR -> EVM/Yul path.

This mirrors the NEAR trace-obligation pattern without claiming a full EVM or
Yul semantics yet. The obligations fix observable IR traces for the shared
Counter and ValueVault scenarios, check that generated EVM Yul exposes every
entrypoint needed by those traces, and execute the focused Yul subset to compare
observable return words.
-/

inductive ObservableReturn where
  | none
  | bool (value : Bool)
  | u32 (value : Nat)
  | u64 (value : Nat)
  | hash (a b c d : Nat)
  | words (values : Array Nat)
  deriving Repr, BEq, DecidableEq

structure ObservableStep where
  entrypointName : String
  selector : String
  returnValue : ObservableReturn
  deriving Repr, BEq, DecidableEq

structure TraceCall where
  entrypoint : Entrypoint
  args : Array ProofForge.IR.Semantics.Value := #[]
  evmArgs : Array Nat := #[]
  deriving Repr

structure TraceObligation where
  name : String
  module : Module
  calls : Array TraceCall
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

def unpackHashWord (word : Nat) : ObservableReturn :=
  let limb := ProofForge.Backend.Evm.YulSemantics.twoPow 64
  let a := word / ProofForge.Backend.Evm.YulSemantics.twoPow 192
  let b := (word / ProofForge.Backend.Evm.YulSemantics.twoPow 128) % limb
  let c := (word / ProofForge.Backend.Evm.YulSemantics.twoPow 64) % limb
  let d := word % limb
  .hash a b c d

def observableReturnFromEvmWords (expectedType : ValueType) (words : Array Nat) :
    Except String ObservableReturn :=
  match expectedType, words.toList with
  | .unit, [] => .ok .none
  | .bool, [0] => .ok (.bool false)
  | .bool, [1] => .ok (.bool true)
  | .bool, [_] => .error "EVM Bool return word must be 0 or 1"
  | .u32, [value] =>
      if value <= 4294967295 then
        .ok (.u32 value)
      else
        .error "EVM U32 return word exceeds U32 range"
  | .u64, [value] => .ok (.u64 value)
  | .hash, [word] => .ok (unpackHashWord word)
  | .fixedArray _ _, words => .ok (.words words.toArray)
  | .structType _, words => .ok (.words words.toArray)
  | .unit, _ => .error s!"entrypoint expected `Unit` but returned {words.size} word(s)"
  | _, [] => .error s!"entrypoint expected `{expectedType.name}` but returned no EVM words"
  | _, _ => .error s!"entrypoint expected `{expectedType.name}` but returned {words.size} EVM word(s)"

def runEntrypointObservable (state : ProofForge.IR.Semantics.State) (call : TraceCall) :
    Except String (ProofForge.IR.Semantics.State × ObservableStep) := do
  let entrypoint := call.entrypoint
  let selector ←
    match entrypoint.selector? with
    | some selector => .ok selector
    | none => .error s!"entrypoint `{entrypoint.name}` has no EVM selector metadata"
  let (nextState, result?) ←
    ProofForge.IR.Semantics.runEntrypointWithArgs state entrypoint call.args
  let returnValue ← observableReturn entrypoint.returns result?
  .ok (nextState, { entrypointName := entrypoint.name, selector, returnValue })

def runTraceList : List TraceCall → ProofForge.IR.Semantics.State →
    Except String (ProofForge.IR.Semantics.State × Array ObservableStep)
  | [], state => .ok (state, #[])
  | call :: rest, state => do
      let (nextState, step) ← runEntrypointObservable state call
      let (finalState, steps) ← runTraceList rest nextState
      .ok (finalState, #[step] ++ steps)

def runTrace (calls : Array TraceCall) : Except String (Array ObservableStep) := do
  let (_, steps) ← runTraceList calls.toList ProofForge.IR.Semantics.State.empty
  .ok steps

def TraceObligation.irTraceOk (obligation : TraceObligation) : Bool :=
  match runTrace obligation.calls with
  | .ok actual => actual == obligation.expected
  | .error _ => false

namespace YulSurface

def isNatLiteral (expected : Nat) : Lean.Compiler.Yul.Expr → Bool
  | .lit literal =>
      match literal.kind with
      | .number => literal.value == toString expected
      | .hexNumber | .bool | .string | .hexString => false
  | .ident _ | .call _ _ | .builtin _ _ => false

def isCalldataSelectorExpr : Lean.Compiler.Yul.Expr → Bool
  | .builtin "shr" args =>
      match args.toList with
      | [shift, .builtin "calldataload" loadArgs] =>
          isNatLiteral 224 shift &&
            match loadArgs.toList with
            | [offset] => isNatLiteral 0 offset
            | _ => false
      | _ => false
  | .lit _ | .ident _ | .call _ _ | .builtin _ _ => false

partial def exprCallsFunction (functionName : String) : Lean.Compiler.Yul.Expr → Bool
  | .call name args =>
      name == functionName || args.any (exprCallsFunction functionName)
  | .builtin _ args =>
      args.any (exprCallsFunction functionName)
  | .lit _ | .ident _ => false

mutual
  partial def blockCallsFunction (functionName : String) (block : Lean.Compiler.Yul.Block) : Bool :=
    block.statements.any (statementCallsFunction functionName)

  partial def caseCallsFunction (functionName : String) (case : Lean.Compiler.Yul.Case) : Bool :=
    blockCallsFunction functionName case.body

  partial def statementCallsFunction (functionName : String) : Lean.Compiler.Yul.Statement → Bool
    | .block block => blockCallsFunction functionName block
    | .varDecl _ value? =>
        match value? with
        | some value => exprCallsFunction functionName value
        | none => false
    | .assignment _ value => exprCallsFunction functionName value
    | .exprStmt value => exprCallsFunction functionName value
    | .ifStmt cond body =>
        exprCallsFunction functionName cond || blockCallsFunction functionName body
    | .switchStmt selector cases =>
        exprCallsFunction functionName selector || cases.any (caseCallsFunction functionName)
    | .funcDef _ _ _ body => blockCallsFunction functionName body
    | .forLoop pre cond post body =>
        blockCallsFunction functionName pre ||
          exprCallsFunction functionName cond ||
          blockCallsFunction functionName post ||
          blockCallsFunction functionName body
    | .break | .continue | .leave => false
end

def caseHasSelector (selector : String) (case : Lean.Compiler.Yul.Case) : Bool :=
  match case.value with
  | some literal =>
      match literal.kind with
      | .hexNumber => literal.value == "0x" ++ selector
      | .number | .bool | .string | .hexString => false
  | none => false

def dispatchCaseOk (selector functionName : String) (case : Lean.Compiler.Yul.Case) : Bool :=
  caseHasSelector selector case && caseCallsFunction functionName case

def statementHasDispatchCase (selector functionName : String) : Lean.Compiler.Yul.Statement → Bool
  | .switchStmt dispatchExpr cases =>
      isCalldataSelectorExpr dispatchExpr &&
        cases.any (dispatchCaseOk selector functionName)
  | _ => false

def hasTopLevelFunction (object : Lean.Compiler.Yul.Object) (functionName : String) : Bool :=
  object.code.statements.any fun
    | .funcDef name _ _ _ => name == functionName
    | _ => false

def hasDispatchCase (object : Lean.Compiler.Yul.Object) (selector functionName : String) : Bool :=
  object.code.statements.any (statementHasDispatchCase selector functionName)

def entrypointOk (module : Module) (object : Lean.Compiler.Yul.Object) (entrypoint : Entrypoint) :
    Bool :=
  match entrypoint.selector? with
  | some selector =>
      let functionName := ProofForge.Backend.Evm.IR.yulFunctionName module.name entrypoint.name
      hasTopLevelFunction object functionName && hasDispatchCase object selector functionName
  | none => false

end YulSurface

def TraceObligation.evmYulSurfaceOk (obligation : TraceObligation) : Bool :=
  match ProofForge.Backend.Evm.IR.lowerModule obligation.module with
  | .ok object =>
      obligation.calls.all fun call =>
        YulSurface.entrypointOk obligation.module object call.entrypoint
  | .error _ => false

def runEvmEntrypointObservable
    (object : Lean.Compiler.Yul.Object)
    (storage : ProofForge.Backend.Evm.YulSemantics.WordBindings)
    (call : TraceCall) :
    Except String (ProofForge.Backend.Evm.YulSemantics.WordBindings × ObservableStep) := do
  let entrypoint := call.entrypoint
  let selectorString ←
    match entrypoint.selector? with
    | some selector => .ok selector
    | none => .error s!"entrypoint `{entrypoint.name}` has no EVM selector metadata"
  let selector ← ProofForge.Backend.Evm.YulSemantics.parseHexNat selectorString
  let (nextStorage, returnWords) ←
    ProofForge.Backend.Evm.YulSemantics.runSelectorWithArgs object storage selector call.evmArgs
  let returnValue ← observableReturnFromEvmWords entrypoint.returns returnWords
  .ok (nextStorage, {
    entrypointName := entrypoint.name
    selector := selectorString
    returnValue
  })

def runEvmTraceList
    (object : Lean.Compiler.Yul.Object) :
    List TraceCall → ProofForge.Backend.Evm.YulSemantics.WordBindings →
      Except String (ProofForge.Backend.Evm.YulSemantics.WordBindings × Array ObservableStep)
  | [], storage => .ok (storage, #[])
  | call :: rest, storage => do
      let (nextStorage, step) ← runEvmEntrypointObservable object storage call
      let (finalStorage, steps) ← runEvmTraceList object rest nextStorage
      .ok (finalStorage, #[step] ++ steps)

def runEvmTrace (object : Lean.Compiler.Yul.Object) (calls : Array TraceCall) :
    Except String (Array ObservableStep) := do
  let (_, steps) ← runEvmTraceList object calls.toList []
  .ok steps

def TraceObligation.evmYulTraceOk (obligation : TraceObligation) : Bool :=
  match ProofForge.Backend.Evm.IR.lowerModule obligation.module with
  | .ok object =>
      match runEvmTrace object obligation.calls with
      | .ok actual => actual == obligation.expected
      | .error _ => false
  | .error _ => false

def counterTraceCalls : Array TraceCall := #[
  { entrypoint := ProofForge.IR.Examples.Counter.initializeEntrypoint },
  { entrypoint := ProofForge.IR.Examples.Counter.get },
  { entrypoint := ProofForge.IR.Examples.Counter.increment },
  { entrypoint := ProofForge.IR.Examples.Counter.get }
]

def counterExpectedTrace : Array ObservableStep := #[
  { entrypointName := "initialize", selector := "8129fc1c", returnValue := .none },
  { entrypointName := "get", selector := "6d4ce63c", returnValue := .u64 0 },
  { entrypointName := "increment", selector := "d09de08a", returnValue := .none },
  { entrypointName := "get", selector := "6d4ce63c", returnValue := .u64 1 }
]

def counterTraceObligation : TraceObligation := {
  name := "Counter.initialize-get-increment-get"
  module := ProofForge.IR.Examples.Counter.module
  calls := counterTraceCalls
  expected := counterExpectedTrace
}

def valueVaultSelector? : String → Option String
  | "initialize" => some "fe4b84df"
  | "deposit" => some "b6b55f25"
  | "charge_fee" => some "be168a46"
  | "release" => some "37bdc99b"
  | "snapshot" => some "9711715a"
  | "get_balance" => some "c1cfb99a"
  | "get_net_value" => some "d43f79a2"
  | _ => none

def hydrateValueVaultEntrypoint (entrypoint : Entrypoint) : Entrypoint :=
  match valueVaultSelector? entrypoint.name with
  | some selector => { entrypoint with selector? := some selector }
  | none => entrypoint

def valueVaultEvmModule : Module :=
  let module := ProofForge.Contract.Examples.ValueVault.module
  { module with entrypoints := module.entrypoints.map hydrateValueVaultEntrypoint }

def missingEntrypoint (name : String) : Entrypoint := {
  name := name
  body := #[]
}

def entrypointByName (module : Module) (name : String) : Entrypoint :=
  (module.entrypoints.find? fun entrypoint => entrypoint.name == name).getD
    (missingEntrypoint name)

def valueVaultEntrypoint (name : String) : Entrypoint :=
  entrypointByName valueVaultEvmModule name

def irU64 (value : Nat) : ProofForge.IR.Semantics.Value :=
  .u64 value

def valueVaultTraceCalls : Array TraceCall := #[
  { entrypoint := valueVaultEntrypoint "initialize", args := #[irU64 100], evmArgs := #[100] },
  { entrypoint := valueVaultEntrypoint "get_balance" },
  { entrypoint := valueVaultEntrypoint "deposit", args := #[irU64 25], evmArgs := #[25] },
  { entrypoint := valueVaultEntrypoint "get_balance" },
  { entrypoint := valueVaultEntrypoint "charge_fee", args := #[irU64 100, irU64 250], evmArgs := #[100, 250] },
  { entrypoint := valueVaultEntrypoint "get_balance" },
  { entrypoint := valueVaultEntrypoint "get_net_value" },
  { entrypoint := valueVaultEntrypoint "release", args := #[irU64 23], evmArgs := #[23] },
  { entrypoint := valueVaultEntrypoint "get_balance" },
  { entrypoint := valueVaultEntrypoint "snapshot" },
  { entrypoint := valueVaultEntrypoint "get_net_value" }
]

def valueVaultExpectedTrace : Array ObservableStep := #[
  { entrypointName := "initialize", selector := "fe4b84df", returnValue := .none },
  { entrypointName := "get_balance", selector := "c1cfb99a", returnValue := .u64 100 },
  { entrypointName := "deposit", selector := "b6b55f25", returnValue := .none },
  { entrypointName := "get_balance", selector := "c1cfb99a", returnValue := .u64 125 },
  { entrypointName := "charge_fee", selector := "be168a46", returnValue := .none },
  { entrypointName := "get_balance", selector := "c1cfb99a", returnValue := .u64 223 },
  { entrypointName := "get_net_value", selector := "d43f79a2", returnValue := .u64 221 },
  { entrypointName := "release", selector := "37bdc99b", returnValue := .none },
  { entrypointName := "get_balance", selector := "c1cfb99a", returnValue := .u64 200 },
  { entrypointName := "snapshot", selector := "9711715a", returnValue := .u64 200 },
  { entrypointName := "get_net_value", selector := "d43f79a2", returnValue := .u64 198 }
]

def valueVaultTraceObligation : TraceObligation := {
  name := "ValueVault.testkit-scenario"
  module := valueVaultEvmModule
  calls := valueVaultTraceCalls
  expected := valueVaultExpectedTrace
}

def expressionTraceCalls : Array TraceCall := #[
  { entrypoint := ProofForge.IR.Examples.EvmExpressionProbe.arithmeticU64 },
  { entrypoint := ProofForge.IR.Examples.EvmExpressionProbe.bitwiseU64 },
  { entrypoint := ProofForge.IR.Examples.EvmExpressionProbe.predicateMatrix },
  {
    entrypoint := ProofForge.IR.Examples.EvmExpressionProbe.castsAndU32
    args := #[.u32 7, .bool true]
    evmArgs := #[7, 1]
  }
]

def expressionExpectedTrace : Array ObservableStep := #[
  { entrypointName := "arithmetic_u64", selector := "139ade38", returnValue := .u64 40 },
  { entrypointName := "bitwise_u64", selector := "2e124ba8", returnValue := .u64 11 },
  { entrypointName := "predicate_matrix", selector := "219a55f8", returnValue := .u64 8 },
  { entrypointName := "casts_and_u32", selector := "555e000e", returnValue := .u64 50 }
]

def expressionTraceObligation : TraceObligation := {
  name := "EvmExpressionProbe.expression-assertion-trace"
  module := ProofForge.IR.Examples.EvmExpressionProbe.module
  calls := expressionTraceCalls
  expected := expressionExpectedTrace
}

/-! The following obligations intentionally exercise EVM/Yul execution only.
    Their IR-side executable semantics is FV-2 work: the current
    `ProofForge.IR.Semantics` model is still scalar-only and does not yet model
    maps, arrays, structs, or aggregate ABI values. -/

def evmMapTraceCalls : Array TraceCall := #[
  { entrypoint := ProofForge.IR.Examples.EvmMapProbe.mapLifecycle },
  { entrypoint := ProofForge.IR.Examples.EvmMapProbe.getSeedBalance },
  {
    entrypoint := ProofForge.IR.Examples.EvmMapProbe.containsBalance
    evmArgs := #[1001]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmMapProbe.upsertBalance
    evmArgs := #[7007, 123]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmMapProbe.readBalance
    evmArgs := #[7007]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmMapProbe.setBalance
    evmArgs := #[7007, 456]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmMapProbe.readBalance
    evmArgs := #[7007]
  },
  { entrypoint := ProofForge.IR.Examples.EvmMapProbe.pathLifecycle },
  { entrypoint := ProofForge.IR.Examples.EvmMapProbe.pathAssignLifecycle },
  { entrypoint := ProofForge.IR.Examples.EvmMapProbe.nestedPathLifecycle },
  {
    entrypoint := ProofForge.IR.Examples.EvmMapProbe.nestedPathDynamic
    evmArgs := #[6006, 7007, 888]
  }
]

def evmMapExpectedTrace : Array ObservableStep := #[
  { entrypointName := "map_lifecycle", selector := "3bb39394", returnValue := .u64 55 },
  { entrypointName := "get_seed_balance", selector := "541be503", returnValue := .u64 55 },
  { entrypointName := "contains_balance", selector := "4c136189", returnValue := .bool true },
  { entrypointName := "upsert_balance", selector := "e1de6ac8", returnValue := .u64 0 },
  { entrypointName := "read_balance", selector := "68eb1eef", returnValue := .u64 123 },
  { entrypointName := "set_balance", selector := "b41d1f5c", returnValue := .none },
  { entrypointName := "read_balance", selector := "68eb1eef", returnValue := .u64 456 },
  { entrypointName := "path_lifecycle", selector := "84c21205", returnValue := .u64 77 },
  { entrypointName := "path_assign_lifecycle", selector := "bce9e77b", returnValue := .u64 58 },
  { entrypointName := "nested_path_lifecycle", selector := "13a524e0", returnValue := .u64 95 },
  { entrypointName := "nested_path_dynamic", selector := "ce6fd7c0", returnValue := .u64 888 }
]

def evmMapTraceObligation : TraceObligation := {
  name := "EvmMapProbe.map-storage-trace"
  module := ProofForge.IR.Examples.EvmMapProbe.module
  calls := evmMapTraceCalls
  expected := evmMapExpectedTrace
}

def evmMapContainsTraceCalls : Array TraceCall := #[
  { entrypoint := ProofForge.IR.Examples.EvmMapProbe.containsLifecycle },
  {
    entrypoint := ProofForge.IR.Examples.EvmMapProbe.containsBalance
    evmArgs := #[1001]
  }
]

def evmMapContainsExpectedTrace : Array ObservableStep := #[
  { entrypointName := "contains_lifecycle", selector := "a0c7a60a", returnValue := .u64 99 },
  { entrypointName := "contains_balance", selector := "4c136189", returnValue := .bool true }
]

def evmMapContainsTraceObligation : TraceObligation := {
  name := "EvmMapProbe.presence-trace"
  module := ProofForge.IR.Examples.EvmMapProbe.module
  calls := evmMapContainsTraceCalls
  expected := evmMapContainsExpectedTrace
}

def typedStorageTraceCalls : Array TraceCall := #[
  { entrypoint := ProofForge.IR.Examples.EvmTypedStorageProbe.boolScalarLifecycle },
  { entrypoint := ProofForge.IR.Examples.EvmTypedStorageProbe.typedArrayLifecycle },
  {
    entrypoint := ProofForge.IR.Examples.EvmTypedStorageProbe.readFlag
    evmArgs := #[0]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmTypedStorageProbe.readFlag
    evmArgs := #[1]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmTypedStorageProbe.readRoot
    evmArgs := #[1]
  },
  { entrypoint := ProofForge.IR.Examples.EvmTypedStorageProbe.pathAssignU32 }
]

def typedStorageExpectedTrace : Array ObservableStep := #[
  { entrypointName := "bool_scalar_lifecycle", selector := "06422075", returnValue := .bool true },
  { entrypointName := "typed_array_lifecycle", selector := "9f3c504b", returnValue := .u64 32 },
  { entrypointName := "read_flag", selector := "afbe1175", returnValue := .bool true },
  { entrypointName := "read_flag", selector := "afbe1175", returnValue := .bool false },
  { entrypointName := "read_root", selector := "4994f441", returnValue := .hash 5 6 7 8 },
  { entrypointName := "path_assign_u32", selector := "5ab2cb77", returnValue := .u64 30 }
]

def typedStorageTraceObligation : TraceObligation := {
  name := "EvmTypedStorageProbe.array-storage-trace"
  module := ProofForge.IR.Examples.EvmTypedStorageProbe.module
  calls := typedStorageTraceCalls
  expected := typedStorageExpectedTrace
}

def storageStructTraceCalls : Array TraceCall := #[
  { entrypoint := ProofForge.IR.Examples.EvmStorageStructProbe.structLifecycle },
  { entrypoint := ProofForge.IR.Examples.EvmStorageStructProbe.pathLifecycle },
  { entrypoint := ProofForge.IR.Examples.EvmStorageStructProbe.arrayStructLifecycle },
  {
    entrypoint := ProofForge.IR.Examples.EvmStorageStructProbe.readPointX
    evmArgs := #[1]
  },
  { entrypoint := ProofForge.IR.Examples.EvmStorageStructProbe.typedSum },
  { entrypoint := ProofForge.IR.Examples.EvmStorageStructProbe.rootValue },
  { entrypoint := ProofForge.IR.Examples.EvmStorageStructProbe.wholeStructWriteSum },
  { entrypoint := ProofForge.IR.Examples.EvmStorageStructProbe.selfStructStorageWrite }
]

def storageStructExpectedTrace : Array ObservableStep := #[
  { entrypointName := "struct_lifecycle", selector := "93ddf147", returnValue := .u64 18 },
  { entrypointName := "path_lifecycle", selector := "84c21205", returnValue := .u64 48 },
  { entrypointName := "array_struct_lifecycle", selector := "2d84bb06", returnValue := .u64 12 },
  { entrypointName := "read_point_x", selector := "db006782", returnValue := .u64 7 },
  { entrypointName := "typed_sum", selector := "2ec467be", returnValue := .u64 34 },
  { entrypointName := "root_value", selector := "c42f8c06", returnValue := .hash 1 2 3 4 },
  { entrypointName := "whole_struct_write_sum", selector := "c1e31e63", returnValue := .u64 70 },
  { entrypointName := "self_struct_storage_write", selector := "696ddaa7", returnValue := .u64 705 }
]

def storageStructTraceObligation : TraceObligation := {
  name := "EvmStorageStructProbe.struct-storage-trace"
  module := ProofForge.IR.Examples.EvmStorageStructProbe.module
  calls := storageStructTraceCalls
  expected := storageStructExpectedTrace
}

def abiAggregateTraceCalls : Array TraceCall := #[
  {
    entrypoint := ProofForge.IR.Examples.EvmAbiAggregateProbe.sumPair
    evmArgs := #[7, 11]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmAbiAggregateProbe.sumArray
    evmArgs := #[2, 3, 5]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmAbiAggregateProbe.sumMatrix
    evmArgs := #[1, 2, 3, 4]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmAbiAggregateProbe.sumPairArray
    evmArgs := #[1, 2, 3, 4]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmAbiAggregateProbe.makePair
    evmArgs := #[13, 21]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmAbiAggregateProbe.makeArray
    evmArgs := #[3, 5, 8]
  },
  {
    entrypoint := ProofForge.IR.Examples.EvmAbiAggregateProbe.makeMatrix
    evmArgs := #[1, 2, 3, 4]
  }
]

def abiAggregateExpectedTrace : Array ObservableStep := #[
  { entrypointName := "sum_pair", selector := "25508e13", returnValue := .u64 18 },
  { entrypointName := "sum_array", selector := "eb353b80", returnValue := .u64 10 },
  { entrypointName := "sum_matrix", selector := "da76e471", returnValue := .u64 10 },
  { entrypointName := "sum_pair_array", selector := "10e4c1da", returnValue := .u64 10 },
  { entrypointName := "make_pair", selector := "ef51ff62", returnValue := .words #[13, 21] },
  { entrypointName := "make_array", selector := "ffac5c16", returnValue := .words #[3, 5, 8] },
  { entrypointName := "make_matrix", selector := "b61c11b8", returnValue := .words #[1, 2, 3, 4] }
]

def abiAggregateTraceObligation : TraceObligation := {
  name := "EvmAbiAggregateProbe.abi-aggregate-trace"
  module := ProofForge.IR.Examples.EvmAbiAggregateProbe.module
  calls := abiAggregateTraceCalls
  expected := abiAggregateExpectedTrace
}

theorem counter_ir_observable_trace_ok :
    counterTraceObligation.irTraceOk = true := by
  native_decide

theorem counter_evm_yul_surface_trace_entrypoints :
    counterTraceObligation.evmYulSurfaceOk = true := by
  native_decide

theorem counter_evm_yul_executable_trace_ok :
    counterTraceObligation.evmYulTraceOk = true := by
  native_decide

theorem value_vault_ir_observable_trace_ok :
    valueVaultTraceObligation.irTraceOk = true := by
  native_decide

theorem value_vault_evm_yul_surface_trace_entrypoints :
    valueVaultTraceObligation.evmYulSurfaceOk = true := by
  native_decide

theorem value_vault_evm_yul_executable_trace_ok :
    valueVaultTraceObligation.evmYulTraceOk = true := by
  native_decide

theorem expression_ir_observable_trace_ok :
    expressionTraceObligation.irTraceOk = true := by
  native_decide

theorem expression_evm_yul_surface_trace_entrypoints :
    expressionTraceObligation.evmYulSurfaceOk = true := by
  native_decide

theorem expression_evm_yul_executable_trace_ok :
    expressionTraceObligation.evmYulTraceOk = true := by
  native_decide

theorem evm_map_yul_surface_trace_entrypoints :
    evmMapTraceObligation.evmYulSurfaceOk = true := by
  native_decide

theorem evm_map_yul_executable_trace_ok :
    evmMapTraceObligation.evmYulTraceOk = true := by
  native_decide

theorem evm_map_contains_yul_surface_trace_entrypoints :
    evmMapContainsTraceObligation.evmYulSurfaceOk = true := by
  native_decide

theorem evm_map_contains_yul_executable_trace_ok :
    evmMapContainsTraceObligation.evmYulTraceOk = true := by
  native_decide

theorem typed_storage_yul_surface_trace_entrypoints :
    typedStorageTraceObligation.evmYulSurfaceOk = true := by
  native_decide

theorem typed_storage_yul_executable_trace_ok :
    typedStorageTraceObligation.evmYulTraceOk = true := by
  native_decide

theorem storage_struct_yul_surface_trace_entrypoints :
    storageStructTraceObligation.evmYulSurfaceOk = true := by
  native_decide

theorem storage_struct_yul_executable_trace_ok :
    storageStructTraceObligation.evmYulTraceOk = true := by
  native_decide

theorem abi_aggregate_yul_surface_trace_entrypoints :
    abiAggregateTraceObligation.evmYulSurfaceOk = true := by
  native_decide

theorem abi_aggregate_yul_executable_trace_ok :
    abiAggregateTraceObligation.evmYulTraceOk = true := by
  native_decide

end ProofForge.Backend.Evm.Refinement
