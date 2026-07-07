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
abbrev ExecutionSegment :=
  ProofForge.Backend.Evm.PowdrExec.ExecutionSegment
abbrev SegmentProvider :=
  ProofForge.Backend.Evm.PowdrExec.SegmentProvider
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

def twoSlotReaderGetBalancePre (s0 : State) : Prop :=
  ∃ (hpushReady : StepFEReady s0 (.Push twoSlotReaderPush1Op))
    (_hpushDecoded :
      s0.decoded =
        some (.Push twoSlotReaderPush1Op,
          some (twoSlotReaderBalanceSlot, 1)))
    (_hsloadReady :
      StepFEReady (pushBalanceSlotPost s0 hpushReady)
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (_hsloadDecoded :
      (pushBalanceSlotPost s0 hpushReady).decoded =
        some (.StackMemFlow
          (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushReady) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushReady).gasAvailable)
    (_hstopReady :
      StepFEReady
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas)
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps)))
    (_hstopDecoded :
      (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady)
        hsloadGas).decoded =
        some (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps), none)),
    True

def twoSlotReaderGetBalancePost (s0 finalState : State) : Prop :=
  ∃ (hpushReady : StepFEReady s0 (.Push twoSlotReaderPush1Op))
    (_hpushDecoded :
      s0.decoded =
        some (.Push twoSlotReaderPush1Op,
          some (twoSlotReaderBalanceSlot, 1)))
    (_hsloadReady :
      StepFEReady (pushBalanceSlotPost s0 hpushReady)
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (_hsloadDecoded :
      (pushBalanceSlotPost s0 hpushReady).decoded =
        some (.StackMemFlow
          (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushReady) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushReady).gasAvailable)
    (_hstopReady :
      StepFEReady
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas)
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps)))
    (_hstopDecoded :
      (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady)
        hsloadGas).decoded =
        some (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps), none)),
    finalState =
      stopPost
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas)

theorem twoSlotReader_getBalance_executionSegment
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
    ExecutionSegment 3 twoSlotReaderGetBalancePost s0
      (stopPost
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas)) := by
  let s1 := pushBalanceSlotPost s0 hpushReady
  let s2 := sloadBalanceSlotPost s1 hsloadGas
  let s3 := stopPost s2
  have hpushStep :
      EvmSemantics.EVM.stepFE s0 = .ok s1 :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_push_data_ok
      (op := twoSlotReaderPush1Op) (value := twoSlotReaderBalanceSlot)
      (argBytes := 1) (widthPred := 0) (by rfl) hpushReady hpushDecoded
  have hsloadStep :
      EvmSemantics.EVM.stepFE s1 = .ok s2 :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_sload_ok
      (rest := s0.stack) hsloadReady hsloadDecoded
      (by
        simp [pushBalanceSlotPost,
          EvmSemantics.EVM.State.replaceStackAndIncrPC])
      hsloadGas
  have hstopStep :
      EvmSemantics.EVM.stepFE s2 = .ok s3 :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_stop_ok
      hstopReady hstopDecoded
  have pushSegment :
      ExecutionSegment 1 (fun _ finalState => finalState = s1) s0 s1 :=
    ProofForge.Backend.Evm.PowdrExec.executionSegment_single
      hpushReady.running hpushStep rfl
  have sloadSegment :
      ExecutionSegment 1 (fun _ finalState => finalState = s2) s1 s2 :=
    ProofForge.Backend.Evm.PowdrExec.executionSegment_single
      hsloadReady.running hsloadStep rfl
  have stopSegment :
      ExecutionSegment 1 (fun _ finalState => finalState = s3) s2 s3 :=
    ProofForge.Backend.Evm.PowdrExec.executionSegment_single
      hstopReady.running hstopStep rfl
  have prefixSegment :
      ExecutionSegment (1 + 1) (fun _ finalState => finalState = s2)
        s0 s2 :=
    ProofForge.Backend.Evm.PowdrExec.executionSegment_append
      (prefixPost := fun _ finalState => finalState = s1)
      (suffixPost := fun _ finalState => finalState = s2)
      (combinedPost := fun _ finalState => finalState = s2)
      (fun _ hsload => hsload) pushSegment sloadSegment
  have fullSegment :
      ExecutionSegment ((1 + 1) + 1) twoSlotReaderGetBalancePost s0 s3 :=
    ProofForge.Backend.Evm.PowdrExec.executionSegment_append
      (prefixPost := fun _ finalState => finalState = s2)
      (suffixPost := fun _ finalState => finalState = s3)
      (combinedPost := twoSlotReaderGetBalancePost)
      (fun _ hstop => by
        rw [hstop]
        exact
          ⟨hpushReady, hpushDecoded, hsloadReady, hsloadDecoded,
            hsloadGas, hstopReady, hstopDecoded, rfl⟩)
      prefixSegment stopSegment
  exact fullSegment

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
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady) hsloadGas)) :=
  (twoSlotReader_getBalance_executionSegment hpushReady hpushDecoded
    hsloadReady hsloadDecoded hsloadGas hstopReady hstopDecoded).path

def twoSlotReaderGetBalanceSegmentProvider :
    SegmentProvider twoSlotReaderGetBalancePre 3
      twoSlotReaderGetBalancePost where
  segment := by
    intro s0 hpre
    rcases hpre with
      ⟨hpushReady, hpushDecoded, hsloadReady, hsloadDecoded,
        hsloadGas, hstopReady, hstopDecoded, _⟩
    refine
      ⟨stopPost
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushReady)
          hsloadGas), ?_⟩
    exact twoSlotReader_getBalance_executionSegment hpushReady hpushDecoded
      hsloadReady hsloadDecoded hsloadGas hstopReady hstopDecoded

theorem twoSlotReader_getBalance_runSteps_from_segmentProvider
    {s0 : State} (hpre : twoSlotReaderGetBalancePre s0) :
    ∃ finalState,
      ProofForge.Backend.Evm.PowdrExec.runSteps s0 3 =
        .ok
          (finalState,
            (#[] : Array ProofForge.Backend.Evm.PowdrExec.ObservableStep)) ∧
      twoSlotReaderGetBalancePost s0 finalState :=
  ProofForge.Backend.Evm.PowdrExec.runSteps_post_of_segmentProvider
    twoSlotReaderGetBalanceSegmentProvider hpre

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
  ProofForge.Backend.Evm.PowdrExec.runSteps_of_executionSegment
    (twoSlotReader_getBalance_executionSegment hpushReady hpushDecoded
      hsloadReady hsloadDecoded hsloadGas hstopReady hstopDecoded)

end ProofForge.Backend.Evm.PowdrExecSmoke
