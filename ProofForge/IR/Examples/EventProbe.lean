import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.EventProbe

open ProofForge.IR

def stateMarker : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
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
  state := #[stateMarker]
  entrypoints := #[
    emitValueEvent,
    emitIndexedEvent,
    emitPairEvent,
    emitArrayEvent,
    emitPairArrayEvent,
    emitIndexedPairEvent,
    emitIndexedPairArrayEvent
  ]
}

end ProofForge.IR.Examples.EventProbe
