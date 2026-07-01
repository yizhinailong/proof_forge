/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

EmitWat — lowers the portable IR (`ProofForge.IR.Contract`) to a `Wasm.Module`
that `Wasm.Printer` renders to WAT, deployable to the NEAR VM via `wat2wasm`.

This is the canonical wasm-near backend (decision D-023). It mirrors
`Backend/Evm/IR.lean` (portable IR → Yul AST) but targets WAT, and reuses none
of the frozen Rust v0 (`Backend/WasmNear/IR.lean`) — only the emission target
changes (Rust strings → Wasm AST → WAT).

v0 scope: U64 scalar state + U64 arithmetic + U64 return. Scalar state is
persisted under per-field NEAR storage keys; U64 returns are formatted as
decimal ASCII and returned via `env.value_return` (JSON-parseable by
near-api-js). Other IR constructs (hash, map, context, events, control flow,
other value types) are rejected with a clear "not yet supported" error and
land in later milestones.
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

-- ---------------------------------------------------------------------------
-- Memory layout (1 page = 65536 bytes)
-- ---------------------------------------------------------------------------

/-- Buffer for u64 storage read/write (8 bytes). -/ def KEY_BUF : Nat := 4096
/-- Buffer for ASCII-formatted u64 returns (32 bytes). -/ def RET_BUF : Nat := 8192

def readU64Name   : String := "__pf_read_u64"
def writeU64Name  : String := "__pf_write_u64"
def returnU64Name : String := "__pf_return_u64"

-- ---------------------------------------------------------------------------
-- Host imports (register-based NEAR API)
-- ---------------------------------------------------------------------------

def hostImport (name : String) (params results : Array ValType) : Import :=
  { module_ := "env", name := name, funcName := name, type := { params := params, results := results } }

def nearImports : Array Import :=
  #[ hostImport "storage_read"  #[.i64, .i64, .i64] #[.i64],
     hostImport "storage_write" #[.i64, .i64, .i64, .i64, .i64] #[.i64],
     hostImport "read_register" #[.i64, .i64] #[],
     hostImport "value_return"  #[.i64, .i64] #[] ]

-- ---------------------------------------------------------------------------
-- Helper functions emitted into every module
-- ---------------------------------------------------------------------------

def readU64Func : Func :=
  { name := readU64Name,
    params := #[{ name := "kp", type := .i32 }, { name := "kl", type := .i32 }],
    results := #[.i64],
    locals := #[{ name := "found", type := .i64 }, { name := "r", type := .i64 }],
    body := { insns := #[
      .i64Const 0, .localSet "r",
      .localGet "kl", .plain "i64.extend_i32_u",
      .localGet "kp", .plain "i64.extend_i32_u",
      .i64Const 0, .call "storage_read", .localSet "found",
      .localGet "found", .i64Const 0, .plain "i64.ne",
      .if_ { insns := #[
        .i64Const 0, .i64Const KEY_BUF, .call "read_register",
        .i32Const KEY_BUF, .load "i64.load" 0, .localSet "r" ] }
         { insns := #[] },
      .localGet "r" ] } }

def writeU64Func : Func :=
  { name := writeU64Name,
    params := #[{ name := "kp", type := .i32 }, { name := "kl", type := .i32 }, { name := "v", type := .i64 }],
    results := #[],
    body := { insns := #[
      .i32Const KEY_BUF, .localGet "v", .store "i64.store" 0,
      .localGet "kl", .plain "i64.extend_i32_u",
      .localGet "kp", .plain "i64.extend_i32_u",
      .i64Const 8, .i64Const KEY_BUF, .i64Const 0, .call "storage_write", .drop ] } }

/-- `__pf_return_u64(v)`: format v as decimal ASCII at RET_BUF and value_return it. -/
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
            .i32Const 48, .localGet "d", .plain "i32.add", .store "i32.store8" 0,
            .br 0 ] } ] } ] },
      .i32Const (RET_BUF + 20), .localGet "p", .plain "i32.sub", .plain "i64.extend_i32_u",
      .localGet "p", .plain "i64.extend_i32_u",
      .call "value_return" ] } }

def helperFuncs : Array Func := #[readU64Func, writeU64Func, returnU64Func]

-- ---------------------------------------------------------------------------
-- State layout: assign each scalar state a storage-key data segment
-- ---------------------------------------------------------------------------

structure StateInfo where
  id     : String
  keyPtr : Nat
  keyLen : Nat

/-- Lay out scalar-state key strings back-to-back from offset 0. -/
def stateLayout (module_ : ProofForge.IR.Module) : Array StateInfo :=
  let go (acc : Array StateInfo) (offset : Nat) (s : StateDecl) : Array StateInfo × Nat :=
    match s.kind with
    | .scalar =>
        let len := s.id.length
        (acc.push { id := s.id, keyPtr := offset, keyLen := len }, offset + len + 1)
    | _ => (acc, offset)
  let result := module_.state.foldl (fun acc s =>
    let (acc', off') := go acc.fst acc.snd s
    (acc', off')) (#[], 0)
  result.fst

def findState? (layout : Array StateInfo) (id : String) : Option StateInfo :=
  layout.find? (fun s => s.id == id)

-- ---------------------------------------------------------------------------
-- Lowering (v0: U64 subset)
-- ---------------------------------------------------------------------------

/-- Lower a U64 expression to instructions leaving an i64 on the stack. -/
partial def lowerU64Expr (layout : Array StateInfo) (e : Expr) : Except EmitError (Array Insn) :=
  match e with
  | .literal (.u64 n) => .ok #[ .i64Const n ]
  | .local name => .ok #[ .localGet name ]
  | .add a b => binop "i64.add" a b
  | .sub a b => binop "i64.sub" a b
  | .mul a b => binop "i64.mul" a b
  | .div a b => binop "i64.div_u" a b
  | .mod a b => binop "i64.rem_u" a b
  | .effect (.storageScalarRead id) =>
    match findState? layout id with
    | some s => .ok #[ .i32Const s.keyPtr, .i32Const s.keyLen, .call readU64Name ]
    | none => err s!"EmitWat v0: unknown scalar state `{id}`"
  | _ => err "EmitWat v0: only U64 literal/local/arithmetic/scalar-read expressions are supported"
where
  binop (op : String) (a b : Expr) : Except EmitError (Array Insn) := do
    let l ← lowerU64Expr layout a
    let r ← lowerU64Expr layout b
    .ok (l ++ r ++ #[.plain op])

/-- Collect U64 locals declared by `letBind` statements. -/
def collectLocals (body : Array Statement) : Except EmitError (Array Local) :=
  body.foldlM (init := #[]) fun acc s =>
    match s with
    | .letBind name .u64 _ => .ok (acc.push { name := name, type := .i64 })
    | .letBind _ t _ => err s!"EmitWat v0: only U64 locals are supported (got `{t.name}`)"
    | _ => .ok acc

/-- Lower a single statement. -/
partial def lowerStmt (layout : Array StateInfo) (returns : ValueType) (s : Statement)
    : Except EmitError (Array Insn) :=
  match s with
  | .effect (.storageScalarWrite id e) =>
    match findState? layout id with
    | some s => do
      let v ← lowerU64Expr layout e
      .ok (#[.i32Const s.keyPtr, .i32Const s.keyLen] ++ v ++ #[.call writeU64Name])
    | none => err s!"EmitWat v0: unknown scalar state `{id}`"
  | .return e =>
    if returns == .u64 then do
      let v ← lowerU64Expr layout e
      .ok (v ++ #[.call returnU64Name])
    else err "EmitWat v0: only U64 returns are supported"
  | _ => err "EmitWat v0: only letBind/scalar-write/return statements are supported"

/-- Lower an entrypoint to a `() -> ()` exported dispatcher. -/
def lowerEntrypoint (layout : Array StateInfo) (ep : Entrypoint) : Except EmitError Func := do
  let locals ← collectLocals ep.body
  -- lower statements; for letBind we need the local.set after the expression
  let insns ← ep.body.foldlM (init := #[]) fun acc s =>
    match s with
    | .letBind name _ e => do
      let is ← lowerU64Expr layout e
      .ok (acc ++ is ++ #[.localSet name])
    | _ => do
      let is ← lowerStmt layout ep.returns s
      .ok (acc ++ is)
  .ok { name := ep.name, locals := locals, body := { insns := insns }, exportName := ep.name }

/-- Lower a portable IR module to a Wasm module. -/
def lowerModule (module_ : ProofForge.IR.Module) : Except EmitError ProofForge.Compiler.Wasm.Module := do
  let layout := stateLayout module_
  let entryFuncs ← module_.entrypoints.mapM (lowerEntrypoint layout)
  let dataSegments := layout.map fun s => { offset := s.keyPtr, bytes := s.id : DataSegment }
  .ok {
    imports := nearImports,
    funcs := helperFuncs ++ entryFuncs,
    memory := some { min := 1 },
    dataSegments := dataSegments
  }

/-- Lower and render to WAT text in one step. -/
def renderModule (module_ : ProofForge.IR.Module) : Except EmitError String :=
  match lowerModule module_ with
  | .ok m => .ok (Printer.render m)
  | .error e => .error e

end ProofForge.Backend.WasmNear.EmitWat
