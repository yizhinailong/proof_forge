import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.EventProbe

open ProofForge.IR

def stateMarker : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
}

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

def module : Module := {
  name := "EventProbe"
  state := #[stateMarker]
  entrypoints := #[emitValueEvent, emitIndexedEvent]
}

end ProofForge.IR.Examples.EventProbe
