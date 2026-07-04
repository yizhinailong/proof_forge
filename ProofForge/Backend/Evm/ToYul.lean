import ProofForge.Backend.Evm.Plan
import ProofForge.Compiler.Yul.AST

namespace ProofForge.Backend.Evm.ToYul

open ProofForge.IR
open ProofForge.Backend.Evm.Plan

def slotExpr (slot : Nat) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.Expr.num slot

def helperCall (helper : Helper) (args : Array Lean.Compiler.Yul.Expr) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.call helper.name args

def entrypointFunctionName (moduleName entrypointName : String) : String :=
  s!"f_{moduleName}_{entrypointName}"

def entrypointPlanFunctionName (moduleName : String) (entrypoint : EntrypointPlan) : String :=
  entrypointFunctionName moduleName entrypoint.name

def checkedAddName : String := "__pf_checked_add"
def checkedSubName : String := "__pf_checked_sub"
def checkedMulName : String := "__pf_checked_mul"

def checkedArithExpr (op : AssignOp) (lhs rhs : Lean.Compiler.Yul.Expr) : Lean.Compiler.Yul.Expr :=
  match op with
  | .add => Lean.Compiler.Yul.call checkedAddName #[lhs, rhs]
  | .sub => Lean.Compiler.Yul.call checkedSubName #[lhs, rhs]
  | .mul => Lean.Compiler.Yul.call checkedMulName #[lhs, rhs]
  | .div => Lean.Compiler.Yul.builtin "div" #[lhs, rhs]
  | .mod => Lean.Compiler.Yul.builtin "mod" #[lhs, rhs]
  | .bitAnd => Lean.Compiler.Yul.builtin "and" #[lhs, rhs]
  | .bitOr => Lean.Compiler.Yul.builtin "or" #[lhs, rhs]
  | .bitXor => Lean.Compiler.Yul.builtin "xor" #[lhs, rhs]
  | .shiftLeft => Lean.Compiler.Yul.builtin "shl" #[rhs, lhs]
  | .shiftRight => Lean.Compiler.Yul.builtin "shr" #[rhs, lhs]

def contextExpr : ContextField → Lean.Compiler.Yul.Expr
  | .userId => Lean.Compiler.Yul.builtin "caller" #[]
  | .contractId => Lean.Compiler.Yul.builtin "address" #[]
  | .checkpointId => Lean.Compiler.Yul.builtin "number" #[]
  | .timestamp => Lean.Compiler.Yul.builtin "timestamp" #[]
  | .chainId => Lean.Compiler.Yul.builtin "chainid" #[]
  | .gasPrice => Lean.Compiler.Yul.builtin "gasprice" #[]
  | .gasLeft => Lean.Compiler.Yul.builtin "gas" #[]
  | .baseFee => Lean.Compiler.Yul.builtin "basefee" #[]
  | .prevRandao => Lean.Compiler.Yul.builtin "prevrandao" #[]
  | .origin => Lean.Compiler.Yul.builtin "origin" #[]
  | .coinbase => Lean.Compiler.Yul.builtin "coinbase" #[]
  | .blockHash _ => Lean.Compiler.Yul.builtin "blockhash" #[]

def calldataWordExpr (paramIndex : Nat) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.builtin "calldataload" #[Lean.Compiler.Yul.Expr.num (4 + paramIndex * 32)]

def revertStatement : Lean.Compiler.Yul.Statement :=
  Lean.Compiler.Yul.Statement.exprStmt
    (Lean.Compiler.Yul.builtin "revert" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])

def calldataloadAt (offset : Lean.Compiler.Yul.Expr) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.builtin "calldataload" #[offset]

def dynamicParamLengthName (name : String) : String :=
  ProofForge.Backend.Evm.Plan.dynamicParamLengthName name

def dynamicParamDataPtrName (name : String) : String :=
  ProofForge.Backend.Evm.Plan.dynamicParamDataPtrName name

def abiParamsHeadWordCount (params : Array AbiParamPlan) : Nat :=
  params.foldl (fun acc param => acc + param.headWordCount) 0

def abiParamsMinSizeValidationStatements (params : Array AbiParamPlan) :
    Array Lean.Compiler.Yul.Statement :=
  let headWordCount := abiParamsHeadWordCount params
  let minSize := 4 + headWordCount * 32
  if headWordCount == 0 then
    #[]
  else
    #[
      Lean.Compiler.Yul.Statement.ifStmt
        (Lean.Compiler.Yul.builtin "lt" #[
          Lean.Compiler.Yul.builtin "calldatasize" #[],
          Lean.Compiler.Yul.Expr.num minSize
        ])
        { statements := #[revertStatement] }
    ]

def abiWordValidationStatement?
    (word : Lean.Compiler.Yul.Expr)
    (type : ValueType) : Option Lean.Compiler.Yul.Statement :=
  match type with
  | .u32 =>
      some <| Lean.Compiler.Yul.Statement.ifStmt
        (Lean.Compiler.Yul.builtin "gt" #[word, Lean.Compiler.Yul.Expr.num 4294967295])
        { statements := #[revertStatement] }
  | .bool =>
      some <| Lean.Compiler.Yul.Statement.ifStmt
        (Lean.Compiler.Yul.builtin "gt" #[word, Lean.Compiler.Yul.Expr.num 1])
        { statements := #[revertStatement] }
  | .u64 | .hash | .address | .unit | .fixedArray _ _ | .structType _ | .bytes | .string =>
      none

def abiParamHeadValidationStatements (params : Array AbiParamPlan) :
    Array Lean.Compiler.Yul.Statement :=
  Id.run do
    let mut statements : Array Lean.Compiler.Yul.Statement := #[]
    for h : i in [0:params.size] do
      let param := params[i]
      if param.isDynamic then
        let offsetExpr := calldataWordExpr param.headWordIndex
        let baseOffset := Lean.Compiler.Yul.Expr.num (4 + param.headWordIndex * 32)
        let offsetPlusBase := Lean.Compiler.Yul.builtin "add" #[baseOffset, offsetExpr]
        statements := statements.push <|
          Lean.Compiler.Yul.Statement.ifStmt
            (Lean.Compiler.Yul.builtin "gt" #[
              offsetPlusBase,
              Lean.Compiler.Yul.builtin "calldatasize" #[]
            ])
            { statements := #[revertStatement] }
      else
        for h : j in [0:param.wordTypes.size] do
          let wordIndex := param.headWordIndex + j
          match abiWordValidationStatement? (calldataWordExpr wordIndex) param.wordTypes[j] with
          | some statement => statements := statements.push statement
          | none => pure ()
    statements

def dynamicAbiParamDecodeStatements (param : AbiParamPlan) :
    Array Lean.Compiler.Yul.Statement :=
  if param.isDynamic then
    let offsetExpr := calldataWordExpr param.headWordIndex
    let dataOffset := Lean.Compiler.Yul.builtin "add" #[
      Lean.Compiler.Yul.Expr.num (4 + param.headWordIndex * 32),
      offsetExpr
    ]
    let lengthExpr := calldataloadAt dataOffset
    let memPtrName := s!"__pf_dyn_ptr_{param.name}"
    let memPtr := Lean.Compiler.Yul.Expr.id memPtrName
    let dataStart := Lean.Compiler.Yul.builtin "add" #[memPtr, Lean.Compiler.Yul.Expr.num 32]
    let wordCount := Lean.Compiler.Yul.builtin "div" #[
      Lean.Compiler.Yul.builtin "add" #[lengthExpr, Lean.Compiler.Yul.Expr.num 31],
      Lean.Compiler.Yul.Expr.num 32
    ]
    let memSize := Lean.Compiler.Yul.builtin "mul" #[wordCount, Lean.Compiler.Yul.Expr.num 32]
    let totalSize := Lean.Compiler.Yul.builtin "add" #[memSize, Lean.Compiler.Yul.Expr.num 32]
    let tailEnd := Lean.Compiler.Yul.builtin "add" #[
      dataOffset,
      Lean.Compiler.Yul.builtin "add" #[Lean.Compiler.Yul.Expr.num 32, memSize]
    ]
    #[
      .ifStmt
        (Lean.Compiler.Yul.builtin "gt" #[tailEnd, Lean.Compiler.Yul.builtin "calldatasize" #[]])
        { statements := #[revertStatement] },
      .varDecl #[{ name := memPtrName }]
        (some (Lean.Compiler.Yul.builtin "mload" #[Lean.Compiler.Yul.Expr.num 0x40])),
      .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[memPtr, lengthExpr]),
      .exprStmt (Lean.Compiler.Yul.builtin "calldatacopy" #[
        dataStart,
        Lean.Compiler.Yul.builtin "add" #[dataOffset, Lean.Compiler.Yul.Expr.num 32],
        memSize
      ]),
      .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[
        Lean.Compiler.Yul.Expr.num 0x40,
        Lean.Compiler.Yul.builtin "add" #[memPtr, totalSize]
      ]),
      .varDecl #[{ name := dynamicParamLengthName param.name }] (some lengthExpr),
      .varDecl #[{ name := dynamicParamDataPtrName param.name }] (some memPtr)
    ]
  else
    #[]

def abiParamDecodeStatements (params : Array AbiParamPlan) :
    Array Lean.Compiler.Yul.Statement :=
  params.foldl (fun acc param => acc ++ dynamicAbiParamDecodeStatements param) #[]

def abiParamValidationAndDecodeStatements (params : Array AbiParamPlan) :
    Array Lean.Compiler.Yul.Statement :=
  abiParamsMinSizeValidationStatements params ++
    abiParamHeadValidationStatements params ++
    abiParamDecodeStatements params

def entrypointCallArgs (params : Array AbiParamPlan) :
    Array Lean.Compiler.Yul.Expr :=
  Id.run do
    let mut args : Array Lean.Compiler.Yul.Expr := #[]
    for h : i in [0:params.size] do
      let param := params[i]
      if param.isDynamic then
        args := args.push (Lean.Compiler.Yul.Expr.id (dynamicParamLengthName param.name))
        args := args.push (Lean.Compiler.Yul.Expr.id (dynamicParamDataPtrName param.name))
      else
        for h : j in [0:param.wordTypes.size] do
          args := args.push (calldataWordExpr (param.headWordIndex + j))
    args

def entrypointParamTypedNames (params : Array AbiParamPlan) :
    Array Lean.Compiler.Yul.TypedName :=
  params.foldl
    (fun acc param =>
      acc ++ param.localNames.map (fun name => ({ name := name } : Lean.Compiler.Yul.TypedName)))
    #[]

def entrypointCallExpr
    (moduleName : String)
    (entrypoint : EntrypointPlan) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.call (entrypointPlanFunctionName moduleName entrypoint) (entrypointCallArgs entrypoint.params)

def entrypointFunctionDefinition
    (moduleName : String)
    (entrypoint : EntrypointPlan)
    (returns : Array Lean.Compiler.Yul.TypedName)
    (bodyStatements : Array Lean.Compiler.Yul.Statement) : Lean.Compiler.Yul.Statement :=
  .funcDef
    (entrypointPlanFunctionName moduleName entrypoint)
    (entrypointParamTypedNames entrypoint.params)
    returns
    { statements := bodyStatements }

def dispatchSelectorExpr : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.builtin "shr" #[
    Lean.Compiler.Yul.Expr.num 224,
    Lean.Compiler.Yul.builtin "calldataload" #[Lean.Compiler.Yul.Expr.num 0]
  ]

def eip1967ImplementationSlotExpr : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.Expr.lit
    (Lean.Compiler.Yul.Literal.hex "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc")

def uupsProxyFallbackBody : Array Lean.Compiler.Yul.Statement := #[
  .varDecl #[{ name := "_impl" }] (some (Lean.Compiler.Yul.builtin "sload" #[eip1967ImplementationSlotExpr])),
  .ifStmt (Lean.Compiler.Yul.builtin "iszero" #[Lean.Compiler.Yul.Expr.id "_impl"]) { statements := #[revertStatement] },
  .exprStmt (Lean.Compiler.Yul.builtin "calldatacopy" #[
    Lean.Compiler.Yul.Expr.num 0,
    Lean.Compiler.Yul.Expr.num 0,
    Lean.Compiler.Yul.builtin "calldatasize" #[]
  ]),
  .varDecl #[{ name := "_ok" }] (some (Lean.Compiler.Yul.builtin "delegatecall" #[
    Lean.Compiler.Yul.builtin "gas" #[],
    Lean.Compiler.Yul.Expr.id "_impl",
    Lean.Compiler.Yul.Expr.num 0,
    Lean.Compiler.Yul.builtin "calldatasize" #[],
    Lean.Compiler.Yul.Expr.num 0,
    Lean.Compiler.Yul.Expr.num 0
  ])),
  .exprStmt (Lean.Compiler.Yul.builtin "returndatacopy" #[
    Lean.Compiler.Yul.Expr.num 0,
    Lean.Compiler.Yul.Expr.num 0,
    Lean.Compiler.Yul.builtin "returndatasize" #[]
  ]),
  .ifStmt (Lean.Compiler.Yul.builtin "iszero" #[Lean.Compiler.Yul.Expr.id "_ok"]) {
    statements := #[
      .exprStmt (Lean.Compiler.Yul.builtin "revert" #[
        Lean.Compiler.Yul.Expr.num 0,
        Lean.Compiler.Yul.builtin "returndatasize" #[]
      ])
    ]
  },
  .exprStmt (Lean.Compiler.Yul.builtin "return" #[
    Lean.Compiler.Yul.Expr.num 0,
    Lean.Compiler.Yul.builtin "returndatasize" #[]
  ])
]

def dispatchDefaultCase (defaultPlan : DispatchDefaultPlan) : Lean.Compiler.Yul.Case :=
  match defaultPlan with
  | .revert => {
      value := none
      body := { statements := #[revertStatement] }
    }
  | .uupsProxy => {
      value := none
      body := { statements := uupsProxyFallbackBody }
    }

def entrypointDispatchCase
    {ε : Type}
    (mkError : String → ε)
    (entrypoint : EntrypointPlan)
    (bodyStatements : Array Lean.Compiler.Yul.Statement) :
    Except ε Lean.Compiler.Yul.Case := do
  if entrypoint.selector.isEmpty then
    .error (mkError s!"EVM EntrypointPlan dispatch case for `{entrypoint.name}` requires a selector")
  else
    .ok {
      value := some (Lean.Compiler.Yul.Literal.hex ("0x" ++ entrypoint.selector))
      body := { statements := bodyStatements }
    }

def dispatchSwitchStatement
    (cases : Array Lean.Compiler.Yul.Case)
    (defaultCase : Lean.Compiler.Yul.Case) : Lean.Compiler.Yul.Statement :=
  .switchStmt dispatchSelectorExpr (cases.push defaultCase)

def abiParamPlanIsDynamic (param : AbiParamPlan) : Bool :=
  param.isDynamic

def entrypointPlanHasDynamicParams (entrypoint : EntrypointPlan) : Bool :=
  entrypoint.params.any abiParamPlanIsDynamic

def dispatchBlockStatement
    (entrypoints : Array EntrypointPlan)
    (cases : Array Lean.Compiler.Yul.Case)
    (defaultCase : Lean.Compiler.Yul.Case) : Lean.Compiler.Yul.Statement :=
  let switchStmt := dispatchSwitchStatement cases defaultCase
  if entrypoints.any entrypointPlanHasDynamicParams then
    .block { statements := #[
      Lean.Compiler.Yul.Statement.exprStmt
        (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 64, Lean.Compiler.Yul.Expr.num 128]),
      switchStmt
    ] }
  else
    switchStmt

def dispatchPlanStatement
    (dispatch : DispatchPlan)
    (cases : Array Lean.Compiler.Yul.Case) : Lean.Compiler.Yul.Statement :=
  dispatchBlockStatement dispatch.entrypoints cases (dispatchDefaultCase dispatch.default)

def dispatchResultName (index : Nat) : String :=
  s!"_r{index}"

def dispatchResultNames (wordCount : Nat) : Array String :=
  if wordCount == 1 then
    #["_r"]
  else
    Id.run do
      let mut names : Array String := #[]
      for _h : idx in [0:wordCount] do
        names := names.push (dispatchResultName idx)
      names

def staticDispatchReturnStatements
    {ε : Type}
    (mkError : String → ε)
    (validationStatements : Array Lean.Compiler.Yul.Statement)
    (returns : ReturnPlan)
    (callExpr : Lean.Compiler.Yul.Expr) :
    Except ε (Array Lean.Compiler.Yul.Statement) := do
  match returns.returnType with
  | .unit =>
    .ok (validationStatements ++ #[
      Lean.Compiler.Yul.Statement.exprStmt callExpr,
      Lean.Compiler.Yul.Statement.exprStmt
        (Lean.Compiler.Yul.builtin "return" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 0])
    ])
  | .bytes | .string =>
      .error (mkError s!"EVM static dispatch return plan does not support dynamic `{returns.returnType.name}`")
  | _ =>
      if returns.wordTypes.isEmpty then
        .error (mkError s!"EVM dispatch return plan for `{returns.returnType.name}` has no ABI words")
      else
        let resultNames := dispatchResultNames returns.wordTypes.size
        let mut statements : Array Lean.Compiler.Yul.Statement :=
          validationStatements ++ #[
            Lean.Compiler.Yul.Statement.varDecl
              (resultNames.map fun name => ({ name := name } : Lean.Compiler.Yul.TypedName))
              (some callExpr)
          ]
        for h : idx in [0:resultNames.size] do
          statements := statements.push <|
            Lean.Compiler.Yul.Statement.exprStmt
              (Lean.Compiler.Yul.builtin "mstore" #[
                Lean.Compiler.Yul.Expr.num (idx * 32),
                Lean.Compiler.Yul.Expr.id resultNames[idx]
              ])
        statements := statements.push <|
          Lean.Compiler.Yul.Statement.exprStmt
            (Lean.Compiler.Yul.builtin "return" #[
              Lean.Compiler.Yul.Expr.num 0,
              Lean.Compiler.Yul.Expr.num (returns.wordTypes.size * 32)
            ])
        .ok statements

def dynamicDispatchReturnStatements
    {ε : Type}
    (mkError : String → ε)
    (validationStatements : Array Lean.Compiler.Yul.Statement)
    (returns : ReturnPlan)
    (callExpr : Lean.Compiler.Yul.Expr) :
    Except ε (Array Lean.Compiler.Yul.Statement) := do
  match returns.returnType with
  | .bytes | .string =>
      .ok (validationStatements ++ #[
        Lean.Compiler.Yul.Statement.varDecl #[{ name := "_r" }] (some callExpr),
        Lean.Compiler.Yul.Statement.varDecl #[{ name := "_ret_len" }]
          (some (Lean.Compiler.Yul.builtin "mload" #[Lean.Compiler.Yul.Expr.id "_r"])),
        Lean.Compiler.Yul.Statement.varDecl #[{ name := "_ret_word_count" }]
          (some (Lean.Compiler.Yul.builtin "div" #[
            Lean.Compiler.Yul.builtin "add" #[Lean.Compiler.Yul.Expr.id "_ret_len", Lean.Compiler.Yul.Expr.num 31],
            Lean.Compiler.Yul.Expr.num 32
          ])),
        Lean.Compiler.Yul.Statement.exprStmt
          (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 0, Lean.Compiler.Yul.Expr.num 32]),
        Lean.Compiler.Yul.Statement.exprStmt
          (Lean.Compiler.Yul.builtin "mstore" #[Lean.Compiler.Yul.Expr.num 32, Lean.Compiler.Yul.Expr.id "_ret_len"]),
        Lean.Compiler.Yul.Statement.forLoop
          { statements := #[
            Lean.Compiler.Yul.Statement.varDecl #[{ name := "_i" }]
              (some (Lean.Compiler.Yul.Expr.num 0))
          ] }
          (Lean.Compiler.Yul.builtin "lt" #[
            Lean.Compiler.Yul.Expr.id "_i",
            Lean.Compiler.Yul.Expr.id "_ret_word_count"
          ])
          { statements := #[
            Lean.Compiler.Yul.Statement.assignment #["_i"]
              (Lean.Compiler.Yul.builtin "add" #[
                Lean.Compiler.Yul.Expr.id "_i",
                Lean.Compiler.Yul.Expr.num 1
              ])
          ] }
          { statements := #[
            Lean.Compiler.Yul.Statement.exprStmt
              (Lean.Compiler.Yul.builtin "mstore" #[
                Lean.Compiler.Yul.builtin "add" #[
                  Lean.Compiler.Yul.Expr.num 64,
                  Lean.Compiler.Yul.builtin "mul" #[Lean.Compiler.Yul.Expr.id "_i", Lean.Compiler.Yul.Expr.num 32]
                ],
                Lean.Compiler.Yul.builtin "mload" #[
                  Lean.Compiler.Yul.builtin "add" #[
                    Lean.Compiler.Yul.builtin "add" #[Lean.Compiler.Yul.Expr.id "_r", Lean.Compiler.Yul.Expr.num 32],
                    Lean.Compiler.Yul.builtin "mul" #[Lean.Compiler.Yul.Expr.id "_i", Lean.Compiler.Yul.Expr.num 32]
                  ]
                ]
              ])
          ] },
        Lean.Compiler.Yul.Statement.exprStmt
          (Lean.Compiler.Yul.builtin "return" #[
            Lean.Compiler.Yul.Expr.num 0,
            Lean.Compiler.Yul.builtin "add" #[
              Lean.Compiler.Yul.Expr.num 64,
              Lean.Compiler.Yul.builtin "mul" #[Lean.Compiler.Yul.Expr.id "_ret_word_count", Lean.Compiler.Yul.Expr.num 32]
            ]
          ])
      ])
  | _ =>
      .error (mkError s!"EVM dynamic dispatch return plan expected bytes/string, got `{returns.returnType.name}`")

def hashPackExpr
    (a b c d : Lean.Compiler.Yul.Expr) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.builtin "or" #[
    Lean.Compiler.Yul.builtin "shl" #[Lean.Compiler.Yul.Expr.num 192, a],
    Lean.Compiler.Yul.builtin "or" #[
      Lean.Compiler.Yul.builtin "shl" #[Lean.Compiler.Yul.Expr.num 128, b],
      Lean.Compiler.Yul.builtin "or" #[
        Lean.Compiler.Yul.builtin "shl" #[Lean.Compiler.Yul.Expr.num 64, c],
        d
      ]
    ]
  ]

def packedUtf8Words (value : String) : Array Nat × Nat := Id.run do
  let bytes := value.toUTF8
  let wordCount := (bytes.size + 31) / 32
  let mut words := #[]
  for _h : wordIdx in [0:wordCount] do
    let mut wordVal := 0
    for _h : byteIdx in [0:32] do
      let pos := wordIdx * 32 + byteIdx
      if pos < bytes.size then
        let b := (bytes.get! pos).toNat
        let shift := (31 - byteIdx) * 8
        wordVal := wordVal + (b * (2 ^ shift))
    words := words.push wordVal
  pure (words, bytes.size)

def eventIndexedTopicName (index : Nat) : String :=
  s!"_indexed_topic{index}"

def eventIndexedFieldCount (event : EventPlan) : Nat :=
  event.indexedFields.size

def eventLogBuiltinName
    {ε : Type}
    (mkError : String → ε)
    (indexedFieldCount : Nat) : Except ε String :=
  if indexedFieldCount <= 3 then
    .ok s!"log{indexedFieldCount + 1}"
  else
    .error (mkError "EVM IR v0 supports at most 3 indexed event fields")

def eventSignatureTopicStatements (event : EventPlan) : Array Lean.Compiler.Yul.Statement := Id.run do
  let (words, length) := packedUtf8Words event.signature
  let mut statements := #[]
  for _h : idx in [0:words.size] do
    statements := statements.push <|
      .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[
        Lean.Compiler.Yul.Expr.num (idx * 32),
        Lean.Compiler.Yul.Expr.num words[idx]
      ])
  pure <| statements.push <|
    .varDecl #[{ name := "_topic0" }]
      (some (Lean.Compiler.Yul.builtin "keccak256" #[
        Lean.Compiler.Yul.Expr.num 0,
        Lean.Compiler.Yul.Expr.num length
      ]))

def eventDataStoreStatements (words : Array Lean.Compiler.Yul.Expr) : Array Lean.Compiler.Yul.Statement := Id.run do
  let mut statements := #[]
  for _h : idx in [0:words.size] do
    statements := statements.push <|
      .exprStmt (Lean.Compiler.Yul.builtin "mstore" #[
        Lean.Compiler.Yul.Expr.num (idx * 32),
        words[idx]
      ])
  pure statements

def eventIndexedTopicStatements
    {ε : Type}
    (mkError : String → ε)
    (field : EventFieldPlan)
    (index : Nat)
    (words : Array Lean.Compiler.Yul.Expr) :
    Except ε (Array Lean.Compiler.Yul.Statement) := do
  let topicName := eventIndexedTopicName index
  match field.type with
  | .u32 | .u64 | .bool | .hash | .address =>
      match words[0]? with
      | some word =>
          if words.size == 1 then
            .ok #[.varDecl #[{ name := topicName }] (some word)]
          else
            .error (mkError s!"EVM indexed scalar event field `{field.name}` expected one data word, got {words.size}")
      | none =>
          .error (mkError s!"EVM indexed scalar event field `{field.name}` expected one data word, got 0")
  | .fixedArray _ _ | .structType _ =>
      .ok <| eventDataStoreStatements words |>.push
        (.varDecl #[{ name := topicName }]
          (some (Lean.Compiler.Yul.builtin "keccak256" #[
            Lean.Compiler.Yul.Expr.num 0,
            Lean.Compiler.Yul.Expr.num (words.size * 32)
          ])))
  | .unit | .bytes | .string =>
      .error (mkError s!"EVM indexed event field `{field.name}` has unsupported type `{field.type.name}`")

def eventLogStatement
    {ε : Type}
    (mkError : String → ε)
    (event : EventPlan)
    (dataWordCount : Nat) : Except ε Lean.Compiler.Yul.Statement := do
  let indexedFieldCount := eventIndexedFieldCount event
  let mut logArgs : Array Lean.Compiler.Yul.Expr := #[
    Lean.Compiler.Yul.Expr.num 0,
    Lean.Compiler.Yul.Expr.num (dataWordCount * 32),
    Lean.Compiler.Yul.Expr.id "_topic0"
  ]
  for _h : idx in [0:indexedFieldCount] do
    logArgs := logArgs.push (Lean.Compiler.Yul.Expr.id (eventIndexedTopicName idx))
  .ok (.exprStmt (Lean.Compiler.Yul.builtin (← eventLogBuiltinName mkError indexedFieldCount) logArgs))

def eventEmitCoreStatement
    {ε : Type}
    (mkError : String → ε)
    (event : EventPlan)
    (indexedTopicStatements : Array Lean.Compiler.Yul.Statement)
    (dataWords : Array Lean.Compiler.Yul.Expr) :
    Except ε Lean.Compiler.Yul.Statement := do
  let mut statements := eventSignatureTopicStatements event
  statements := statements ++ indexedTopicStatements
  statements := statements ++ eventDataStoreStatements dataWords
  statements := statements.push (← eventLogStatement mkError event dataWords.size)
  .ok (.block { statements := statements })

def lowerValuePlan
    {ε : Type}
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr) :
    ValuePlan → Except ε Lean.Compiler.Yul.Expr
  | .irExpr expr => lowerExpr expr

def lowerMapValueSlotExpr
    {ε : Type}
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (rootSlot : Nat)
    (keys : Array ValuePlan) : Except ε Lean.Compiler.Yul.Expr := do
  let mut current := slotExpr rootSlot
  for key in keys do
    current := helperCall Helper.mapSlot #[current, ← lowerValuePlan lowerExpr key]
  .ok current

def lowerMapPresenceSlotExpr
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (rootSlot : Nat)
    (keys : Array ValuePlan) : Except ε Lean.Compiler.Yul.Expr := do
  match keys.toList.reverse with
  | [] => .error (mkError "EVM map presence slot plan requires at least one key")
  | last :: parentKeysReversed =>
      let mut parent := slotExpr rootSlot
      for key in parentKeysReversed.reverse do
        parent := helperCall Helper.mapSlot #[parent, ← lowerValuePlan lowerExpr key]
      .ok (helperCall Helper.mapPresenceSlot #[parent, ← lowerValuePlan lowerExpr last])

def storageSlotExpr
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr) :
    StorageSlotPlan → Except ε Lean.Compiler.Yul.Expr
  | .scalarSlot slot => .ok (slotExpr slot)
  | .fixedSlot slotHex => .ok (Lean.Compiler.Yul.Expr.lit (Lean.Compiler.Yul.Literal.hex slotHex))
  | .mapValueSlot rootSlot keys =>
      if keys.isEmpty then
        .error (mkError "EVM map value slot plan requires at least one key")
      else
        lowerMapValueSlotExpr lowerExpr rootSlot keys
  | .mapPresenceSlot rootSlot keys =>
      lowerMapPresenceSlotExpr mkError lowerExpr rootSlot keys
  | .arraySlot rootSlot length index => do
      .ok (helperCall Helper.arraySlot #[
        slotExpr rootSlot,
        Lean.Compiler.Yul.Expr.num length,
        ← lowerValuePlan lowerExpr index
      ])
  | .structArrayFieldSlot rootSlot length fieldCount fieldOffset index => do
      .ok (helperCall Helper.structArraySlot #[
        slotExpr rootSlot,
        Lean.Compiler.Yul.Expr.num length,
        Lean.Compiler.Yul.Expr.num fieldCount,
        Lean.Compiler.Yul.Expr.num fieldOffset,
        ← lowerValuePlan lowerExpr index
      ])

partial def exprPlanExpr
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr) :
    ExprPlan → Except ε Lean.Compiler.Yul.Expr
  | .literalWord value => .ok (Lean.Compiler.Yul.Expr.num value)
  | .local name => .ok (Lean.Compiler.Yul.Expr.id name)
  | .calldataWord paramIndex => .ok (calldataWordExpr paramIndex)
  | .storageLoad slot => do
      .ok (Lean.Compiler.Yul.builtin "sload" #[← storageSlotExpr mkError lowerExpr slot])
  | .builtin name args => do
      .ok (Lean.Compiler.Yul.builtin name (← args.mapM (exprPlanExpr mkError lowerExpr lowerEffect)))
  | .helperCall helper args => do
      .ok (helperCall helper (← args.mapM (exprPlanExpr mkError lowerExpr lowerEffect)))
  | .checkedArith op lhs rhs => do
      .ok (checkedArithExpr op
        (← exprPlanExpr mkError lowerExpr lowerEffect lhs)
        (← exprPlanExpr mkError lowerExpr lowerEffect rhs))
  | .hashPack a b c d => do
      .ok (hashPackExpr
        (← exprPlanExpr mkError lowerExpr lowerEffect a)
        (← exprPlanExpr mkError lowerExpr lowerEffect b)
        (← exprPlanExpr mkError lowerExpr lowerEffect c)
        (← exprPlanExpr mkError lowerExpr lowerEffect d))
  | .context field =>
      .ok (contextExpr field)
  | .crosscall .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support crosscall plans yet")
  | .create .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support create plans yet")
  | .cast source _ =>
      exprPlanExpr mkError lowerExpr lowerEffect source
  | .localAbiWords .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support ABI word expansion plans yet")
  | .localCrosscallWords .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support crosscall word expansion plans yet")
  | .structField .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support struct field plans yet")
  | .arrayGet .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support array get plans yet")
  | .localArrayGet .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support local array get plans yet")
  | .arrayLit .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support array literal plans yet")
  | .structLit .. =>
      .error (mkError "EVM ExprPlan-to-Yul scalar lowering does not support struct literal plans yet")
  | .hashValue a b c d => do
      .ok (hashPackExpr
        (← exprPlanExpr mkError lowerExpr lowerEffect a)
        (← exprPlanExpr mkError lowerExpr lowerEffect b)
        (← exprPlanExpr mkError lowerExpr lowerEffect c)
        (← exprPlanExpr mkError lowerExpr lowerEffect d))
  | .hash preimage => do
      .ok (helperCall Helper.hashWord #[← exprPlanExpr mkError lowerExpr lowerEffect preimage])
  | .hashTwoToOne lhs rhs => do
      .ok (helperCall Helper.hashPair #[
        ← exprPlanExpr mkError lowerExpr lowerEffect lhs,
        ← exprPlanExpr mkError lowerExpr lowerEffect rhs
      ])
  | .nativeValue =>
      .ok (Lean.Compiler.Yul.builtin "callvalue" #[])
  | .effect effect =>
      lowerEffect effect

/-! ## StmtPlan-to-Yul helpers -/

def scalarBindingStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .letBind name _ value
  | .letMutBind name _ value => do
      .ok #[
        .varDecl
          #[({ name := name } : Lean.Compiler.Yul.TypedName)]
          (some (← exprPlanExpr mkError lowerExpr lowerEffect value))
      ]
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul scalar binding lowering expected a let binding")

def assertStatementFromCondition
    (condition : Lean.Compiler.Yul.Expr)
    (revertStatements : Array Lean.Compiler.Yul.Statement) :
    Lean.Compiler.Yul.Statement :=
  Lean.Compiler.Yul.Statement.ifStmt
    (Lean.Compiler.Yul.builtin "iszero" #[condition])
    { statements := revertStatements }

def scalarAssertStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (revertStatementsFor : Option ProofForge.IR.ErrorRef → Array Lean.Compiler.Yul.Statement) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .assert condition _ errorRef? => do
      .ok #[
        assertStatementFromCondition
          (← exprPlanExpr mkError lowerExpr lowerEffect condition)
          (revertStatementsFor errorRef?)
      ]
  | .assertEq lhs rhs _ errorRef? => do
      let lhsExpr ← exprPlanExpr mkError lowerExpr lowerEffect lhs
      let rhsExpr ← exprPlanExpr mkError lowerExpr lowerEffect rhs
      .ok #[
        assertStatementFromCondition
          (Lean.Compiler.Yul.builtin "eq" #[lhsExpr, rhsExpr])
          (revertStatementsFor errorRef?)
      ]
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul scalar assertion lowering expected assert/assertEq")

def scalarReturnStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (returnNames : Array String)
    (leaveAfterReturn : Bool) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .return value => do
      let some returnName := returnNames[0]?
        | .error (mkError "EVM StmtPlan-to-Yul scalar return lowering expected one return name, got 0")
      if returnNames.size != 1 then
        .error (mkError s!"EVM StmtPlan-to-Yul scalar return lowering expected one return name, got {returnNames.size}")
      else
        let statements := #[
          Lean.Compiler.Yul.Statement.assignment
            #[returnName]
            (← exprPlanExpr mkError lowerExpr lowerEffect value)
        ]
        .ok <| if leaveAfterReturn then statements.push .leave else statements
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul scalar return lowering expected return")

def scalarAssignmentStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .assign (.local targetName) value => do
      .ok #[
        Lean.Compiler.Yul.Statement.assignment
          #[targetName]
          (← exprPlanExpr mkError lowerExpr lowerEffect value)
      ]
  | .assignOp (.local targetName) op value => do
      .ok #[
        Lean.Compiler.Yul.Statement.assignment
          #[targetName]
          (checkedArithExpr op
            (Lean.Compiler.Yul.Expr.id targetName)
            (← exprPlanExpr mkError lowerExpr lowerEffect value))
      ]
  | .assign _ _ =>
      .error (mkError "EVM StmtPlan-to-Yul scalar assignment lowering expected a local target")
  | .assignOp _ _ _ =>
      .error (mkError "EVM StmtPlan-to-Yul scalar compound assignment lowering expected a local target")
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul scalar assignment lowering expected assign/assignOp")

def ifElseStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (thenStatements elseStatements : Array Lean.Compiler.Yul.Statement) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .ifElse condition _ _ => do
      .ok #[
        .switchStmt
          (← exprPlanExpr mkError lowerExpr lowerEffect condition)
          #[
            {
              value := some (Lean.Compiler.Yul.Literal.natLit 0)
              body := { statements := elseStatements }
            },
            {
              value := none
              body := { statements := thenStatements }
            }
          ]
      ]
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul ifElse lowering expected ifElse")

def boundedForConditionPlan (indexName : String) (stopExclusive : Nat) : ExprPlan :=
  .builtin "lt" #[.local indexName, .literalWord stopExclusive]

def boundedForStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (bodyStatements : Array Lean.Compiler.Yul.Statement) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .boundedFor indexName start stopExclusive _ => do
      if stopExclusive <= start then
        .error (mkError s!"bounded loop `{indexName}` must have stop greater than start")
      else
        .ok #[
          .forLoop
            { statements := #[
              .varDecl #[{ name := indexName }] (some (Lean.Compiler.Yul.Expr.num start))
            ] }
            (← exprPlanExpr mkError lowerExpr lowerEffect
              (boundedForConditionPlan indexName stopExclusive))
            { statements := #[
              .assignment #[indexName]
                (Lean.Compiler.Yul.builtin "add" #[
                  Lean.Compiler.Yul.Expr.id indexName,
                  Lean.Compiler.Yul.Expr.num 1
                ])
            ] }
            { statements := bodyStatements }
        ]
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul boundedFor lowering expected boundedFor")

def scalarStorageEffectPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (storageSlotFor : String → Except ε Lean.Compiler.Yul.Expr) :
    EffectPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .storageScalarWrite stateId value => do
      .ok #[
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          ← storageSlotFor stateId,
          ← exprPlanExpr mkError lowerExpr lowerEffect value
        ])
      ]
  | .storageScalarAssignOp stateId op value => do
      let storageSlot ← storageSlotFor stateId
      .ok #[
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          storageSlot,
          checkedArithExpr op
            (Lean.Compiler.Yul.builtin "sload" #[storageSlot])
            (← exprPlanExpr mkError lowerExpr lowerEffect value)
        ])
      ]
  | _ =>
      .error (mkError "EVM EffectPlan-to-Yul scalar storage effect lowering expected storageScalarWrite/storageScalarAssignOp")

def scalarStorageEffectStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (storageSlotFor : String → Except ε Lean.Compiler.Yul.Expr) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .effect effect =>
      scalarStorageEffectPlanStatements mkError lowerExpr lowerEffect storageSlotFor effect
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul scalar storage effect lowering expected effect")

def mapWriteEffectPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (mapRootSlotFor : String → Except ε Lean.Compiler.Yul.Expr) :
    EffectPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .storageMapInsert stateId key value
  | .storageMapSet stateId key value => do
      .ok #[
        .exprStmt (helperCall Helper.mapWrite #[
          ← mapRootSlotFor stateId,
          ← exprPlanExpr mkError lowerExpr lowerEffect key,
          ← exprPlanExpr mkError lowerExpr lowerEffect value
        ])
      ]
  | _ =>
      .error (mkError "EVM EffectPlan-to-Yul map write lowering expected storageMapInsert/storageMapSet")

def mapWriteEffectStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (mapRootSlotFor : String → Except ε Lean.Compiler.Yul.Expr) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .effect effect =>
      mapWriteEffectPlanStatements mkError lowerExpr lowerEffect mapRootSlotFor effect
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul map write lowering expected effect")

def arrayWriteEffectPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (arraySlotFor : String → ExprPlan → Except ε Lean.Compiler.Yul.Expr) :
    EffectPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .storageArrayWrite stateId index value => do
      .ok #[
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          ← arraySlotFor stateId index,
          ← exprPlanExpr mkError lowerExpr lowerEffect value
        ])
      ]
  | _ =>
      .error (mkError "EVM EffectPlan-to-Yul array write lowering expected storageArrayWrite")

def arrayWriteEffectStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (arraySlotFor : String → ExprPlan → Except ε Lean.Compiler.Yul.Expr) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .effect effect =>
      arrayWriteEffectPlanStatements mkError lowerExpr lowerEffect arraySlotFor effect
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul array write lowering expected effect")

def structFieldWriteEffectPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (structFieldSlotFor : String → String → Except ε Lean.Compiler.Yul.Expr)
    (structArrayFieldSlotFor : String → ExprPlan → String → Except ε Lean.Compiler.Yul.Expr) :
    EffectPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .storageStructFieldWrite stateId fieldName value => do
      .ok #[
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          ← structFieldSlotFor stateId fieldName,
          ← exprPlanExpr mkError lowerExpr lowerEffect value
        ])
      ]
  | .storageArrayStructFieldWrite stateId index fieldName value => do
      .ok #[
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          ← structArrayFieldSlotFor stateId index fieldName,
          ← exprPlanExpr mkError lowerExpr lowerEffect value
        ])
      ]
  | _ =>
      .error (mkError "EVM EffectPlan-to-Yul struct field write lowering expected storageStructFieldWrite/storageArrayStructFieldWrite")

def structFieldWriteEffectStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (structFieldSlotFor : String → String → Except ε Lean.Compiler.Yul.Expr)
    (structArrayFieldSlotFor : String → ExprPlan → String → Except ε Lean.Compiler.Yul.Expr) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .effect effect =>
      structFieldWriteEffectPlanStatements mkError lowerExpr lowerEffect structFieldSlotFor structArrayFieldSlotFor effect
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul struct field write lowering expected effect")

structure StorageStructWriteField where
  slot : Lean.Compiler.Yul.Expr
  fieldName : String
  value : Lean.Compiler.Yul.Expr
  deriving Inhabited

def storageStructAssignTempName (stateId fieldName : String) : String :=
  s!"__proof_forge_assign_storage_struct_{stateId}_{fieldName}"

def storageStructWriteStatements
    (stateId : String)
    (fields : Array StorageStructWriteField) : Array Lean.Compiler.Yul.Statement :=
  Id.run do
    let mut statements : Array Lean.Compiler.Yul.Statement := #[]
    for field in fields do
      statements := statements.push <|
        .varDecl #[{ name := storageStructAssignTempName stateId field.fieldName }] (some field.value)
    for field in fields do
      statements := statements.push <|
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
          field.slot,
          Lean.Compiler.Yul.Expr.id (storageStructAssignTempName stateId field.fieldName)
        ])
    pure statements

def storageStructWriteEffectPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (storageStructFieldsFor : String → ExprPlan → Except ε (Array StorageStructWriteField)) :
    EffectPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .storageScalarWrite stateId value => do
      .ok #[
        .block { statements := storageStructWriteStatements stateId (← storageStructFieldsFor stateId value) }
      ]
  | _ =>
      .error (mkError "EVM EffectPlan-to-Yul storage struct write lowering expected storageScalarWrite")

def storageStructWriteEffectStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (storageStructFieldsFor : String → ExprPlan → Except ε (Array StorageStructWriteField)) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .effect effect =>
      storageStructWriteEffectPlanStatements mkError storageStructFieldsFor effect
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul storage struct write lowering expected effect")

inductive StoragePathWriteTarget where
  | mapWrite (rootSlot key : Lean.Compiler.Yul.Expr)
  | singleSlot (slot : Lean.Compiler.Yul.Expr)
  | mapValuePresence (valueSlot presenceSlot : Lean.Compiler.Yul.Expr)
  deriving Inhabited

def storagePathWriteTargetStatements
    (value : Lean.Compiler.Yul.Expr) :
    StoragePathWriteTarget → Array Lean.Compiler.Yul.Statement
  | .mapWrite rootSlot key =>
      #[
        .exprStmt (helperCall Helper.mapWrite #[rootSlot, key, value])
      ]
  | .singleSlot slot =>
      #[
        .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[slot, value])
      ]
  | .mapValuePresence valueSlot presenceSlot =>
      #[
        .block { statements := #[
          .varDecl #[{ name := "_slot" }] (some valueSlot),
          .varDecl #[{ name := "_presence_slot" }] (some presenceSlot),
          .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
            Lean.Compiler.Yul.Expr.id "_slot",
            value
          ]),
          .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
            Lean.Compiler.Yul.Expr.id "_presence_slot",
            Lean.Compiler.Yul.Expr.num 1
          ])
        ]}
      ]

def storagePathWriteEffectPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (storagePathTargetFor : String → Array StoragePathSegment → Except ε StoragePathWriteTarget) :
    EffectPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .storagePathWrite stateId path value => do
      .ok <| storagePathWriteTargetStatements
        (← exprPlanExpr mkError lowerExpr lowerEffect value)
        (← storagePathTargetFor stateId path)
  | _ =>
      .error (mkError "EVM EffectPlan-to-Yul storage path write lowering expected storagePathWrite")

def storagePathWriteEffectStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (storagePathTargetFor : String → Array StoragePathSegment → Except ε StoragePathWriteTarget) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .effect effect =>
      storagePathWriteEffectPlanStatements mkError lowerExpr lowerEffect storagePathTargetFor effect
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul storage path write lowering expected effect")

def storagePathAssignOpTargetStatements
    (op : AssignOp)
    (value : Lean.Compiler.Yul.Expr) :
    StoragePathWriteTarget → Array Lean.Compiler.Yul.Statement
  | .mapWrite rootSlot key =>
      #[
        .exprStmt (helperCall (Helper.mapAssign op) #[rootSlot, key, value])
      ]
  | .singleSlot slot =>
      #[
        .block { statements := #[
          .varDecl #[{ name := "_slot" }] (some slot),
          .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
            Lean.Compiler.Yul.Expr.id "_slot",
            checkedArithExpr op
              (Lean.Compiler.Yul.builtin "sload" #[Lean.Compiler.Yul.Expr.id "_slot"])
              value
          ])
        ]}
      ]
  | .mapValuePresence valueSlot presenceSlot =>
      #[
        .block { statements := #[
          .varDecl #[{ name := "_slot" }] (some valueSlot),
          .varDecl #[{ name := "_presence_slot" }] (some presenceSlot),
          .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
            Lean.Compiler.Yul.Expr.id "_slot",
            checkedArithExpr op
              (Lean.Compiler.Yul.builtin "sload" #[Lean.Compiler.Yul.Expr.id "_slot"])
              value
          ]),
          .exprStmt (Lean.Compiler.Yul.builtin "sstore" #[
            Lean.Compiler.Yul.Expr.id "_presence_slot",
            Lean.Compiler.Yul.Expr.num 1
          ])
        ]}
      ]

def storagePathAssignOpEffectPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (storagePathTargetFor : String → Array StoragePathSegment → Except ε StoragePathWriteTarget) :
    EffectPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .storagePathAssignOp stateId path op value => do
      .ok <| storagePathAssignOpTargetStatements op
        (← exprPlanExpr mkError lowerExpr lowerEffect value)
        (← storagePathTargetFor stateId path)
  | _ =>
      .error (mkError "EVM EffectPlan-to-Yul storage path assign_op lowering expected storagePathAssignOp")

def storagePathAssignOpEffectStmtPlanStatements
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (lowerEffect : EffectPlan → Except ε Lean.Compiler.Yul.Expr)
    (storagePathTargetFor : String → Array StoragePathSegment → Except ε StoragePathWriteTarget) :
    StmtPlan → Except ε (Array Lean.Compiler.Yul.Statement)
  | .effect effect =>
      storagePathAssignOpEffectPlanStatements mkError lowerExpr lowerEffect storagePathTargetFor effect
  | _ =>
      .error (mkError "EVM StmtPlan-to-Yul storage path assign_op lowering expected effect")

/-! ## Plan-driven helper requirements

`StorageSlotPlan.requiredHelpers` lets the plan declare which EVM helper functions
a given slot plan needs, without `ToYul` re-discovering them from Yul text. -/

def slotHelperRequirements (slot : StorageSlotPlan) : HelperSet :=
  slot.requiredHelpers

def storageLayoutHelpers (layout : StorageLayout) : HelperSet :=
  layout.states.foldl (init := #[]) fun acc state =>
    match state.kind with
    | .map _ _ => HelperSet.insert (HelperSet.insert acc Helper.mapSlot) Helper.mapPresenceSlot
    | _ => acc

end ProofForge.Backend.Evm.ToYul
