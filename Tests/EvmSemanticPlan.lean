import ProofForge.Backend.Evm.IR
import ProofForge.IR.Examples.Counter
import ProofForge.IR.Examples.EventProbe

namespace ProofForge.Tests.EvmSemanticPlan

open ProofForge.IR
open ProofForge.Backend.Evm.IR

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def requireSome {α : Type} (value : Option α) (message : String) : IO α :=
  match value with
  | some x => pure x
  | none => throw <| IO.userError message

def requireOk {α : Type} (result : Except LowerError α) (message : String) : IO α :=
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
  let get := plan.entrypoints[2]!
  require (get.name == "get") "counter plan get name"
  require (get.selector == "6d4ce63c") "counter plan get selector"
  require (get.returns.returnType == .u64) "counter plan get returns u64"
  require (get.returns.wordTypes == #[.u64]) "counter plan get return words"
  let storageCount ← requireSome (plan.storage.find? "count") "counter plan missing count storage"
  require (storageCount.slot == 0) "counter plan count slot"
  require (storageCount.span == 1) "counter plan count span"
  require (plan.usesCheckedArithmetic == true) "counter plan checked arithmetic (increment uses add)"
  require (plan.creates.size == 0) "counter plan no creates"

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

def testSemanticPlanRender : IO Unit := do
  let rendered ← requireOk (renderSemanticPlan ProofForge.IR.Examples.Counter.module) "counter plan render"
  require (rendered.contains "module: Counter") "counter plan render module"
  require (rendered.contains "target: evm") "counter plan render target"
  require (rendered.contains "entrypoints:") "counter plan render entrypoints"
  require (rendered.contains "initialize") "counter plan render initialize"
  require (rendered.contains "storage:") "counter plan render storage"

def main : IO UInt32 := do
  testCounterSemanticPlan
  testEventSemanticPlan
  testArtifactMetadata
  testDeployMetadata
  testSemanticPlanRender
  IO.println "evm-semantic-plan: ok"
  return 0

end ProofForge.Tests.EvmSemanticPlan

def main : IO UInt32 :=
  ProofForge.Tests.EvmSemanticPlan.main