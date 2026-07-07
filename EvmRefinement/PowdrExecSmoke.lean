import EvmRefinement.PowdrExec

/-!
Small non-Counter reuse smoke for `PowdrExec`.

This file deliberately avoids importing `CounterRefinement`.  It models the
bytecode skeleton of a tiny two-slot reader entrypoint (`PUSH1 slot; SLOAD;
STOP`) and proves the three-step path only by composing the generic powdr
execution lemmas.
-/

namespace ProofForge.Backend.Evm.PowdrExecSmoke

abbrev State := ProofForge.Backend.Evm.PowdrExec.State
abbrev StepFEReady := ProofForge.Backend.Evm.PowdrExec.StepFEReady
abbrev StepFEPath := ProofForge.Backend.Evm.PowdrExec.StepFEPath
abbrev UInt256 := EvmSemantics.UInt256
abbrev Operation := EvmSemantics.Operation

def twoSlotReaderPush1Op : EvmSemantics.Operation.PushOp :=
  { width := ⟨1, by decide⟩ }

def twoSlotReaderBalanceSlot : UInt256 :=
  EvmSemantics.UInt256.ofNat 1

def pushBalanceSlotPost (state : State)
    (hready : StepFEReady state (.Push twoSlotReaderPush1Op)) : State :=
  (state.consumeGas
    (EvmSemantics.EVM.Gas.baseCost state.fork
      (.Push twoSlotReaderPush1Op : Operation)) hready.gas).replaceStackAndIncrPC
    (twoSlotReaderBalanceSlot :: state.stack) (pcΔ := 2)

def sloadBalanceSlotPost (state : State)
    (hgas :
      EvmSemantics.EVM.Gas.sloadTotal state twoSlotReaderBalanceSlot ≤
        state.gasAvailable) : State :=
  ({ (state.consumeGas
      (EvmSemantics.EVM.Gas.sloadTotal state twoSlotReaderBalanceSlot)
      hgas) with
      substate := state.substate.addAccessedStorageKey
        (state.executionEnv.address, twoSlotReaderBalanceSlot) }.replaceStackAndIncrPC
    ((state.accountMap state.executionEnv.address).storage
      twoSlotReaderBalanceSlot :: state.stack.tail))

def stopPost (state : State) : State :=
  { state with halt := .Success, hReturn := .empty }

theorem twoSlotReader_getBalance_stepFEPath
    {s0 : State}
    (hpushReady : StepFEReady s0 (.Push twoSlotReaderPush1Op))
    (hpushDecoded :
      s0.decoded =
        some (.Push twoSlotReaderPush1Op,
          some (twoSlotReaderBalanceSlot, 1)))
    (hsloadReady :
      StepFEReady (pushBalanceSlotPost s0 hpushReady)
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (hsloadDecoded :
      (pushBalanceSlotPost s0 hpushReady).decoded =
        some (.StackMemFlow
          (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushReady) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushReady).gasAvailable)
    (hstopReady :
      StepFEReady
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas)
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps)))
    (hstopDecoded :
      (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas).decoded =
        some (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps), none)) :
    StepFEPath s0 3
      (stopPost
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas)) := by
  have hpushStep :
      EvmSemantics.EVM.stepFE s0 =
        .ok (pushBalanceSlotPost s0 hpushReady) :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_push_data_ok
      (op := twoSlotReaderPush1Op) (value := twoSlotReaderBalanceSlot)
      (argBytes := 1) (widthPred := 0) (by rfl) hpushReady hpushDecoded
  have hsloadStep :
      EvmSemantics.EVM.stepFE (pushBalanceSlotPost s0 hpushReady) =
        .ok
          (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady)
            hsloadGas) :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_sload_ok
      (rest := s0.stack) hsloadReady hsloadDecoded
      (by
        simp [pushBalanceSlotPost,
          EvmSemantics.EVM.State.replaceStackAndIncrPC])
      hsloadGas
  have hstopStep :
      EvmSemantics.EVM.stepFE
          (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady)
            hsloadGas) =
        .ok
          (stopPost
            (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady)
              hsloadGas)) :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_stop_ok
      hstopReady hstopDecoded
  exact ProofForge.Backend.Evm.PowdrExec.stepFEPath_three
    hpushReady.running hpushStep
    hsloadReady.running hsloadStep
    hstopReady.running hstopStep

theorem twoSlotReader_getBalance_runSteps
    {s0 : State}
    (hpushReady : StepFEReady s0 (.Push twoSlotReaderPush1Op))
    (hpushDecoded :
      s0.decoded =
        some (.Push twoSlotReaderPush1Op,
          some (twoSlotReaderBalanceSlot, 1)))
    (hsloadReady :
      StepFEReady (pushBalanceSlotPost s0 hpushReady)
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (hsloadDecoded :
      (pushBalanceSlotPost s0 hpushReady).decoded =
        some (.StackMemFlow
          (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushReady) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushReady).gasAvailable)
    (hstopReady :
      StepFEReady
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas)
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps)))
    (hstopDecoded :
      (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas).decoded =
        some (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps), none)) :
    ProofForge.Backend.Evm.PowdrExec.runSteps s0 3 =
      .ok
        (stopPost
          (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas),
          (#[] : Array ProofForge.Backend.Evm.PowdrExec.ObservableStep)) :=
  ProofForge.Backend.Evm.PowdrExec.runSteps_of_stepFEPath_done
    (twoSlotReader_getBalance_stepFEPath hpushReady hpushDecoded
      hsloadReady hsloadDecoded hsloadGas hstopReady hstopDecoded)

end ProofForge.Backend.Evm.PowdrExecSmoke
