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

end ProofForge.Backend.Evm.ToYul.AbiEncode
