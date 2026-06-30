module

import ProofForge.Evm

open Lean.Evm

def counterSlot : Nat := 0

def increment : IO Unit := do
  let n ← Storage.load counterSlot
  let next := Nat.add n 1
  Storage.store counterSlot next
  returnU256 next

def main : IO Unit := increment
