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

def rootState : StateDecl := {
  id := "root"
  kind := .scalar
  type := .hash
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

def zeroLengthAbiArrayModule : Module :=
  selectedModule "BadZeroLengthAbiArray" {
    name := "bad"
    selector? := some "deadbeef"
    params := #[("xs", .fixedArray .u64 0)]
    returns := .unit
    body := #[]
  }

def nestedAbiArrayModule : Module :=
  selectedModule "BadNestedAbiArray" {
    name := "bad"
    selector? := some "deadbeef"
    params := #[("xs", .fixedArray (.fixedArray .u64 2) 2)]
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

def unitStateModule : Module := {
  name := "BadUnitState"
  state := #[{
    id := "void"
    kind := .scalar
    type := .unit
  }]
  entrypoints := #[selectedEntrypoint "bad"]
}

def mapStateModule : Module := {
  name := "BadMapState"
  state := #[{
    id := "balances"
    kind := .map .unit 16
    type := .u64
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
  name := "BadUnitStorageArray"
  state := #[{
    id := "voids"
    kind := .array 3
    type := .unit
  }]
  entrypoints := #[selectedEntrypoint "bad"]
}

def u64ArrayState : StateDecl := {
  id := "values"
  kind := .array 3
  type := .u64
}

def selectedArrayModule (name : String) (entrypoint : Entrypoint) : Module := {
  name := name
  state := #[u64ArrayState]
  entrypoints := #[entrypoint]
}

def immutableFixedArrayElementAssignmentModule : Module :=
  selectedModule "BadImmutableFixedArrayElementAssignment" <| selectedEntrypoint "bad" #[
    .letBind "xs" (.fixedArray .u64 2) (.arrayLit .u64 #[.literal (.u64 1), .literal (.u64 2)]),
    .assign (.arrayGet (.local "xs") (.literal (.u64 0))) (.literal (.u64 3))
  ]

def fixedArrayOutOfBoundsModule : Module :=
  selectedModule "BadFixedArrayOutOfBounds" <| selectedReturnEntrypoint "bad" .u64 #[
    .letBind "xs" (.fixedArray .u64 2) (.arrayLit .u64 #[.literal (.u64 1), .literal (.u64 2)]),
    .return (.arrayGet (.local "xs") (.literal (.u64 2)))
  ]

def pointStruct : StructDecl := {
  name := "Point"
  fields := #[{ id := "x", type := .u64 }]
}

def structStorageMissingFieldModule : Module := {
  name := "BadStructStorageMissingField"
  structs := #[pointStruct]
  state := #[{
    id := "current"
    kind := .scalar
    type := .structType "Point"
  }]
  entrypoints := #[selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storageStructFieldRead "current" "y"))
  ]]
}

def immutableStructFieldAssignmentModule : Module := {
  name := "BadImmutableStructFieldAssignment"
  structs := #[pointStruct]
  state := #[markerState]
  entrypoints := #[selectedEntrypoint "bad" #[
    .letBind "p" (.structType "Point") (.structLit "Point" #[("x", .literal (.u64 1))]),
    .assign (.field (.local "p") "x") (.literal (.u64 2))
  ]]
}

def wrapperStruct : StructDecl := {
  name := "Wrapper"
  fields := #[{ id := "point", type := .structType "Point" }]
}

def nestedStructModule : Module := {
  name := "BadNestedStruct"
  structs := #[pointStruct, wrapperStruct]
  state := #[markerState]
  entrypoints := #[selectedEntrypoint "bad"]
}

def duplicateStructModule : Module := {
  name := "BadDuplicateStruct"
  structs := #[pointStruct, pointStruct]
  state := #[markerState]
  entrypoints := #[selectedEntrypoint "bad"]
}

def emptyStruct : StructDecl := {
  name := "Empty"
  fields := #[]
}

def emptyStructModule : Module := {
  name := "BadEmptyStruct"
  structs := #[emptyStruct]
  state := #[markerState]
  entrypoints := #[selectedEntrypoint "bad"]
}

def duplicateFieldStruct : StructDecl := {
  name := "DuplicateField"
  fields := #[
    { id := "x", type := .u64 },
    { id := "x", type := .u32 }
  ]
}

def duplicateStructFieldModule : Module := {
  name := "BadDuplicateStructField"
  structs := #[duplicateFieldStruct]
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

def storageArrayReadStmtModule : Module :=
  selectedArrayModule "BadStorageArrayReadStmt" <| selectedEntrypoint "bad" #[
    .effect (.storageArrayRead "values" (.literal (.u64 0)))
  ]

def storageArrayWriteExprModule : Module :=
  selectedArrayModule "BadStorageArrayWriteExpr" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storageArrayWrite "values" (.literal (.u64 0)) (.literal (.u64 1))))
  ]

def storageScalarAssignModule : Module := {
  name := "BadStorageAssign"
  state := #[rootState]
  entrypoints := #[selectedEntrypoint "bad" #[
    .effect (.storageScalarAssignOp "root" .add (.literal (.hash4 1 2 3 4)))
  ]]
}

def storageMapContainsStatementModule : Module :=
  selectedMapModule "BadStorageMapContainsStatement" <| selectedEntrypoint "bad" #[
    .effect (.storageMapContains "balances" (.literal (.u64 1)))
  ]

def storagePathEmptyModule : Module :=
  selectedMapModule "BadStoragePathEmpty" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storagePathRead "balances" #[]))
  ]

def storagePathNestedMapModule : Module :=
  selectedMapModule "BadStoragePathNestedMap" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storagePathRead "balances" #[.mapKey (.literal (.u64 1)), .mapKey (.literal (.u64 2))]))
  ]

def storagePathFieldModule : Module :=
  selectedMapModule "BadStoragePathField" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storagePathRead "balances" #[.field "amount"]))
  ]

def storagePathIndexModule : Module :=
  selectedMapModule "BadStoragePathIndex" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storagePathRead "balances" #[.index (.literal (.u64 0))]))
  ]

def storageArrayPathNestedIndexModule : Module :=
  selectedArrayModule "BadStorageArrayPathNestedIndex" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storagePathRead "values" #[.index (.literal (.u64 0)), .index (.literal (.u64 1))]))
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

def eventIndexedExprModule : Module :=
  selectedModule "BadEventIndexedExpr" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.eventEmitIndexed "Seen" #[("user", .literal (.u64 1))] #[("value", .literal (.u64 2))]))
  ]

def eventTooManyIndexedModule : Module :=
  selectedModule "BadEventTooManyIndexed" <| selectedEntrypoint "bad" #[
    .effect (.eventEmitIndexed "Seen" #[
      ("a", .literal (.u64 1)),
      ("b", .literal (.u64 2)),
      ("c", .literal (.u64 3)),
      ("d", .literal (.u64 4))
    ] #[("value", .literal (.u64 5))])
  ]

def eventIndexedAggregateModule : Module := {
  name := "BadEventIndexedAggregate"
  structs := #[pointStruct]
  state := #[markerState]
  entrypoints := #[selectedEntrypoint "bad" #[
    .effect (.eventEmitIndexed
      "Seen"
      #[("point", .structLit "Point" #[("x", .literal (.u64 1))])]
      #[])
  ]]
}

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

def typedCrosscallReturnTypeModule : Module := {
  name := "BadTypedCrosscallReturnType"
  structs := #[pointStruct]
  state := #[markerState]
  entrypoints := #[selectedReturnEntrypoint "bad" (.structType "Point") #[
    .return (.crosscallInvokeTyped (.literal (.u64 1)) (.literal (.u64 2)) #[] (.structType "Point"))
  ]]
}

def typedCrosscallArgumentTypeModule : Module :=
  selectedModule "BadTypedCrosscallArgumentType" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.crosscallInvokeTyped
      (.literal (.u64 1))
      (.literal (.u64 2))
      #[.arrayLit .u64 #[.literal (.u64 1), .literal (.u64 2)]]
      .u64)
  ]

def valueCrosscallValueTypeModule : Module :=
  selectedModule "BadValueCrosscallValueType" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.crosscallInvokeValueTyped
      (.literal (.u64 1))
      (.literal (.u64 2))
      (.literal (.bool true))
      #[]
      .u64)
  ]

def valueCrosscallReturnTypeModule : Module :=
  selectedModule "BadValueCrosscallReturnType" <| selectedReturnEntrypoint "bad" (.fixedArray .u64 2) #[
    .return (.crosscallInvokeValueTyped
      (.literal (.u64 1))
      (.literal (.u64 2))
      (.literal (.u64 3))
      #[]
      (.fixedArray .u64 2))
  ]

def staticCrosscallArgumentTypeModule : Module :=
  selectedModule "BadStaticCrosscallArgumentType" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.crosscallInvokeStaticTyped
      (.literal (.u64 1))
      (.literal (.u64 2))
      #[.arrayLit .u64 #[.literal (.u64 1), .literal (.u64 2)]]
      .u64)
  ]

def staticCrosscallReturnTypeModule : Module :=
  selectedModule "BadStaticCrosscallReturnType" <| selectedReturnEntrypoint "bad" (.fixedArray .u64 2) #[
    .return (.crosscallInvokeStaticTyped
      (.literal (.u64 1))
      (.literal (.u64 2))
      #[]
      (.fixedArray .u64 2))
  ]

def delegateCrosscallArgumentTypeModule : Module :=
  selectedModule "BadDelegateCrosscallArgumentType" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.crosscallInvokeDelegateTyped
      (.literal (.u64 1))
      (.literal (.u64 2))
      #[.arrayLit .u64 #[.literal (.u64 1), .literal (.u64 2)]]
      .u64)
  ]

def delegateCrosscallReturnTypeModule : Module :=
  selectedModule "BadDelegateCrosscallReturnType" <| selectedReturnEntrypoint "bad" (.fixedArray .u64 2) #[
    .return (.crosscallInvokeDelegateTyped
      (.literal (.u64 1))
      (.literal (.u64 2))
      #[]
      (.fixedArray .u64 2))
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

def storagePathAssignExprModule : Module :=
  selectedMapModule "BadStoragePathAssignExpr" <| selectedReturnEntrypoint "bad" .u64 #[
    .return (.effect (.storagePathAssignOp "balances" #[.mapKey (.literal (.u64 1))] .add (.literal (.u64 2))))
  ]

def storagePathAssignNestedModule : Module :=
  selectedMapModule "BadStoragePathAssignNested" <| selectedEntrypoint "bad" #[
    .effect (.storagePathAssignOp "balances" #[.mapKey (.literal (.u64 1)), .mapKey (.literal (.u64 2))] .add (.literal (.u64 3)))
  ]

def compoundAssignmentTargetModule : Module :=
  selectedModule "BadCompoundAssignmentTarget" <| selectedEntrypoint "bad" #[
    .assignOp (.add (.literal (.u64 1)) (.literal (.u64 2))) .add (.literal (.u64 3))
  ]

def compoundAssignmentTypeModule : Module :=
  selectedModule "BadCompoundAssignmentType" <| selectedEntrypoint "bad" #[
    .letMutBind "flag" .bool (.literal (.bool true)),
    .assignOp (.local "flag") .add (.literal (.bool false))
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
    "entrypoint `set` parameter `value` uses Unit; IR EVM v0 ABI values must use U32, U64, Bool, Hash, fixed arrays, or structs"
  ),
  (
    "zero-length ABI array unsupported",
    zeroLengthAbiArrayModule,
    "entrypoint `bad` parameter `xs` uses Array<U64,0>; IR EVM v0 ABI fixed arrays must have non-zero length"
  ),
  (
    "nested ABI array unsupported",
    nestedAbiArrayModule,
    "entrypoint `bad` parameter `xs` fixed-array element has unsupported EVM IR v0 ABI aggregate type `Array<U64,2>`; ABI fixed arrays support U32, U64, Bool, Hash, or flat structs"
  ),
  (
    "missing return",
    missingReturnModule,
    "entrypoint `bad` returns `U64` but does not return on every control-flow path"
  ),
  (
    "hash return type mismatch",
    hashReturnModule,
    "return value expected `Hash`, got `U64`"
  ),
  (
    "unit scalar state unsupported",
    unitStateModule,
    "state `void` has unsupported EVM IR v0 type `Unit`"
  ),
  (
    "map state shape unsupported",
    mapStateModule,
    "map state `balances` has unsupported EVM IR v0 type `Map<Unit, U64, 16>`; storage maps support key/value word types U32, U64, Bool, or Hash"
  ),
  (
    "storage array element type unsupported",
    storageArrayModule,
    "array state `voids` has unsupported EVM IR v0 element type `Unit`; storage arrays support U32, U64, Bool, Hash, or flat struct arrays"
  ),
  (
    "immutable fixed array element assignment unsupported",
    immutableFixedArrayElementAssignmentModule,
    "assignment target local `xs` is not mutable"
  ),
  (
    "fixed array literal out of bounds",
    fixedArrayOutOfBoundsModule,
    "fixed array index 2 is out of bounds for length 2"
  ),
  (
    "struct storage missing field unsupported",
    structStorageMissingFieldModule,
    "struct `Point` has no field `y`"
  ),
  (
    "immutable struct field assignment unsupported",
    immutableStructFieldAssignmentModule,
    "assignment target local `p` is not mutable"
  ),
  (
    "nested struct field unsupported",
    nestedStructModule,
    "field `point` in struct `Wrapper` has unsupported EVM IR v0 local struct field type `Point`; local structs support U32, U64, Bool, or Hash fields"
  ),
  (
    "duplicate struct declaration unsupported",
    duplicateStructModule,
    "duplicate struct `Point`"
  ),
  (
    "empty struct declaration unsupported",
    emptyStructModule,
    "struct `Empty` must declare at least one field"
  ),
  (
    "duplicate struct field unsupported",
    duplicateStructFieldModule,
    "duplicate field `x` in struct `DuplicateField`"
  ),
  (
    "bounded loop invalid range",
    invalidBoundedLoopModule,
    "bounded loop `_i` must have stop greater than start"
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
    "storage array read used as statement",
    storageArrayReadStmtModule,
    "storage.array.read must be used as an expression"
  ),
  (
    "storage array write used as expression",
    storageArrayWriteExprModule,
    "storage.array.write is a statement effect, not an expression"
  ),
  (
    "storage scalar assign_op type mismatch",
    storageScalarAssignModule,
    "compound assignment addition expects matching numeric operands, got `Hash` and `Hash`"
  ),
  (
    "storage map contains statement misuse",
    storageMapContainsStatementModule,
    "storage.map.contains must be used as an expression"
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
    "storage path field unsupported",
    storagePathFieldModule,
    "EVM IR v0 supports only single-segment mapKey storage paths"
  ),
  (
    "storage path index unsupported",
    storagePathIndexModule,
    "EVM IR v0 supports only single-segment mapKey storage paths"
  ),
  (
    "storage array path nested index unsupported",
    storageArrayPathNestedIndexModule,
    "EVM IR v0 supports only single-segment index storage paths for arrays"
  ),
  (
    "storage path assign_op used as expression",
    storagePathAssignExprModule,
    "storage.path.assign_op is a statement effect, not an expression"
  ),
  (
    "storage path assign_op nested map unsupported",
    storagePathAssignNestedModule,
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
    "indexed event used as expression",
    eventIndexedExprModule,
    "event.emit.indexed is a statement effect, not an expression"
  ),
  (
    "event too many indexed fields unsupported",
    eventTooManyIndexedModule,
    "event `Seen` has 4 indexed field(s); EVM IR v0 supports at most 3 indexed fields"
  ),
  (
    "indexed aggregate event field unsupported",
    eventIndexedAggregateModule,
    "event `Seen` indexed field `point` has unsupported EVM IR v0 type `Point`; indexed event fields must be U32, U64, Bool, or Hash"
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
    "typed crosscall return type unsupported",
    typedCrosscallReturnTypeModule,
    "typed crosscall return has unsupported EVM IR v0 crosscall word type `Point`; crosscall scalar words support U32, U64, Bool, or Hash"
  ),
  (
    "typed crosscall argument type unsupported",
    typedCrosscallArgumentTypeModule,
    "typed crosscall argument has unsupported EVM IR v0 crosscall word type `Array<U64,2>`; crosscall scalar words support U32, U64, Bool, or Hash"
  ),
  (
    "value crosscall call value type mismatch",
    valueCrosscallValueTypeModule,
    "value crosscall call value expected `U64`, got `Bool`"
  ),
  (
    "value crosscall return type unsupported",
    valueCrosscallReturnTypeModule,
    "value crosscall return has unsupported EVM IR v0 crosscall word type `Array<U64,2>`; crosscall scalar words support U32, U64, Bool, or Hash"
  ),
  (
    "static crosscall argument type unsupported",
    staticCrosscallArgumentTypeModule,
    "static crosscall argument has unsupported EVM IR v0 crosscall word type `Array<U64,2>`; crosscall scalar words support U32, U64, Bool, or Hash"
  ),
  (
    "static crosscall return type unsupported",
    staticCrosscallReturnTypeModule,
    "static crosscall return has unsupported EVM IR v0 crosscall word type `Array<U64,2>`; crosscall scalar words support U32, U64, Bool, or Hash"
  ),
  (
    "delegate crosscall argument type unsupported",
    delegateCrosscallArgumentTypeModule,
    "delegate crosscall argument has unsupported EVM IR v0 crosscall word type `Array<U64,2>`; crosscall scalar words support U32, U64, Bool, or Hash"
  ),
  (
    "delegate crosscall return type unsupported",
    delegateCrosscallReturnTypeModule,
    "delegate crosscall return has unsupported EVM IR v0 crosscall word type `Array<U64,2>`; crosscall scalar words support U32, U64, Bool, or Hash"
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
    "assignment target must be a mutable local, mutable local fixed-array element, mutable local struct field, or mutable local struct-array field in IR EVM v0"
  ),
  (
    "immutable assignment unsupported",
    immutableAssignmentModule,
    "assignment target local `x` is not mutable"
  ),
  (
    "compound assignment target unsupported",
    compoundAssignmentTargetModule,
    "compound assignment target must be a mutable local, mutable local fixed-array element, mutable local struct field, or mutable local struct-array field in IR EVM v0"
  ),
  (
    "compound assignment type mismatch",
    compoundAssignmentTypeModule,
    "compound assignment addition expects matching numeric operands, got `Bool` and `Bool`"
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
