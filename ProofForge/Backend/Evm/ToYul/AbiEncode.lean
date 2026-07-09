/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# AbiEncode.Plan → Yul (Wave δ)

Turns a pure `AbiEncode.Plan` (offset → word stores) into Yul statements that:

1. Place the 4-byte function selector at `memBase` via `shl(224, selector)`
2. `mstore` every plan word at `memBase + 4 + offset`
3. Issue `call` / `staticcall` with `inOffset = memBase`, `inSize = 4 + plan.size`

This is the EVM analogue of EmitWat consuming `JsonEncode.Node`: layout is
planned once, emit is mechanical. Multicall `aggregate` / `aggregate3` use this
path for real Call[] calldata (not scalar-handle smoke only).

Memory at `memBase..memBase+4+size` should be zeroed or unused free memory
(EVM expands memory with zeros). Plans only list non-default stores; gaps stay 0.
-/
import ProofForge.Backend.Evm.AbiEncode
import ProofForge.Backend.Evm.Plan
import ProofForge.IR.Contract
import ProofForge.Compiler.Yul.AST
import ProofForge.Compiler.Yul.Printer

namespace ProofForge.Backend.Evm.ToYul.AbiEncode

open ProofForge.Backend.Evm.AbiEncode
open Lean.Compiler.Yul

def catalogId : String := "evm.yul.abi_encode"

/-- Default scratch base (after Solidity free-memory pointer region). -/
def defaultMemBase : Nat := 0x80

def wordNat : WordVal → Nat
  | .num n => n

/-- `mstore(memBase + offset, value)` for each plan store. -/
def planMstoreStatements (memBase : Nat) (plan : Plan) : Array Statement :=
  plan.stores.map fun s =>
    .exprStmt (builtin "mstore" #[
      .num (memBase + s.offset),
      .num (wordNat s.value)
    ])

/-- Selector word at `memBase`: high 4 bytes = selector (`shl(224, selector)`). -/
def selectorStoreStatement (memBase selector : Nat) : Statement :=
  .exprStmt (builtin "mstore" #[
    .num memBase,
    builtin "shl" #[.num 224, .num selector]
  ])

/-- Args region starts at `memBase + 4` so it sits after the 4-byte selector. -/
def argsBase (memBase : Nat) : Nat :=
  memBase + 4

/-- Full in-region size for CALL: selector (4) + ABI args (`plan.size`). -/
def callInSize (plan : Plan) : Nat :=
  4 + plan.size

/-- Pack selector + plan into memory starting at `memBase`. -/
def packCalldataStatements (memBase selector : Nat) (plan : Plan) : Array Statement :=
  #[selectorStoreStatement memBase selector] ++
    planMstoreStatements (argsBase memBase) plan

/-- CALL with value 0; success left in `_abi_ok`. Out buffer reuses `memBase`. -/
def callStatement (memBase target inSize outSize : Nat) : Statement :=
  .varDecl #[{ name := "_abi_ok" }] (some <|
    builtin "call" #[
      builtin "gas" #[],
      .num target,
      .num 0,
      .num memBase,
      .num inSize,
      .num memBase,
      .num outSize
    ])

def staticcallStatement (memBase target inSize outSize : Nat) : Statement :=
  .varDecl #[{ name := "_abi_ok" }] (some <|
    builtin "staticcall" #[
      builtin "gas" #[],
      .num target,
      .num memBase,
      .num inSize,
      .num memBase,
      .num outSize
    ])

/-- Revert if last ABI call failed. -/
def requireSuccessStatement : Statement :=
  .ifStmt
    (builtin "iszero" #[.id "_abi_ok"])
    { statements := #[
      .exprStmt (builtin "revert" #[.num 0, .num 0])
    ] }

/-- Complete payload: pack calldata, CALL, require success. -/
structure CallEmit where
  statements : Array Statement
  memBase : Nat
  inSize : Nat
  outSize : Nat

/-- Emit CALL for a known selector + ABI args plan. -/
def emitCall (memBase target selector outSize : Nat) (plan : Plan) : CallEmit :=
  let inSize := callInSize plan
  let stmts :=
    packCalldataStatements memBase selector plan ++
    #[callStatement memBase target inSize outSize, requireSuccessStatement]
  { statements := stmts, memBase := memBase, inSize := inSize, outSize := outSize }

/-- Emit STATICCALL (view-shaped). -/
def emitStaticcall (memBase target selector outSize : Nat) (plan : Plan) : CallEmit :=
  let inSize := callInSize plan
  let stmts :=
    packCalldataStatements memBase selector plan ++
    #[staticcallStatement memBase target inSize outSize, requireSuccessStatement]
  { statements := stmts, memBase := memBase, inSize := inSize, outSize := outSize }

/-- Multicall3 `aggregate(Call[])` CALL payload. -/
def emitAggregateCall (memBase multicallTarget outSize : Nat) (calls : Array Call) : CallEmit :=
  emitCall memBase multicallTarget 0x252dba42 outSize (encodeAggregateArgs calls)

/-- Multicall3 `aggregate3(Call3[])` CALL payload. -/
def emitAggregate3Call (memBase multicallTarget outSize : Nat) (calls : Array Call3) : CallEmit :=
  emitCall memBase multicallTarget 0x82ad56cb outSize (encodeAggregate3Args calls)

/-- Render emit statements as a Yul block snippet (for tests / fixtures). -/
def renderStatements (stmts : Array Statement) : String :=
  Printer.printBlock 0 { statements := stmts }

/-- Render full aggregate CALL as Yul source text. -/
def renderAggregateCallYul (memBase multicallTarget outSize : Nat) (calls : Array Call) : String :=
  renderStatements (emitAggregateCall memBase multicallTarget outSize calls).statements

/-- Render full aggregate3 CALL as Yul source text. -/
def renderAggregate3CallYul (memBase multicallTarget outSize : Nat) (calls : Array Call3) : String :=
  renderStatements (emitAggregate3Call memBase multicallTarget outSize calls).statements

/-- Dense word list for plan (gap = 0) — useful for golden hex dumps. -/
def planDenseWords (plan : Plan) : Array Nat :=
  let n := pad32 plan.size / 32
  Id.run do
    let mut words : Array Nat := Array.replicate n 0
    for s in plan.stores do
      let idx := s.offset / 32
      if idx < n then
        words := words.set! idx (wordNat s.value)
    words

/-- Standalone Yul object that packs `aggregate(Call[])` and CALLs Multicall3.
Compile-time Call[] materialize path (Wave δ follow-on): no portable IR nodes —
fixture / smoke consume this object via solc `--strict-assembly`. -/
def aggregateObject (objectName : String) (multicallTarget outSize : Nat)
    (calls : Array Call) (memBase : Nat := defaultMemBase) : Object :=
  let emit := emitAggregateCall memBase multicallTarget outSize calls
  let body : Array Statement :=
    emit.statements ++ #[
      .exprStmt (builtin "return" #[.num memBase, .num outSize])
    ]
  {
    name := objectName
    code := {
      statements := #[
        .funcDef "main" #[] #[] { statements := body }
      ]
    }
  }

def renderAggregateObjectYul (objectName : String) (multicallTarget outSize : Nat)
    (calls : Array Call) (memBase : Nat := defaultMemBase) : String :=
  Printer.render (aggregateObject objectName multicallTarget outSize calls memBase)

/-! ## IR auto-lower: compile-time ABI pack → Yul helper (target is runtime) -/

open ProofForge.Backend.Evm.Plan (AbiPackedHelperSpec)

/-- Stable helper name for a static pack (selector + stores fingerprint). -/
def abiPackedHelperName (spec : AbiPackedHelperSpec) : String :=
  Id.run do
    let mut acc := s!"__pf_abi_packed_{spec.selector}_{spec.argsSize}_{spec.outSize}"
    match spec.dynLenOffset? with
    | some off => acc := s!"{acc}_dyn{off}"
    | none => pure ()
    for s in spec.stores do
      acc := s!"{acc}_{s.1}_{s.2}"
    acc

/-- Yul helper: pack selector+stores at `memBase`, optional runtime length
    overwrite, CALL `target`, return first out word.
    Static: params `(target)`. Dyn length: params `(target, n)`. -/
def abiPackedHelperFunction (spec : AbiPackedHelperSpec) (memBase : Nat := defaultMemBase) :
    Statement :=
  let plan : Plan := {
    stores := spec.stores.map fun s => { offset := s.1, value := .num s.2 }
    size := spec.argsSize
  }
  let inSize := callInSize plan
  let pack := packCalldataStatements memBase spec.selector plan
  let overwrite :=
    match spec.dynLenOffset? with
    | none => #[]
    | some off =>
        -- args region starts at memBase+4; overwrite length word with runtime `n`
        #[.exprStmt (builtin "mstore" #[
          .num (memBase + 4 + off),
          .id "n"
        ])]
  let body :=
    pack ++ overwrite ++ #[
      .varDecl #[{ name := "_abi_ok" }] (some <|
        builtin "call" #[
          builtin "gas" #[],
          .id "target",
          .num 0,
          .num memBase,
          .num inSize,
          .num memBase,
          .num spec.outSize
        ]),
      .ifStmt
        (builtin "iszero" #[.id "_abi_ok"])
        { statements := #[.exprStmt (builtin "revert" #[.num 0, .num 0])] },
      .assignment #["result"]
        (if spec.outSize == 0 then .num 0
         else builtin "mload" #[.num memBase])
    ]
  let params : Array Lean.Compiler.Yul.TypedName :=
    match spec.dynLenOffset? with
    | none => #[{ name := "target" }]
    | some _ => #[{ name := "target" }, { name := "n" }]
  .funcDef (abiPackedHelperName spec) params #[{ name := "result" }] { statements := body }

def abiPackedHelperCallExpr (target : Lean.Compiler.Yul.Expr) (spec : AbiPackedHelperSpec)
    (dynLen? : Option Lean.Compiler.Yul.Expr := none) : Lean.Compiler.Yul.Expr :=
  match spec.dynLenOffset?, dynLen? with
  | some _, some n => Lean.Compiler.Yul.call (abiPackedHelperName spec) #[target, n]
  | _, _ => Lean.Compiler.Yul.call (abiPackedHelperName spec) #[target]

/-- Build IR `crosscallAbiPacked` from an AbiEncode plan (args region). -/
def irFromPlan (target : ProofForge.IR.Expr) (selector : Nat) (plan : Plan)
    (outSize : Nat := 32)
    (dynLenOffset? : Option Nat := none)
    (dynLen? : Option ProofForge.IR.Expr := none) : ProofForge.IR.Expr :=
  ProofForge.IR.Expr.crosscallAbiPacked target selector
    (plan.stores.map fun s => (s.offset, wordNat s.value))
    plan.size
    outSize
    dynLenOffset?
    dynLen?

/-- Multicall3 `aggregate(Call[])` as IR expr (compile-time calls / length). -/
def irAggregate (target : ProofForge.IR.Expr) (calls : Array Call) (outSize : Nat := 32) :
    ProofForge.IR.Expr :=
  irFromPlan target 0x252dba42 (encodeAggregateArgs calls) outSize

/-- Multicall3 `aggregate(Call[])` with **runtime** length `n` (0..calls.size].
    Packs the full static Call[] then overwrites the array length word at
    args offset `0x20` with `n`. Multicall only iterates `n` elements. -/
def irAggregateDynLen (target n : ProofForge.IR.Expr) (calls : Array Call)
    (outSize : Nat := 32) : ProofForge.IR.Expr :=
  irFromPlan target 0x252dba42 (encodeAggregateArgs calls) outSize (some 0x20) (some n)

/-- Multicall3 `aggregate3(Call3[])` as IR expr. -/
def irAggregate3 (target : ProofForge.IR.Expr) (calls : Array Call3) (outSize : Nat := 32) :
    ProofForge.IR.Expr :=
  irFromPlan target 0x82ad56cb (encodeAggregate3Args calls) outSize

/-- Runtime-length aggregate3: length word at args offset `0x20`. -/
def irAggregate3DynLen (target n : ProofForge.IR.Expr) (calls : Array Call3)
    (outSize : Nat := 32) : ProofForge.IR.Expr :=
  irFromPlan target 0x82ad56cb (encodeAggregate3Args calls) outSize (some 0x20) (some n)

end ProofForge.Backend.Evm.ToYul.AbiEncode
