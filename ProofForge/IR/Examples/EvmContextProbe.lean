import ProofForge.IR.Examples.ContextProbe

namespace ProofForge.IR.Examples.EvmContextProbe

open ProofForge.IR

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
  state := #[ProofForge.IR.Examples.ContextProbe.stateMarker]
  entrypoints := #[
    ProofForge.IR.Examples.ContextProbe.sumContext,
    nativeValue
  ]
}

end ProofForge.IR.Examples.EvmContextProbe
