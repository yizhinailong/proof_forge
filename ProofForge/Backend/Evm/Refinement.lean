import ProofForge.Backend.Evm.IR
import ProofForge.Backend.Evm.YulSemantics
import ProofForge.Contract.Examples.ValueVault
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

end ProofForge.Backend.Evm.Refinement
