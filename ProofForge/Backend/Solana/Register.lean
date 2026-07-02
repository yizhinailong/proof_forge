/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Solana sBPF Register Allocation

A simple register pool for the 11 sBPF registers. The convention is:

- r0: return value / syscall result
- r1: syscall arg 1 / entrypoint input pointer (preserved)
- r2–r5: syscall args 2–5 / scratch
- r6–r9: callee-saved scratch (can hold longer-lived temps)
- r10: frame pointer (stack, grows downward)

This module tracks which registers are free and spills to the stack when the
pool is exhausted. It is intentionally simple for Phase 1; a real allocator
can replace it later without changing callers.

See `docs/targets/solana-sbpf-asm.md` (D-026).
-/

import ProofForge.Backend.Solana.Asm

namespace ProofForge.Backend.Solana.Register

open ProofForge.Backend.Solana.Asm

/-- Registers available for general allocation. r0, r1, r10 are reserved. -/
def allocatableRegs : Array Reg := #[.r2, .r3, .r4, .r5, .r6, .r7, .r8, .r9]

structure Allocator where
  inUse : Array Reg
  nextSpill : Nat
  deriving Repr, Inhabited

def Allocator.new : Allocator := { inUse := #[], nextSpill := 8 }

/-- Allocate a register. Returns `(reg, allocator')`. If none are free, returns
a stack spill slot encoded as `r10` with an offset (the caller must decide how
to materialize spills; for now we return `r10` as a sentinel). -/
def Allocator.alloc (a : Allocator) : Reg × Allocator :=
  match allocatableRegs.find? (fun r => !a.inUse.contains r) with
  | some r => (r, { a with inUse := a.inUse.push r })
  | none   => (.r10, { a with nextSpill := a.nextSpill + 8 }) -- spill sentinel

/-- Mark a register as free again. -/
def Allocator.free (a : Allocator) (r : Reg) : Allocator :=
  { a with inUse := a.inUse.filter (· != r) }

end ProofForge.Backend.Solana.Register