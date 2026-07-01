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
def MAPKEY_BUF : Nat := 12500    -- scratch for building map storage keys (prefix ++ key bytes)
def HASH_HEAP : Nat := 30000       -- bump-allocator base for hash (32-byte) temporaries
def HASH_CONCAT_BUF : Nat := 40000 -- 64-byte scratch for hash_two_to_one
def CTX_BUF : Nat := 41000          -- 128-byte scratch for account-id → sha256 → u64
def EVENT_BUF : Nat := 42000       -- 256-byte scratch for building event JSON
def EVT_KEY_PTR : Nat := 42800     -- fixed "event" key string (5 bytes)
def STRING_BASE : Nat := 43000     -- event/field name string pool base
def INPUT_BUF : Nat := 44000       -- 1 KB scratch for Borsh input args

-- Value type → Wasm
def wasmTypeOf : ValueType → ValType
  | .u32 => .i32 | .u64 => .i64 | .bool => .i32 | .hash => .i32 | _ => .i32
def widthOf : ValueType → String
  | .u32 => "i32" | .u64 => "i64" | .bool => "i32" | .hash => "i32" | _ => "i32"
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

def returnU32Name  : String := "__pf_return_u32"

def returnU64Func : Func :=
  { name := returnU64Name, params := #[{ name := "v", type := .i64 }],
    body := { insns := #[
      .i32Const RET_BUF, .localGet "v", .store "i64.store" 0,
      .i64Const 8, .i64Const RET_BUF, .call "value_return" ] } }

def returnU32Func : Func :=
  { name := returnU32Name, params := #[{ name := "v", type := .i32 }],
    body := { insns := #[
      .i32Const RET_BUF, .localGet "v", .store "i32.store" 0,
      .i64Const 4, .i64Const RET_BUF, .call "value_return" ] } }

def returnBoolFunc : Func :=
  { name := returnBoolName, params := #[{ name := "v", type := .i32 }],
    body := { insns := #[
      .i32Const RET_BUF, .localGet "v", .store "i32.store8" 0,
      .i64Const 1, .i64Const RET_BUF, .call "value_return" ] } }

def helperFuncs : Array Func :=
  #[ readFunc .u32, writeFunc .u32, readFunc .u64, writeFunc .u64,
     readFunc .bool, writeFunc .bool, returnU64Func, returnU32Func, returnBoolFunc ]

-- Map helpers ----------------------------------------------------------
-- Map<U64, T>: storage key = prefix(stateId ++ ":") ++ 8 key bytes.

def mapReadName  (vt : ValueType) : String := "__pf_map_read_"  ++ typeSuffix vt
def mapWriteName (vt : ValueType) : String := "__pf_map_write_" ++ typeSuffix vt
def mapContainsName : String := "__pf_map_contains"
def mapBuildkeyName  : String := "__pf_map_buildkey"

/-- `__pf_map_buildkey(pp, pl, k)`: write prefix[pp..pp+pl] then 8 key bytes to MAPKEY_BUF. -/
def mapBuildkeyFunc : Func :=
  { name := mapBuildkeyName,
    params := #[{ name := "pp", type := .i32 }, { name := "pl", type := .i32 }, { name := "k", type := .i64 }],
    locals := #[{ name := "i", type := .i32 }],
    body := { insns := #[
      .i32Const 0, .localSet "i",
      .block_ { insns := #[ .loop_ { insns := #[
        .localGet "i", .localGet "pl", .plain "i32.ge_u", .brIf 1,
        .localGet "i", .i32Const MAPKEY_BUF, .plain "i32.add",
        .localGet "i", .localGet "pp", .plain "i32.add", .load "i32.load8_u" 0,
        .store "i32.store8" 0,
        .localGet "i", .i32Const 1, .plain "i32.add", .localSet "i", .br 0 ] } ] } ,
      .i32Const MAPKEY_BUF, .localGet "pl", .plain "i32.add", .localGet "k", .store "i64.store" 0 ] } }

def mapReadFunc (vt : ValueType) : Func :=
  { name := mapReadName vt,
    params := #[{ name := "pp", type := .i32 }, { name := "pl", type := .i32 }, { name := "k", type := .i64 }],
    results := #[wasmTypeOf vt],
    locals := #[{ name := "found", type := .i64 }, { name := "r", type := wasmTypeOf vt }],
    body := { insns := #[
      .const (wasmTypeOf vt) "0", .localSet "r",
      .localGet "pp", .localGet "pl", .localGet "k", .call mapBuildkeyName,
      .localGet "pl", .i32Const 8, .plain "i32.add", .plain "i64.extend_i32_u",
      .i64Const MAPKEY_BUF, .i64Const 0, .call "storage_read", .localSet "found",
      .localGet "found", .i64Const 0, .plain "i64.ne",
      .if_ { insns := #[ .i64Const 0, .i64Const KEY_BUF, .call "read_register",
                        .i32Const KEY_BUF, .load (loadOpFor vt) 0, .localSet "r" ] } { insns := #[] },
      .localGet "r" ] } }

def mapWriteFunc (vt : ValueType) : Func :=
  { name := mapWriteName vt,
    params := #[{ name := "pp", type := .i32 }, { name := "pl", type := .i32 },
                { name := "k", type := .i64 }, { name := "v", type := wasmTypeOf vt }],
    body := { insns := #[
      .localGet "pp", .localGet "pl", .localGet "k", .call mapBuildkeyName,
      .i32Const KEY_BUF, .localGet "v", .store (storeOpFor vt) 0,
      .localGet "pl", .i32Const 8, .plain "i32.add", .plain "i64.extend_i32_u",
      .i64Const MAPKEY_BUF, .i64Const (scalarWidth vt), .i64Const KEY_BUF, .i64Const 0,
      .call "storage_write", .drop ] } }

def mapContainsFunc : Func :=
  { name := mapContainsName,
    params := #[{ name := "pp", type := .i32 }, { name := "pl", type := .i32 }, { name := "k", type := .i64 }],
    results := #[.i64],
    body := { insns := #[
      .localGet "pp", .localGet "pl", .localGet "k", .call mapBuildkeyName,
      .localGet "pl", .i32Const 8, .plain "i32.add", .plain "i64.extend_i32_u",
      .i64Const MAPKEY_BUF, .call "storage_has_key" ] } }

/-- storage_has_key import (added only when a map is present; see lowerModule). -/
def storageHasKeyImport : Import :=
  hostImport "storage_has_key" #[.i64, .i64] #[.i64]

def mapHelperFuncs : Array Func :=
  #[ mapBuildkeyFunc, mapReadFunc .u32, mapWriteFunc .u32, mapReadFunc .u64, mapWriteFunc .u64,
     mapReadFunc .bool, mapWriteFunc .bool, mapContainsFunc ]

-- Hash helpers ---------------------------------------------------------
-- Hash = 32-byte memory region (4×u64), referenced by an i32 pointer. A
-- mutable global `hash_ptr` bump-allocates a fresh 32-byte slot per temp
-- (reset each NEAR call since the instance is fresh).

def hashAllocName    : String := "__pf_hash_alloc"
def hashMakeName      : String := "__pf_hash_make"
def hashSName         : String := "__pf_hash"
def memcpyName        : String := "__pf_memcpy"
def hashTwoName       : String := "__pf_hash_two_to_one"
def hashEqName        : String := "__pf_hash_eq"
def readHashName      : String := "__pf_read_hash"
def writeHashName     : String := "__pf_write_hash"
def hashPtrGlobal     : String := "hash_ptr"

def sha256Import : Import := hostImport "sha256" #[.i64, .i64, .i64] #[]
def logUtf8Import : Import := hostImport "log_utf8" #[.i64, .i64] #[]
def inputImport : Import := hostImport "input" #[.i64] #[]
def predecessorImport : Import := hostImport "predecessor_account_id" #[.i64] #[]
def currentAcctImport : Import := hostImport "current_account_id" #[.i64] #[]
def registerLenImport : Import := hostImport "register_len" #[.i64] #[.i64]
def blockHeightImport : Import := hostImport "block_index" #[] #[.i64]
def ctxUserIdName : String := "__pf_ctx_user_id"
def ctxContractIdName : String := "__pf_ctx_contract_id"

def hashPtrGlobalDecl : Global :=
  { name := hashPtrGlobal, type := .i32, init := toString HASH_HEAP, isMutable := true }

def hashAllocFunc : Func :=
  { name := hashAllocName, results := #[.i32],
    body := { insns := #[ .globalGet hashPtrGlobal,
      .globalGet hashPtrGlobal, .i32Const 32, .plain "i32.add", .globalSet hashPtrGlobal ] } }

def hashMakeFunc : Func :=
  { name := hashMakeName,
    params := #[{ name := "a", type := .i64 }, { name := "b", type := .i64 },
                { name := "c", type := .i64 }, { name := "d", type := .i64 }],
    results := #[.i32], locals := #[{ name := "p", type := .i32 }],
    body := { insns := #[
      .call hashAllocName, .localSet "p",
      .localGet "p", .localGet "a", .store "i64.store" 0,
      .localGet "p", .localGet "b", .store "i64.store" 8,
      .localGet "p", .localGet "c", .store "i64.store" 16,
      .localGet "p", .localGet "d", .store "i64.store" 24,
      .localGet "p" ] } }

def hashSFunc : Func :=
  { name := hashSName, params := #[{ name := "preimage", type := .i32 }], results := #[.i32],
    locals := #[{ name := "p", type := .i32 }],
    body := { insns := #[
      .i64Const 32, .localGet "preimage", .plain "i64.extend_i32_u", .i64Const 0, .call "sha256",
      .call hashAllocName, .localSet "p",
      .i64Const 0, .localGet "p", .plain "i64.extend_i32_u", .call "read_register",
      .localGet "p" ] } }

def memcpyFunc : Func :=
  { name := memcpyName,
    params := #[{ name := "dst", type := .i32 }, { name := "src", type := .i32 }, { name := "n", type := .i32 }],
    locals := #[{ name := "i", type := .i32 }],
    body := { insns := #[
      .i32Const 0, .localSet "i",
      .block_ { insns := #[ .loop_ { insns := #[
        .localGet "i", .localGet "n", .plain "i32.ge_u", .brIf 1,
        .localGet "i", .localGet "dst", .plain "i32.add",
        .localGet "i", .localGet "src", .plain "i32.add", .load "i32.load8_u" 0,
        .store "i32.store8" 0,
        .localGet "i", .i32Const 1, .plain "i32.add", .localSet "i", .br 0 ] } ] } ] } }

def hashTwoFunc : Func :=
  { name := hashTwoName,
    params := #[{ name := "l", type := .i32 }, { name := "r", type := .i32 }], results := #[.i32],
    locals := #[{ name := "p", type := .i32 }],
    body := { insns := #[
      .i32Const HASH_CONCAT_BUF, .localGet "l", .i32Const 32, .call memcpyName,
      .i32Const (HASH_CONCAT_BUF + 32), .localGet "r", .i32Const 32, .call memcpyName,
      .i64Const 64, .i64Const HASH_CONCAT_BUF, .i64Const 0, .call "sha256",
      .call hashAllocName, .localSet "p",
      .i64Const 0, .localGet "p", .plain "i64.extend_i32_u", .call "read_register",
      .localGet "p" ] } }

def hashEqFunc : Func :=
  { name := hashEqName,
    params := #[{ name := "a", type := .i32 }, { name := "b", type := .i32 }], results := #[.i32],
    body := { insns := #[
      .localGet "a", .load "i64.load" 0, .localGet "b", .load "i64.load" 0, .plain "i64.eq",
      .localGet "a", .load "i64.load" 8, .localGet "b", .load "i64.load" 8, .plain "i64.eq", .plain "i32.and",
      .localGet "a", .load "i64.load" 16, .localGet "b", .load "i64.load" 16, .plain "i64.eq", .plain "i32.and",
      .localGet "a", .load "i64.load" 24, .localGet "b", .load "i64.load" 24, .plain "i64.eq", .plain "i32.and" ] } }

def readHashFunc : Func :=
  { name := readHashName,
    params := #[{ name := "kp", type := .i32 }, { name := "kl", type := .i32 }], results := #[.i32],
    locals := #[{ name := "found", type := .i64 }, { name := "p", type := .i32 }],
    body := { insns := #[
      .call hashAllocName, .localSet "p",
      .localGet "kl", .plain "i64.extend_i32_u", .localGet "kp", .plain "i64.extend_i32_u",
      .i64Const 0, .call "storage_read", .localSet "found",
      .localGet "found", .i64Const 0, .plain "i64.ne",
      .if_ { insns := #[ .i64Const 0, .localGet "p", .plain "i64.extend_i32_u", .call "read_register" ] } { insns := #[] },
      .localGet "p" ] } }

def writeHashFunc : Func :=
  { name := writeHashName,
    params := #[{ name := "kp", type := .i32 }, { name := "kl", type := .i32 }, { name := "v", type := .i32 }],
    body := { insns := #[
      .localGet "kl", .plain "i64.extend_i32_u", .localGet "kp", .plain "i64.extend_i32_u",
      .i64Const 32, .localGet "v", .plain "i64.extend_i32_u", .i64Const 0, .call "storage_write", .drop ] } }

def hashHelperFuncs : Array Func :=
  #[ hashAllocFunc, hashMakeFunc, hashSFunc, memcpyFunc, hashTwoFunc, hashEqFunc,
     readHashFunc, writeHashFunc ]

-- Context helpers ------------------------------------------------------
-- userId/contractId: sha256(account_id_bytes)[0..8] as u64.

def ctxUserIdFunc : Func :=
  { name := ctxUserIdName, results := #[.i64], locals := #[{ name := "len", type := .i64 }],
    body := { insns := #[
      .i64Const 0, .call "predecessor_account_id",
      .i64Const 0, .call "register_len", .localSet "len",
      .i64Const 0, .i64Const CTX_BUF, .call "read_register",
      .localGet "len", .i64Const CTX_BUF, .i64Const 1, .call "sha256",
      .i64Const 1, .i64Const CTX_BUF, .call "read_register",
      .i32Const CTX_BUF, .load "i64.load" 0 ] } }

def ctxContractIdFunc : Func :=
  { name := ctxContractIdName, results := #[.i64], locals := #[{ name := "len", type := .i64 }],
    body := { insns := #[
      .i64Const 0, .call "current_account_id",
      .i64Const 0, .call "register_len", .localSet "len",
      .i64Const 0, .i64Const CTX_BUF, .call "read_register",
      .localGet "len", .i64Const CTX_BUF, .i64Const 1, .call "sha256",
      .i64Const 1, .i64Const CTX_BUF, .call "read_register",
      .i32Const CTX_BUF, .load "i64.load" 0 ] } }

def ctxHelperFuncs : Array Func := #[ ctxUserIdFunc, ctxContractIdFunc ]
def ctxImports : Array Import := #[ predecessorImport, currentAcctImport, registerLenImport, blockHeightImport ]

-- Event helpers --------------------------------------------------------
-- Build a JSON event string in EVENT_BUF via an append pointer, then log_utf8.

def fmtU64Name    : String := "__pf_fmt_u64"
def evtPtrGlobal   : String := "evt_ptr"
def evtStartName   : String := "__pf_evt_start"
def evtPutcName    : String := "__pf_evt_putc"
def evtPutstrName  : String := "__pf_evt_putstr"
def evtPutu64Name  : String := "__pf_evt_putu64"
def evtPutboolName : String := "__pf_evt_putbool"
def evtLogName     : String := "__pf_evt_log"

def evtPtrGlobalDecl : Global :=
  { name := evtPtrGlobal, type := .i32, init := toString EVENT_BUF, isMutable := true }

def fmtU64Func : Func :=
  { name := fmtU64Name, params := #[{ name := "v", type := .i64 }], results := #[.i32],
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
      .localGet "p" ] } }

def evtStartFunc : Func :=
  { name := evtStartName, body := { insns := #[ .i32Const EVENT_BUF, .globalSet evtPtrGlobal ] } }

def evtPutcFunc : Func :=
  { name := evtPutcName, params := #[{ name := "c", type := .i32 }],
    body := { insns := #[
      .globalGet evtPtrGlobal, .localGet "c", .store "i32.store8" 0,
      .globalGet evtPtrGlobal, .i32Const 1, .plain "i32.add", .globalSet evtPtrGlobal ] } }

def evtPutstrFunc : Func :=
  { name := evtPutstrName, params := #[{ name := "ptr", type := .i32 }, { name := "len", type := .i32 }],
    body := { insns := #[
      .globalGet evtPtrGlobal, .localGet "ptr", .localGet "len", .call memcpyName,
      .globalGet evtPtrGlobal, .localGet "len", .plain "i32.add", .globalSet evtPtrGlobal ] } }

def evtPutu64Func : Func :=
  { name := evtPutu64Name, params := #[{ name := "v", type := .i64 }],
    locals := #[{ name := "p", type := .i32 }, { name := "len", type := .i32 }],
    body := { insns := #[
      .localGet "v", .call fmtU64Name, .localSet "p",
      .i32Const (RET_BUF + 20), .localGet "p", .plain "i32.sub", .localSet "len",
      .globalGet evtPtrGlobal, .localGet "p", .localGet "len", .call memcpyName,
      .globalGet evtPtrGlobal, .localGet "len", .plain "i32.add", .globalSet evtPtrGlobal ] } }

def evtPutboolFunc : Func :=
  { name := evtPutboolName, params := #[{ name := "b", type := .i32 }],
    body := { insns := #[
      .localGet "b", .plain "i32.eqz",
      .if_ { insns := #[ .i32Const FALSE_PTR, .i32Const 5, .call evtPutstrName ] }
         { insns := #[ .i32Const TRUE_PTR, .i32Const 4, .call evtPutstrName ] } ] } }

def evtLogFunc : Func :=
  { name := evtLogName,
    body := { insns := #[
      .globalGet evtPtrGlobal, .i32Const EVENT_BUF, .plain "i32.sub", .plain "i64.extend_i32_u",
      .i64Const EVENT_BUF, .call "log_utf8" ] } }

def evtHelperFuncs : Array Func :=
  #[ fmtU64Func, evtStartFunc, evtPutcFunc, evtPutstrFunc, evtPutu64Func, evtPutboolFunc, evtLogFunc ]
def evtGlobals : Array Global := #[ evtPtrGlobalDecl ]

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

structure MapInfo where
  id        : String
  keyType   : ValueType
  valueType : ValueType
  prefixPtr : Nat
  prefixLen : Nat

/-- Map state → prefix data segment `id ++ ":"` laid out back-to-back from a high offset. -/
def mapLayout (mod : ProofForge.IR.Module) : Array MapInfo :=
  let step (acc : Array MapInfo) (offset : Nat) (s : StateDecl) : Array MapInfo × Nat :=
    match s.kind with
    | .map kt _ => (acc.push { id := s.id, keyType := kt, valueType := s.type, prefixPtr := offset, prefixLen := s.id.length + 1 }, offset + s.id.length + 2)
    | _ => (acc, offset)
  let result : Array MapInfo × Nat := mod.state.foldl (init := (#[], 20000)) fun (acc, offset) s => step acc offset s
  result.fst

def findMapState? (layout : Array MapInfo) (id : String) : Option MapInfo :=
  layout.find? (fun m => m.id == id)

structure StringInfo where
  str : String
  ptr : Nat
  len : Nat

/-- Collect event-name + field-name strings into a deduped pool at STRING_BASE. -/
def stringPool (mod : ProofForge.IR.Module) : Array StringInfo :=
  let raw : Array String := mod.entrypoints.foldl (init := #[]) fun acc ep =>
    ep.body.foldl (init := acc) fun acc' s =>
      match s with
      | .effect (.eventEmit name fields) => acc' ++ #[name] ++ fields.map (fun (n, _) => n)
      | _ => acc'
  let unique : Array String := raw.foldl (init := #[]) fun acc s => if acc.contains s then acc else acc.push s
  let result : Array StringInfo × Nat :=
    unique.foldl (init := (#[], STRING_BASE)) fun (acc, offset) s =>
      (acc.push { str := s, ptr := offset, len := s.length }, offset + s.length + 1)
  result.fst

def findString? (pool : Array StringInfo) (s : String) : Option StringInfo :=
  pool.find? (fun si => si.str == s)

-- Type-directed expression lowering (mutually recursive)
structure Ctx where
  scalars : Array StateInfo
  maps    : Array MapInfo
  strings : Array StringInfo

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
  partial def lowerExpr (ctx : Ctx) (env : LocalTypes) (e : Expr)
      : Except EmitError (Array Insn × ValueType) :=
    match e with
    | .literal (.u32 n) => .ok (#[.const .i32 (toString n)], .u32)
    | .literal (.u64 n) => .ok (#[.const .i64 (toString n)], .u64)
    | .literal (.bool b) => .ok (#[.const .i32 (if b then "1" else "0")], .bool)
    | .literal (.hash4 a b c d) => .ok (#[.i64Const a, .i64Const b, .i64Const c, .i64Const d, .call hashMakeName], .hash)
    | .hashValue a b c d => do
      let (ia, ta) ← lowerExpr ctx env a
      let (ib, tb) ← lowerExpr ctx env b
      let (ic, tc) ← lowerExpr ctx env c
      let (id_, td) ← lowerExpr ctx env d
      if !(ta == .u64 && tb == .u64 && tc == .u64 && td == .u64) then err "EmitWat: hashValue expects four U64 limbs"
      else .ok (ia ++ ib ++ ic ++ id_ ++ #[.call hashMakeName], .hash)
    | .hash preimage => do
      let (is, t) ← lowerExpr ctx env preimage
      if t != .hash then err s!"EmitWat: hash preimage expected Hash, got `{t.name}`"
      else .ok (is ++ #[.call hashSName], .hash)
    | .hashTwoToOne l r => do
      let (la, ta) ← lowerExpr ctx env l
      let (lb, tb) ← lowerExpr ctx env r
      if !(ta == .hash && tb == .hash) then err "EmitWat: hash_two_to_one expects two Hash operands"
      else .ok (la ++ lb ++ #[.call hashTwoName], .hash)
    | .local name =>
      match lookupLocal? env name with
      | some t => .ok (#[.localGet name], t)
      | none => err s!"EmitWat: unknown local `{name}`"
    | .add a b => lowerNumBin ctx env "add" a b
    | .sub a b => lowerNumBin ctx env "sub" a b
    | .mul a b => lowerNumBin ctx env "mul" a b
    | .div a b => lowerNumBin ctx env "div_u" a b
    | .mod a b => lowerNumBin ctx env "rem_u" a b
    | .bitAnd a b => lowerNumBin ctx env "and" a b
    | .bitOr a b => lowerNumBin ctx env "or" a b
    | .bitXor a b => lowerNumBin ctx env "xor" a b
    | .shiftLeft a b => lowerNumBin ctx env "shl" a b
    | .shiftRight a b => lowerNumBin ctx env "shr_u" a b
    | .pow _ _ => err "EmitWat: pow is not yet supported"
    | .eq a b => lowerCmp ctx env "eq" a b
    | .ne a b => lowerCmp ctx env "ne" a b
    | .lt a b => lowerCmp ctx env "lt_u" a b
    | .le a b => lowerCmp ctx env "le_u" a b
    | .gt a b => lowerCmp ctx env "gt_u" a b
    | .ge a b => lowerCmp ctx env "ge_u" a b
    | .boolAnd a b => lowerBoolBin ctx env "and" a b
    | .boolOr a b => lowerBoolBin ctx env "or" a b
    | .boolNot a => do
      let (is, t) ← lowerExpr ctx env a
      if t != .bool then err s!"EmitWat: boolean not operand expected Bool, got `{t.name}`"
      else .ok (is ++ #[.plain "i32.eqz"], .bool)
    | .cast value target => lowerCast ctx env value target
    | .effect (.storageScalarRead id) =>
      match findScalarState? ctx.scalars id with
      | some s =>
        let callName := if s.type == .hash then readHashName else readName s.type
        .ok (#[.i32Const s.keyPtr, .i32Const s.keyLen, .call callName], s.type)
      | none => err s!"EmitWat: unknown scalar state `{id}`"
    | .effect (.storageMapGet id key) => lowerMapGet ctx env id key
    | .effect (.storageMapContains id key) => lowerMapContains ctx env id key
    | .effect (.contextRead .userId) => .ok (#[.call ctxUserIdName], .u64)
    | .effect (.contextRead .contractId) => .ok (#[.call ctxContractIdName], .u64)
    | .effect (.contextRead .checkpointId) => .ok (#[.call "block_index"], .u64)
    | _ => err "EmitWat: this expression form is not yet supported"

  partial def lowerNumBin (ctx : Ctx) (env : LocalTypes) (op : String) (a b : Expr)
      : Except EmitError (Array Insn × ValueType) := do
    let (la, ta) ← lowerExpr ctx env a
    let (lb, tb) ← lowerExpr ctx env b
    if !(isNumeric ta && ta == tb) then
      err s!"EmitWat: `{op}` expected matching U32/U64 operands, got `{ta.name}`/`{tb.name}`"
    else .ok (la ++ lb ++ #[.plain (widthOf ta ++ "." ++ op)], ta)

  partial def lowerCmp (ctx : Ctx) (env : LocalTypes) (op : String) (a b : Expr)
      : Except EmitError (Array Insn × ValueType) := do
    let (la, ta) ← lowerExpr ctx env a
    let (lb, tb) ← lowerExpr ctx env b
    if ta != tb then err s!"EmitWat: `{op}` expected matching operand types, got `{ta.name}`/`{tb.name}`"
    else if ta == .hash && op == "eq" then .ok (la ++ lb ++ #[.call hashEqName], .bool)
    else if ta == .hash && op == "ne" then .ok (la ++ lb ++ #[.call hashEqName, .plain "i32.eqz"], .bool)
    else .ok (la ++ lb ++ #[.plain (widthOf ta ++ "." ++ op)], .bool)

  partial def lowerBoolBin (ctx : Ctx) (env : LocalTypes) (op : String) (a b : Expr)
      : Except EmitError (Array Insn × ValueType) := do
    let (la, ta) ← lowerExpr ctx env a
    let (lb, tb) ← lowerExpr ctx env b
    if !(ta == .bool && tb == .bool) then err s!"EmitWat: boolean `{op}` expected Bool operands"
    else .ok (la ++ lb ++ #[.plain ("i32." ++ op)], .bool)

  partial def lowerCast (ctx : Ctx) (env : LocalTypes) (value : Expr) (target : ValueType)
      : Except EmitError (Array Insn × ValueType) := do
    let (is, src) ← lowerExpr ctx env value
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

  partial def lowerMapKeyU64 (ctx : Ctx) (env : LocalTypes) (key : Expr)
      : Except EmitError (Array Insn) := do
    let (is, t) ← lowerExpr ctx env key
    if t != .u64 then err s!"EmitWat: map key expected U64, got `{t.name}`"
    else .ok is

  partial def lowerMapGet (ctx : Ctx) (env : LocalTypes) (id : String) (key : Expr)
      : Except EmitError (Array Insn × ValueType) := do
    match findMapState? ctx.maps id with
    | none => err s!"EmitWat: unknown map state `{id}`"
    | some m =>
      if m.keyType != .u64 then err s!"EmitWat: only Map<U64, T> is supported (`{id}` has key `{m.keyType.name}`)"
      else do
        let kis ← lowerMapKeyU64 ctx env key
        .ok (#[.i32Const m.prefixPtr, .i32Const m.prefixLen] ++ kis ++ #[.call (mapReadName m.valueType)], m.valueType)

  partial def lowerMapContains (ctx : Ctx) (env : LocalTypes) (id : String) (key : Expr)
      : Except EmitError (Array Insn × ValueType) := do
    match findMapState? ctx.maps id with
    | none => err s!"EmitWat: unknown map state `{id}`"
    | some m =>
      if m.keyType != .u64 then err s!"EmitWat: only Map<U64, T> is supported"
      else do
        let kis ← lowerMapKeyU64 ctx env key
        .ok (#[.i32Const m.prefixPtr, .i32Const m.prefixLen] ++ kis ++ #[.call mapContainsName, .plain "i32.wrap_i64"], .bool)
end

-- Statements
def collectLocals (body : Array Statement) : Except EmitError LocalTypes :=
  body.foldlM (init := #[]) fun acc s =>
    match s with
    | .letBind name t _ | .letMutBind name t _ =>
      if isNumeric t || t == .bool || t == .hash then .ok (acc.push { name := name, vt := t })
      else err s!"EmitWat: only U32/U64/Bool locals are supported (got `{t.name}`)"
    | _ => .ok acc

def lowerReturn (ctx : Ctx) (env : LocalTypes) (expected : ValueType) (e : Expr)
    : Except EmitError (Array Insn) := do
  let (is, t) ← lowerExpr ctx env e
  if t != expected then err s!"EmitWat: return expected `{expected.name}`, got `{t.name}`"
  else match t with
    | .u64 => .ok (is ++ #[.call returnU64Name])
    | .u32 => .ok (is ++ #[.call returnU32Name])
    | .bool => .ok (is ++ #[.call returnBoolName])
    | .hash => .ok (#[.i64Const 32] ++ is ++ #[.plain "i64.extend_i32_u", .call "value_return"])
    | _ => err s!"EmitWat: return type `{t.name}` is not supported"

partial def lowerEventEmit (ctx : Ctx) (env : LocalTypes) (name : String) (fields : Array (String × Expr))
    : Except EmitError (Array Insn) := do
  let some nameSi ← pure (findString? ctx.strings name) | err s!"EmitWat: event name `{name}` not in string pool"
  let putc (c : Nat) : Array Insn := #[.i32Const c, .call evtPutcName]
  let header : Array Insn := #[.call evtStartName] ++ putc 0x7B ++ putc 0x22
    ++ #[.i32Const EVT_KEY_PTR, .i32Const 5, .call evtPutstrName] ++ putc 0x22 ++ putc 0x3A ++ putc 0x22
    ++ #[.i32Const nameSi.ptr, .i32Const nameSi.len, .call evtPutstrName] ++ putc 0x22
  let fieldInsns ← fields.foldlM (init := #[]) fun acc f => do
    let (fname, vexpr) := f
    let some fsi ← pure (findString? ctx.strings fname) | err s!"EmitWat: field name `{fname}` not in string pool"
    let (vis, vt) ← lowerExpr ctx env vexpr
    let valInsn ←
      match vt with
      | .u64 => .ok #[.call evtPutu64Name]
      | .u32 => .ok #[.plain "i64.extend_i32_u", .call evtPutu64Name]
      | .bool => .ok #[.call evtPutboolName]
      | _ => err s!"EmitWat: event field `{fname}` has unsupported type `{vt.name}`"
    .ok (acc ++ putc 0x2C ++ putc 0x22 ++ #[.i32Const fsi.ptr, .i32Const fsi.len, .call evtPutstrName]
            ++ putc 0x22 ++ putc 0x3A ++ vis ++ valInsn)
  .ok (header ++ fieldInsns ++ putc 0x7D ++ #[.call evtLogName])

partial def lowerMapWrite (ctx : Ctx) (env : LocalTypes) (id : String) (key value : Expr)
    : Except EmitError (Array Insn) := do
  match findMapState? ctx.maps id with
  | none => err s!"EmitWat: unknown map state `{id}`"
  | some m =>
    if m.keyType != .u64 then err s!"EmitWat: only Map<U64, T> is supported"
    else do
      let kis ← lowerMapKeyU64 ctx env key
      let (vis, vt) ← lowerExpr ctx env value
      if vt != m.valueType then err s!"EmitWat: map write `{id}` expected `{m.valueType.name}`, got `{vt.name}`"
      else .ok (#[.i32Const m.prefixPtr, .i32Const m.prefixLen] ++ kis ++ vis ++ #[.call (mapWriteName m.valueType)])

partial def lowerStmt (ctx : Ctx) (env : LocalTypes) (returns : ValueType)
    (s : Statement) : Except EmitError (Array Insn) :=
  match s with
  | .letBind name t e | .letMutBind name t e => do
    let (is, te) ← lowerExpr ctx env e
    if te != t then err s!"EmitWat: let `{name}` expected `{t.name}`, got `{te.name}`"
    else .ok (is ++ #[.localSet name])
  | .assign (.local name) e => do
    let (is, _) ← lowerExpr ctx env e
    if (lookupLocal? env name).isNone then err s!"EmitWat: assignment to unknown local `{name}`"
    else .ok (is ++ #[.localSet name])
  | .assign _ _ => err "EmitWat: assignment target must be a local"
  | .assignOp (.local name) op e => do
    let some lt ← pure (lookupLocal? env name) | err s!"EmitWat: compound assignment to unknown local `{name}`"
    if !(isNumeric lt) then err "EmitWat: compound assignment requires U32/U64 local"
    else do
      let (is, t) ← lowerExpr ctx env e
      if t != lt then err s!"EmitWat: compound `{assignOpName op}` expected `{lt.name}`, got `{t.name}`"
      else .ok (#[.localGet name] ++ is ++ #[.plain (widthOf lt ++ "." ++ assignOpName op), .localSet name])
  | .assignOp _ _ _ => err "EmitWat: compound assignment target must be a local"
  | .effect (.storageScalarWrite id e) => do
    let some s ← pure (findScalarState? ctx.scalars id) | err s!"EmitWat: unknown scalar state `{id}`"
    let (is, t) ← lowerExpr ctx env e
    if t != s.type then err s!"EmitWat: scalar write `{id}` expected `{s.type.name}`, got `{t.name}`"
    else
      let callName := if s.type == .hash then writeHashName else writeName s.type
      .ok (#[.i32Const s.keyPtr, .i32Const s.keyLen] ++ is ++ #[.call callName])
  | .effect (.storageMapSet id key value) | .effect (.storageMapInsert id key value) =>
    lowerMapWrite ctx env id key value
  | .effect (.eventEmit name fields) => lowerEventEmit ctx env name fields
  | .assert cond _ => do
    let (is, t) ← lowerExpr ctx env cond
    if t != .bool then err "EmitWat: assert condition must be Bool"
    else .ok (is ++ #[.plain "i32.eqz", .if_ { insns := #[.unreachable] } { insns := #[] }])
  | .assertEq a b _ => do
    let (la, ta) ← lowerExpr ctx env a
    let (lb, tb) ← lowerExpr ctx env b
    if ta != tb then err "EmitWat: assertEq operands must share a type"
    else
      let eqInsn := if ta == .hash then #[.call hashEqName] else #[.plain (widthOf ta ++ ".eq")]
      .ok (la ++ lb ++ eqInsn ++ #[.plain "i32.eqz",
                            .if_ { insns := #[.unreachable] } { insns := #[] }])
  | .return e => lowerReturn ctx env returns e
  | _ => err "EmitWat: this statement form is not yet supported"

/-- Build the Borsh input prologue: env.input → INPUT_BUF, then load each
    param at its cumulative Borsh offset into a local. Entrypoint params have
    no wasm-level params; they are decoded from input and held in locals. -/
def loadParams (params : Array (String × ValueType))
    : Except EmitError (Array Insn × Array Local) := do
  let prologue : Array Insn :=
    #[.i64Const 0, .call "input", .i64Const 0, .i64Const INPUT_BUF, .call "read_register"]
  let result ← params.foldlM (init := (prologue, (#[] : Array Local), 0))
    fun (insns, locals, offset) p =>
      let (name, vt) := p
      match vt with
      | .u32 | .u64 | .bool =>
        let loadInsns := #[.i32Const (INPUT_BUF + offset), .load (loadOpFor vt) 0, .localSet name]
        .ok (insns ++ loadInsns, locals.push { name := name, type := wasmTypeOf vt }, offset + scalarWidth vt)
      | _ => err s!"EmitWat: param `{name}` has unsupported Borsh type `{vt.name}`"
  pure (result.fst, result.snd.fst)

def lowerEntrypoint (ctx : Ctx) (ep : Entrypoint) : Except EmitError Func := do
  let bodyLocals ← collectLocals ep.body
  let (paramPrologue, paramLocals) ← loadParams ep.params
  let allLocalTypes : LocalTypes :=
    (ep.params.map (fun (n, t) => { name := n, vt := t : LBind })) ++ bodyLocals
  let locals := paramLocals ++ bodyLocals.map (fun b => { name := b.name, type := wasmTypeOf b.vt : Local })
  let bodyInsns ← ep.body.foldlM (init := #[]) fun acc s => return acc ++ (← lowerStmt ctx allLocalTypes ep.returns s)
  .ok { name := ep.name, locals := locals, body := { insns := paramPrologue ++ bodyInsns }, exportName := ep.name }

def lowerModule (mod : ProofForge.IR.Module) : Except EmitError ProofForge.Compiler.Wasm.Module := do
  let scalars := stateLayout mod
  let maps := mapLayout mod
  let strs := stringPool mod
  let ctx := { scalars := scalars, maps := maps, strings := strs : Ctx }
  let entryFuncs ← mod.entrypoints.mapM (lowerEntrypoint ctx)
  let scalarData := scalars.map fun s => { offset := s.keyPtr, bytes := s.id : DataSegment }
  let mapData := maps.map fun m => { offset := m.prefixPtr, bytes := m.id ++ ":" : DataSegment }
  let boolData : Array DataSegment :=
    #[{ offset := TRUE_PTR, bytes := "true" }, { offset := FALSE_PTR, bytes := "false" }]
  let evtKeyData : DataSegment := { offset := EVT_KEY_PTR, bytes := "event" }
  let stringData := strs.map fun si => { offset := si.ptr, bytes := si.str : DataSegment }
  let baseImports := nearImports.push sha256Import |>.push logUtf8Import |>.push inputImport
  let imports := baseImports ++ ctxImports ++ (if maps.isEmpty then #[] else #[storageHasKeyImport])
  let funcs := helperFuncs ++ hashHelperFuncs ++ ctxHelperFuncs ++ evtHelperFuncs ++ (if maps.isEmpty then #[] else mapHelperFuncs) ++ entryFuncs
  let globals := #[hashPtrGlobalDecl] ++ evtGlobals
  .ok { imports := imports, globals := globals, funcs := funcs,
        memory := some { min := 1 },
        dataSegments := scalarData ++ mapData ++ boolData ++ #[evtKeyData] ++ stringData }

def renderModule (mod : ProofForge.IR.Module) : Except EmitError String :=
  match lowerModule mod with
  | .ok m => .ok (Printer.render m)
  | .error e => .error e

end ProofForge.Backend.WasmNear.EmitWat
