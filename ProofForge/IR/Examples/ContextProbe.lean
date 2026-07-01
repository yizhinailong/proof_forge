import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.ContextProbe

open ProofForge.IR

def stateMarker : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
}

def sumContext : Entrypoint := {
  name := "sum_context"
  selector? := some "14a70e97"
  returns := .u64
  params := #[
    ("a", .u64),
    ("b", .u64)
  ]
  body := #[
    .return <|
      .add
        (.add (.local "a") (.local "b"))
        (.add
          (.effect (.contextRead .userId))
          (.add
            (.effect (.contextRead .contractId))
            (.effect (.contextRead .checkpointId))))
  ]
}

def nativeValue : Entrypoint := {
  name := "native_value"
  selector? := some "f0eba40f"
  returns := .u64
  body := #[
    .return .nativeValue
  ]
}

def module : Module := {
  name := "ContextProbe"
  state := #[stateMarker]
  entrypoints := #[sumContext, nativeValue]
}

end ProofForge.IR.Examples.ContextProbe
