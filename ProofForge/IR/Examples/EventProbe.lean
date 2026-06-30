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
  returns := .unit
  params := #[("value", .u64)]
  body := #[
    .effect (.eventEmit "ValueEvent" #[("value", .local "value")])
  ]
}

def module : Module := {
  name := "EventProbe"
  state := #[stateMarker]
  entrypoints := #[emitValueEvent]
}

end ProofForge.IR.Examples.EventProbe
