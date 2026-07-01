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

-- Init code that deploys runtime `602a60005260206000f3`, a tiny contract that
-- returns U256 42 for any call.
def returnFortyTwoInitCodeHex : String :=
  "69602a60005260206000f3600052600a6016f3"

def matrix2x2 (a b c d : Expr) : Expr :=
  .arrayLit (.fixedArray .u64 2) #[
    .arrayLit .u64 #[a, b],
    .arrayLit .u64 #[c, d]
  ]

def pair (flag small : Expr) : Expr :=
  .structLit "RemotePair" #[
    ("flag", flag),
    ("small", small)
  ]

def pairMatrix2x2
    (flag00 small00 flag01 small01 flag10 small10 flag11 small11 : Expr) : Expr :=
  .arrayLit (.fixedArray (.structType "RemotePair") 2) #[
    .arrayLit (.structType "RemotePair") #[
      pair flag00 small00,
      pair flag01 small01
    ],
    .arrayLit (.structType "RemotePair") #[
      pair flag10 small10,
      pair flag11 small11
    ]
  ]

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

def callRemoteMatrix : Entrypoint := {
  name := "call_remote_matrix"
  selector? := some "d49690a6"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.fixedArray .u64 2) 2
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[] (.fixedArray (.fixedArray .u64 2) 2))
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

def callRemoteMatrixArg : Entrypoint := {
  name := "call_remote_matrix_arg"
  selector? := some "25c0a43d"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("a", .u64),
    ("b", .u64),
    ("c", .u64),
    ("d", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[matrix2x2 (.local "a") (.local "b") (.local "c") (.local "d")] .u64)
  ]
}

def callRemotePairArray : Entrypoint := {
  name := "call_remote_pair_array"
  selector? := some "031396d6"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.structType "RemotePair") 2
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[] (.fixedArray (.structType "RemotePair") 2))
  ]
}

def callRemotePairArrayArg : Entrypoint := {
  name := "call_remote_pair_array_arg"
  selector? := some "7a45fdce"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag0", .bool),
    ("small0", .u32),
    ("flag1", .bool),
    ("small1", .u32)
  ]
  returns := .u64
  body := #[
    .letBind "pairs" (.fixedArray (.structType "RemotePair") 2) (.arrayLit (.structType "RemotePair") #[
      .structLit "RemotePair" #[
        ("flag", .local "flag0"),
        ("small", .local "small0")
      ],
      .structLit "RemotePair" #[
        ("flag", .local "flag1"),
        ("small", .local "small1")
      ]
    ]),
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[.local "pairs"] .u64)
  ]
}

def callRemotePairMatrix : Entrypoint := {
  name := "call_remote_pair_matrix"
  selector? := some "3652f87d"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.fixedArray (.structType "RemotePair") 2) 2
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[] (.fixedArray (.fixedArray (.structType "RemotePair") 2) 2))
  ]
}

def callRemotePairMatrixArg : Entrypoint := {
  name := "call_remote_pair_matrix_arg"
  selector? := some "48fc8f80"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag00", .bool),
    ("small00", .u32),
    ("flag01", .bool),
    ("small01", .u32),
    ("flag10", .bool),
    ("small10", .u32),
    ("flag11", .bool),
    ("small11", .u32)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeTyped (.local "target") (.local "method") #[
      pairMatrix2x2
        (.local "flag00") (.local "small00")
        (.local "flag01") (.local "small01")
        (.local "flag10") (.local "small10")
        (.local "flag11") (.local "small11")
    ] .u64)
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

def callRemoteValuePair : Entrypoint := {
  name := "call_remote_value_pair"
  selector? := some "01ff40fb"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .structType "RemotePair"
  body := #[
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[] (.structType "RemotePair"))
  ]
}

def callRemoteValueArray : Entrypoint := {
  name := "call_remote_value_array"
  selector? := some "2bedc30a"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray .u64 2
  body := #[
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[] (.fixedArray .u64 2))
  ]
}

def callRemoteValueMatrix : Entrypoint := {
  name := "call_remote_value_matrix"
  selector? := some "4b634dd4"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.fixedArray .u64 2) 2
  body := #[
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[] (.fixedArray (.fixedArray .u64 2) 2))
  ]
}

def callRemoteValuePairArray : Entrypoint := {
  name := "call_remote_value_pair_array"
  selector? := some "63ec1609"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.structType "RemotePair") 2
  body := #[
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[] (.fixedArray (.structType "RemotePair") 2))
  ]
}

def callRemoteValuePairArrayArg : Entrypoint := {
  name := "call_remote_value_pair_array_arg"
  selector? := some "27c33745"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag0", .bool),
    ("small0", .u32),
    ("flag1", .bool),
    ("small1", .u32)
  ]
  returns := .u64
  body := #[
    .letBind "pairs" (.fixedArray (.structType "RemotePair") 2) (.arrayLit (.structType "RemotePair") #[
      .structLit "RemotePair" #[
        ("flag", .local "flag0"),
        ("small", .local "small0")
      ],
      .structLit "RemotePair" #[
        ("flag", .local "flag1"),
        ("small", .local "small1")
      ]
    ]),
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[.local "pairs"] .u64)
  ]
}

def callRemoteValuePairMatrix : Entrypoint := {
  name := "call_remote_value_pair_matrix"
  selector? := some "fa3cf7ed"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.fixedArray (.structType "RemotePair") 2) 2
  body := #[
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[] (.fixedArray (.fixedArray (.structType "RemotePair") 2) 2))
  ]
}

def callRemoteValuePairMatrixArg : Entrypoint := {
  name := "call_remote_value_pair_matrix_arg"
  selector? := some "4f1e8d96"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag00", .bool),
    ("small00", .u32),
    ("flag01", .bool),
    ("small01", .u32),
    ("flag10", .bool),
    ("small10", .u32),
    ("flag11", .bool),
    ("small11", .u32)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[
      pairMatrix2x2
        (.local "flag00") (.local "small00")
        (.local "flag01") (.local "small01")
        (.local "flag10") (.local "small10")
        (.local "flag11") (.local "small11")
    ] .u64)
  ]
}

def callRemoteValueMatrixArg : Entrypoint := {
  name := "call_remote_value_matrix_arg"
  selector? := some "635d3715"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("a", .u64),
    ("b", .u64),
    ("c", .u64),
    ("d", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeValueTyped (.local "target") (.local "method") .nativeValue #[matrix2x2 (.local "a") (.local "b") (.local "c") (.local "d")] .u64)
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

def callRemoteStaticPair : Entrypoint := {
  name := "call_remote_static_pair"
  selector? := some "2236e75b"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .structType "RemotePair"
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[] (.structType "RemotePair"))
  ]
}

def callRemoteStaticArray : Entrypoint := {
  name := "call_remote_static_array"
  selector? := some "b1d5165b"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray .u64 2
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[] (.fixedArray .u64 2))
  ]
}

def callRemoteStaticMatrix : Entrypoint := {
  name := "call_remote_static_matrix"
  selector? := some "202850f3"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.fixedArray .u64 2) 2
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[] (.fixedArray (.fixedArray .u64 2) 2))
  ]
}

def callRemoteStaticPairArray : Entrypoint := {
  name := "call_remote_static_pair_array"
  selector? := some "e0315e4e"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.structType "RemotePair") 2
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[] (.fixedArray (.structType "RemotePair") 2))
  ]
}

def callRemoteStaticPairArrayArg : Entrypoint := {
  name := "call_remote_static_pair_array_arg"
  selector? := some "1b46265d"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag0", .bool),
    ("small0", .u32),
    ("flag1", .bool),
    ("small1", .u32)
  ]
  returns := .u64
  body := #[
    .letBind "pairs" (.fixedArray (.structType "RemotePair") 2) (.arrayLit (.structType "RemotePair") #[
      .structLit "RemotePair" #[
        ("flag", .local "flag0"),
        ("small", .local "small0")
      ],
      .structLit "RemotePair" #[
        ("flag", .local "flag1"),
        ("small", .local "small1")
      ]
    ]),
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[.local "pairs"] .u64)
  ]
}

def callRemoteStaticPairMatrix : Entrypoint := {
  name := "call_remote_static_pair_matrix"
  selector? := some "9893a8f6"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.fixedArray (.structType "RemotePair") 2) 2
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[] (.fixedArray (.fixedArray (.structType "RemotePair") 2) 2))
  ]
}

def callRemoteStaticPairMatrixArg : Entrypoint := {
  name := "call_remote_static_pair_matrix_arg"
  selector? := some "db5109a1"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag00", .bool),
    ("small00", .u32),
    ("flag01", .bool),
    ("small01", .u32),
    ("flag10", .bool),
    ("small10", .u32),
    ("flag11", .bool),
    ("small11", .u32)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[
      pairMatrix2x2
        (.local "flag00") (.local "small00")
        (.local "flag01") (.local "small01")
        (.local "flag10") (.local "small10")
        (.local "flag11") (.local "small11")
    ] .u64)
  ]
}

def callRemoteStaticMatrixArg : Entrypoint := {
  name := "call_remote_static_matrix_arg"
  selector? := some "5ef5b6fb"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("a", .u64),
    ("b", .u64),
    ("c", .u64),
    ("d", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeStaticTyped (.local "target") (.local "method") #[matrix2x2 (.local "a") (.local "b") (.local "c") (.local "d")] .u64)
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

def callRemoteDelegatePair : Entrypoint := {
  name := "call_remote_delegate_pair"
  selector? := some "41e8bd85"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .structType "RemotePair"
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[] (.structType "RemotePair"))
  ]
}

def callRemoteDelegateArray : Entrypoint := {
  name := "call_remote_delegate_array"
  selector? := some "52579065"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray .u64 2
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[] (.fixedArray .u64 2))
  ]
}

def callRemoteDelegateMatrix : Entrypoint := {
  name := "call_remote_delegate_matrix"
  selector? := some "b8c58c92"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.fixedArray .u64 2) 2
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[] (.fixedArray (.fixedArray .u64 2) 2))
  ]
}

def callRemoteDelegatePairArray : Entrypoint := {
  name := "call_remote_delegate_pair_array"
  selector? := some "a26d8a3c"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.structType "RemotePair") 2
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[] (.fixedArray (.structType "RemotePair") 2))
  ]
}

def callRemoteDelegatePairArrayArg : Entrypoint := {
  name := "call_remote_delegate_pair_array_arg"
  selector? := some "73049a39"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag0", .bool),
    ("small0", .u32),
    ("flag1", .bool),
    ("small1", .u32)
  ]
  returns := .u64
  body := #[
    .letBind "pairs" (.fixedArray (.structType "RemotePair") 2) (.arrayLit (.structType "RemotePair") #[
      .structLit "RemotePair" #[
        ("flag", .local "flag0"),
        ("small", .local "small0")
      ],
      .structLit "RemotePair" #[
        ("flag", .local "flag1"),
        ("small", .local "small1")
      ]
    ]),
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[.local "pairs"] .u64)
  ]
}

def callRemoteDelegatePairMatrix : Entrypoint := {
  name := "call_remote_delegate_pair_matrix"
  selector? := some "26db7add"
  params := #[
    ("target", .u64),
    ("method", .u64)
  ]
  returns := .fixedArray (.fixedArray (.structType "RemotePair") 2) 2
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[] (.fixedArray (.fixedArray (.structType "RemotePair") 2) 2))
  ]
}

def callRemoteDelegatePairMatrixArg : Entrypoint := {
  name := "call_remote_delegate_pair_matrix_arg"
  selector? := some "667806e6"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("flag00", .bool),
    ("small00", .u32),
    ("flag01", .bool),
    ("small01", .u32),
    ("flag10", .bool),
    ("small10", .u32),
    ("flag11", .bool),
    ("small11", .u32)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[
      pairMatrix2x2
        (.local "flag00") (.local "small00")
        (.local "flag01") (.local "small01")
        (.local "flag10") (.local "small10")
        (.local "flag11") (.local "small11")
    ] .u64)
  ]
}

def callRemoteDelegateMatrixArg : Entrypoint := {
  name := "call_remote_delegate_matrix_arg"
  selector? := some "08edf8ea"
  params := #[
    ("target", .u64),
    ("method", .u64),
    ("a", .u64),
    ("b", .u64),
    ("c", .u64),
    ("d", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallInvokeDelegateTyped (.local "target") (.local "method") #[matrix2x2 (.local "a") (.local "b") (.local "c") (.local "d")] .u64)
  ]
}

def deployCreate : Entrypoint := {
  name := "deploy_create"
  selector? := some "c9bc2909"
  params := #[
    ("value", .u64)
  ]
  returns := .u64
  body := #[
    .return (.crosscallCreate (.local "value") returnFortyTwoInitCodeHex)
  ]
}

def deployCreate2 : Entrypoint := {
  name := "deploy_create2"
  selector? := some "70b22efb"
  params := #[
    ("value", .u64),
    ("salt", .hash)
  ]
  returns := .u64
  body := #[
    .return (.crosscallCreate2 (.local "value") (.local "salt") returnFortyTwoInitCodeHex)
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
    callRemoteMatrix,
    callRemotePairArg,
    callRemoteArrayArg,
    callRemoteMatrixArg,
    callRemotePairArray,
    callRemotePairArrayArg,
    callRemotePairMatrix,
    callRemotePairMatrixArg,
    callRemoteValue,
    callRemoteValuePairArg,
    callRemoteValuePair,
    callRemoteValueArray,
    callRemoteValueMatrix,
    callRemoteValuePairArray,
    callRemoteValuePairArrayArg,
    callRemoteValuePairMatrix,
    callRemoteValuePairMatrixArg,
    callRemoteValueMatrixArg,
    callRemoteStatic,
    callRemoteStaticBool,
    callRemoteStaticU32,
    callRemoteStaticHash,
    callRemoteStaticPairArg,
    callRemoteStaticPair,
    callRemoteStaticArray,
    callRemoteStaticMatrix,
    callRemoteStaticPairArray,
    callRemoteStaticPairArrayArg,
    callRemoteStaticPairMatrix,
    callRemoteStaticPairMatrixArg,
    callRemoteStaticMatrixArg,
    callRemoteDelegate,
    callRemoteDelegateBool,
    callRemoteDelegateU32,
    callRemoteDelegateHash,
    callRemoteDelegatePairArg,
    callRemoteDelegatePair,
    callRemoteDelegateArray,
    callRemoteDelegateMatrix,
    callRemoteDelegatePairArray,
    callRemoteDelegatePairArrayArg,
    callRemoteDelegatePairMatrix,
    callRemoteDelegatePairMatrixArg,
    callRemoteDelegateMatrixArg,
    deployCreate,
    deployCreate2
  ]
}

end ProofForge.IR.Examples.EvmCrosscallProbe
