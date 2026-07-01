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

def unitParameterModule : Module :=
  selectedModule "BadUnitParameter" {
    name := "set"
    selector? := some "60fe47b1"
    params := #[("value", .unit)]
    returns := .unit
    body := #[]
  }

def hashParameterModule : Module :=
  selectedModule "BadHashParameter" {
    name := "set"
    selector? := some "60fe47b1"
    params := #[("value", .hash)]
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
    kind := .map .hash 16
    type := .hash
  }]
  entrypoints := #[selectedEntrypoint "bad"]
}

def u64MapState : StateDecl := {
  id := "balances"
  kind := .map .u64 16
  type := .u64
}

def selectedMapModule (name : String) (entrypoint : Entrypoint) : Module := {
  name := name
  state := #[u64MapState]
  entrypoints := #[entrypoint]
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

def conditionalReturnModule : Module :=
  selectedModule "BadConditionalReturn" <| selectedReturnEntrypoint "bad" .u64 #[
    .ifElse (.literal (.bool true)) #[
      .return (.literal (.u64 1))
    ] #[
      .letBind "x" .u64 (.literal (.u64 2))
    ],
    .return (.literal (.u64 3))
  ]

def invalidBoundedLoopModule : Module :=
  selectedModule "BadLoopRange" <| selectedEntrypoint "bad" #[
    .boundedFor "_i" 3 3 #[]
  ]

def boundedLoopReturnModule : Module :=
  selectedModule "BadLoopReturn" <| selectedReturnEntrypoint "bad" .u64 #[
    .boundedFor "_i" 0 1 #[
      .return (.literal (.u64 1))
    ],
    .return (.literal (.u64 0))
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

def storageMapContainsModule : Module :=
  selectedMapModule "BadStorageMapContains" <| selectedReturnEntrypoint "bad" .bool #[
    .return (.effect (.storageMapContains "balances" (.literal (.u64 1))))
  ]

def storagePathEmptyModule : Module :=
  selectedMapModule "BadStoragePathEmpty" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storagePathRead "balances" #[]))
  ]

def storagePathNestedMapModule : Module :=
  selectedMapModule "BadStoragePathNestedMap" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storagePathRead "balances" #[.mapKey (.literal (.u64 1)), .mapKey (.literal (.u64 2))]))
  ]

def contextReadStmtModule : Module :=
  selectedModule "BadContextReadStmt" <| selectedEntrypoint "bad" #[
    .effect (.contextRead .userId)
  ]

def eventExprModule : Module :=
  selectedModule "BadEventExpr" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.eventEmit "Seen" #[("value", .literal (.u64 1))]))
  ]

def eventEmptyNameModule : Module :=
  selectedModule "BadEventEmptyName" <| selectedEntrypoint "bad" #[
    .effect (.eventEmit "" #[("value", .literal (.u64 1))])
  ]

def nativeValueModule : Module :=
  selectedModule "BadNativeValue" <| selectedReturnEntrypoint "bad" .u64 #[
    .return .nativeValue
  ]

def crosscallTargetTypeModule : Module :=
  selectedModule "BadCrosscallTargetType" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.crosscallInvoke (.literal (.bool true)) (.literal (.u64 2)) #[])
  ]

def crosscallMethodTypeModule : Module :=
  selectedModule "BadCrosscallMethodType" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.crosscallInvoke (.literal (.u64 1)) (.literal (.bool true)) #[])
  ]

def crosscallArgumentTypeModule : Module :=
  selectedModule "BadCrosscallArgumentType" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.crosscallInvoke (.literal (.u64 1)) (.literal (.u64 2)) #[.literal (.bool true)])
  ]

def hashLiteralModule : Module :=
  selectedModule "BadHashLiteral" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.literal (.hash4 1 2 3 4))
  ]

def hashExprModule : Module :=
  selectedModule "BadHashExpr" <| selectedReturnEntrypoint "bad" .hash #[
    .return (.hash (.literal (.u64 1)))
  ]

def invalidAssignmentTargetModule : Module :=
  selectedModule "BadAssignmentTarget" <| selectedEntrypoint "bad" #[
    .assign (.add (.literal (.u64 1)) (.literal (.u64 2))) (.literal (.u64 3))
  ]

def immutableAssignmentModule : Module :=
  selectedModule "BadImmutableAssignment" <| selectedEntrypoint "bad" #[
    .letBind "x" .u64 (.literal (.u64 1)),
    .assign (.local "x") (.literal (.u64 2))
  ]

def compoundAssignmentModule : Module :=
  selectedModule "BadCompoundAssignment" <| selectedEntrypoint "bad" #[
    .letMutBind "x" .u64 (.literal (.u64 1)),
    .assignOp (.local "x") .add (.literal (.u64 2))
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
    "unit parameter unsupported",
    unitParameterModule,
    "entrypoint `set` parameter `value` uses Unit; IR EVM v0 ABI parameters must use U32, U64, Bool, or Hash"
  ),
  (
    "missing return",
    missingReturnModule,
    "entrypoint `bad` returns `U64` but does not end with a return statement"
  ),
  (
    "hash return type mismatch",
    hashReturnModule,
    "return value expected `Hash`, got `U64`"
  ),
  (
    "bool scalar state unsupported",
    boolStateModule,
    "state `flag` has unsupported EVM IR v0 type `Bool`"
  ),
  (
    "map state shape unsupported",
    mapStateModule,
    "map state `balances` has unsupported EVM IR v0 type `Map<Hash, Hash, 16>`; only Map<U64, U64, N> is supported"
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
    "conditional branch return unsupported",
    conditionalReturnModule,
    "return statements inside if/else branches are not supported by IR EVM v0; return must be the final entrypoint statement"
  ),
  (
    "bounded loop invalid range",
    invalidBoundedLoopModule,
    "bounded loop `_i` must have stop greater than start"
  ),
  (
    "bounded loop return unsupported",
    boundedLoopReturnModule,
    "return statements inside bounded for loops are not supported by IR EVM v0; return must be the final entrypoint statement"
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
    "storage map contains unsupported",
    storageMapContainsModule,
    "storage.map.contains is not supported by IR EVM v0 because EVM mappings do not track key presence"
  ),
  (
    "storage path missing map key",
    storagePathEmptyModule,
    "storage path state `balances` is map storage; first segment must be a map key"
  ),
  (
    "storage path nested map unsupported",
    storagePathNestedMapModule,
    "EVM IR v0 supports only single-segment mapKey storage paths"
  ),
  (
    "context read used as statement",
    contextReadStmtModule,
    "context reads must be used as expressions"
  ),
  (
    "event used as expression",
    eventExprModule,
    "event.emit is a statement effect, not an expression"
  ),
  (
    "event empty name unsupported",
    eventEmptyNameModule,
    "event name must be non-empty for IR EVM v0"
  ),
  (
    "native value unsupported",
    nativeValueModule,
    "native value inspection is not supported by IR EVM v0"
  ),
  (
    "crosscall target type mismatch",
    crosscallTargetTypeModule,
    "crosscall target contract id expected `U64`, got `Bool`"
  ),
  (
    "crosscall method type mismatch",
    crosscallMethodTypeModule,
    "crosscall method id expected `U64`, got `Bool`"
  ),
  (
    "crosscall argument type mismatch",
    crosscallArgumentTypeModule,
    "crosscall argument expected `U64`, got `Bool`"
  ),
  (
    "hash literal return type mismatch",
    hashLiteralModule,
    "return value expected `U64`, got `Hash`"
  ),
  (
    "hash preimage type mismatch",
    hashExprModule,
    "hash preimage expected `Hash`, got `U64`"
  ),
  (
    "invalid assignment target unsupported",
    invalidAssignmentTargetModule,
    "assignment target must be a local in IR EVM v0"
  ),
  (
    "immutable assignment unsupported",
    immutableAssignmentModule,
    "assignment target local `x` is not mutable"
  ),
  (
    "compound assignment unsupported",
    compoundAssignmentModule,
    "compound assignment statements are not supported by IR EVM v0"
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
