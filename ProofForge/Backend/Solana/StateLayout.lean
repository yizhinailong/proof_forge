/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Solana Account State Layout

Compute serialized account data offsets from the instruction manifest and IR
state declarations. The layout is deterministic so codegen can emit `.equ`
constants for every field.

See `docs/targets/solana-sbpf-asm.md` (D-026).
-/

import ProofForge.IR.Contract

namespace ProofForge.Backend.Solana.StateLayout

open ProofForge.IR

-- ============================================================================
-- Solana serialized input constants
-- ============================================================================

def ACCOUNT_HEADER_SIZE : Nat := 8   -- is_signer + is_writable + is_executable + padding
def PUBKEY_SIZE : Nat := 32
def U64_SIZE : Nat := 8
def MAX_PERMITTED_DATA_INCREASE : Nat := 10240

def alignTo8 (n : Nat) : Nat :=
  let r := n % 8
  if r == 0 then 0 else 8 - r

/-- Layout for a single account with `dataSize` bytes of account data.
Returns `(dataStartOffset, instructionDataStartOffset)` relative to the
beginning of the Solana input buffer. -/
def computeSingleAccountLayout (dataSize : Nat) : Nat × Nat :=
  let numAccounts := U64_SIZE
  let dataStart := numAccounts + ACCOUNT_HEADER_SIZE + PUBKEY_SIZE + PUBKEY_SIZE + U64_SIZE + U64_SIZE
  let afterPadding := dataStart + dataSize + MAX_PERMITTED_DATA_INCREASE
  let align := alignTo8 afterPadding
  let rentEpochEnd := afterPadding + align + U64_SIZE
  let instrDataStart := rentEpochEnd + U64_SIZE
  (dataStart, instrDataStart)

/-- Compute the total account data size needed for all IR state variables.
Phase 1 packs everything as 8-byte words. -/
def moduleDataSize (module : Module) : Nat :=
  module.state.size * 8

-- ============================================================================
-- Per-module field offsets
-- ============================================================================

structure StateField where
  id : String
  absOff : Nat
  deriving Repr, Inhabited

/-- Build a flat list of absolute account-data offsets for every state field
in the module. Phase 1 assumes all state lives in account 0. -/
def buildStateOffsets (module : Module) : Array StateField := Id.run do
  let dataSize := moduleDataSize module
  let (acctDataOff, _) := computeSingleAccountLayout dataSize
  let mut offsets := #[]
  let mut fieldOff := 0
  for state in module.state do
    offsets := offsets.push { id := state.id, absOff := acctDataOff + fieldOff }
    fieldOff := fieldOff + 8
  return offsets

end ProofForge.Backend.Solana.StateLayout