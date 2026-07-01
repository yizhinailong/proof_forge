/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

EmitWat — lowers the portable IR (`ProofForge.IR.Contract`) to a `Wasm.Module`
that `Wasm.Printer` renders to WAT, deployable to the NEAR VM via `wat2wasm`.

Canonical wasm-near backend (decision D-023). Scope: scalar value types
U32/U64/Bool — literals, locals, arithmetic, bitwise, shift, comparisons,
boolean ops, casts, scalar storage read/write, assignment, assert/assertEq,
and U32/U64/Bool returns. Hash / map / context / events / control flow land
later.
-/
import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.IR.Contract
import ProofForge.Compiler.Wasm.AST
import ProofForge.Compiler.Wasm.Printer

namespace ProofForge.Backend.WasmNear.EmitWat

open ProofForge.IR
open ProofForge.Compiler.Wasm

structure EmitError where
  message : String
  deriving Repr, Inhabited

def err (msg : String) : Except EmitError α := .error { message := msg }

-- Memory layout
def KEY_BUF   : Nat := 4096
def RET_BUF   : Nat := 8192
def TRUE_PTR  : Nat := 12000
def FALSE_PTR : Nat := 12006

-- Value type → Wasm
def wasmTypeOf : ValueType → ValType
  | .u32 => .i32 | .u64 => .i64 | .bool => .i32 | _ => .i32
def widthOf : ValueType → String
  | .u32 => "i32" | .u64 => "i64" | .bool => "i32" | _ => "i32"
def isNumeric (t : ValueType) : Bool := match t with | .u32 | .u64 => true | _ => false
def scalarWidth : ValueType → Nat
  | .u32 => 4 | .u64 => 8 | .bool => 1 | _ => 8
def loadOpFor : ValueType → String
  | .u32 => "i32.load" | .u64 => "i64.load" | .bool => "i32.load8_u" | _ => "i64.load"
def storeOpFor : ValueType → String
  | .u32 => "i32.store" | .u64 => "i64.store" | .bool => "i32.store8" | _ => "i64.store"
def typeSuffix (vt : ValueType) : String :=
  match vt with | .u32 => "u32" | .u64 => "u64" | .bool => "bool" | _ => "x"
def readName  (vt : ValueType) : String := "__pf_read_"  ++ typeSuffix vt
def writeName (vt : ValueType) : String := "__pf_write_" ++ typeSuffix vt
def returnU64Name  : String := "__pf_return_u64"
def returnBoolName : String := "__pf_return_bool"

-- Host imports
def hostImport (name : String) (params results : Array ValType) : Import :=
  { module_ := "env", name := name, funcName := name, type := { params := params, results := results } }
def nearImports : Array Import :=
  #[ hostImport "storage_read"  #[.i64, .i64, .i64] #[.i64],
     hostImport "storage_write" #[.i64, .i64, .i64, .i64, .i64] #[.i64],
     hostImport "read_register" #[.i64, .i64] #[],
     hostImport "value_return"  #[.i64, .i64] #[] ]

-- Helpers (per scalar type)
def readFunc (vt : ValueType) : Func :=
  { name := readName vt,
    params := #[{ name := "kp", type := .i32 }, { name := "kl", type := .i32 }],
    results := #[wasmTypeOf vt],
    locals := #[{ name := "found", type := .i64 }, { name := "r", type := wasmTypeOf vt }],
    body := { insns := #[
      .const (wasmTypeOf vt) "0", .localSet "r",
      .localGet "kl", .plain "i64.extend_i32_u", .localGet "kp", .plain "i64.extend_i32_u",
      .i64Const 0, .call "storage_read", .localSet "found",
      .localGet "found", .i64Const 0, .plain "i64.ne",
      .if_ { insns := #[ .i64Const 0, .i64Const KEY_BUF, .call "read_register",
                        .i32Const KEY_BUF, .load (loadOpFor vt) 0, .localSet "r" ] } { insns := #[] },
      .localGet "r" ] } }

def writeFunc (vt : ValueType) : Func :=
  { name := writeName vt,
    params := #[{ name := "kp", type := .i32 }, { name := "kl", type := .i32 }, { name := "v", type := wasmTypeOf vt }],
    results := #[],
    body := { insns := #[
      .i32Const KEY_BUF, .localGet "v", .store (storeOpFor vt) 0,
      .localGet "kl", .plain "i64.extend_i32_u", .localGet "kp", .plain "i64.extend_i32_u",
      .i64Const (scalarWidth vt), .i64Const KEY_BUF, .i64Const 0, .call "storage_write", .drop ] } }

def returnU64Func : Func :=
  { name := returnU64Name,
    params := #[{ name := "v", type := .i64 }],
    locals := #[{ name := "tmp", type := .i64 }, { name := "p", type := .i32 }, { name := "d", type := .i32 }],
    body := { insns := #[
      .localGet "v", .localSet "tmp",
      .i32Const (RET_BUF + 20), .localSet "p",
      .localGet "tmp", .plain "i64.eqz",
      .if_ { insns := #[ .i32Const (RET_BUF + 19), .i32Const 48, .store "i32.store8" 0,
                        .i32Const (RET_BUF + 19), .localSet "p" ] }
         { insns := #[ .block_ { insns := #[ .loop_ { insns := #[
            .localGet "tmp", .plain "i64.eqz", .brIf 1,
            .localGet "tmp", .i64Const 10, .plain "i64.rem_u", .plain "i32.wrap_i64", .localSet "d",
            .localGet "tmp", .i64Const 10, .plain "i64.div_u", .localSet "tmp",
            .localGet "p", .i32Const 1, .plain "i32.sub", .localTee "p",
            .i32Const 48, .localGet "d", .plain "i32.add", .store "i32.store8" 0, .br 0 ] } ] } ] },
      .i32Const (RET_BUF + 20), .localGet "p", .plain "i32.sub", .plain "i64.extend_i32_u",
      .localGet "p", .plain "i64.extend_i32_u", .call "value_return" ] } }

def returnBoolFunc : Func :=
  { name := returnBoolName, params := #[{ name := "v", type := .i32 }],
    body := { insns := #[
      .localGet "v", .plain "i32.eqz",
      .if_ { insns := #[ .i64Const 5, .i64Const FALSE_PTR, .call "value_return" ] }
         { insns := #[ .i64Const 4, .i64Const TRUE_PTR, .call "value_return" ] } ] } }

def helperFuncs : Array Func :=
  #[ readFunc .u32, writeFunc .u32, readFunc .u64, writeFunc .u64,
     readFunc .bool, writeFunc .bool, returnU64Func, returnBoolFunc ]

-- State layout
structure StateInfo where
  id : String
  type : ValueType
  keyPtr : Nat
  keyLen : Nat

def stateLayout (mod : ProofForge.IR.Module) : Array StateInfo :=
  let step (acc : Array StateInfo) (offset : Nat) (s : StateDecl) : Array StateInfo × Nat :=
    match s.kind with
    | .scalar => (acc.push { id := s.id, type := s.type, keyPtr := offset, keyLen := s.id.length }, offset + s.id.length + 1)
    | _ => (acc, offset)
  let result : Array StateInfo × Nat := mod.state.foldl (init := (#[], 0))
    fun (acc, offset) s => step acc offset s
  result.fst

def findScalarState? (layout : Array StateInfo) (id : String) : Option StateInfo :=
  layout.find? (fun s => s.id == id)

-- Type-directed expression lowering (mutually recursive)
structure LBind where
  name : String
  vt : ValueType
abbrev LocalTypes := Array LBind

def lookupLocal? (env : LocalTypes) (name : String) : Option ValueType :=
  match env.find? (fun b => b.name == name) with
  | some b => some b.vt
  | none => none

def assignOpName : AssignOp → String
  | .add => "add" | .sub => "sub" | .mul => "mul" | .div => "div_u" | .mod => "rem_u"
  | .bitAnd => "and" | .bitOr => "or" | .bitXor => "xor"
  | .shiftLeft => "shl" | .shiftRight => "shr_u"

mutual
  partial def lowerExpr (layout : Array StateInfo) (env : LocalTypes) (e : Expr)
      : Except EmitError (Array Insn × ValueType) :=
    match e with
    | .literal (.u32 n) => .ok (#[.const .i32 (toString n)], .u32)
    | .literal (.u64 n) => .ok (#[.const .i64 (toString n)], .u64)
    | .literal (.bool b) => .ok (#[.const .i32 (if b then "1" else "0")], .bool)
    | .local name =>
      match lookupLocal? env name with
      | some t => .ok (#[.localGet name], t)
      | none => err s!"EmitWat: unknown local `{name}`"
    | .add a b => lowerNumBin layout env "add" a b
    | .sub a b => lowerNumBin layout env "sub" a b
    | .mul a b => lowerNumBin layout env "mul" a b
    | .div a b => lowerNumBin layout env "div_u" a b
    | .mod a b => lowerNumBin layout env "rem_u" a b
    | .bitAnd a b => lowerNumBin layout env "and" a b
    | .bitOr a b => lowerNumBin layout env "or" a b
    | .bitXor a b => lowerNumBin layout env "xor" a b
    | .shiftLeft a b => lowerNumBin layout env "shl" a b
    | .shiftRight a b => lowerNumBin layout env "shr_u" a b
    | .pow _ _ => err "EmitWat: pow is not yet supported"
    | .eq a b => lowerCmp layout env "eq" a b
    | .ne a b => lowerCmp layout env "ne" a b
    | .lt a b => lowerCmp layout env "lt_u" a b
    | .le a b => lowerCmp layout env "le_u" a b
    | .gt a b => lowerCmp layout env "gt_u" a b
    | .ge a b => lowerCmp layout env "ge_u" a b
    | .boolAnd a b => lowerBoolBin layout env "and" a b
    | .boolOr a b => lowerBoolBin layout env "or" a b
    | .boolNot a => do
      let (is, t) ← lowerExpr layout env a
      if t != .bool then err s!"EmitWat: boolean not operand expected Bool, got `{t.name}`"
      else .ok (is ++ #[.plain "i32.eqz"], .bool)
    | .cast value target => lowerCast layout env value target
    | .effect (.storageScalarRead id) =>
      match findScalarState? layout id with
      | some s => .ok (#[.i32Const s.keyPtr, .i32Const s.keyLen, .call (readName s.type)], s.type)
      | none => err s!"EmitWat: unknown scalar state `{id}`"
    | _ => err "EmitWat: this expression form is not yet supported"

  partial def lowerNumBin (layout : Array StateInfo) (env : LocalTypes) (op : String) (a b : Expr)
      : Except EmitError (Array Insn × ValueType) := do
    let (la, ta) ← lowerExpr layout env a
    let (lb, tb) ← lowerExpr layout env b
    if !(isNumeric ta && ta == tb) then
      err s!"EmitWat: `{op}` expected matching U32/U64 operands, got `{ta.name}`/`{tb.name}`"
    else .ok (la ++ lb ++ #[.plain (widthOf ta ++ "." ++ op)], ta)

  partial def lowerCmp (layout : Array StateInfo) (env : LocalTypes) (op : String) (a b : Expr)
      : Except EmitError (Array Insn × ValueType) := do
    let (la, ta) ← lowerExpr layout env a
    let (lb, tb) ← lowerExpr layout env b
    if ta != tb then err s!"EmitWat: `{op}` expected matching operand types, got `{ta.name}`/`{tb.name}`"
    else .ok (la ++ lb ++ #[.plain (widthOf ta ++ "." ++ op)], .bool)

  partial def lowerBoolBin (layout : Array StateInfo) (env : LocalTypes) (op : String) (a b : Expr)
      : Except EmitError (Array Insn × ValueType) := do
    let (la, ta) ← lowerExpr layout env a
    let (lb, tb) ← lowerExpr layout env b
    if !(ta == .bool && tb == .bool) then err s!"EmitWat: boolean `{op}` expected Bool operands"
    else .ok (la ++ lb ++ #[.plain ("i32." ++ op)], .bool)

  partial def lowerCast (layout : Array StateInfo) (env : LocalTypes) (value : Expr) (target : ValueType)
      : Except EmitError (Array Insn × ValueType) := do
    let (is, src) ← lowerExpr layout env value
    let extra ←
      match src, target with
      | .u32, .u64 => .ok #[.plain "i64.extend_i32_u"]
      | .u64, .u32 => .ok #[.plain "i32.wrap_i64"]
      | .u32, .bool => .ok #[.i32Const 0, .plain "i32.ne"]
      | .u64, .bool => .ok #[.i64Const 0, .plain "i64.ne"]
      | .bool, .u32 => .ok #[]
      | .bool, .u64 => .ok #[.plain "i64.extend_i32_u"]
      | _, _ => err s!"EmitWat: cast from `{src.name}` to `{target.name}` is not supported"
    .ok (is ++ extra, target)
end

-- Statements
def collectLocals (body : Array Statement) : Except EmitError LocalTypes :=
  body.foldlM (init := #[]) fun acc s =>
    match s with
    | .letBind name t _ | .letMutBind name t _ =>
      if isNumeric t || t == .bool then .ok (acc.push { name := name, vt := t })
      else err s!"EmitWat: only U32/U64/Bool locals are supported (got `{t.name}`)"
    | _ => .ok acc

def lowerReturn (layout : Array StateInfo) (env : LocalTypes) (expected : ValueType) (e : Expr)
    : Except EmitError (Array Insn) := do
  let (is, t) ← lowerExpr layout env e
  if t != expected then err s!"EmitWat: return expected `{expected.name}`, got `{t.name}`"
  else match t with
    | .u64 => .ok (is ++ #[.call returnU64Name])
    | .u32 => .ok (is ++ #[.plain "i64.extend_i32_u", .call returnU64Name])
    | .bool => .ok (is ++ #[.call returnBoolName])
    | _ => err s!"EmitWat: return type `{t.name}` is not supported"

partial def lowerStmt (layout : Array StateInfo) (env : LocalTypes) (returns : ValueType)
    (s : Statement) : Except EmitError (Array Insn) :=
  match s with
  | .letBind name t e | .letMutBind name t e => do
    let (is, te) ← lowerExpr layout env e
    if te != t then err s!"EmitWat: let `{name}` expected `{t.name}`, got `{te.name}`"
    else .ok (is ++ #[.localSet name])
  | .assign (.local name) e => do
    let (is, _) ← lowerExpr layout env e
    if (lookupLocal? env name).isNone then err s!"EmitWat: assignment to unknown local `{name}`"
    else .ok (is ++ #[.localSet name])
  | .assign _ _ => err "EmitWat: assignment target must be a local"
  | .assignOp (.local name) op e => do
    let some lt ← pure (lookupLocal? env name) | err s!"EmitWat: compound assignment to unknown local `{name}`"
    if !(isNumeric lt) then err "EmitWat: compound assignment requires U32/U64 local"
    else do
      let (is, t) ← lowerExpr layout env e
      if t != lt then err s!"EmitWat: compound `{assignOpName op}` expected `{lt.name}`, got `{t.name}`"
      else .ok (#[.localGet name] ++ is ++ #[.plain (widthOf lt ++ "." ++ assignOpName op), .localSet name])
  | .assignOp _ _ _ => err "EmitWat: compound assignment target must be a local"
  | .effect (.storageScalarWrite id e) => do
    let some s ← pure (findScalarState? layout id) | err s!"EmitWat: unknown scalar state `{id}`"
    let (is, t) ← lowerExpr layout env e
    if t != s.type then err s!"EmitWat: scalar write `{id}` expected `{s.type.name}`, got `{t.name}`"
    else .ok (#[.i32Const s.keyPtr, .i32Const s.keyLen] ++ is ++ #[.call (writeName s.type)])
  | .assert cond _ => do
    let (is, t) ← lowerExpr layout env cond
    if t != .bool then err "EmitWat: assert condition must be Bool"
    else .ok (is ++ #[.plain "i32.eqz", .if_ { insns := #[.unreachable] } { insns := #[] }])
  | .assertEq a b _ => do
    let (la, ta) ← lowerExpr layout env a
    let (lb, tb) ← lowerExpr layout env b
    if ta != tb then err "EmitWat: assertEq operands must share a type"
    else .ok (la ++ lb ++ #[.plain (widthOf ta ++ ".eq"), .plain "i32.eqz",
                            .if_ { insns := #[.unreachable] } { insns := #[] }])
  | .return e => lowerReturn layout env returns e
  | _ => err "EmitWat: this statement form is not yet supported"

def lowerEntrypoint (layout : Array StateInfo) (ep : Entrypoint) : Except EmitError Func := do
  let localsArr ← collectLocals ep.body
  let locals := localsArr.map fun b => { name := b.name, type := wasmTypeOf b.vt : Local }
  let insns ← ep.body.foldlM (init := #[]) fun acc s => return acc ++ (← lowerStmt layout localsArr ep.returns s)
  .ok { name := ep.name, locals := locals, body := { insns := insns }, exportName := ep.name }

def lowerModule (mod : ProofForge.IR.Module) : Except EmitError ProofForge.Compiler.Wasm.Module := do
  let layout := stateLayout mod
  let entryFuncs ← mod.entrypoints.mapM (lowerEntrypoint layout)
  let keyData := layout.map fun s => { offset := s.keyPtr, bytes := s.id : DataSegment }
  let boolData : Array DataSegment :=
    #[{ offset := TRUE_PTR, bytes := "true" }, { offset := FALSE_PTR, bytes := "false" }]
  .ok { imports := nearImports, funcs := helperFuncs ++ entryFuncs,
        memory := some { min := 1 }, dataSegments := keyData ++ boolData }

def renderModule (mod : ProofForge.IR.Module) : Except EmitError String :=
  match lowerModule mod with
  | .ok m => .ok (Printer.render m)
  | .error e => .error e

end ProofForge.Backend.WasmNear.EmitWat
