import ProofForge.IR.Contract

namespace ProofForge.IR.Examples.EvmCrosscallProbe

open ProofForge.IR

def stateMarker : StateDecl := {
  id := "_proof_forge_marker"
  kind := .scalar
  type := .u64
}

def remotePairStruct : StructDecl := {
  name := "RemotePair"
  fields := #[
    { id := "flag", type := .bool },
    { id := "small", type := .u32 }
  ]
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

def callRemotePair : Entrypoint := {
  name := "call_remote_pair"
  selector? := some "47c6c9b7"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .structType "RemotePair"
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[] (.structType "RemotePair"))
  ]
}

def callRemoteArray : Entrypoint := {
  name := "call_remote_array"
  selector? := some "717d6851"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray .u64 2
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[] (.fixedArray .u64 2))
  ]
}

def callRemotePairArg : Entrypoint := {
  name := "call_remote_pair_arg"
  selector? := some "cabe3922"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag", .bool),
    ("small", .u32)
  ]
  returns := .bool
  body := #[
    .letBind "pair" (.structType "RemotePair") (.structLit "RemotePair" #[
      ("flag", .local "flag"),
      ("small", .local "small")
    ]),
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[.local "pair"] .bool)
  ]
}

def callRemoteArrayArg : Entrypoint := {
  name := "call_remote_array_arg"
  selector? := some "00746b10"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("x", .u64),
    ("y", .u64)
  ]
  returns := .u64
  body := #[
    .letBind "values" (.fixedArray .u64 2) (.arrayLit .u64 #[.local "x", .local "y"]),
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[.local "values"] .u64)
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

def callRemoteValuePairArg : Entrypoint := {
  name := "call_remote_value_pair_arg"
  selector? := some "885cf3f5"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag", .bool),
    ("small", .u32)
  ]
  returns := .u64
  body := #[
    .letBind "pair" (.structType "RemotePair") (.structLit "RemotePair" #[
      ("flag", .local "flag"),
      ("small", .local "small")
    ]),
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[.local "pair"] .u64)
  ]
}

def callRemoteStatic : Entrypoint := {
  name := "call_remote_static"
  selector? := some "d13203a8"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[] .u64)
  ]
}

def callRemoteStaticBool : Entrypoint := {
  name := "call_remote_static_bool"
  selector? := some "ae266f0a"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag", .bool)
  ]
  returns := .bool
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[.local "flag"] .bool)
  ]
}

def callRemoteStaticU32 : Entrypoint := {
  name := "call_remote_static_u32"
  selector? := some "ec8c40f9"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("x", .u32)
  ]
  returns := .u32
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[.local "x"] .u32)
  ]
}

def callRemoteStaticHash : Entrypoint := {
  name := "call_remote_static_hash"
  selector? := some "4e0edd3c"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("value", .hash)
  ]
  returns := .hash
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[.local "value"] .hash)
  ]
}

def callRemoteStaticPairArg : Entrypoint := {
  name := "call_remote_static_pair_arg"
  selector? := some "d1b1bf68"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag", .bool),
    ("small", .u32)
  ]
  returns := .u32
  body := #[
    .letBind "pair" (.structType "RemotePair") (.structLit "RemotePair" #[
      ("flag", .local "flag"),
      ("small", .local "small")
    ]),
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[.local "pair"] .u32)
  ]
}

def callRemoteDelegate : Entrypoint := {
  name := "call_remote_delegate"
  selector? := some "427320b1"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[] .u64)
  ]
}

def callRemoteDelegateBool : Entrypoint := {
  name := "call_remote_delegate_bool"
  selector? := some "62e5114d"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag", .bool)
  ]
  returns := .bool
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[.local "flag"] .bool)
  ]
}

def callRemoteDelegateU32 : Entrypoint := {
  name := "call_remote_delegate_u32"
  selector? := some "e3abe276"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("x", .u32)
  ]
  returns := .u32
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[.local "x"] .u32)
  ]
}

def callRemoteDelegateHash : Entrypoint := {
  name := "call_remote_delegate_hash"
  selector? := some "6a2c2006"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("value", .hash)
  ]
  returns := .hash
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[.local "value"] .hash)
  ]
}

def callRemoteDelegatePairArg : Entrypoint := {
  name := "call_remote_delegate_pair_arg"
  selector? := some "8283d1d1"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag", .bool),
    ("small", .u32)
  ]
  returns := .u32
  body := #[
    .letBind "pair" (.structType "RemotePair") (.structLit "RemotePair" #[
      ("flag", .local "flag"),
      ("small", .local "small")
    ]),
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[.local "pair"] .u32)
  ]
}

def module : Module := {
  name := "EvmCrosscallProbe"
  structs := #[remotePairStruct]
  state := #[stateMarker]
  entrypoints := #[
    callRemote,
    callRemote1,
    callRemote2,
    callRemoteBool,
    callRemoteU32,
    callRemoteHash,
    callRemotePair,
    callRemoteArray,
    callRemotePairArg,
    callRemoteArrayArg,
    callRemoteValue,
    callRemoteValuePairArg,
    callRemoteStatic,
    callRemoteStaticBool,
    callRemoteStaticU32,
    callRemoteStaticHash,
    callRemoteStaticPairArg,
    callRemoteDelegate,
    callRemoteDelegateBool,
    callRemoteDelegateU32,
    callRemoteDelegateHash,
    callRemoteDelegatePairArg
  ]
}

end ProofForge.IR.Examples.EvmCrosscallProbe
