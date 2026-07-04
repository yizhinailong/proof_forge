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

def contextExtras : Entrypoint := {
  name := "context_extras"
  selector? := some "d9b80589"
  returns := .fixedArray .u64 6
  body := #[
    .return <| .arrayLit .u64 #[
      .effect (.contextRead .timestamp),
      .effect (.contextRead .chainId),
      .effect (.contextRead .gasPrice),
      .effect (.contextRead .gasLeft),
      .effect (.contextRead .baseFee),
      .effect (.contextRead .prevRandao)
    ]
  ]
}

def module : Module := {
  name := "ContextProbe"
  state := #[ProofForge.IR.Examples.ContextProbe.stateMarker]
  entrypoints := #[
    ProofForge.IR.Examples.ContextProbe.sumContext,
    nativeValue,
    contextExtras
  ]
}

end ProofForge.IR.Examples.EvmContextProbe
