import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.EventProbe

open ProofForge.IR

def stateMarker : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
}

def storedPairState : StateDecl := {
  id := "storedPair"
  kind := .scalar
  type := .structType "Pair"
}

def storedValuesState : StateDecl := {
  id := "storedValues"
  kind := .array 2
  type := .u64
}

def storedPairsState : StateDecl := {
  id := "storedPairs"
  kind := .array 2
  type := .structType "Pair"
}

def pairStruct : StructDecl := {
  name := "Pair"
  fields := #[
    { id := "left", type := .u64 },
    { id := "right", type := .u64 }
  ]
}

def pair (left right : Expr) : Expr :=
  .structLit "Pair" #[
    ("left", left),
    ("right", right)
  ]

def u64 (value : Nat) : Expr :=
  .literal (.u64 value)

def storedValues : Expr :=
  .arrayLit .u64 #[
    .effect (.storageArrayRead "storedValues" (u64 0)),
    .effect (.storageArrayRead "storedValues" (u64 1))
  ]

def storedPairAt (index : Nat) : Expr :=
  pair
    (.effect (.storageArrayStructFieldRead "storedPairs" (u64 index) "left"))
    (.effect (.storageArrayStructFieldRead "storedPairs" (u64 index) "right"))

def storedPairs : Expr :=
  .arrayLit (.structType "Pair") #[
    storedPairAt 0,
    storedPairAt 1
  ]

def emitValueEvent : Entrypoint := {
  name := "emit_value_event"
  selector? := some "2ae8cae3"
  returns := .unit
  params := #[("value", .u64)]
  body := #[
    .effect (.eventEmit "ValueEvent" #[("value", .local "value")])
  ]
}

def emitIndexedEvent : Entrypoint := {
  name := "emit_indexed_event"
  selector? := some "bc07d04f"
  returns := .unit
  params := #[("user", .u64), ("value", .u64)]
  body := #[
    .effect (.eventEmitIndexed
      "IndexedValue"
      #[("user", .local "user")]
      #[("value", .local "value")])
  ]
}

def emitTwoIndexedEvent : Entrypoint := {
  name := "emit_two_indexed_event"
  selector? := some "2d00700c"
  returns := .unit
  params := #[("first", .u64), ("second", .u64), ("value", .u64)]
  body := #[
    .effect (.eventEmitIndexed
      "IndexedTwoValues"
      #[("first", .local "first"), ("second", .local "second")]
      #[("value", .local "value")])
  ]
}

def emitThreeIndexedEvent : Entrypoint := {
  name := "emit_three_indexed_event"
  selector? := some "e7d142d1"
  returns := .unit
  params := #[("first", .u64), ("second", .u64), ("third", .u64), ("value", .u64)]
  body := #[
    .effect (.eventEmitIndexed
      "IndexedThreeValues"
      #[("first", .local "first"), ("second", .local "second"), ("third", .local "third")]
      #[("value", .local "value")])
  ]
}

def emitPairEvent : Entrypoint := {
  name := "emit_pair_event"
  selector? := some "35361bda"
  returns := .unit
  params := #[("left", .u64), ("right", .u64)]
  body := #[
    .letBind "pair" (.structType "Pair") (pair (.local "left") (.local "right")),
    .effect (.eventEmit "PairEvent" #[("pair", .local "pair")])
  ]
}

def emitStoragePairEvent : Entrypoint := {
  name := "emit_storage_pair_event"
  selector? := some "65123829"
  returns := .unit
  params := #[("left", .u64), ("right", .u64)]
  body := #[
    .effect (.storageScalarWrite "storedPair" (pair (.local "left") (.local "right"))),
    .effect (.eventEmit "StoragePairEvent" #[("pair", .effect (.storageScalarRead "storedPair"))])
  ]
}

def emitStorageArrayEvent : Entrypoint := {
  name := "emit_storage_array_event"
  selector? := some "99eb21de"
  returns := .unit
  params := #[("left", .u64), ("right", .u64)]
  body := #[
    .effect (.storageArrayWrite "storedValues" (u64 0) (.local "left")),
    .effect (.storageArrayWrite "storedValues" (u64 1) (.local "right")),
    .effect (.eventEmit "StorageArrayEvent" #[("values", storedValues)])
  ]
}

def emitArrayEvent : Entrypoint := {
  name := "emit_array_event"
  selector? := some "393f7138"
  returns := .unit
  params := #[("left", .u64), ("right", .u64)]
  body := #[
    .letBind "values" (.fixedArray .u64 2) (.arrayLit .u64 #[.local "left", .local "right"]),
    .effect (.eventEmit "ArrayEvent" #[("values", .local "values")])
  ]
}

def emitPairArrayEvent : Entrypoint := {
  name := "emit_pair_array_event"
  selector? := some "85611e74"
  returns := .unit
  params := #[("a", .u64), ("b", .u64), ("c", .u64), ("d", .u64)]
  body := #[
    .letBind "pairs" (.fixedArray (.structType "Pair") 2) (.arrayLit (.structType "Pair") #[
      pair (.local "a") (.local "b"),
      pair (.local "c") (.local "d")
    ]),
    .effect (.eventEmit "PairArrayEvent" #[("pairs", .local "pairs")])
  ]
}

def emitStoragePairArrayEvent : Entrypoint := {
  name := "emit_storage_pair_array_event"
  selector? := some "f31d3375"
  returns := .unit
  params := #[("a", .u64), ("b", .u64), ("c", .u64), ("d", .u64)]
  body := #[
    .effect (.storageArrayStructFieldWrite "storedPairs" (u64 0) "left" (.local "a")),
    .effect (.storageArrayStructFieldWrite "storedPairs" (u64 0) "right" (.local "b")),
    .effect (.storageArrayStructFieldWrite "storedPairs" (u64 1) "left" (.local "c")),
    .effect (.storageArrayStructFieldWrite "storedPairs" (u64 1) "right" (.local "d")),
    .effect (.eventEmit "StoragePairArrayEvent" #[("pairs", storedPairs)])
  ]
}

def emitIndexedPairEvent : Entrypoint := {
  name := "emit_indexed_pair_event"
  selector? := some "e027f054"
  returns := .unit
  params := #[("left", .u64), ("right", .u64), ("value", .u64)]
  body := #[
    .letBind "pair" (.structType "Pair") (pair (.local "left") (.local "right")),
    .effect (.eventEmitIndexed
      "IndexedPair"
      #[("pair", .local "pair")]
      #[("value", .local "value")])
  ]
}

def emitIndexedStoragePairEvent : Entrypoint := {
  name := "emit_indexed_storage_pair_event"
  selector? := some "f4a27402"
  returns := .unit
  params := #[("left", .u64), ("right", .u64), ("value", .u64)]
  body := #[
    .effect (.storageScalarWrite "storedPair" (pair (.local "left") (.local "right"))),
    .effect (.eventEmitIndexed
      "IndexedStoragePair"
      #[("pair", .effect (.storageScalarRead "storedPair"))]
      #[("value", .local "value")])
  ]
}

def emitIndexedStorageArrayEvent : Entrypoint := {
  name := "emit_indexed_storage_array_event"
  selector? := some "42a8056e"
  returns := .unit
  params := #[("left", .u64), ("right", .u64), ("value", .u64)]
  body := #[
    .effect (.storageArrayWrite "storedValues" (u64 0) (.local "left")),
    .effect (.storageArrayWrite "storedValues" (u64 1) (.local "right")),
    .effect (.eventEmitIndexed
      "IndexedStorageArray"
      #[("values", storedValues)]
      #[("value", .local "value")])
  ]
}

def emitIndexedArrayEvent : Entrypoint := {
  name := "emit_indexed_array_event"
  selector? := some "b7de5dd7"
  returns := .unit
  params := #[("left", .u64), ("right", .u64), ("value", .u64)]
  body := #[
    .letBind "values" (.fixedArray .u64 2) (.arrayLit .u64 #[.local "left", .local "right"]),
    .effect (.eventEmitIndexed
      "IndexedArray"
      #[("values", .local "values")]
      #[("value", .local "value")])
  ]
}

def emitIndexedStoragePairArrayEvent : Entrypoint := {
  name := "emit_indexed_storage_pair_array_event"
  selector? := some "45440e6c"
  returns := .unit
  params := #[("a", .u64), ("b", .u64), ("c", .u64), ("d", .u64), ("value", .u64)]
  body := #[
    .effect (.storageArrayStructFieldWrite "storedPairs" (u64 0) "left" (.local "a")),
    .effect (.storageArrayStructFieldWrite "storedPairs" (u64 0) "right" (.local "b")),
    .effect (.storageArrayStructFieldWrite "storedPairs" (u64 1) "left" (.local "c")),
    .effect (.storageArrayStructFieldWrite "storedPairs" (u64 1) "right" (.local "d")),
    .effect (.eventEmitIndexed
      "IndexedStoragePairArray"
      #[("pairs", storedPairs)]
      #[("value", .local "value")])
  ]
}

def emitIndexedPairArrayEvent : Entrypoint := {
  name := "emit_indexed_pair_array_event"
  selector? := some "c1375f82"
  returns := .unit
  params := #[("a", .u64), ("b", .u64), ("c", .u64), ("d", .u64), ("value", .u64)]
  body := #[
    .letBind "pairs" (.fixedArray (.structType "Pair") 2) (.arrayLit (.structType "Pair") #[
      pair (.local "a") (.local "b"),
      pair (.local "c") (.local "d")
    ]),
    .effect (.eventEmitIndexed
      "IndexedPairArray"
      #[("pairs", .local "pairs")]
      #[("value", .local "value")])
  ]
}

def module : Module := {
  name := "EventProbe"
  state := #[stateMarker]
  entrypoints := #[emitValueEvent]
}

def evmModule : Module := {
  name := "EventProbe"
  structs := #[pairStruct]
  state := #[stateMarker, storedPairState, storedValuesState, storedPairsState]
  entrypoints := #[
    emitValueEvent,
    emitIndexedEvent,
    emitTwoIndexedEvent,
    emitThreeIndexedEvent,
    emitPairEvent,
    emitStoragePairEvent,
    emitStorageArrayEvent,
    emitArrayEvent,
    emitPairArrayEvent,
    emitStoragePairArrayEvent,
    emitIndexedPairEvent,
    emitIndexedStoragePairEvent,
    emitIndexedStorageArrayEvent,
    emitIndexedArrayEvent,
    emitIndexedStoragePairArrayEvent,
    emitIndexedPairArrayEvent
  ]
}

end ProofForge.IR.Examples.EventProbe
