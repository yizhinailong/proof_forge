import ProofForge.Backend.Evm.IR
import ProofForge.IR.Contract

namespace ProofForge.Tests.EvmDiagnostics

open ProofForge.IR

def markerState : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
}

def countState : StateDecl := {
  id := "count"
  kind := .scalar
  type := .u64
}

def selectedEntrypoint (name : String) (body : Array Statement := #[]) : Entrypoint := {
  name := name
  selector? := some "deadbeef"
  returns := .unit
  body := body
}

def selectedReturnEntrypoint (name : String) (returns : ValueType) (body : Array Statement) : Entrypoint := {
  name := name
  selector? := some "deadbeef"
  returns := returns
  body := body
}

def selectedModule (name : String) (entrypoint : Entrypoint) : Module := {
  name := name
  state := #[markerState]
  entrypoints := #[entrypoint]
}

def missingSelectorModule : Module := {
  name := "MissingSelector"
  state := #[markerState]
  entrypoints := #[{
    name := "bad"
    returns := .unit
    body := #[]
  }]
}

def parameterModule : Module :=
  selectedModule "BadParameter" {
    name := "set"
    selector? := some "60fe47b1"
    params := #[("value", .u64)]
    returns := .unit
    body := #[]
  }

def missingReturnModule : Module :=
  selectedModule "BadMissingReturn" {
    name := "bad"
    selector? := some "deadbeef"
    returns := .u64
    body := #[.letBind "x" .u64 (.literal (.u64 1))]
  }

def hashReturnModule : Module :=
  selectedModule "BadHashReturn" {
    name := "bad"
    selector? := some "deadbeef"
    returns := .hash
    body := #[.return (.literal (.u64 1))]
  }

def boolStateModule : Module := {
  name := "BadBoolState"
  state := #[{
    id := "flag"
    kind := .scalar
    type := .bool
  }]
  entrypoints := #[selectedEntrypoint "bad"]
}

def mapStateModule : Module := {
  name := "BadMapState"
  state := #[{
    id := "balances"
    kind := .map .u64 16
    type := .u64
  }]
  entrypoints := #[selectedEntrypoint "bad"]
}

def storageArrayModule : Module := {
  name := "BadStorageArray"
  state := #[{
    id := "values"
    kind := .array 3
    type := .u64
  }]
  entrypoints := #[selectedEntrypoint "bad"]
}

def fixedArrayModule : Module :=
  selectedModule "BadFixedArray" <| selectedEntrypoint "bad" #[
    .letBind "xs" (.fixedArray .u64 2) (.arrayLit .u64 #[.literal (.u64 1), .literal (.u64 2)])
  ]

def pointStruct : StructDecl := {
  name := "Point"
  fields := #[{ id := "x", type := .u64 }]
}

def structModule : Module := {
  name := "BadStruct"
  structs := #[pointStruct]
  state := #[markerState]
  entrypoints := #[selectedEntrypoint "bad"]
}

def assertionModule : Module :=
  selectedModule "BadAssertion" <| selectedEntrypoint "bad" #[
    .assert (.literal (.bool true)) "not yet"
  ]

def conditionalModule : Module :=
  selectedModule "BadConditional" <| selectedEntrypoint "bad" #[
    .ifElse (.literal (.bool true)) #[] #[]
  ]

def boundedLoopModule : Module :=
  selectedModule "BadLoop" <| selectedEntrypoint "bad" #[
    .boundedFor "_i" 0 1 #[]
  ]

def storageWriteExprModule : Module :=
  selectedModule "BadStorageWriteExpr" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storageScalarWrite "_proof_forge_marker" (.literal (.u64 1))))
  ]

def storageReadStmtModule : Module :=
  selectedModule "BadStorageReadStmt" <| selectedEntrypoint "bad" #[
    .effect (.storageScalarRead "_proof_forge_marker")
  ]

def storageScalarAssignModule : Module := {
  name := "BadStorageAssign"
  state := #[countState]
  entrypoints := #[selectedEntrypoint "bad" #[
    .effect (.storageScalarAssignOp "count" .add (.literal (.u64 1)))
  ]]
}

def storageMapGetModule : Module :=
  selectedModule "BadStorageMapGet" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storageMapGet "balances" (.literal (.u64 1))))
  ]

def contextUserModule : Module :=
  selectedModule "BadContextUser" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.contextRead .userId))
  ]

def contextContractModule : Module :=
  selectedModule "BadContextContract" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.contextRead .contractId))
  ]

def eventModule : Module :=
  selectedModule "BadEvent" <| selectedEntrypoint "bad" #[
    .effect (.eventEmit "Seen" #[("value", .literal (.u64 1))])
  ]

def nativeValueModule : Module :=
  selectedModule "BadNativeValue" <| selectedReturnEntrypoint "bad" .u64 #[
    .return .nativeValue
  ]

def crosscallModule : Module :=
  selectedModule "BadCrosscall" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.crosscallInvoke (.literal (.u64 1)) (.literal (.u64 2)) #[])
  ]

def hashLiteralModule : Module :=
  selectedModule "BadHashLiteral" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.literal (.hash4 1 2 3 4))
  ]

def hashExprModule : Module :=
  selectedModule "BadHashExpr" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.hash (.literal (.hash4 1 2 3 4)))
  ]

def mutableLetModule : Module :=
  selectedModule "BadMutableLet" <| selectedEntrypoint "bad" #[
    .letMutBind "x" .u64 (.literal (.u64 1))
  ]

def assignmentModule : Module :=
  selectedModule "BadAssignment" <| selectedEntrypoint "bad" #[
    .letBind "x" .u64 (.literal (.u64 1)),
    .assign (.local "x") (.literal (.u64 2))
  ]

def renderError? (module : Module) : Option String :=
  match ProofForge.Backend.Evm.IR.renderModule module with
  | .ok _ => none
  | .error err => some err.render

def cases : Array (String × Module × String) := #[
  (
    "missing selector",
    missingSelectorModule,
    "entrypoint `bad` has no EVM selector metadata"
  ),
  (
    "entrypoint parameter unsupported",
    parameterModule,
    "entrypoint `set` has parameters; IR EVM v0 supports no parameters"
  ),
  (
    "missing return",
    missingReturnModule,
    "entrypoint `bad` returns `U64` but does not end with a return statement"
  ),
  (
    "hash return unsupported",
    hashReturnModule,
    "entrypoint `bad` returns Hash; IR EVM v0 supports only Unit, U64, and Bool"
  ),
  (
    "bool scalar state unsupported",
    boolStateModule,
    "state `flag` has unsupported EVM IR v0 type `Bool`"
  ),
  (
    "map state unsupported",
    mapStateModule,
    "state `balances` is storage.map; IR EVM v0 does not lower portable map storage yet"
  ),
  (
    "storage array capability unsupported",
    storageArrayModule,
    "target `evm` does not support capability `storage.array`: capability is not present in the target profile"
  ),
  (
    "fixed array capability unsupported",
    fixedArrayModule,
    "target `evm` does not support capability `data.fixed_array`: capability is not present in the target profile"
  ),
  (
    "struct capability unsupported",
    structModule,
    "target `evm` does not support capability `data.struct`: capability is not present in the target profile"
  ),
  (
    "assertion capability unsupported",
    assertionModule,
    "target `evm` does not support capability `assertions.check`: capability is not present in the target profile"
  ),
  (
    "conditional capability unsupported",
    conditionalModule,
    "target `evm` does not support capability `control.conditional`: capability is not present in the target profile"
  ),
  (
    "bounded loop capability unsupported",
    boundedLoopModule,
    "target `evm` does not support capability `control.bounded_loop`: capability is not present in the target profile"
  ),
  (
    "storage write used as expression",
    storageWriteExprModule,
    "storage.scalar.write is a statement effect, not an expression"
  ),
  (
    "storage read used as statement",
    storageReadStmtModule,
    "storage.scalar.read must be used as an expression"
  ),
  (
    "storage scalar assign_op unsupported",
    storageScalarAssignModule,
    "storage.scalar.assign_op is not supported by IR EVM v0"
  ),
  (
    "storage map get unsupported",
    storageMapGetModule,
    "storage.map.get is not supported by IR EVM v0"
  ),
  (
    "context user unsupported",
    contextUserModule,
    "context field `userId` is not supported by IR EVM v0"
  ),
  (
    "context contract capability unsupported",
    contextContractModule,
    "target `evm` does not support capability `account.explicit`: capability is not present in the target profile"
  ),
  (
    "event unsupported",
    eventModule,
    "event emission is not supported by IR EVM v0"
  ),
  (
    "native value unsupported",
    nativeValueModule,
    "native value inspection is not supported by IR EVM v0"
  ),
  (
    "crosscall unsupported",
    crosscallModule,
    "cross-contract calls are not supported by IR EVM v0"
  ),
  (
    "hash literal unsupported",
    hashLiteralModule,
    "Hash literals are not supported by IR EVM v0"
  ),
  (
    "hash expression unsupported",
    hashExprModule,
    "crypto.hash is not supported by IR EVM v0"
  ),
  (
    "mutable let unsupported",
    mutableLetModule,
    "mutable let binding `x` is not supported by IR EVM v0"
  ),
  (
    "assignment unsupported",
    assignmentModule,
    "assignment statements are not supported by IR EVM v0"
  )
]

def checkCase (name : String) (module : Module) (expected : String) : IO Bool := do
  match renderError? module with
  | some actual =>
      if actual == expected then
        IO.println s!"evm-diagnostics: ok: {name}"
        pure true
      else
        IO.eprintln s!"evm-diagnostics: FAILED: {name}"
        IO.eprintln s!"  expected: {expected}"
        IO.eprintln s!"  actual:   {actual}"
        pure false
  | none =>
      IO.eprintln s!"evm-diagnostics: FAILED: {name}"
      IO.eprintln "  expected an error, but EVM IR generation succeeded"
      pure false

def main : IO UInt32 := do
  let mut failures : Nat := 0
  for (name, module, expected) in cases do
    let ok ← checkCase name module expected
    if !ok then
      failures := failures + 1
  if failures == 0 then
    IO.println s!"evm-diagnostics: {cases.size} cases passed"
    pure 0
  else
    IO.eprintln s!"evm-diagnostics: {failures} case(s) failed"
    pure 1

end ProofForge.Tests.EvmDiagnostics

def main : IO UInt32 :=
  ProofForge.Tests.EvmDiagnostics.main
