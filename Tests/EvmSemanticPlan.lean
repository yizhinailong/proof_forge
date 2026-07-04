import ProofForge.Backend.Evm.IR
import ProofForge.IR.Examples.Counter
import ProofForge.IR.Examples.EvmDynamicAbiProbe
import ProofForge.IR.Examples.EvmMapProbe
import ProofForge.IR.Examples.EvmStorageArrayProbe
import ProofForge.IR.Examples.EvmStorageStructProbe
import ProofForge.IR.Examples.EventProbe

namespace ProofForge.Tests.EvmSemanticPlan

open ProofForge.IR
open ProofForge.Backend.Evm.IR
open ProofForge.Backend.Evm.Plan

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some x => pure x
  | none => throw <| IO.userError message

def requireAt {α : Type} (values : Array α) (index : Nat) (message : String) : IO α :=
  match values[index]? with
  | some value => pure value
  | none => throw <| IO.userError message

def requireOk {α : Type} (result : Except LowerError α) (message : String) : IO α :=
  match result with
  | .ok x => pure x
  | .error err => throw <| IO.userError s!"{message}: {err.message}"

def requireValidateOk {α : Type}
    (result : Except ProofForge.Backend.Evm.Validate.LowerError α)
    (message : String) : IO α :=
  match result with
  | .ok x => pure x
  | .error err => throw <| IO.userError s!"{message}: {err.message}"

def testCounterSemanticPlan : IO Unit := do
  let plan ← requireOk (buildSemanticPlan ProofForge.IR.Examples.Counter.module) "counter plan"
  require (plan.name == "Counter") "counter plan name"
  require (plan.targetPlan.targetId == "evm") "counter plan target"
  require (plan.entrypoints.size == 3) "counter plan entrypoint count"
  let init := plan.entrypoints[0]!
  require (init.name == "initialize") "counter plan initialize name"
  require (init.selector == "8129fc1c") "counter plan initialize selector"
  require (init.params.size == 0) "counter plan initialize params"
  require (init.returns.returnType == .unit) "counter plan initialize returns unit"
  require (init.body.size == 1) "counter plan initialize body size"
  match ← requireAt init.body 0 "counter plan initialize missing body" with
  | .effect (.storageScalarWrite stateId (.literalWord value)) => do
      require (stateId == "count") "counter plan initialize storage write state"
      require (value == 0) "counter plan initialize storage write value"
  | _ => throw <| IO.userError "counter plan initialize body must be storage scalar write"
  let inc := plan.entrypoints[1]!
  require (inc.name == "increment") "counter plan increment name"
  require (inc.body.size == 2) "counter plan increment body size"
  match ← requireAt inc.body 0 "counter plan increment missing first statement" with
  | .letBind name type (.effect (.storageScalarRead stateId)) => do
      require (name == "n") "counter plan increment let name"
      require (type == .u64) "counter plan increment let type"
      require (stateId == "count") "counter plan increment read state"
  | _ => throw <| IO.userError "counter plan increment first statement must read count"
  match ← requireAt inc.body 1 "counter plan increment missing second statement" with
  | .effect (.storageScalarWrite stateId (.checkedArith .add (.local name) (.literalWord value))) => do
      require (stateId == "count") "counter plan increment write state"
      require (name == "n") "counter plan increment add lhs"
      require (value == 1) "counter plan increment add rhs"
  | _ => throw <| IO.userError "counter plan increment second statement must write checked add"
  let get := plan.entrypoints[2]!
  require (get.name == "get") "counter plan get name"
  require (get.selector == "6d4ce63c") "counter plan get selector"
  require (get.returns.returnType == .u64) "counter plan get returns u64"
  require (get.returns.wordTypes == #[.u64]) "counter plan get return words"
  require (get.body.size == 1) "counter plan get body size"
  match ← requireAt get.body 0 "counter plan get missing body" with
  | .return (.effect (.storageScalarRead stateId)) =>
      require (stateId == "count") "counter plan get return read state"
  | _ => throw <| IO.userError "counter plan get body must return storage scalar read"
  let storageCount ← requireSome (plan.storage.find? "count") "counter plan missing count storage"
  require (storageCount.slot == 0) "counter plan count slot"
  require (storageCount.span == 1) "counter plan count span"
  require (plan.usesCheckedArithmetic == true) "counter plan checked arithmetic (increment uses add)"
  require (plan.creates.size == 0) "counter plan no creates"
  require (plan.dispatch.entrypoints.size == plan.entrypoints.size) "counter plan dispatch entrypoint count"
  require (plan.dispatch.default == .revert) "counter plan dispatch default"

def testEventSemanticPlan : IO Unit := do
  let plan ← requireOk (buildSemanticPlan ProofForge.IR.Examples.EventProbe.evmModule) "event plan"
  require (plan.entrypoints.size > 0) "event plan entrypoint count"
  require (plan.events.size > 0) "event plan event count"
  let valueEvent? := plan.events.find? (fun ev => ev.name == "ValueEvent")
  require valueEvent?.isSome "event plan missing ValueEvent"
  let valueEvent := valueEvent?.get!
  require (valueEvent.signature == "ValueEvent(uint64)") "event plan ValueEvent signature"
  let fields := valueEvent.fields
  require (fields.size == 1) "event plan ValueEvent field count"
  require (fields[0]!.name == "value") "event plan ValueEvent field name"
  require (fields[0]!.type == .u64) "event plan ValueEvent field type"
  require (fields[0]!.indexed == false) "event plan ValueEvent field not indexed"
  let topicStmts := ProofForge.Backend.Evm.ToYul.eventSignatureTopicStatements valueEvent
  require (topicStmts.size > 0) "event plan-to-yul topic statement count"
  match topicStmts[topicStmts.size - 1]? with
  | some (Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.builtin "keccak256" args))) => do
      match vars[0]? with
      | some var => require (var.name == "_topic0") "event plan-to-yul topic var name"
      | none => throw <| IO.userError "event plan-to-yul missing topic var"
      require (args.size == 2) "event plan-to-yul keccak arg count"
  | _ => throw <| IO.userError "event plan-to-yul topic must end with keccak topic0"
  let indexedEvent ← requireSome
    (plan.events.find? (fun ev => ev.name == "IndexedValue"))
    "event plan missing IndexedValue"
  let indexedField ← requireAt indexedEvent.indexedFields 0 "event plan missing IndexedValue indexed field"
  let indexedTopicStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.eventIndexedTopicStatements
      toYulError
      indexedField
      0
      #[Lean.Compiler.Yul.Expr.num 7])
    "event plan-to-yul indexed scalar topic"
  require (indexedTopicStmts.size == 1) "event plan-to-yul indexed scalar topic statement count"
  match indexedTopicStmts[0]! with
  | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.lit lit)) => do
      match vars[0]? with
      | some var => require (var.name == "_indexed_topic0") "event plan-to-yul indexed scalar topic var"
      | none => throw <| IO.userError "event plan-to-yul indexed scalar topic missing var"
      require (lit.value == "7") "event plan-to-yul indexed scalar topic value"
  | _ => throw <| IO.userError "event plan-to-yul indexed scalar topic must be var decl"
  let aggregateTopicStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.eventIndexedTopicStatements
      toYulError
      (EventFieldPlan.mk "values" (.fixedArray .u64 2) true)
      1
      #[Lean.Compiler.Yul.Expr.num 1, Lean.Compiler.Yul.Expr.num 2])
    "event plan-to-yul indexed aggregate topic"
  require (aggregateTopicStmts.size == 3) "event plan-to-yul indexed aggregate topic statement count"
  match aggregateTopicStmts[2]! with
  | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.builtin "keccak256" args)) => do
      match vars[0]? with
      | some var => require (var.name == "_indexed_topic1") "event plan-to-yul indexed aggregate topic var"
      | none => throw <| IO.userError "event plan-to-yul indexed aggregate topic missing var"
      require (args.size == 2) "event plan-to-yul indexed aggregate keccak arg count"
  | _ => throw <| IO.userError "event plan-to-yul indexed aggregate topic must hash stored words"
  let logStmt ← requireOk
    (ProofForge.Backend.Evm.ToYul.eventLogStatement toYulError indexedEvent 1)
    "event plan-to-yul log statement"
  match logStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin name args) => do
      require (name == "log2") "event plan-to-yul indexed log builtin"
      require (args.size == 4) "event plan-to-yul indexed log arg count"
      match args[3]! with
      | Lean.Compiler.Yul.Expr.ident topicName =>
          require (topicName == "_indexed_topic0") "event plan-to-yul indexed topic arg"
      | _ => throw <| IO.userError "event plan-to-yul indexed log topic must be identifier"
  | _ => throw <| IO.userError "event plan-to-yul log must be expr statement"

def testERC20StandardEventSignatureTypes : IO Unit := do
  let module := ProofForge.IR.Examples.Counter.module
  let transferFrom ← requireValidateOk
    (ProofForge.Backend.Evm.Validate.eventSignatureFieldType module "Transfer" "from" .u64)
    "erc20 Transfer.from event ABI type"
  require (transferFrom == "address") "erc20 Transfer.from must stay address"
  let transferValue ← requireValidateOk
    (ProofForge.Backend.Evm.Validate.eventSignatureFieldType module "Transfer" "value" .u64)
    "erc20 Transfer.value event ABI type"
  require
    (transferValue == "uint256")
    "erc20 Transfer.value must stay Solidity/ERC-20 uint256"
  let approvalOwner ← requireValidateOk
    (ProofForge.Backend.Evm.Validate.eventSignatureFieldType module "Approval" "owner" .u64)
    "erc20 Approval.owner event ABI type"
  require (approvalOwner == "address") "erc20 Approval.owner must stay address"
  let approvalValue ← requireValidateOk
    (ProofForge.Backend.Evm.Validate.eventSignatureFieldType module "Approval" "value" .u64)
    "erc20 Approval.value event ABI type"
  require
    (approvalValue == "uint256")
    "erc20 Approval.value must stay Solidity/ERC-20 uint256"
  let defaultValue ← requireValidateOk
    (ProofForge.Backend.Evm.Validate.eventSignatureFieldType module "ValueEvent" "value" .u64)
    "default event ABI type"
  require (defaultValue == "uint64") "non-ERC20 U64 event fields must stay uint64"

def testArtifactMetadata : IO Unit := do
  let artifactMeta ← requireOk (buildPlanArtifactMetadata ProofForge.IR.Examples.Counter.module) "counter artifact metadata"
  require (artifactMeta.moduleName == "Counter") "counter metadata module name"
  require (artifactMeta.targetId == "evm") "counter metadata target"
  require (artifactMeta.entrypoints.size == 3) "counter metadata entrypoint count"
  let init := artifactMeta.entrypoints[0]!
  require (init.name == "initialize") "counter metadata initialize name"
  require (init.selector == "8129fc1c") "counter metadata initialize selector"

def testDeployMetadata : IO Unit := do
  let deployMeta ← requireOk (buildPlanDeployMetadata ProofForge.IR.Examples.Counter.module) "counter deploy metadata"
  require (deployMeta.moduleName == "Counter") "counter deploy metadata module name"
  require (deployMeta.targetId == "evm") "counter deploy metadata target"
  require (deployMeta.entrypointSelectors.size == 3) "counter deploy metadata selectors"
  let initSel := deployMeta.entrypointSelectors[0]!
  require (initSel.fst == "initialize") "counter deploy metadata initialize name"
  require (initSel.snd == "8129fc1c") "counter deploy metadata initialize selector"

def testEntrypointDispatchPlanToYul : IO Unit := do
  let plan ← requireOk (buildSemanticPlan ProofForge.IR.Examples.Counter.module) "counter plan"
  let getEntrypoint ← requireSome
    (plan.entrypoints.find? (fun entrypoint => entrypoint.name == "get"))
    "counter plan missing get entrypoint"
  let getCase ← requireOk
    (ProofForge.Backend.Evm.ToYul.entrypointDispatchCase
      toYulError
      getEntrypoint
      #[revertStmt])
    "entrypoint dispatch case plan-to-yul"
  match getCase.value with
  | some lit =>
      require (lit.value == "0x6d4ce63c") "entrypoint dispatch case selector literal"
  | none => throw <| IO.userError "entrypoint dispatch case must have selector"
  require (getCase.body.statements.size == 1) "entrypoint dispatch case body statement count"
  let directDispatch :=
    ProofForge.Backend.Evm.ToYul.dispatchPlanStatement
      plan.dispatch
      #[getCase]
  match directDispatch with
  | Lean.Compiler.Yul.Statement.switchStmt (Lean.Compiler.Yul.Expr.builtin name args) cases => do
      require (name == "shr") "entrypoint dispatch block helper selector opcode"
      require (args.size == 2) "entrypoint dispatch block helper selector arg count"
      require (cases.size == 2) "entrypoint dispatch block helper case count"
      let defaultCase ← requireAt cases (cases.size - 1) "entrypoint dispatch block helper missing default case"
      require defaultCase.value.isNone "entrypoint dispatch block helper default case value"
      require (defaultCase.body.statements.size == 1) "entrypoint dispatch block helper revert default size"
  | _ => throw <| IO.userError "entrypoint dispatch block helper must lower static params to selector switch"
  let returnStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.staticDispatchReturnStatements
      toYulError
      #[]
      getEntrypoint.returns
      (Lean.Compiler.Yul.call "Counter_get" #[]))
    "entrypoint static dispatch return plan-to-yul"
  require (returnStmts.size == 3) "entrypoint static dispatch return statement count"
  match returnStmts[0]! with
  | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.call name args)) => do
      require (vars.size == 1) "entrypoint static dispatch return result count"
      match vars[0]? with
      | some var => require (var.name == "_r") "entrypoint static dispatch return result name"
      | none => throw <| IO.userError "entrypoint static dispatch return missing result var"
      require (name == "Counter_get") "entrypoint static dispatch return call name"
      require (args.size == 0) "entrypoint static dispatch return call arg count"
  | _ => throw <| IO.userError "entrypoint static dispatch return must bind call result"
  match returnStmts[2]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin name args) => do
      require (name == "return") "entrypoint static dispatch return builtin"
      require (args.size == 2) "entrypoint static dispatch return arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.lit lit => require (lit.value == "32") "entrypoint static dispatch return byte count"
      | _ => throw <| IO.userError "entrypoint static dispatch return byte count must be literal"
  | _ => throw <| IO.userError "entrypoint static dispatch return must end with return"
  let initEntrypoint ← requireSome
    (plan.entrypoints.find? (fun entrypoint => entrypoint.name == "initialize"))
    "counter plan missing initialize entrypoint"
  let unitReturnStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.staticDispatchReturnStatements
      toYulError
      #[]
      initEntrypoint.returns
      (Lean.Compiler.Yul.call "Counter_initialize" #[]))
    "entrypoint unit dispatch return plan-to-yul"
  require (unitReturnStmts.size == 2) "entrypoint unit dispatch return statement count"
  match unitReturnStmts[1]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin name args) => do
      require (name == "return") "entrypoint unit dispatch return builtin"
      require (args.size == 2) "entrypoint unit dispatch return arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.lit lit => require (lit.value == "0") "entrypoint unit dispatch return byte count"
      | _ => throw <| IO.userError "entrypoint unit dispatch return byte count must be literal"
  | _ => throw <| IO.userError "entrypoint unit dispatch return must end with return"
  let dispatch ← requireOk (dispatchBlock ProofForge.IR.Examples.Counter.module) "counter dispatch block"
  match dispatch with
  | Lean.Compiler.Yul.Statement.switchStmt (Lean.Compiler.Yul.Expr.builtin name args) cases => do
      require (name == "shr") "entrypoint dispatch switch selector opcode"
      require (args.size == 2) "entrypoint dispatch switch selector arg count"
      require (cases.size == plan.entrypoints.size + 1) "entrypoint dispatch switch case count"
  | _ => throw <| IO.userError "entrypoint dispatch block must lower to selector switch"
  let dynamicPlan ← requireOk
    (buildSemanticPlan ProofForge.IR.Examples.EvmDynamicAbiProbe.module)
    "dynamic ABI plan"
  let bytesEntrypoint ← requireSome
    (dynamicPlan.entrypoints.find? (fun entrypoint => entrypoint.name == "echo_bytes"))
    "dynamic ABI plan missing echo_bytes entrypoint"
  let bytesParam ← requireAt bytesEntrypoint.params 0 "dynamic ABI echo_bytes missing param"
  require (bytesParam.headWordIndex == 0) "dynamic ABI bytes param head word index"
  require bytesParam.isDynamic "dynamic ABI bytes param is dynamic"
  let bytesDecodeStmts :=
    ProofForge.Backend.Evm.ToYul.abiParamValidationAndDecodeStatements bytesEntrypoint.params
  require (bytesDecodeStmts.size == 9) "dynamic ABI bytes decode statement count"
  match bytesDecodeStmts[bytesDecodeStmts.size - 1]! with
  | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.ident ptrName)) => do
      match vars[0]? with
      | some var => require (var.name == "data__data_ptr") "dynamic ABI bytes data ptr local"
      | none => throw <| IO.userError "dynamic ABI bytes decode missing data ptr var"
      require (ptrName == "__pf_dyn_ptr_data") "dynamic ABI bytes decode data ptr source"
  | _ => throw <| IO.userError "dynamic ABI bytes decode must end with data ptr var"
  let transferEntrypoint ← requireSome
    (dynamicPlan.entrypoints.find? (fun entrypoint => entrypoint.name == "transfer"))
    "dynamic ABI plan missing transfer entrypoint"
  let transferToParam ← requireAt transferEntrypoint.params 0 "transfer missing to param"
  let transferAmountParam ← requireAt transferEntrypoint.params 1 "transfer missing amount param"
  require (transferToParam.headWordIndex == 0) "transfer to param head word index"
  require (transferAmountParam.headWordIndex == 1) "transfer amount param head word index"
  let transferArgs := ProofForge.Backend.Evm.ToYul.entrypointCallArgs transferEntrypoint.params
  require (transferArgs.size == 2) "transfer plan-to-yul call arg count"
  match transferArgs[1]! with
  | Lean.Compiler.Yul.Expr.builtin name args => do
      require (name == "calldataload") "transfer amount call arg load"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.lit lit => require (lit.value == "36") "transfer amount calldata offset"
      | _ => throw <| IO.userError "transfer amount calldata offset must be literal"
  | _ => throw <| IO.userError "transfer amount call arg must be calldata load"
  match ProofForge.Backend.Evm.ToYul.entrypointCallExpr dynamicPlan.name transferEntrypoint with
  | Lean.Compiler.Yul.Expr.call name args => do
      require (name == "f_EvmDynamicAbiProbe_transfer") "transfer plan-to-yul call name"
      require (args.size == 2) "transfer plan-to-yul call arg count"
  | _ => throw <| IO.userError "transfer plan-to-yul call must be a function call"
  let dynamicDirectDispatch :=
    ProofForge.Backend.Evm.ToYul.dispatchPlanStatement
      dynamicPlan.dispatch
      #[getCase]
  match dynamicDirectDispatch with
  | Lean.Compiler.Yul.Statement.block block => do
      require (block.statements.size == 2) "dynamic dispatch block helper statement count"
      match block.statements[0]! with
      | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin name args) => do
          require (name == "mstore") "dynamic dispatch block helper initializes memory"
          require (args.size == 2) "dynamic dispatch block helper memory init arg count"
      | _ => throw <| IO.userError "dynamic dispatch block helper must start with memory init"
      match block.statements[1]! with
      | Lean.Compiler.Yul.Statement.switchStmt (Lean.Compiler.Yul.Expr.builtin name args) _ => do
          require (name == "shr") "dynamic dispatch block helper selector opcode"
          require (args.size == 2) "dynamic dispatch block helper selector arg count"
      | _ => throw <| IO.userError "dynamic dispatch block helper must end with selector switch"
  | _ => throw <| IO.userError "dynamic dispatch block helper must wrap selector switch"
  let dynamicReturnStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.dynamicDispatchReturnStatements
      toYulError
      #[]
      bytesEntrypoint.returns
      (Lean.Compiler.Yul.call "EvmDynamicAbiProbe_echo_bytes" #[Lean.Compiler.Yul.Expr.id "payload"]))
    "entrypoint dynamic dispatch return plan-to-yul"
  require (dynamicReturnStmts.size == 7) "entrypoint dynamic dispatch return statement count"
  match dynamicReturnStmts[0]! with
  | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.call name args)) => do
      match vars[0]? with
      | some var => require (var.name == "_r") "entrypoint dynamic dispatch return result name"
      | none => throw <| IO.userError "entrypoint dynamic dispatch return missing result var"
      require (name == "EvmDynamicAbiProbe_echo_bytes") "entrypoint dynamic dispatch return call name"
      require (args.size == 1) "entrypoint dynamic dispatch return call arg count"
  | _ => throw <| IO.userError "entrypoint dynamic dispatch return must bind call result"
  match dynamicReturnStmts[5]! with
  | Lean.Compiler.Yul.Statement.forLoop _ (Lean.Compiler.Yul.Expr.builtin name args) _ _ => do
      require (name == "lt") "entrypoint dynamic dispatch return copy loop guard"
      require (args.size == 2) "entrypoint dynamic dispatch return copy loop guard arg count"
  | _ => throw <| IO.userError "entrypoint dynamic dispatch return must copy data with loop"
  let dynamicDispatch ← requireOk
    (dispatchBlock ProofForge.IR.Examples.EvmDynamicAbiProbe.module)
    "dynamic ABI dispatch block"
  match dynamicDispatch with
  | Lean.Compiler.Yul.Statement.block block => do
      require (block.statements.size == 2) "dynamic ABI dispatch block statement count"
      match block.statements[1]! with
      | Lean.Compiler.Yul.Statement.switchStmt (Lean.Compiler.Yul.Expr.builtin name args) cases => do
          require (name == "shr") "dynamic ABI dispatch switch selector opcode"
          require (args.size == 2) "dynamic ABI dispatch switch selector arg count"
          require (cases.size == dynamicPlan.entrypoints.size + 1) "dynamic ABI dispatch switch case count"
      | _ => throw <| IO.userError "dynamic ABI dispatch block must contain selector switch"
  | _ => throw <| IO.userError "dynamic ABI dispatch must initialize memory and wrap selector switch"
  let uupsModule := { ProofForge.IR.Examples.Counter.module with evmProxyPattern? := some "uups" }
  let uupsPlan ← requireOk (buildSemanticPlan uupsModule) "UUPS counter plan"
  require (uupsPlan.dispatch.default == .uupsProxy) "UUPS plan dispatch default"
  let uupsDefault := ProofForge.Backend.Evm.ToYul.dispatchDefaultCase uupsPlan.dispatch.default
  require (uupsDefault.value.isNone) "UUPS default case selector"
  require
    (uupsDefault.body.statements.size == ProofForge.Backend.Evm.ToYul.uupsProxyFallbackBody.size)
    "UUPS default case fallback statement count"
  let uupsDispatch ← requireOk (dispatchBlockWithPlan uupsModule uupsPlan.dispatch) "UUPS dispatch block"
  match uupsDispatch with
  | Lean.Compiler.Yul.Statement.switchStmt _ cases => do
      require (cases.size == uupsPlan.dispatch.entrypoints.size + 1) "UUPS dispatch switch case count"
      let defaultCase ← requireAt cases (cases.size - 1) "UUPS dispatch missing default case"
      require
        (defaultCase.body.statements.size == ProofForge.Backend.Evm.ToYul.uupsProxyFallbackBody.size)
        "UUPS dispatch default fallback statement count"
  | _ => throw <| IO.userError "UUPS dispatch block must lower to selector switch"

def testSemanticPlanRender : IO Unit := do
  let rendered ← requireOk (renderSemanticPlan ProofForge.IR.Examples.Counter.module) "counter plan render"
  require (rendered.contains "module: Counter") "counter plan render module"
  require (rendered.contains "target: evm") "counter plan render target"
  require (rendered.contains "entrypoints:") "counter plan render entrypoints"
  require (rendered.contains "initialize") "counter plan render initialize"
  require (rendered.contains "storage:") "counter plan render storage"

def testScalarExprPlanToYul : IO Unit := do
  let readExpr ← requireOk
    (lowerExprViaPlan
      ProofForge.IR.Examples.Counter.module
      #[]
      (.effect (.storageScalarRead "count")))
    "counter scalar read plan-to-yul"
  match readExpr with
  | Lean.Compiler.Yul.Expr.builtin name args => do
      require (name == "sload") "counter scalar read plan-to-yul opcode"
      require (args.size == 1) "counter scalar read plan-to-yul arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.lit lit =>
          require (lit.value == "0") "counter scalar read plan-to-yul slot"
      | _ => throw <| IO.userError "counter scalar read plan-to-yul slot must be literal"
  | _ => throw <| IO.userError "counter scalar read plan-to-yul must be sload"
  let addExpr ← requireOk
    (lowerExprViaPlan
      ProofForge.IR.Examples.Counter.module
      #[{ name := "n", type := .u64, isMutable := false }]
      (.add (.local "n") (.literal (.u64 1))))
    "counter checked add plan-to-yul"
  match addExpr with
  | Lean.Compiler.Yul.Expr.call name args => do
      require (name == "__pf_checked_add") "counter checked add plan-to-yul helper"
      require (args.size == 2) "counter checked add plan-to-yul arg count"
  | _ => throw <| IO.userError "counter checked add plan-to-yul must be helper call"

def testScalarAssertPlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "n", type := .u64, isMutable := false }]
  let checkGuardBuiltin := fun (stmt : Lean.Compiler.Yul.Statement) (expected : String) (label : String) => do
    match stmt with
    | Lean.Compiler.Yul.Statement.ifStmt (Lean.Compiler.Yul.Expr.builtin name args) _ => do
        require (name == "iszero") s!"{label} guard builtin"
        require (args.size == 1) s!"{label} iszero arg count"
        match args[0]! with
        | Lean.Compiler.Yul.Expr.builtin name _ =>
            require (name == expected) s!"{label} condition builtin"
        | _ => throw <| IO.userError s!"{label} condition must be builtin"
    | _ => throw <| IO.userError s!"{label} must lower to if iszero"
  let directAssertStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarAssertStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      (fun _ => #[revertStmt])
      (ProofForge.Backend.Evm.Plan.StmtPlan.assert
        (.builtin "gt" #[.local "n", .literalWord 0])
        "positive"
        none))
    "scalar assert StmtPlan-to-Yul helper"
  require (directAssertStmts.size == 1) "scalar assert StmtPlan-to-Yul helper statement count"
  checkGuardBuiltin directAssertStmts[0]! "gt" "scalar assert StmtPlan-to-Yul helper"
  let directAssertEqStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarAssertStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      (fun _ => #[revertStmt])
      (ProofForge.Backend.Evm.Plan.StmtPlan.assertEq
        (.local "n")
        (.literalWord 1)
        "one"
        none))
    "scalar assertEq StmtPlan-to-Yul helper"
  require (directAssertEqStmts.size == 1) "scalar assertEq StmtPlan-to-Yul helper statement count"
  checkGuardBuiltin directAssertEqStmts[0]! "eq" "scalar assertEq StmtPlan-to-Yul helper"
  let (assertStmts, _) ← requireOk
    (lowerStatement
      ProofForge.IR.Examples.Counter.module
      "scalar_assert"
      .unit
      env
      false
      (.assert (.gt (.local "n") (.literal (.u64 0))) "positive" none))
    "scalar assert statement plan-to-yul integration"
  require (assertStmts.size == 1) "scalar assert statement plan-to-yul integration statement count"
  match assertStmts[0]! with
  | Lean.Compiler.Yul.Statement.ifStmt (Lean.Compiler.Yul.Expr.builtin name args) _ => do
      require (name == "iszero") "scalar assert statement plan-to-yul integration guard builtin"
      require (args.size == 1) "scalar assert statement plan-to-yul integration iszero arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.builtin name _ =>
          require (name == "gt") "scalar assert statement plan-to-yul integration condition builtin"
      | _ => throw <| IO.userError "scalar assert statement plan-to-yul integration condition must be builtin"
  | _ => throw <| IO.userError "scalar assert statement plan-to-yul integration must lower to if iszero"
  let (assertEqStmts, _) ← requireOk
    (lowerStatement
      ProofForge.IR.Examples.Counter.module
      "scalar_assert_eq"
      .unit
      env
      false
      (.assertEq (.local "n") (.literal (.u64 1)) "one" none))
    "scalar assertEq statement plan-to-yul integration"
  require (assertEqStmts.size == 1) "scalar assertEq statement plan-to-yul integration statement count"
  match assertEqStmts[0]! with
  | Lean.Compiler.Yul.Statement.ifStmt (Lean.Compiler.Yul.Expr.builtin name args) _ => do
      require (name == "iszero") "scalar assertEq statement plan-to-yul integration guard builtin"
      require (args.size == 1) "scalar assertEq statement plan-to-yul integration iszero arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.builtin name _ =>
          require (name == "eq") "scalar assertEq statement plan-to-yul integration condition builtin"
      | _ => throw <| IO.userError "scalar assertEq statement plan-to-yul integration condition must be builtin"
  | _ => throw <| IO.userError "scalar assertEq statement plan-to-yul integration must lower to if iszero"

def testScalarReturnPlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "n", type := .u64, isMutable := false }]
  let directStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarReturnStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      #["result"]
      false
      (ProofForge.Backend.Evm.Plan.StmtPlan.return
        (.checkedArith .add (.local "n") (.literalWord 1))))
    "scalar return StmtPlan-to-Yul helper"
  require (directStmts.size == 1) "scalar return StmtPlan-to-Yul helper statement count"
  match directStmts[0]! with
  | Lean.Compiler.Yul.Statement.assignment names (Lean.Compiler.Yul.Expr.call name args) => do
      require (names == #["result"]) "scalar return StmtPlan-to-Yul helper target"
      require (name == "__pf_checked_add") "scalar return StmtPlan-to-Yul helper checked add"
      require (args.size == 2) "scalar return StmtPlan-to-Yul helper checked add arg count"
  | _ => throw <| IO.userError "scalar return StmtPlan-to-Yul helper must assign helper result"
  let directLeaveStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarReturnStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      #["result"]
      true
      (ProofForge.Backend.Evm.Plan.StmtPlan.return
        (.effect (.storageScalarRead "count"))))
    "scalar return StmtPlan-to-Yul helper leave"
  require (directLeaveStmts.size == 2) "scalar return StmtPlan-to-Yul helper leave statement count"
  match directLeaveStmts[0]! with
  | Lean.Compiler.Yul.Statement.assignment names (Lean.Compiler.Yul.Expr.builtin name args) => do
      require (names == #["result"]) "scalar return StmtPlan-to-Yul helper leave target"
      require (name == "sload") "scalar return StmtPlan-to-Yul helper leave storage read"
      require (args.size == 1) "scalar return StmtPlan-to-Yul helper leave sload arg count"
  | _ => throw <| IO.userError "scalar return StmtPlan-to-Yul helper leave must assign sload"
  match directLeaveStmts[1]! with
  | Lean.Compiler.Yul.Statement.leave => pure ()
  | _ => throw <| IO.userError "scalar return StmtPlan-to-Yul helper leave must append leave"
  let returnStmts ← requireOk
    (lowerReturnStmt
      ProofForge.IR.Examples.Counter.module
      env
      "checked_return"
      .u64
      (.add (.local "n") (.literal (.u64 1)))
      false)
    "scalar return plan-to-yul"
  require (returnStmts.size == 1) "scalar return plan-to-yul statement count"
  match returnStmts[0]! with
  | Lean.Compiler.Yul.Statement.assignment names (Lean.Compiler.Yul.Expr.call name args) => do
      require (names == #["result"]) "scalar return plan-to-yul target"
      require (name == "__pf_checked_add") "scalar return plan-to-yul helper"
      require (args.size == 2) "scalar return plan-to-yul arg count"
  | _ => throw <| IO.userError "scalar return plan-to-yul must assign helper result"
  let storageReturnStmts ← requireOk
    (lowerReturnStmt
      ProofForge.IR.Examples.Counter.module
      #[]
      "storage_return"
      .u64
      (.effect (.storageScalarRead "count"))
      false)
    "storage scalar return plan-to-yul"
  require (storageReturnStmts.size == 1) "storage scalar return plan-to-yul statement count"
  match storageReturnStmts[0]! with
  | Lean.Compiler.Yul.Statement.assignment names (Lean.Compiler.Yul.Expr.builtin name args) => do
      require (names == #["result"]) "storage scalar return plan-to-yul target"
      require (name == "sload") "storage scalar return plan-to-yul opcode"
      require (args.size == 1) "storage scalar return plan-to-yul arg count"
  | _ => throw <| IO.userError "storage scalar return plan-to-yul must assign sload"

def testScalarBindingStmtPlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "n", type := .u64, isMutable := false }]
  let directStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarBindingStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      (.letBind
        "m"
        .u64
        (.checkedArith .add (.local "n") (.literalWord 1))))
    "scalar let StmtPlan-to-Yul helper"
  require (directStmts.size == 1) "scalar let StmtPlan-to-Yul helper statement count"
  match directStmts[0]! with
  | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.call name args)) => do
      match vars[0]? with
      | some var => require (var.name == "m") "scalar let StmtPlan-to-Yul helper var name"
      | none => throw <| IO.userError "scalar let StmtPlan-to-Yul helper missing var"
      require (name == "__pf_checked_add") "scalar let StmtPlan-to-Yul helper checked add"
      require (args.size == 2) "scalar let StmtPlan-to-Yul helper checked add arg count"
  | _ => throw <| IO.userError "scalar let StmtPlan-to-Yul helper must lower to var decl"
  let (letStmts, _) ← requireOk
    (lowerStatement
      ProofForge.IR.Examples.Counter.module
      "scalar_binding"
      .unit
      env
      false
      (.letBind "m" .u64 (.add (.local "n") (.literal (.u64 1)))))
    "scalar let statement plan-to-yul integration"
  require (letStmts.size == 1) "scalar let statement plan-to-yul integration statement count"
  match letStmts[0]! with
  | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.call name args)) => do
      match vars[0]? with
      | some var => require (var.name == "m") "scalar let statement plan-to-yul integration var name"
      | none => throw <| IO.userError "scalar let statement plan-to-yul integration missing var"
      require (name == "__pf_checked_add") "scalar let statement plan-to-yul integration checked add"
      require (args.size == 2) "scalar let statement plan-to-yul integration checked add arg count"
  | _ => throw <| IO.userError "scalar let statement plan-to-yul integration must lower to var decl"
  let (letMutStmts, _) ← requireOk
    (lowerStatement
      ProofForge.IR.Examples.Counter.module
      "scalar_binding"
      .unit
      #[]
      false
      (.letMutBind "m" .u64 (.effect (.storageScalarRead "count"))))
    "scalar let mut statement plan-to-yul integration"
  require (letMutStmts.size == 1) "scalar let mut statement plan-to-yul integration statement count"
  match letMutStmts[0]! with
  | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.builtin name args)) => do
      match vars[0]? with
      | some var => require (var.name == "m") "scalar let mut statement plan-to-yul integration var name"
      | none => throw <| IO.userError "scalar let mut statement plan-to-yul integration missing var"
      require (name == "sload") "scalar let mut statement plan-to-yul integration storage read"
      require (args.size == 1) "scalar let mut statement plan-to-yul integration sload arg count"
  | _ => throw <| IO.userError "scalar let mut statement plan-to-yul integration must lower to var decl"

def testScalarAssignmentPlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "n", type := .u64, isMutable := true }]
  let directAssignStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarAssignmentStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      (ProofForge.Backend.Evm.Plan.StmtPlan.assign
        (.local "n")
        (.checkedArith .add (.local "n") (.literalWord 1))))
    "scalar assignment StmtPlan-to-Yul helper"
  require (directAssignStmts.size == 1) "scalar assignment StmtPlan-to-Yul helper statement count"
  match directAssignStmts[0]! with
  | Lean.Compiler.Yul.Statement.assignment names (Lean.Compiler.Yul.Expr.call name args) => do
      require (names == #["n"]) "scalar assignment StmtPlan-to-Yul helper target"
      require (name == "__pf_checked_add") "scalar assignment StmtPlan-to-Yul helper checked add"
      require (args.size == 2) "scalar assignment StmtPlan-to-Yul helper checked add arg count"
  | _ => throw <| IO.userError "scalar assignment StmtPlan-to-Yul helper must assign helper result"
  let directAssignOpStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarAssignmentStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      (ProofForge.Backend.Evm.Plan.StmtPlan.assignOp
        (.local "n")
        .add
        (.effect (.storageScalarRead "count"))))
    "scalar compound assignment StmtPlan-to-Yul helper"
  require (directAssignOpStmts.size == 1) "scalar compound assignment StmtPlan-to-Yul helper statement count"
  match directAssignOpStmts[0]! with
  | Lean.Compiler.Yul.Statement.assignment names (Lean.Compiler.Yul.Expr.call name args) => do
      require (names == #["n"]) "scalar compound assignment StmtPlan-to-Yul helper target"
      require (name == "__pf_checked_add") "scalar compound assignment StmtPlan-to-Yul helper checked add"
      require (args.size == 2) "scalar compound assignment StmtPlan-to-Yul helper checked add arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.builtin name _ =>
          require (name == "sload") "scalar compound assignment StmtPlan-to-Yul helper rhs opcode"
      | _ => throw <| IO.userError "scalar compound assignment StmtPlan-to-Yul helper rhs must be sload"
  | _ => throw <| IO.userError "scalar compound assignment StmtPlan-to-Yul helper must assign helper result"
  let assignStmts ← requireOk
    (lowerAssignStmt
      ProofForge.IR.Examples.Counter.module
      env
      (.local "n")
      (.add (.local "n") (.literal (.u64 1))))
    "scalar assignment plan-to-yul"
  require (assignStmts.size == 1) "scalar assignment plan-to-yul statement count"
  match assignStmts[0]! with
  | Lean.Compiler.Yul.Statement.assignment names (Lean.Compiler.Yul.Expr.call name args) => do
      require (names == #["n"]) "scalar assignment plan-to-yul target"
      require (name == "__pf_checked_add") "scalar assignment plan-to-yul helper"
      require (args.size == 2) "scalar assignment plan-to-yul arg count"
  | _ => throw <| IO.userError "scalar assignment plan-to-yul must assign helper result"
  let assignOpStmts ← requireOk
    (lowerAssignOpStmt
      ProofForge.IR.Examples.Counter.module
      env
      (.local "n")
      .add
      (.effect (.storageScalarRead "count")))
    "scalar compound assignment plan-to-yul"
  require (assignOpStmts.size == 1) "scalar compound assignment plan-to-yul statement count"
  match assignOpStmts[0]! with
  | Lean.Compiler.Yul.Statement.assignment names (Lean.Compiler.Yul.Expr.call name args) => do
      require (names == #["n"]) "scalar compound assignment plan-to-yul target"
      require (name == "__pf_checked_add") "scalar compound assignment plan-to-yul helper"
      require (args.size == 2) "scalar compound assignment plan-to-yul arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.builtin name _ =>
          require (name == "sload") "scalar compound assignment plan-to-yul rhs opcode"
      | _ => throw <| IO.userError "scalar compound assignment plan-to-yul rhs must be sload"
  | _ => throw <| IO.userError "scalar compound assignment plan-to-yul must assign helper result"

def testScalarControlFlowPlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "n", type := .u64, isMutable := true }]
  let directIfStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.ifElseStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      #[Lean.Compiler.Yul.Statement.assignment #["n"] (Lean.Compiler.Yul.Expr.num 2)]
      #[Lean.Compiler.Yul.Statement.assignment #["n"] (Lean.Compiler.Yul.Expr.num 1)]
      (ProofForge.Backend.Evm.Plan.StmtPlan.ifElse
        (.builtin "gt" #[.local "n", .literalWord 0])
        #[]
        #[]))
    "scalar ifElse StmtPlan-to-Yul helper"
  require (directIfStmts.size == 1) "scalar ifElse StmtPlan-to-Yul helper statement count"
  match directIfStmts[0]! with
  | Lean.Compiler.Yul.Statement.switchStmt (Lean.Compiler.Yul.Expr.builtin name args) cases => do
      require (name == "gt") "scalar ifElse StmtPlan-to-Yul helper opcode"
      require (args.size == 2) "scalar ifElse StmtPlan-to-Yul helper arg count"
      require (cases.size == 2) "scalar ifElse StmtPlan-to-Yul helper case count"
  | _ => throw <| IO.userError "scalar ifElse StmtPlan-to-Yul helper must lower to switch over builtin"
  let directForStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.boundedForStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      #[Lean.Compiler.Yul.Statement.assignment #["n"] (Lean.Compiler.Yul.Expr.id "i")]
      (ProofForge.Backend.Evm.Plan.StmtPlan.boundedFor
        "i"
        0
        3
        #[]))
    "scalar boundedFor StmtPlan-to-Yul helper"
  require (directForStmts.size == 1) "scalar boundedFor StmtPlan-to-Yul helper statement count"
  match directForStmts[0]! with
  | Lean.Compiler.Yul.Statement.forLoop _ (Lean.Compiler.Yul.Expr.builtin name args) _ body => do
      require (name == "lt") "scalar boundedFor StmtPlan-to-Yul helper opcode"
      require (args.size == 2) "scalar boundedFor StmtPlan-to-Yul helper arg count"
      require (body.statements.size == 1) "scalar boundedFor StmtPlan-to-Yul helper body count"
  | _ => throw <| IO.userError "scalar boundedFor StmtPlan-to-Yul helper must lower to for over builtin"
  let (ifStmts, _) ← requireOk
    (lowerStatement
      ProofForge.IR.Examples.Counter.module
      "control_flow"
      .unit
      env
      false
      (.ifElse
        (.gt (.local "n") (.literal (.u64 0)))
        #[.assign (.local "n") (.add (.local "n") (.literal (.u64 1)))]
        #[.assign (.local "n") (.literal (.u64 1))]))
    "scalar ifElse condition plan-to-yul"
  require (ifStmts.size == 1) "scalar ifElse condition plan-to-yul statement count"
  match ifStmts[0]! with
  | Lean.Compiler.Yul.Statement.switchStmt (Lean.Compiler.Yul.Expr.builtin name args) _ => do
      require (name == "gt") "scalar ifElse condition plan-to-yul opcode"
      require (args.size == 2) "scalar ifElse condition plan-to-yul arg count"
  | _ => throw <| IO.userError "scalar ifElse condition plan-to-yul must lower to switch over builtin"
  let (forStmts, _) ← requireOk
    (lowerStatement
      ProofForge.IR.Examples.Counter.module
      "control_flow"
      .unit
      env
      false
      (.boundedFor
        "i"
        0
        3
        #[.assign (.local "n") (.add (.local "n") (.local "i"))]))
    "scalar boundedFor condition plan-to-yul"
  require (forStmts.size == 1) "scalar boundedFor condition plan-to-yul statement count"
  match forStmts[0]! with
  | Lean.Compiler.Yul.Statement.forLoop _ (Lean.Compiler.Yul.Expr.builtin name args) _ _ => do
      require (name == "lt") "scalar boundedFor condition plan-to-yul opcode"
      require (args.size == 2) "scalar boundedFor condition plan-to-yul arg count"
  | _ => throw <| IO.userError "scalar boundedFor condition plan-to-yul must lower to for over builtin"

def testScalarEventPlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "n", type := .u64, isMutable := false }]
  let directEvent := ProofForge.Backend.Evm.Plan.EventPlan.mk
    "PlanIndexed"
    "PlanIndexed(uint64,uint64)"
    #[
      ProofForge.Backend.Evm.Plan.EventFieldPlan.mk "key" .u64 true,
      ProofForge.Backend.Evm.Plan.EventFieldPlan.mk "value" .u64 false
    ]
  let directStmt ← requireOk
    (ProofForge.Backend.Evm.ToYul.eventEmitCoreStatement
      toYulError
      directEvent
      #[Lean.Compiler.Yul.Statement.varDecl
        #[{ name := "_indexed_topic0" }]
        (some (Lean.Compiler.Yul.Expr.num 5))]
      #[Lean.Compiler.Yul.Expr.num 9])
    "event EventPlan-to-Yul core helper"
  match directStmt with
  | Lean.Compiler.Yul.Statement.block block => do
      require (block.statements.size >= 4) "event EventPlan-to-Yul core helper statement count"
      match block.statements[block.statements.size - 1]! with
      | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin name args) => do
          require (name == "log2") "event EventPlan-to-Yul core helper log builtin"
          require (args.size == 4) "event EventPlan-to-Yul core helper log arg count"
      | _ => throw <| IO.userError "event EventPlan-to-Yul core helper must end with log statement"
  | _ => throw <| IO.userError "event EventPlan-to-Yul core helper must lower to block"
  let dataStmt ← requireOk
    (lowerEventEmitCoreStmt
      ProofForge.IR.Examples.EventProbe.evmModule
      env
      "PlanValue"
      #[]
      #[("value", .add (.local "n") (.literal (.u64 1)))])
    "scalar event data field plan-to-yul"
  match dataStmt with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundCheckedAdd := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "mstore" args) => do
            if args.size == 2 then
              match args[1]! with
              | Lean.Compiler.Yul.Expr.call "__pf_checked_add" addArgs =>
                  foundCheckedAdd := foundCheckedAdd || addArgs.size == 2
              | _ => pure ()
        | _ => pure ()
      require foundCheckedAdd "scalar event data field must lower through checked add plan"
  | _ => throw <| IO.userError "scalar event data field plan-to-yul must lower to block"
  let indexedStmt ← requireOk
    (lowerEventEmitCoreStmt
      ProofForge.IR.Examples.EventProbe.evmModule
      env
      "PlanIndexed"
      #[("key", .effect (.storageScalarRead "_proof_forge_marker"))]
      #[("value", .add (.local "n") (.literal (.u64 1)))])
    "scalar indexed event topic plan-to-yul"
  match indexedStmt with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundIndexedSload := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.builtin "sload" args)) => do
            match vars[0]? with
            | some var =>
                if vars.size == 1 && var.name == "_indexed_topic0" then
                  foundIndexedSload := foundIndexedSload || args.size == 1
            | none => pure ()
        | _ => pure ()
      require foundIndexedSload "scalar indexed event topic must lower storage read through plan"
  | _ => throw <| IO.userError "scalar indexed event topic plan-to-yul must lower to block"

def testScalarStorageEffectPlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "n", type := .u64, isMutable := false }]
  let directWriteStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarStorageEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      (fun _ => .ok (Lean.Compiler.Yul.Expr.num 0))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storageScalarWrite
          "count"
          (.checkedArith .add (.local "n") (.literalWord 1)))))
    "scalar storage write StmtPlan-to-Yul helper"
  require (directWriteStmts.size == 1) "scalar storage write StmtPlan-to-Yul helper statement count"
  match directWriteStmts[0]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "scalar storage write StmtPlan-to-Yul helper arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call name addArgs => do
          require (name == "__pf_checked_add") "scalar storage write StmtPlan-to-Yul helper checked add"
          require (addArgs.size == 2) "scalar storage write StmtPlan-to-Yul helper checked add arg count"
      | _ => throw <| IO.userError "scalar storage write StmtPlan-to-Yul helper value must be helper call"
  | _ => throw <| IO.userError "scalar storage write StmtPlan-to-Yul helper must lower to sstore"
  let directAssignOpStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.scalarStorageEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.Counter.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.Counter.module env)
      (fun _ => .ok (Lean.Compiler.Yul.Expr.num 0))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storageScalarAssignOp
          "count"
          .add
          (.effect (.storageScalarRead "count")))))
    "scalar storage assign_op StmtPlan-to-Yul helper"
  require (directAssignOpStmts.size == 1) "scalar storage assign_op StmtPlan-to-Yul helper statement count"
  match directAssignOpStmts[0]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "scalar storage assign_op StmtPlan-to-Yul helper arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call name addArgs => do
          require (name == "__pf_checked_add") "scalar storage assign_op StmtPlan-to-Yul helper checked add"
          require (addArgs.size == 2) "scalar storage assign_op StmtPlan-to-Yul helper checked add arg count"
          match addArgs[0]! with
          | Lean.Compiler.Yul.Expr.builtin readName _ =>
              require (readName == "sload") "scalar storage assign_op StmtPlan-to-Yul helper lhs must be sload"
          | _ => throw <| IO.userError "scalar storage assign_op StmtPlan-to-Yul helper lhs must be sload"
      | _ => throw <| IO.userError "scalar storage assign_op StmtPlan-to-Yul helper value must be helper call"
  | _ => throw <| IO.userError "scalar storage assign_op StmtPlan-to-Yul helper must lower to sstore"
  let writeStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.Counter.module
      env
      (.storageScalarWrite "count" (.add (.local "n") (.literal (.u64 1)))))
    "scalar storage write value plan-to-yul"
  match writeStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "scalar storage write plan-to-yul arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call name addArgs => do
          require (name == "__pf_checked_add") "scalar storage write plan-to-yul helper"
          require (addArgs.size == 2) "scalar storage write plan-to-yul helper arg count"
      | _ => throw <| IO.userError "scalar storage write plan-to-yul value must be helper call"
  | _ => throw <| IO.userError "scalar storage write plan-to-yul must lower to sstore"
  let assignOpStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.Counter.module
      env
      (.storageScalarAssignOp "count" .add (.effect (.storageScalarRead "count"))))
    "scalar storage assign_op value plan-to-yul"
  match assignOpStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "scalar storage assign_op plan-to-yul arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call name addArgs => do
          require (name == "__pf_checked_add") "scalar storage assign_op plan-to-yul helper"
          require (addArgs.size == 2) "scalar storage assign_op plan-to-yul helper arg count"
          match addArgs[1]! with
          | Lean.Compiler.Yul.Expr.builtin readName _ =>
              require (readName == "sload") "scalar storage assign_op rhs must be plan-lowered sload"
          | _ => throw <| IO.userError "scalar storage assign_op rhs must be sload"
      | _ => throw <| IO.userError "scalar storage assign_op plan-to-yul value must be helper call"
  | _ => throw <| IO.userError "scalar storage assign_op plan-to-yul must lower to sstore"

def testMapWritePlanToYul : IO Unit := do
  let env : TypeEnv := #[
    { name := "key", type := .u64, isMutable := false },
    { name := "value", type := .u64, isMutable := false }
  ]
  let directWriteStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.mapWriteEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.EvmMapProbe.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.EvmMapProbe.module env)
      (fun _ => .ok (Lean.Compiler.Yul.Expr.num 0))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storageMapSet
          "balances"
          (.checkedArith .add (.local "key") (.literalWord 1))
          (.effect (.storageScalarRead "before")))))
    "map write StmtPlan-to-Yul helper"
  require (directWriteStmts.size == 1) "map write StmtPlan-to-Yul helper statement count"
  match directWriteStmts[0]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.call name args) => do
      require (name == mapWriteFunctionName) "map write StmtPlan-to-Yul helper call"
      require (args.size == 3) "map write StmtPlan-to-Yul helper arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "map write StmtPlan-to-Yul helper key checked add"
          require (addArgs.size == 2) "map write StmtPlan-to-Yul helper key checked add arg count"
      | _ => throw <| IO.userError "map write StmtPlan-to-Yul helper key must be checked add"
      match args[2]! with
      | Lean.Compiler.Yul.Expr.builtin readName readArgs => do
          require (readName == "sload") "map write StmtPlan-to-Yul helper value storage read"
          require (readArgs.size == 1) "map write StmtPlan-to-Yul helper value sload arg count"
      | _ => throw <| IO.userError "map write StmtPlan-to-Yul helper value must be storage read"
  | _ => throw <| IO.userError "map write StmtPlan-to-Yul helper must lower to helper call"
  let directInsertStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.mapWriteEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.EvmMapProbe.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.EvmMapProbe.module env)
      (fun _ => .ok (Lean.Compiler.Yul.Expr.num 0))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storageMapInsert "balances" (.local "key") (.local "value"))))
    "map insert StmtPlan-to-Yul helper"
  require (directInsertStmts.size == 1) "map insert StmtPlan-to-Yul helper statement count"
  match directInsertStmts[0]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.call name args) => do
      require (name == mapWriteFunctionName) "map insert StmtPlan-to-Yul helper call"
      require (args.size == 3) "map insert StmtPlan-to-Yul helper arg count"
  | _ => throw <| IO.userError "map insert StmtPlan-to-Yul helper must lower to helper call"
  let writeStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmMapProbe.module
      env
      (.storageMapSet
        "balances"
        (.add (.local "key") (.literal (.u64 1)))
        (.effect (.storageScalarRead "before"))))
    "map write key/value plan-to-yul"
  match writeStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.call name args) => do
      require (name == mapWriteFunctionName) "map write plan-to-yul helper"
      require (args.size == 3) "map write plan-to-yul arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "map write key must lower through checked add plan"
          require (addArgs.size == 2) "map write key checked add arg count"
      | _ => throw <| IO.userError "map write key must be plan-lowered checked add"
      match args[2]! with
      | Lean.Compiler.Yul.Expr.builtin readName readArgs => do
          require (readName == "sload") "map write value must lower storage read through plan"
          require (readArgs.size == 1) "map write value sload arg count"
      | _ => throw <| IO.userError "map write value must be plan-lowered storage read"
  | _ => throw <| IO.userError "map write plan-to-yul must lower to helper call"
  let setReturnExpr ← requireOk
    (lowerMapSetReturnExpr
      ProofForge.IR.Examples.EvmMapProbe.module
      env
      "balances"
      (.local "key")
      (.add (.local "value") (.literal (.u64 2))))
    "map set-return value plan-to-yul"
  match setReturnExpr with
  | Lean.Compiler.Yul.Expr.call name args => do
      require (name == mapSetReturnFunctionName) "map set-return plan-to-yul helper"
      require (args.size == 3) "map set-return plan-to-yul arg count"
      match args[2]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "map set-return value must lower through checked add plan"
          require (addArgs.size == 2) "map set-return value checked add arg count"
      | _ => throw <| IO.userError "map set-return value must be plan-lowered checked add"
  | _ => throw <| IO.userError "map set-return plan-to-yul must lower to helper call"

def testArrayWritePlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "value", type := .u64, isMutable := false }]
  let directWriteStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.arrayWriteEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.EvmStorageArrayProbe.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.EvmStorageArrayProbe.module env)
      (fun _ index => do
        .ok (Lean.Compiler.Yul.call arraySlotFunctionName #[
          Lean.Compiler.Yul.Expr.num 1,
          Lean.Compiler.Yul.Expr.num 3,
          ← ProofForge.Backend.Evm.ToYul.exprPlanExpr
            toYulError
            (fun expr => lowerExpr ProofForge.IR.Examples.EvmStorageArrayProbe.module env expr)
            (lowerPlanEffectExpr ProofForge.IR.Examples.EvmStorageArrayProbe.module env)
            index
        ]))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storageArrayWrite
          "values"
          (.checkedArith .add (.literalWord 1) (.literalWord 1))
          (.effect (.storageScalarRead "before")))))
    "array write StmtPlan-to-Yul helper"
  require (directWriteStmts.size == 1) "array write StmtPlan-to-Yul helper statement count"
  match directWriteStmts[0]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "array write StmtPlan-to-Yul helper arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.call slotName slotArgs => do
          require (slotName == arraySlotFunctionName) "array write StmtPlan-to-Yul helper slot call"
          require (slotArgs.size == 3) "array write StmtPlan-to-Yul helper slot arg count"
          match slotArgs[2]! with
          | Lean.Compiler.Yul.Expr.call addName addArgs => do
              require (addName == "__pf_checked_add") "array write StmtPlan-to-Yul helper index checked add"
              require (addArgs.size == 2) "array write StmtPlan-to-Yul helper index checked add arg count"
          | _ => throw <| IO.userError "array write StmtPlan-to-Yul helper index must be checked add"
      | _ => throw <| IO.userError "array write StmtPlan-to-Yul helper slot must use array helper"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.builtin readName readArgs => do
          require (readName == "sload") "array write StmtPlan-to-Yul helper value storage read"
          require (readArgs.size == 1) "array write StmtPlan-to-Yul helper value sload arg count"
      | _ => throw <| IO.userError "array write StmtPlan-to-Yul helper value must be storage read"
  | _ => throw <| IO.userError "array write StmtPlan-to-Yul helper must lower to sstore"
  let writeStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageArrayProbe.module
      env
      (.storageArrayWrite
        "values"
        (.literal (.u64 1))
        (.add (.local "value") (.literal (.u64 3)))))
    "array write value plan-to-yul"
  match writeStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "array write plan-to-yul arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.call slotName slotArgs => do
          require (slotName == arraySlotFunctionName) "array write plan-to-yul slot call"
          require (slotArgs.size == 3) "array write plan-to-yul slot arg count"
      | _ => throw <| IO.userError "array write plan-to-yul slot must use array helper"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "array write value must lower through checked add plan"
          require (addArgs.size == 2) "array write value checked add arg count"
      | _ => throw <| IO.userError "array write value must be plan-lowered checked add"
  | _ => throw <| IO.userError "array write plan-to-yul must lower to sstore"
  let storageValueStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageArrayProbe.module
      env
      (.storageArrayWrite
        "values"
        (.literal (.u64 2))
        (.effect (.storageScalarRead "before"))))
    "array write storage-read value plan-to-yul"
  match storageValueStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "array write storage-read value arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.builtin readName readArgs => do
          require (readName == "sload") "array write value must lower storage read through plan"
          require (readArgs.size == 1) "array write value sload arg count"
      | _ => throw <| IO.userError "array write value must be plan-lowered storage read"
  | _ => throw <| IO.userError "array write storage-read value must lower to sstore"

def testStructFieldWritePlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "value", type := .u64, isMutable := false }]
  let directFieldStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.structFieldWriteEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.EvmStorageStructProbe.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.EvmStorageStructProbe.module env)
      (fun _ _ => .ok (Lean.Compiler.Yul.Expr.num 2))
      (fun _ index _ => do
        .ok (Lean.Compiler.Yul.call structArraySlotFunctionName #[
          Lean.Compiler.Yul.Expr.num 4,
          Lean.Compiler.Yul.Expr.num 2,
          Lean.Compiler.Yul.Expr.num 2,
          Lean.Compiler.Yul.Expr.num 1,
          ← ProofForge.Backend.Evm.ToYul.exprPlanExpr
            toYulError
            (fun expr => lowerExpr ProofForge.IR.Examples.EvmStorageStructProbe.module env expr)
            (lowerPlanEffectExpr ProofForge.IR.Examples.EvmStorageStructProbe.module env)
            index
        ]))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storageStructFieldWrite
          "current"
          "x"
          (.checkedArith .add (.local "value") (.literalWord 5)))))
    "struct field write StmtPlan-to-Yul helper"
  require (directFieldStmts.size == 1) "struct field write StmtPlan-to-Yul helper statement count"
  match directFieldStmts[0]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "struct field write StmtPlan-to-Yul helper arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "struct field write StmtPlan-to-Yul helper checked add"
          require (addArgs.size == 2) "struct field write StmtPlan-to-Yul helper checked add arg count"
      | _ => throw <| IO.userError "struct field write StmtPlan-to-Yul helper value must be checked add"
  | _ => throw <| IO.userError "struct field write StmtPlan-to-Yul helper must lower to sstore"
  let directArrayFieldStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.structFieldWriteEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.EvmStorageStructProbe.module env expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.EvmStorageStructProbe.module env)
      (fun _ _ => .ok (Lean.Compiler.Yul.Expr.num 2))
      (fun _ index _ => do
        .ok (Lean.Compiler.Yul.call structArraySlotFunctionName #[
          Lean.Compiler.Yul.Expr.num 4,
          Lean.Compiler.Yul.Expr.num 2,
          Lean.Compiler.Yul.Expr.num 2,
          Lean.Compiler.Yul.Expr.num 1,
          ← ProofForge.Backend.Evm.ToYul.exprPlanExpr
            toYulError
            (fun expr => lowerExpr ProofForge.IR.Examples.EvmStorageStructProbe.module env expr)
            (lowerPlanEffectExpr ProofForge.IR.Examples.EvmStorageStructProbe.module env)
            index
        ]))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storageArrayStructFieldWrite
          "points"
          (.checkedArith .add (.literalWord 0) (.literalWord 1))
          "y"
          (.effect (.storageScalarRead "before")))))
    "struct array field write StmtPlan-to-Yul helper"
  require (directArrayFieldStmts.size == 1) "struct array field write StmtPlan-to-Yul helper statement count"
  match directArrayFieldStmts[0]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "struct array field write StmtPlan-to-Yul helper arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.call slotName slotArgs => do
          require (slotName == structArraySlotFunctionName) "struct array field write StmtPlan-to-Yul helper slot call"
          require (slotArgs.size == 5) "struct array field write StmtPlan-to-Yul helper slot arg count"
          match slotArgs[4]! with
          | Lean.Compiler.Yul.Expr.call addName addArgs => do
              require (addName == "__pf_checked_add") "struct array field write StmtPlan-to-Yul helper index checked add"
              require (addArgs.size == 2) "struct array field write StmtPlan-to-Yul helper index checked add arg count"
          | _ => throw <| IO.userError "struct array field write StmtPlan-to-Yul helper index must be checked add"
      | _ => throw <| IO.userError "struct array field write StmtPlan-to-Yul helper slot must use struct-array helper"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.builtin readName readArgs => do
          require (readName == "sload") "struct array field write StmtPlan-to-Yul helper value storage read"
          require (readArgs.size == 1) "struct array field write StmtPlan-to-Yul helper value sload arg count"
      | _ => throw <| IO.userError "struct array field write StmtPlan-to-Yul helper value must be storage read"
  | _ => throw <| IO.userError "struct array field write StmtPlan-to-Yul helper must lower to sstore"
  let fieldStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageStructProbe.module
      env
      (.storageStructFieldWrite
        "current"
        "x"
        (.add (.local "value") (.literal (.u64 5)))))
    "struct field write value plan-to-yul"
  match fieldStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "struct field write plan-to-yul arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "struct field write value must lower through checked add plan"
          require (addArgs.size == 2) "struct field write checked add arg count"
      | _ => throw <| IO.userError "struct field write value must be plan-lowered checked add"
  | _ => throw <| IO.userError "struct field write plan-to-yul must lower to sstore"
  let arrayFieldStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageStructProbe.module
      env
      (.storageArrayStructFieldWrite
        "points"
        (.literal (.u64 1))
        "y"
        (.effect (.storageScalarRead "before"))))
    "struct array field write value plan-to-yul"
  match arrayFieldStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "struct array field write plan-to-yul arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.call slotName slotArgs => do
          require (slotName == structArraySlotFunctionName) "struct array field write plan-to-yul slot call"
          require (slotArgs.size == 5) "struct array field write plan-to-yul slot arg count"
      | _ => throw <| IO.userError "struct array field write plan-to-yul slot must use struct-array helper"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.builtin readName readArgs => do
          require (readName == "sload") "struct array field write value must lower storage read through plan"
          require (readArgs.size == 1) "struct array field write sload arg count"
      | _ => throw <| IO.userError "struct array field write value must be plan-lowered storage read"
  | _ => throw <| IO.userError "struct array field write plan-to-yul must lower to sstore"

def testWholeStructStorageWritePlanToYul : IO Unit := do
  let env : TypeEnv := #[{ name := "value", type := .u64, isMutable := false }]
  let directStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.storageStructWriteEffectStmtPlanStatements
      toYulError
      (fun _ _ => .ok #[
        {
          slot := Lean.Compiler.Yul.Expr.num 3
          fieldName := "x"
          value := Lean.Compiler.Yul.call "__pf_checked_add" #[
            Lean.Compiler.Yul.Expr.id "value",
            Lean.Compiler.Yul.Expr.num 7
          ]
        },
        {
          slot := Lean.Compiler.Yul.Expr.num 4
          fieldName := "y"
          value := Lean.Compiler.Yul.builtin "sload" #[Lean.Compiler.Yul.Expr.num 0]
        }
      ])
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storageScalarWrite
          "current"
          (.structLit "Point" #[
            ("x", .checkedArith .add (.local "value") (.literalWord 7)),
            ("y", .effect (.storageScalarRead "before"))
          ]))))
    "whole struct storage write StmtPlan-to-Yul helper"
  require (directStmts.size == 1) "whole struct storage write StmtPlan-to-Yul helper statement count"
  match directStmts[0]! with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundTempX := false
      let mut foundTempY := false
      let mut foundStoreX := false
      let mut foundStoreY := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.varDecl vars (some _) => do
            match vars[0]? with
            | some var =>
                foundTempX := foundTempX || var.name == storageStructAssignTempName "current" "x"
                foundTempY := foundTempY || var.name == storageStructAssignTempName "current" "y"
            | none => pure ()
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
            if args.size == 2 then
              match args[1]! with
              | Lean.Compiler.Yul.Expr.ident name =>
                  foundStoreX := foundStoreX || name == storageStructAssignTempName "current" "x"
                  foundStoreY := foundStoreY || name == storageStructAssignTempName "current" "y"
              | _ => pure ()
        | _ => pure ()
      require foundTempX "whole struct storage write StmtPlan-to-Yul helper must snapshot x"
      require foundTempY "whole struct storage write StmtPlan-to-Yul helper must snapshot y"
      require foundStoreX "whole struct storage write StmtPlan-to-Yul helper must store x temp"
      require foundStoreY "whole struct storage write StmtPlan-to-Yul helper must store y temp"
  | _ => throw <| IO.userError "whole struct storage write StmtPlan-to-Yul helper must lower to block"
  let writeStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageStructProbe.module
      env
      (.storageScalarWrite
        "current"
        (.structLit "Point" #[
          ("x", .add (.local "value") (.literal (.u64 7))),
          ("y", .effect (.storageScalarRead "before"))
        ])))
    "whole struct storage write field values plan-to-yul"
  match writeStmt with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundCheckedX := false
      let mut foundStorageY := false
      let mut foundStoreX := false
      let mut foundStoreY := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.call addName addArgs)) => do
            match vars[0]? with
            | some var =>
                foundCheckedX := foundCheckedX ||
                  (var.name == storageStructAssignTempName "current" "x" &&
                    addName == "__pf_checked_add" &&
                    addArgs.size == 2)
            | none => pure ()
        | Lean.Compiler.Yul.Statement.varDecl vars (some (Lean.Compiler.Yul.Expr.builtin readName readArgs)) => do
            match vars[0]? with
            | some var =>
                foundStorageY := foundStorageY ||
                  (var.name == storageStructAssignTempName "current" "y" &&
                    readName == "sload" &&
                    readArgs.size == 1)
            | none => pure ()
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
            if args.size == 2 then
              match args[1]! with
              | Lean.Compiler.Yul.Expr.ident name =>
                  foundStoreX := foundStoreX || name == storageStructAssignTempName "current" "x"
                  foundStoreY := foundStoreY || name == storageStructAssignTempName "current" "y"
              | _ => pure ()
        | _ => pure ()
      require foundCheckedX "whole struct storage write x field must lower through checked add plan"
      require foundStorageY "whole struct storage write y field must lower storage read through plan"
      require foundStoreX "whole struct storage write must store x temp"
      require foundStoreY "whole struct storage write must store y temp"
  | _ => throw <| IO.userError "whole struct storage write plan-to-yul must lower to block"

def testStoragePathWritePlanToYul : IO Unit := do
  let arrayEnv : TypeEnv := #[{ name := "value", type := .u64, isMutable := false }]
  let directWriteStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.storagePathWriteEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.EvmStorageArrayProbe.module arrayEnv expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.EvmStorageArrayProbe.module arrayEnv)
      (fun _ _ => .ok (.singleSlot (Lean.Compiler.Yul.Expr.num 9)))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storagePathWrite
          "values"
          #[.index (.literal (.u64 0))]
          (.checkedArith .add (.local "value") (.literalWord 4)))))
    "storage path write StmtPlan-to-Yul helper"
  require (directWriteStmts.size == 1) "storage path write StmtPlan-to-Yul helper statement count"
  match directWriteStmts[0]! with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "storage path write StmtPlan-to-Yul helper arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.lit lit =>
          require (lit.value == "9") "storage path write StmtPlan-to-Yul helper slot"
      | _ => throw <| IO.userError "storage path write StmtPlan-to-Yul helper slot must be literal"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "storage path write StmtPlan-to-Yul helper checked add"
          require (addArgs.size == 2) "storage path write StmtPlan-to-Yul helper checked add arg count"
      | _ => throw <| IO.userError "storage path write StmtPlan-to-Yul helper value must be checked add"
  | _ => throw <| IO.userError "storage path write StmtPlan-to-Yul helper must lower to sstore"
  let arrayWriteStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageArrayProbe.module
      arrayEnv
      (.storagePathWrite
        "values"
        #[.index (.literal (.u64 1))]
        (.add (.local "value") (.literal (.u64 4)))))
    "array storage path write value plan-to-yul"
  match arrayWriteStmt with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
      require (args.size == 2) "array storage path write plan-to-yul arg count"
      match args[0]! with
      | Lean.Compiler.Yul.Expr.call slotName slotArgs => do
          require (slotName == arraySlotFunctionName) "array storage path write plan-to-yul slot call"
          require (slotArgs.size == 3) "array storage path write plan-to-yul slot arg count"
      | _ => throw <| IO.userError "array storage path write plan-to-yul slot must use array helper"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "array storage path write value must lower through checked add plan"
          require (addArgs.size == 2) "array storage path write value checked add arg count"
      | _ => throw <| IO.userError "array storage path write value must be plan-lowered checked add"
  | _ => throw <| IO.userError "array storage path write plan-to-yul must lower to sstore"
  let mapEnv : TypeEnv := #[
    { name := "outer", type := .u64, isMutable := false },
    { name := "inner", type := .u64, isMutable := false },
    { name := "value", type := .u64, isMutable := false }
  ]
  let nestedWriteStmt ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmMapProbe.module
      mapEnv
      (.storagePathWrite
        "balances"
        #[.mapKey (.local "outer"), .mapKey (.local "inner")]
        (.add (.local "value") (.literal (.u64 9)))))
    "nested storage path write value plan-to-yul"
  match nestedWriteStmt with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundCheckedValue := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
            if args.size == 2 then
              match args[0]!, args[1]! with
              | Lean.Compiler.Yul.Expr.ident slotName, Lean.Compiler.Yul.Expr.call addName addArgs =>
                  foundCheckedValue := foundCheckedValue ||
                    (slotName == "_slot" && addName == "__pf_checked_add" && addArgs.size == 2)
              | _, _ => pure ()
        | _ => pure ()
      require foundCheckedValue "nested storage path write value must lower through checked add plan"
  | _ => throw <| IO.userError "nested storage path write plan-to-yul must lower to block"
  let directAssignOpStmts ← requireOk
    (ProofForge.Backend.Evm.ToYul.storagePathAssignOpEffectStmtPlanStatements
      toYulError
      (fun expr => lowerExpr ProofForge.IR.Examples.EvmStorageArrayProbe.module arrayEnv expr)
      (lowerPlanEffectExpr ProofForge.IR.Examples.EvmStorageArrayProbe.module arrayEnv)
      (fun _ _ => .ok (.singleSlot (Lean.Compiler.Yul.Expr.num 9)))
      (ProofForge.Backend.Evm.Plan.StmtPlan.effect
        (.storagePathAssignOp
          "values"
          #[.index (.literal (.u64 0))]
          .add
          (.effect (.storageScalarRead "before")))))
    "storage path assign_op StmtPlan-to-Yul helper"
  require (directAssignOpStmts.size == 1) "storage path assign_op StmtPlan-to-Yul helper statement count"
  match directAssignOpStmts[0]! with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundStorageReadValue := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
            if args.size == 2 then
              match args[1]! with
              | Lean.Compiler.Yul.Expr.call addName addArgs =>
                  if addName == "__pf_checked_add" && addArgs.size == 2 then
                    match addArgs[1]! with
                    | Lean.Compiler.Yul.Expr.builtin readName readArgs =>
                        foundStorageReadValue := foundStorageReadValue ||
                          (readName == "sload" && readArgs.size == 1)
                    | _ => pure ()
              | _ => pure ()
        | _ => pure ()
      require foundStorageReadValue "storage path assign_op StmtPlan-to-Yul helper value must lower storage read through plan"
  | _ => throw <| IO.userError "storage path assign_op StmtPlan-to-Yul helper must lower to block"
  let directMapAssign ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmMapProbe.module
      mapEnv
      (.storagePathAssignOp
        "balances"
        #[.mapKey (.add (.local "outer") (.literal (.u64 1)))]
        .add
        (.effect (.storageScalarRead "before"))))
    "direct map storage path assign_op key/value plan-to-yul"
  match directMapAssign with
  | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.call name args) => do
      require (name == mapAssignFunctionName .add) "direct map storage path assign_op helper"
      require (args.size == 3) "direct map storage path assign_op arg count"
      match args[1]! with
      | Lean.Compiler.Yul.Expr.call addName addArgs => do
          require (addName == "__pf_checked_add") "direct map storage path assign_op key must lower through checked add plan"
          require (addArgs.size == 2) "direct map storage path assign_op key checked add arg count"
      | _ => throw <| IO.userError "direct map storage path assign_op key must be plan-lowered checked add"
      match args[2]! with
      | Lean.Compiler.Yul.Expr.builtin readName readArgs => do
          require (readName == "sload") "direct map storage path assign_op value must lower storage read through plan"
          require (readArgs.size == 1) "direct map storage path assign_op value sload arg count"
      | _ => throw <| IO.userError "direct map storage path assign_op value must be plan-lowered storage read"
  | _ => throw <| IO.userError "direct map storage path assign_op plan-to-yul must lower to helper call"
  let nestedMapAssign ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmMapProbe.module
      mapEnv
      (.storagePathAssignOp
        "balances"
        #[.mapKey (.local "outer"), .mapKey (.local "inner")]
        .add
        (.effect (.storageScalarRead "before"))))
    "nested map storage path assign_op value plan-to-yul"
  match nestedMapAssign with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundStorageReadValue := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
            if args.size == 2 then
              match args[0]!, args[1]! with
              | Lean.Compiler.Yul.Expr.ident slotName, Lean.Compiler.Yul.Expr.call addName addArgs =>
                  if slotName == "_slot" && addName == "__pf_checked_add" && addArgs.size == 2 then
                    match addArgs[1]! with
                    | Lean.Compiler.Yul.Expr.builtin readName readArgs =>
                        foundStorageReadValue := foundStorageReadValue ||
                          (readName == "sload" && readArgs.size == 1)
                    | _ => pure ()
              | _, _ => pure ()
        | _ => pure ()
      require foundStorageReadValue "nested map storage path assign_op value must lower storage read through plan"
  | _ => throw <| IO.userError "nested map storage path assign_op plan-to-yul must lower to block"
  let arrayAssign ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageArrayProbe.module
      #[]
      (.storagePathAssignOp
        "values"
        #[.index (.literal (.u64 1))]
        .add
        (.effect (.storageScalarRead "before"))))
    "array storage path assign_op value plan-to-yul"
  match arrayAssign with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundStorageReadValue := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
            if args.size == 2 then
              match args[1]! with
              | Lean.Compiler.Yul.Expr.call addName addArgs =>
                  if addName == "__pf_checked_add" && addArgs.size == 2 then
                    match addArgs[1]! with
                    | Lean.Compiler.Yul.Expr.builtin readName readArgs =>
                        foundStorageReadValue := foundStorageReadValue ||
                          (readName == "sload" && readArgs.size == 1)
                    | _ => pure ()
              | _ => pure ()
        | _ => pure ()
      require foundStorageReadValue "array storage path assign_op value must lower storage read through plan"
  | _ => throw <| IO.userError "array storage path assign_op plan-to-yul must lower to block"
  let structEnv : TypeEnv := #[{ name := "value", type := .u64, isMutable := false }]
  let fieldAssign ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageStructProbe.module
      structEnv
      (.storagePathAssignOp
        "current"
        #[.field "x"]
        .add
        (.add (.local "value") (.literal (.u64 2)))))
    "struct field storage path assign_op value plan-to-yul"
  match fieldAssign with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundCheckedValue := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
            if args.size == 2 then
              match args[1]! with
              | Lean.Compiler.Yul.Expr.call addName addArgs =>
                  if addName == "__pf_checked_add" && addArgs.size == 2 then
                    match addArgs[1]! with
                    | Lean.Compiler.Yul.Expr.call rhsAddName rhsAddArgs =>
                        foundCheckedValue := foundCheckedValue ||
                          (rhsAddName == "__pf_checked_add" && rhsAddArgs.size == 2)
                    | _ => pure ()
              | _ => pure ()
        | _ => pure ()
      require foundCheckedValue "struct field storage path assign_op value must lower through checked add plan"
  | _ => throw <| IO.userError "struct field storage path assign_op plan-to-yul must lower to block"
  let arrayFieldAssign ← requireOk
    (lowerEffectStmt
      ProofForge.IR.Examples.EvmStorageStructProbe.module
      #[]
      (.storagePathAssignOp
        "points"
        #[.index (.literal (.u64 1)), .field "y"]
        .add
        (.effect (.storageScalarRead "before"))))
    "struct-array field storage path assign_op value plan-to-yul"
  match arrayFieldAssign with
  | Lean.Compiler.Yul.Statement.block block => do
      let mut foundStorageReadValue := false
      for stmt in block.statements do
        match stmt with
        | Lean.Compiler.Yul.Statement.exprStmt (Lean.Compiler.Yul.Expr.builtin "sstore" args) => do
            if args.size == 2 then
              match args[1]! with
              | Lean.Compiler.Yul.Expr.call addName addArgs =>
                  if addName == "__pf_checked_add" && addArgs.size == 2 then
                    match addArgs[1]! with
                    | Lean.Compiler.Yul.Expr.builtin readName readArgs =>
                        foundStorageReadValue := foundStorageReadValue ||
                          (readName == "sload" && readArgs.size == 1)
                    | _ => pure ()
              | _ => pure ()
        | _ => pure ()
      require foundStorageReadValue "struct-array field storage path assign_op value must lower storage read through plan"
  | _ => throw <| IO.userError "struct-array field storage path assign_op plan-to-yul must lower to block"

def main : IO UInt32 := do
  testCounterSemanticPlan
  testEventSemanticPlan
  testERC20StandardEventSignatureTypes
  testArtifactMetadata
  testDeployMetadata
  testEntrypointDispatchPlanToYul
  testSemanticPlanRender
  testScalarExprPlanToYul
  testScalarAssertPlanToYul
  testScalarReturnPlanToYul
  testScalarBindingStmtPlanToYul
  testScalarAssignmentPlanToYul
  testScalarControlFlowPlanToYul
  testScalarEventPlanToYul
  testScalarStorageEffectPlanToYul
  testMapWritePlanToYul
  testArrayWritePlanToYul
  testStructFieldWritePlanToYul
  testWholeStructStorageWritePlanToYul
  testStoragePathWritePlanToYul
  IO.println "evm-semantic-plan: ok"
  return 0

end ProofForge.Tests.EvmSemanticPlan

def main : IO UInt32 :=
  ProofForge.Tests.EvmSemanticPlan.main
