/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Host bridge: ProofForge sBPF memory/regs ↔ solanalib machine state

Maps the mathlib-free `SbpfInterpreter` word-sparse `Memory` into solanalib's
byte-addressable `Mem`, and drives `bpfInterp` on **Counter core-tail**
programs (no Solana account prologue, no syscalls).

## Scope (honest)

| In scope | Out of scope (still on SbpfInterpreter / Mollusk) |
|----------|-----------------------------------------------------|
| `mov64` / `add64` / `ldxdw` / `stxdw` / `exit` | Full account-input layout |
| Word at `countOff = 96` | `call` syscalls (`sol_set_return_data`, …) |
| `r1 = inputBase = 0` | PDA / CPI / clock / log |
| Fuel-bounded `bpfInterp` success | Full EmitSBPF program end-to-end |

Portable IR remains the multi-chain source. This bridge only deepens the
**Solana target** leg so CompileCorrect can eventually state:

```
IR.Semantics  ⇝  SbpfInterpreter  ⇝  solanalib.bpfInterp
```

on the Counter core-tail fragment.
-/

import ProofForge.Backend.Solana.Asm
import ProofForge.Backend.Solana.BpfEncode
import ProofForge.Backend.Solana.CounterSbpfExec
import ProofForge.Backend.Solana.LabeledSbpf
import ProofForge.Backend.Solana.SbpfInterpreter
import SolanaRefinement.LabeledToSolanalib
import SolanaRefinement.SolanalibAdapter
import Solanalib.SBPF.CommType
import Solanalib.SBPF.Syntax
import Solanalib.SBPF.Memory
import Solanalib.SBPF.State
import Solanalib.SBPF.Interpreter
import Solanalib.SBPF.Decoder
import Solanalib.SBPF.Verifier

namespace ProofForge.Backend.Solana.HostBridge

open ProofForge.Backend.Solana.Asm
open ProofForge.Backend.Solana.BpfEncode
open ProofForge.Backend.Solana.CounterSbpfExec
open ProofForge.Backend.Solana.SbpfInterpreter
open ProofForge.Backend.Solana.LabeledToSolanalib
open ProofForge.Backend.Solana.SolanalibAdapter
open Solanalib.SBPF

/-! ### Word-sparse Memory ↔ byte Mem -/

/-- Write one little-endian `u64` word into solanalib `Mem`. -/
def storeWordLE (m : Mem) (addr value : Nat) : Mem :=
  Id.run do
    let mut mem := m
    let mut x := value
    for i in [0:8] do
      let b : U8 := BitVec.ofNat 8 (x % 256)
      let a : U64 := BitVec.ofNat 64 (addr + i)
      mem := fun i' => if i' = a then some b else mem i'
      x := x / 256
    mem

/-- Read one little-endian `u64` word; missing any byte ⇒ `none`. -/
def loadWordLE? (m : Mem) (addr : Nat) : Option Nat :=
  Id.run do
    let mut acc : Nat := 0
    let mut shift : Nat := 1
    for i in [0:8] do
      let a : U64 := BitVec.ofNat 64 (addr + i)
      match m a with
      | none => return none
      | some b =>
          acc := acc + b.toNat * shift
          shift := shift * 256
    some acc

/-- Convert ProofForge word-sparse memory into solanalib byte memory.
Each `(addr, word)` entry expands to 8 LE bytes at `addr..addr+7`. -/
def memOfPfMemory (memory : Memory) : Mem :=
  memory.foldl (init := initMem) fun m entry =>
    storeWordLE m entry.fst entry.snd

/-- Project a solanalib word back into ProofForge sparse memory at `addr`. -/
def pfMemoryWriteWord (memory : Memory) (addr value : Nat) : Memory :=
  memory.write addr value

/-- Read ProofForge-style word (0 if missing). -/
def pfMemoryRead (memory : Memory) (addr : Nat) : Nat :=
  memory.read addr

/-! ### Register file bridge -/

def regMapOfPfRegs (regs : Array Nat) : RegMap :=
  fun r => BitVec.ofNat 64 (regs.getD r.toU4.toNat 0)

/-- Build a solanalib initial `ok` state for core-tail programs.

- PC = 0 (core-tail programs are flat, no entrypoint label dispatch)
- `r1` = `inputBase` (0), matching Counter core-tail conventions
- `r10` = solanalib stack top (via `initBpfState`)
- Memory = word-sparse ProofForge memory expanded to bytes
- Version = v1 (matches EmitSBPF / verify table)
- Fuel = `remainCu` -/
def initCoreTailState (memory : Memory) (fuel : Nat := 256) : BpfState :=
  let rs0 := initRegMap
  let rs1 := setReg rs0 .br1 (BitVec.ofNat 64 inputBase)
  let m := memOfPfMemory memory
  initBpfState rs1 m (BitVec.ofNat 64 fuel) .v1

/-! ### Encode a flat core-tail `SbpfProgram` to solanalib bytes -/

def encodeCoreProgram (program : SbpfProgram) : Except String BpfBin := do
  match resolveProgram program with
  | .error e => .error e.render
  | .ok (slots, bytes) =>
      if !bpfBinWellFormed bytes then
        .error "core-tail encode: ill-formed bytecode"
      else
        -- Prefer direct lift for instruction-level checks; still return bytes
        -- for bpfInterp (which drives findInstr on the byte stream).
        match liftSlots slots with
        | .error e => .error e
        | .ok insns =>
            if !verifyAll insns .v1 then
              .error "core-tail encode: verifyInstr failed"
            else
              .ok (toBpfBin bytes)

/-! ### Observable projection after bpfInterp -/

structure CoreTailResult where
  /-- `r0` on success, else none. -/
  r0 : Option Nat := none
  /-- Word at `countOff` if fully mapped. -/
  countWord : Option Nat := none
  /-- Raw solanalib terminal state tag. -/
  ok : Bool := false
  deriving Repr, Inhabited

def projectResult (st : BpfState) : CoreTailResult :=
  match st with
  | .success v =>
      { r0 := some v.toNat, ok := true }
  | .ok _pc rs m _ss _sv _fm _cur _remain =>
      { r0 := some (rs .br0).toNat
        countWord := loadWordLE? m countOff
        ok := true }
  | .eflag | .err => { ok := false }

/-- Single-step the solanalib machine on a binary program.

Unlike `bpfInterp`, this returns the post-state of the step even when the
caller will stop mid-program. (`bpfInterp fuel` returns `.eflag` when fuel
hits 0, discarding the last `.ok` — unusable for pre-exit memory reads.) -/
def stepBin (bin : BpfBin) (st : BpfState) (gaps : Bool := false)
    (vmAddr : U64 := 0) : BpfState :=
  match st with
  | .eflag => .eflag
  | .err => .err
  | .success v => .success v
  | .ok pc rs m ss sv fm curCu remainCu =>
      if insnSize * pc.toNat < bin.length then
        if curCu.toNat ≥ remainCu.toNat then .eflag
        else
          match findInstr pc.toNat bin with
          | none => .eflag
          | some ins => step pc ins rs m ss sv fm gaps vmAddr curCu remainCu
      else
        .eflag

/-- Run exactly `n` steps, returning the state after the n-th step (or an
earlier terminal state). -/
def runStepsBin : Nat → BpfBin → BpfState → BpfState
  | 0, _, st => st
  | n + 1, bin, st =>
      match st with
      | .ok .. => runStepsBin n bin (stepBin bin st)
      | other => other

/-- Run until success/fault or fuel exhaustion, using `stepBin`. -/
def runToHalt (bin : BpfBin) (memory : Memory) (fuel : Nat := 256) : BpfState :=
  go fuel (initCoreTailState memory fuel)
where
  go : Nat → BpfState → BpfState
    | 0, st => st
    | n + 1, st =>
        match st with
        | .ok .. => go n (stepBin bin st)
        | other => other

/-- Pre-exit observation: take `steps` steps from the core-tail initial state
(for initialize: 3 steps leave memory after `stxdw`/`mov r0` and before `exit`). -/
def runBeforeExit (bin : BpfBin) (memory : Memory) (steps : Nat)
    (fuelBudget : Nat := 256) : BpfState :=
  runStepsBin steps bin (initCoreTailState memory fuelBudget)

def runToSuccess (bin : BpfBin) (memory : Memory) (fuel : Nat := 256) : BpfState :=
  runToHalt bin memory fuel

/-! ### Counter core-tail differentials -/

/-- initialize: empty memory → success r0=0, and pre-exit memory count=0. -/
def initializeSolanalibOk : Bool :=
  match encodeCoreProgram initializeProgram with
  | .error _ => false
  | .ok bin =>
      let success := runToSuccess bin #[] 32
      let preExit := runBeforeExit bin #[] 3 32
      match success, preExit with
      | .success v, .ok _pc _rs m _ss _sv _fm _cur _remain =>
          v.toNat == 0 &&
            match loadWordLE? m countOff with
            | some w => w == 0
            | none => false
      | _, _ => false

/-- increment from count=n: success r0=0, pre-exit memory count=n+1. -/
def incrementSolanalibOk (n : Nat) : Bool :=
  match encodeCoreProgram incrementProgram with
  | .error _ => false
  | .ok bin =>
      let mem : Memory := #[(countOff, n)]
      let success := runToSuccess bin mem 32
      -- increment core: ldxdw; mov64 1; add64; stxdw; mov64 r0,0; exit
      -- → 6 insns; pre-exit fuel = 5 leaves memory after stxdw / mov r0.
      let preExit := runBeforeExit bin mem 5 32
      match success, preExit with
      | .success v, .ok _pc _rs m _ss _sv _fm _cur _remain =>
          v.toNat == 0 &&
            match loadWordLE? m countOff with
            | some w => w == n + 1
            | none => false
      | _, _ => false

/-- Differential vs ProofForge core-tail final states (r0 + count word). -/
def initializeDiffOk : Bool :=
  -- ProofForge lemmas pin final count=0 and r0=0 after initialize.
  initializeSolanalibOk &&
    (initializeFinalState.entryR0 == 0) &&
    (initializeFinalState.memory.read countOff == 0)

def incrementDiffOk (n : Nat) : Bool :=
  incrementSolanalibOk n &&
    ((incrementFinalState n).entryR0 == 0) &&
    ((incrementFinalState n).memory.read countOff == n + 1)

/-- Fixed-point smokes used by CompileCorrect. -/
def counterCoreTailBridgeOk : Bool :=
  initializeDiffOk &&
    incrementDiffOk 0 &&
    incrementDiffOk 1 &&
    incrementDiffOk 41

theorem counter_core_tail_bridge_ok :
    counterCoreTailBridgeOk = true := by
  native_decide

theorem initialize_solanalib_ok :
    initializeSolanalibOk = true := by
  native_decide

theorem increment_solanalib_zero_ok :
    incrementSolanalibOk 0 = true := by
  native_decide

theorem increment_solanalib_one_ok :
    incrementSolanalibOk 1 = true := by
  native_decide

end ProofForge.Backend.Solana.HostBridge
