import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.EvmCrosscallProbe

open ProofForge.IR

def stateMarker : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
}

def callRemote : Entrypoint := {
  name := "call_remote"
  selector? := some "0de1d044"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvoke (.local "target") (.local "method") #[])
  ]
}

def callRemote1 : Entrypoint := {
  name := "call_remote1"
  selector? := some "7ec7d7f8"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("x", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvoke (.local "target") (.local "method") #[.local "x"])
  ]
}

def callRemote2 : Entrypoint := {
  name := "call_remote2"
  selector? := some "ff5ce87f"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("x", .u64),
    ("y", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvoke (.local "target") (.local "method") #[.local "x", .local "y"])
  ]
}

def module : Module := {
  name := "EvmCrosscallProbe"
  state := #[stateMarker]
  entrypoints := #[callRemote, callRemote1, callRemote2]
}

end ProofForge.IR.Examples.EvmCrosscallProbe
