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

def callRemoteBool : Entrypoint := {
  name := "call_remote_bool"
  selector? := some "6a7b13b8"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag", .bool)
  ]
  returns := .bool
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[.local "flag"] .bool)
  ]
}

def callRemoteU32 : Entrypoint := {
  name := "call_remote_u32"
  selector? := some "0f35944c"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("x", .u32)
  ]
  returns := .u32
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[.local "x"] .u32)
  ]
}

def callRemoteHash : Entrypoint := {
  name := "call_remote_hash"
  selector? := some "6a5317aa"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("value", .hash)
  ]
  returns := .hash
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[.local "value"] .hash)
  ]
}

def callRemoteValue : Entrypoint := {
  name := "call_remote_value"
  selector? := some "365f4a44"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[] .u64)
  ]
}

def module : Module := {
  name := "EvmCrosscallProbe"
  state := #[stateMarker]
  entrypoints := #[callRemote, callRemote1, callRemote2, callRemoteBool, callRemoteU32, callRemoteHash, callRemoteValue]
}

end ProofForge.IR.Examples.EvmCrosscallProbe
