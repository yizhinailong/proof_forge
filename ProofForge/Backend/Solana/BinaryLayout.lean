/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Solana BinaryLayout (internal pack hygiene — Wave δ.2)

Little-endian field packing for **instruction data** bytes. Parallel to:

| Host | Pack layer |
|------|------------|
| EVM | `AbiEncode` |
| NEAR | `JsonEncode` |
| Solana | CPI `dataLayout` names + this pure byte planner |

Authors never call this. New SPL / Token-2022 layouts can declare a field list
and materialize bytes once, instead of hand-rolling store sequences. sBPF
`stx` emission still lives in `Extension/Cpi.lean`; this module owns the
**byte plan** only (same split as AbiEncode vs ToYul.AbiEncode).

Not a general Borsh codec — only LE tags/scalars used by known program ix data.
-/
import Init.Data.Array.Basic
import Init.Data.Nat.Basic

namespace ProofForge.Backend.Solana.BinaryLayout

def catalogId : String := "solana.binary_layout"

/-- One LE field in ix data. -/
inductive Field where
  | u8 (n : Nat)
  | u16 (n : Nat)
  | u32 (n : Nat)
  | u64 (n : Nat)
  | bytes (data : Array Nat)
  deriving Repr

def Field.size : Field → Nat
  | .u8 _ => 1
  | .u16 _ => 2
  | .u32 _ => 4
  | .u64 _ => 8
  | .bytes d => d.size

/-- Append little-endian bytes for `n` using `width` bytes. -/
def pushLe (acc : Array Nat) (n width : Nat) : Array Nat :=
  Id.run do
    let mut a := acc
    let mut x := n
    for _ in [0:width] do
      a := a.push (x % 256)
      x := x / 256
    a

def Field.appendBytes (acc : Array Nat) : Field → Array Nat
  | .u8 n => acc.push (n % 256)
  | .u16 n => pushLe acc n 2
  | .u32 n => pushLe acc n 4
  | .u64 n => pushLe acc n 8
  | .bytes d =>
      d.foldl (fun a b => a.push (b % 256)) acc

/-- Pack fields into a flat byte array (ix data body). -/
def pack (fields : Array Field) : Array Nat :=
  fields.foldl Field.appendBytes #[]

def packSize (fields : Array Field) : Nat :=
  fields.foldl (fun n f => n + f.size) 0

/-- Honesty: packed length matches sum of field sizes. -/
def packSizeMatches (fields : Array Field) : Bool :=
  (pack fields).size == packSize fields

/-! ## Common SPL Token shapes (byte plans only) -/

/-- SPL Token `transfer_checked` data: `u8 tag=12` ‖ `u64 amount` ‖ `u8 decimals`. -/
def splTransferChecked (amount decimals : Nat) : Array Field :=
  #[.u8 12, .u64 amount, .u8 decimals]

/-- SPL Token `transfer` data: `u8 tag=3` ‖ `u64 amount`. -/
def splTransfer (amount : Nat) : Array Field :=
  #[.u8 3, .u64 amount]

/-- System program `transfer`: `u32 tag=2` ‖ `u64 lamports`. -/
def systemTransfer (lamports : Nat) : Array Field :=
  #[.u32 2, .u64 lamports]

end ProofForge.Backend.Solana.BinaryLayout
