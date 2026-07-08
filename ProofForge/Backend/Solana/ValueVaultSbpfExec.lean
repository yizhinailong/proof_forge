import ProofForge.Backend.Solana.SbpfExec
import ProofForge.IR.Examples.ValueVault

/-!
ValueVault reuse slice over generic `SbpfExec` step lemmas.

This is the SOL-4(a) genericity surface: unlike Counter, the deposit storage
core touches multiple scalar slots and combines stack locals, account data,
arithmetic, and stores. Keep this file as a short composition over `SbpfExec`;
new per-instruction facts belong in `SbpfExec.lean`.
-/

namespace ProofForge.Backend.Solana.ValueVaultSbpfExec

open ProofForge.Backend.Solana.Asm
open ProofForge.Backend.Solana.SbpfInterpreter
open ProofForge.Backend.Solana.SbpfExec

abbrev Program := SbpfProgram
abbrev State := SbpfState

def balanceOff : Nat := 96
def releasedOff : Nat := 104
def feesOff : Nat := 112
def lastValueOff : Nat := 120
def lastCheckpointOff : Nat := 128
def operationsOff : Nat := 136

def depositAmountScratch : Nat := stackBase - 8
def depositCurrentScratch : Nat := stackBase - 16
def depositNextScratch : Nat := stackBase - 24
def depositLhsScratch : Nat := stackBase - 32
def depositNextOpsScratch : Nat := stackBase - 40
def depositOpsScratch : Nat := stackBase - 48

/-! ### deposit storage core

This models the storage-update tail after account validation and parameter
decoding:

`balance := balance + amount; last_value := amount; operations := operations + 1`.
-/

def depositStorageProgram : Program := {
  instructions := #[
    inst .ldxdw (some .r2) (some .r1) (some (.num balanceOff)) none,
    inst .stxdw (some .r10) (some .r2) (some (.num 16)) none,
    inst .ldxdw (some .r2) (some .r10) (some (.num 16)) none,
    inst .stxdw (some .r10) (some .r2) (some (.num 32)) none,
    inst .ldxdw (some .r2) (some .r10) (some (.num 8)) none,
    inst .ldxdw (some .r3) (some .r10) (some (.num 32)) none,
    inst .add64 (some .r2) (some .r3) none none,
    inst .stxdw (some .r10) (some .r2) (some (.num 24)) none,
    inst .ldxdw (some .r2) (some .r1) (some (.num operationsOff)) none,
    inst .stxdw (some .r10) (some .r2) (some (.num 32)) none,
    inst .ldxdw (some .r2) (some .r10) (some (.num 32)) none,
    inst .stxdw (some .r10) (some .r2) (some (.num 48)) none,
    inst .mov64 (some .r2) none none (some (.num 1)),
    inst .ldxdw (some .r3) (some .r10) (some (.num 48)) none,
    inst .add64 (some .r2) (some .r3) none none,
    inst .stxdw (some .r10) (some .r2) (some (.num 40)) none,
    inst .ldxdw (some .r2) (some .r10) (some (.num 24)) none,
    inst .stxdw (some .r1) (some .r2) (some (.num balanceOff)) none,
    inst .ldxdw (some .r2) (some .r10) (some (.num 8)) none,
    inst .stxdw (some .r1) (some .r2) (some (.num lastValueOff)) none,
    inst .ldxdw (some .r2) (some .r10) (some (.num 40)) none,
    inst .stxdw (some .r1) (some .r2) (some (.num operationsOff)) none,
    inst .mov64 (some .r0) none none (some (.num 0)),
    inst .exit
  ]
  labels := #[]
  symbols := #[]
}

def depositStorageInitialState (balance amount operations : Nat) : State :=
  { regs := regSet (regSet emptyRegs .r1 inputBase) .r10 stackBase
    memory := #[
      (balanceOff, balance),
      (operationsOff, operations),
      (depositAmountScratch, amount)
    ]
    pc := 0 }

def depositState1 (balance amount operations : Nat) : State :=
  execLoad (depositStorageInitialState balance amount operations) .r2 balanceOff balance

def depositState2 (balance amount operations : Nat) : State :=
  execStore (depositState1 balance amount operations) depositCurrentScratch balance

def depositState3 (balance amount operations : Nat) : State :=
  execLoad (depositState2 balance amount operations) .r2 depositCurrentScratch balance

def depositState4 (balance amount operations : Nat) : State :=
  execStore (depositState3 balance amount operations) depositLhsScratch balance

def depositState5 (balance amount operations : Nat) : State :=
  execLoad (depositState4 balance amount operations) .r2 depositAmountScratch amount

def depositState6 (balance amount operations : Nat) : State :=
  execLoad (depositState5 balance amount operations) .r3 depositLhsScratch balance

def depositState7 (balance amount operations : Nat) : State :=
  nextPc (setReg (depositState6 balance amount operations) .r2 (amount + balance))

def depositState8 (balance amount operations : Nat) : State :=
  execStore (depositState7 balance amount operations) depositNextScratch (amount + balance)

def depositState9 (balance amount operations : Nat) : State :=
  execLoad (depositState8 balance amount operations) .r2 operationsOff operations

def depositState10 (balance amount operations : Nat) : State :=
  execStore (depositState9 balance amount operations) depositLhsScratch operations

def depositState11 (balance amount operations : Nat) : State :=
  execLoad (depositState10 balance amount operations) .r2 depositLhsScratch operations

def depositState12 (balance amount operations : Nat) : State :=
  execStore (depositState11 balance amount operations) depositOpsScratch operations

def depositState13 (balance amount operations : Nat) : State :=
  execMov64 (depositState12 balance amount operations) .r2 1

def depositState14 (balance amount operations : Nat) : State :=
  execLoad (depositState13 balance amount operations) .r3 depositOpsScratch operations

def depositState15 (balance amount operations : Nat) : State :=
  nextPc (setReg (depositState14 balance amount operations) .r2 (1 + operations))

def depositState16 (balance amount operations : Nat) : State :=
  execStore (depositState15 balance amount operations) depositNextOpsScratch (1 + operations)

def depositState17 (balance amount operations : Nat) : State :=
  execLoad (depositState16 balance amount operations) .r2 depositNextScratch (amount + balance)

def depositState18 (balance amount operations : Nat) : State :=
  execStore (depositState17 balance amount operations) balanceOff (amount + balance)

def depositState19 (balance amount operations : Nat) : State :=
  execLoad (depositState18 balance amount operations) .r2 depositAmountScratch amount

def depositState20 (balance amount operations : Nat) : State :=
  execStore (depositState19 balance amount operations) lastValueOff amount

def depositState21 (balance amount operations : Nat) : State :=
  execLoad (depositState20 balance amount operations) .r2 depositNextOpsScratch (1 + operations)

def depositState22 (balance amount operations : Nat) : State :=
  execStore (depositState21 balance amount operations) operationsOff (1 + operations)

def depositState23 (balance amount operations : Nat) : State :=
  execMov64 (depositState22 balance amount operations) .r0 0

def depositFinalState (balance amount operations : Nat) : State :=
  execExit (depositState23 balance amount operations) 0

theorem deposit_not_halted0 (b a o : Nat) :
    ¬ (depositStorageInitialState b a o).halted := by intro h; cases h
theorem deposit_not_halted1 (b a o : Nat) : ¬ (depositState1 b a o).halted := by intro h; cases h
theorem deposit_not_halted2 (b a o : Nat) : ¬ (depositState2 b a o).halted := by intro h; cases h
theorem deposit_not_halted3 (b a o : Nat) : ¬ (depositState3 b a o).halted := by intro h; cases h
theorem deposit_not_halted4 (b a o : Nat) : ¬ (depositState4 b a o).halted := by intro h; cases h
theorem deposit_not_halted5 (b a o : Nat) : ¬ (depositState5 b a o).halted := by intro h; cases h
theorem deposit_not_halted6 (b a o : Nat) : ¬ (depositState6 b a o).halted := by intro h; cases h
theorem deposit_not_halted7 (b a o : Nat) : ¬ (depositState7 b a o).halted := by intro h; cases h
theorem deposit_not_halted8 (b a o : Nat) : ¬ (depositState8 b a o).halted := by intro h; cases h
theorem deposit_not_halted9 (b a o : Nat) : ¬ (depositState9 b a o).halted := by intro h; cases h
theorem deposit_not_halted10 (b a o : Nat) : ¬ (depositState10 b a o).halted := by intro h; cases h
theorem deposit_not_halted11 (b a o : Nat) : ¬ (depositState11 b a o).halted := by intro h; cases h
theorem deposit_not_halted12 (b a o : Nat) : ¬ (depositState12 b a o).halted := by intro h; cases h
theorem deposit_not_halted13 (b a o : Nat) : ¬ (depositState13 b a o).halted := by intro h; cases h
theorem deposit_not_halted14 (b a o : Nat) : ¬ (depositState14 b a o).halted := by intro h; cases h
theorem deposit_not_halted15 (b a o : Nat) : ¬ (depositState15 b a o).halted := by intro h; cases h
theorem deposit_not_halted16 (b a o : Nat) : ¬ (depositState16 b a o).halted := by intro h; cases h
theorem deposit_not_halted17 (b a o : Nat) : ¬ (depositState17 b a o).halted := by intro h; cases h
theorem deposit_not_halted18 (b a o : Nat) : ¬ (depositState18 b a o).halted := by intro h; cases h
theorem deposit_not_halted19 (b a o : Nat) : ¬ (depositState19 b a o).halted := by intro h; cases h
theorem deposit_not_halted20 (b a o : Nat) : ¬ (depositState20 b a o).halted := by intro h; cases h
theorem deposit_not_halted21 (b a o : Nat) : ¬ (depositState21 b a o).halted := by intro h; cases h
theorem deposit_not_halted22 (b a o : Nat) : ¬ (depositState22 b a o).halted := by intro h; cases h
theorem deposit_not_halted23 (b a o : Nat) : ¬ (depositState23 b a o).halted := by intro h; cases h
theorem depositFinal_halted (b a o : Nat) : (depositFinalState b a o).halted := rfl

def depositReady0 (b a o : Nat) : StepReady depositStorageProgram (depositStorageInitialState b a o) :=
  ⟨deposit_not_halted0 b a o, ⟨depositStorageProgram.instructions[0], rfl⟩⟩
def depositReady1 (b a o : Nat) : StepReady depositStorageProgram (depositState1 b a o) :=
  ⟨deposit_not_halted1 b a o, ⟨depositStorageProgram.instructions[1], rfl⟩⟩
def depositReady2 (b a o : Nat) : StepReady depositStorageProgram (depositState2 b a o) :=
  ⟨deposit_not_halted2 b a o, ⟨depositStorageProgram.instructions[2], rfl⟩⟩
def depositReady3 (b a o : Nat) : StepReady depositStorageProgram (depositState3 b a o) :=
  ⟨deposit_not_halted3 b a o, ⟨depositStorageProgram.instructions[3], rfl⟩⟩
def depositReady4 (b a o : Nat) : StepReady depositStorageProgram (depositState4 b a o) :=
  ⟨deposit_not_halted4 b a o, ⟨depositStorageProgram.instructions[4], rfl⟩⟩
def depositReady5 (b a o : Nat) : StepReady depositStorageProgram (depositState5 b a o) :=
  ⟨deposit_not_halted5 b a o, ⟨depositStorageProgram.instructions[5], rfl⟩⟩
def depositReady6 (b a o : Nat) : StepReady depositStorageProgram (depositState6 b a o) :=
  ⟨deposit_not_halted6 b a o, ⟨depositStorageProgram.instructions[6], rfl⟩⟩
def depositReady7 (b a o : Nat) : StepReady depositStorageProgram (depositState7 b a o) :=
  ⟨deposit_not_halted7 b a o, ⟨depositStorageProgram.instructions[7], rfl⟩⟩
def depositReady8 (b a o : Nat) : StepReady depositStorageProgram (depositState8 b a o) :=
  ⟨deposit_not_halted8 b a o, ⟨depositStorageProgram.instructions[8], rfl⟩⟩
def depositReady9 (b a o : Nat) : StepReady depositStorageProgram (depositState9 b a o) :=
  ⟨deposit_not_halted9 b a o, ⟨depositStorageProgram.instructions[9], rfl⟩⟩
def depositReady10 (b a o : Nat) : StepReady depositStorageProgram (depositState10 b a o) :=
  ⟨deposit_not_halted10 b a o, ⟨depositStorageProgram.instructions[10], rfl⟩⟩
def depositReady11 (b a o : Nat) : StepReady depositStorageProgram (depositState11 b a o) :=
  ⟨deposit_not_halted11 b a o, ⟨depositStorageProgram.instructions[11], rfl⟩⟩
def depositReady12 (b a o : Nat) : StepReady depositStorageProgram (depositState12 b a o) :=
  ⟨deposit_not_halted12 b a o, ⟨depositStorageProgram.instructions[12], rfl⟩⟩
def depositReady13 (b a o : Nat) : StepReady depositStorageProgram (depositState13 b a o) :=
  ⟨deposit_not_halted13 b a o, ⟨depositStorageProgram.instructions[13], rfl⟩⟩
def depositReady14 (b a o : Nat) : StepReady depositStorageProgram (depositState14 b a o) :=
  ⟨deposit_not_halted14 b a o, ⟨depositStorageProgram.instructions[14], rfl⟩⟩
def depositReady15 (b a o : Nat) : StepReady depositStorageProgram (depositState15 b a o) :=
  ⟨deposit_not_halted15 b a o, ⟨depositStorageProgram.instructions[15], rfl⟩⟩
def depositReady16 (b a o : Nat) : StepReady depositStorageProgram (depositState16 b a o) :=
  ⟨deposit_not_halted16 b a o, ⟨depositStorageProgram.instructions[16], rfl⟩⟩
def depositReady17 (b a o : Nat) : StepReady depositStorageProgram (depositState17 b a o) :=
  ⟨deposit_not_halted17 b a o, ⟨depositStorageProgram.instructions[17], rfl⟩⟩
def depositReady18 (b a o : Nat) : StepReady depositStorageProgram (depositState18 b a o) :=
  ⟨deposit_not_halted18 b a o, ⟨depositStorageProgram.instructions[18], rfl⟩⟩
def depositReady19 (b a o : Nat) : StepReady depositStorageProgram (depositState19 b a o) :=
  ⟨deposit_not_halted19 b a o, ⟨depositStorageProgram.instructions[19], rfl⟩⟩
def depositReady20 (b a o : Nat) : StepReady depositStorageProgram (depositState20 b a o) :=
  ⟨deposit_not_halted20 b a o, ⟨depositStorageProgram.instructions[20], rfl⟩⟩
def depositReady21 (b a o : Nat) : StepReady depositStorageProgram (depositState21 b a o) :=
  ⟨deposit_not_halted21 b a o, ⟨depositStorageProgram.instructions[21], rfl⟩⟩
def depositReady22 (b a o : Nat) : StepReady depositStorageProgram (depositState22 b a o) :=
  ⟨deposit_not_halted22 b a o, ⟨depositStorageProgram.instructions[22], rfl⟩⟩
def depositReady23 (b a o : Nat) : StepReady depositStorageProgram (depositState23 b a o) :=
  ⟨deposit_not_halted23 b a o, ⟨depositStorageProgram.instructions[23], rfl⟩⟩

theorem deposit_r1_base (s : State)
    (h : regGet s.regs .r1 = inputBase) :
    regGet (nextPc s).regs .r1 = inputBase := by
  simpa [nextPc] using h

theorem deposit_r10_stack (s : State)
    (h : regGet s.regs .r10 = stackBase) :
    regGet (nextPc s).regs .r10 = stackBase := by
  simpa [nextPc] using h

theorem deposit_initial_r1 (b a o : Nat) :
    regGet (depositStorageInitialState b a o).regs .r1 = inputBase := by
  unfold depositStorageInitialState regGet regSet emptyRegs inputBase registerCount
  rfl

theorem deposit_initial_r10 (b a o : Nat) :
    regGet (depositStorageInitialState b a o).regs .r10 = stackBase := by
  unfold depositStorageInitialState regGet regSet emptyRegs stackBase registerCount
  rfl

theorem deposit_addr_r1_balance0 (b a o : Nat) :
    memoryAddress (depositStorageInitialState b a o) .r1 balanceOff = balanceOff := by
  simp [memoryAddress, deposit_initial_r1 b a o, balanceOff, inputBase]
  native_decide

theorem deposit_read_balance0 (b a o : Nat) :
    (depositStorageInitialState b a o).memory.read balanceOff = b := by
  unfold depositStorageInitialState balanceOff
  simp [Memory.read]

theorem deposit_step0 (b a o : Nat) :
    step depositStorageProgram (depositStorageInitialState b a o) =
      .ok (depositState1 b a o) :=
  step_ldxdw_ok (depositReady0 b a o) (by rfl)
    (deposit_addr_r1_balance0 b a o) (deposit_read_balance0 b a o)

theorem deposit_state1_r10 (b a o : Nat) :
    regGet (depositState1 b a o).regs .r10 = stackBase := by
  unfold depositState1 depositStorageInitialState execLoad setReg nextPc regGet regSet stackBase
  rfl

theorem deposit_state1_r2 (b a o : Nat) :
    regGet (depositState1 b a o).regs .r2 = b := by
  unfold depositState1 depositStorageInitialState execLoad setReg nextPc regGet regSet
  rfl

theorem deposit_addr_r10_current1 (b a o : Nat) :
    memoryAddress (depositState1 b a o) .r10 16 = depositCurrentScratch := by
  simp [memoryAddress, deposit_state1_r10 b a o, depositCurrentScratch]
  native_decide

theorem deposit_step1 (b a o : Nat) :
    step depositStorageProgram (depositState1 b a o) =
      .ok (depositState2 b a o) :=
  step_stxdw_ok (depositReady1 b a o) (by rfl)
    (deposit_addr_r10_current1 b a o) (deposit_state1_r2 b a o)

theorem deposit_state2_r10 (b a o : Nat) :
    regGet (depositState2 b a o).regs .r10 = stackBase := by
  unfold depositState2 depositState1 depositStorageInitialState
    execStore execLoad setReg nextPc regGet regSet stackBase
  rfl

theorem deposit_addr_r10_current2 (b a o : Nat) :
    memoryAddress (depositState2 b a o) .r10 16 = depositCurrentScratch := by
  simp [memoryAddress, deposit_state2_r10 b a o, depositCurrentScratch]
  native_decide

theorem deposit_read_current2 (b a o : Nat) :
    (depositState2 b a o).memory.read depositCurrentScratch = b := by
  unfold depositState2 execStore
  simp [nextPc, Memory.read_write]

theorem deposit_step2 (b a o : Nat) :
    step depositStorageProgram (depositState2 b a o) =
      .ok (depositState3 b a o) :=
  step_ldxdw_ok (depositReady2 b a o) (by rfl)
    (deposit_addr_r10_current2 b a o) (deposit_read_current2 b a o)

theorem deposit_state3_r10 (b a o : Nat) :
    regGet (depositState3 b a o).regs .r10 = stackBase := by
  unfold depositState3 depositState2 depositState1 depositStorageInitialState
    execLoad execStore setReg nextPc regGet regSet stackBase
  rfl

theorem deposit_state3_r2 (b a o : Nat) :
    regGet (depositState3 b a o).regs .r2 = b := by
  unfold depositState3 execLoad setReg nextPc regGet
  rfl

theorem deposit_addr_r10_lhs3 (b a o : Nat) :
    memoryAddress (depositState3 b a o) .r10 32 = depositLhsScratch := by
  simp [memoryAddress, deposit_state3_r10 b a o, depositLhsScratch]
  native_decide

theorem deposit_step3 (b a o : Nat) :
    step depositStorageProgram (depositState3 b a o) =
      .ok (depositState4 b a o) :=
  step_stxdw_ok (depositReady3 b a o) (by rfl)
    (deposit_addr_r10_lhs3 b a o) (deposit_state3_r2 b a o)

theorem deposit_state4_r10 (b a o : Nat) :
    regGet (depositState4 b a o).regs .r10 = stackBase := by
  unfold depositState4 depositState3 depositState2 depositState1 depositStorageInitialState
    execStore execLoad setReg nextPc regGet regSet stackBase
  rfl

theorem deposit_addr_r10_amount4 (b a o : Nat) :
    memoryAddress (depositState4 b a o) .r10 8 = depositAmountScratch := by
  simp [memoryAddress, deposit_state4_r10 b a o, depositAmountScratch]
  native_decide

theorem deposit_read_amount4 (b a o : Nat) :
    (depositState4 b a o).memory.read depositAmountScratch = a := by
  unfold depositState4 depositState3 depositState2 depositState1 depositStorageInitialState
    execStore execLoad setReg nextPc depositAmountScratch depositCurrentScratch depositLhsScratch
  simp [Memory.read, Memory.write, balanceOff, operationsOff, stackBase]

theorem deposit_step4 (b a o : Nat) :
    step depositStorageProgram (depositState4 b a o) =
      .ok (depositState5 b a o) :=
  step_ldxdw_ok (depositReady4 b a o) (by rfl)
    (deposit_addr_r10_amount4 b a o) (deposit_read_amount4 b a o)

theorem deposit_read_lhs4 (b a o : Nat) :
    (depositState4 b a o).memory.read depositLhsScratch = b := by
  unfold depositState4 execStore
  simp [nextPc, Memory.read_write]

theorem deposit_state5_r10 (b a o : Nat) :
    regGet (depositState5 b a o).regs .r10 = stackBase := by
  unfold depositState5 depositState4 depositState3 depositState2 depositState1
    depositStorageInitialState execLoad execStore setReg nextPc regGet regSet stackBase
  rfl

theorem deposit_addr_r10_lhs5 (b a o : Nat) :
    memoryAddress (depositState5 b a o) .r10 32 = depositLhsScratch := by
  simp [memoryAddress, deposit_state5_r10 b a o, depositLhsScratch]
  native_decide

theorem deposit_read_lhs5 (b a o : Nat) :
    (depositState5 b a o).memory.read depositLhsScratch = b := by
  unfold depositState5 execLoad setReg nextPc
  simpa using deposit_read_lhs4 b a o

theorem deposit_step5 (b a o : Nat) :
    step depositStorageProgram (depositState5 b a o) =
      .ok (depositState6 b a o) :=
  step_ldxdw_ok (depositReady5 b a o) (by rfl)
    (deposit_addr_r10_lhs5 b a o) (deposit_read_lhs5 b a o)

theorem deposit_state6_r2 (b a o : Nat) :
    regGet (depositState6 b a o).regs .r2 = a := by
  unfold depositState6 depositState5 execLoad setReg nextPc regGet
  rfl

theorem deposit_state6_r3 (b a o : Nat) :
    regGet (depositState6 b a o).regs .r3 = b := by
  unfold depositState6 execLoad setReg nextPc regGet
  rfl

theorem deposit_step6 (b a o : Nat) :
    step depositStorageProgram (depositState6 b a o) =
      .ok (depositState7 b a o) :=
  step_add64_reg_ok (depositReady6 b a o) (by rfl)
    (deposit_state6_r2 b a o) (deposit_state6_r3 b a o)

theorem deposit_state7_r10 (b a o : Nat) :
    regGet (depositState7 b a o).regs .r10 = stackBase := by
  unfold depositState7 depositState6 depositState5 depositState4 depositState3
    depositState2 depositState1 depositStorageInitialState execLoad execStore setReg
    nextPc regGet regSet stackBase
  rfl

theorem deposit_state7_r2 (b a o : Nat) :
    regGet (depositState7 b a o).regs .r2 = a + b := by
  unfold depositState7 setReg nextPc regGet
  rfl

theorem deposit_addr_r10_next7 (b a o : Nat) :
    memoryAddress (depositState7 b a o) .r10 24 = depositNextScratch := by
  simp [memoryAddress, deposit_state7_r10 b a o, depositNextScratch]
  native_decide

theorem deposit_step7 (b a o : Nat) :
    step depositStorageProgram (depositState7 b a o) =
      .ok (depositState8 b a o) :=
  step_stxdw_ok (depositReady7 b a o) (by rfl)
    (deposit_addr_r10_next7 b a o) (deposit_state7_r2 b a o)

theorem deposit_state8_next_balance_scratch (b a o : Nat) :
    (depositState8 b a o).memory.read depositNextScratch = a + b := by
  unfold depositState8 execStore
  simp [nextPc, Memory.read_write]

theorem deposit_state18_balance (b a o : Nat) :
    (depositState18 b a o).memory.read balanceOff = a + b := by
  unfold depositState18 execStore
  simp [nextPc, Memory.read_write]

theorem balanceOff_matches_layout :
    stateFieldOffset? ProofForge.IR.Examples.ValueVault.module "balance" = some balanceOff := by
  native_decide

theorem operationsOff_matches_layout :
    stateFieldOffset? ProofForge.IR.Examples.ValueVault.module "operations" = some operationsOff := by
  native_decide

end ProofForge.Backend.Solana.ValueVaultSbpfExec
