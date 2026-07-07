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
abbrev StepFEReduction := ProofForge.Backend.Evm.PowdrExec.StepFEReduction
abbrev ReadyOpcodeAt := ProofForge.Backend.Evm.PowdrExec.ReadyOpcodeAt
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

def twoSlotReaderCode : ByteArray :=
  ByteArray.mk #[0x60, 0x01, 0x54, 0x00]

theorem twoSlotReaderCode_decode_push_balance :
    EvmSemantics.EVM.Decode.decodeAt twoSlotReaderCode 0 =
      some (.Push twoSlotReaderPush1Op,
        some (twoSlotReaderBalanceSlot, 1)) := by
  native_decide

theorem twoSlotReaderCode_decode_sload :
    EvmSemantics.EVM.Decode.decodeAt twoSlotReaderCode 2 =
      some (.StackMemFlow
        (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none) := by
  native_decide

theorem twoSlotReaderCode_decode_stop :
    EvmSemantics.EVM.Decode.decodeAt twoSlotReaderCode 3 =
      some (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps), none) := by
  native_decide

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
  ∃ (hpushAt :
      ReadyOpcodeAt twoSlotReaderCode 0 (.Push twoSlotReaderPush1Op)
        (some (twoSlotReaderBalanceSlot, 1)) s0)
    (_hsloadAt :
      ReadyOpcodeAt twoSlotReaderCode 2
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps))
        none (pushBalanceSlotPost s0 hpushAt.ready))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushAt.ready) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushAt.ready).gasAvailable)
    (_hstopAt :
      ReadyOpcodeAt twoSlotReaderCode 3
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps))
        none
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready)
          hsloadGas)),
    True

def twoSlotReaderGetBalancePost (s0 finalState : State) : Prop :=
  ∃ (hpushAt :
      ReadyOpcodeAt twoSlotReaderCode 0 (.Push twoSlotReaderPush1Op)
        (some (twoSlotReaderBalanceSlot, 1)) s0)
    (_hsloadAt :
      ReadyOpcodeAt twoSlotReaderCode 2
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps))
        none (pushBalanceSlotPost s0 hpushAt.ready))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushAt.ready) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushAt.ready).gasAvailable)
    (_hstopAt :
      ReadyOpcodeAt twoSlotReaderCode 3
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps))
        none
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready)
          hsloadGas)),
    finalState =
      stopPost
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready) hsloadGas)

theorem twoSlotReader_getBalance_executionSegment
    {s0 : State}
    (hpushAt :
      ReadyOpcodeAt twoSlotReaderCode 0 (.Push twoSlotReaderPush1Op)
        (some (twoSlotReaderBalanceSlot, 1)) s0)
    (hsloadAt :
      ReadyOpcodeAt twoSlotReaderCode 2
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps))
        none (pushBalanceSlotPost s0 hpushAt.ready))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushAt.ready) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushAt.ready).gasAvailable)
    (hstopAt :
      ReadyOpcodeAt twoSlotReaderCode 3
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps))
        none
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready)
          hsloadGas)) :
    ExecutionSegment 3 twoSlotReaderGetBalancePost s0
      (stopPost
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready) hsloadGas)) := by
  let s1 := pushBalanceSlotPost s0 hpushAt.ready
  let s2 := sloadBalanceSlotPost s1 hsloadGas
  let s3 := stopPost s2
  have hpushStep :
      EvmSemantics.EVM.stepFE s0 = .ok s1 :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_push_data_at_ok
      (op := twoSlotReaderPush1Op) (value := twoSlotReaderBalanceSlot)
      (argBytes := 1) (widthPred := 0) hpushAt (by rfl)
  have hsloadStep :
      EvmSemantics.EVM.stepFE s1 = .ok s2 :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_sload_at_ok
      (rest := s0.stack) hsloadAt
      (by
        simp [pushBalanceSlotPost,
          EvmSemantics.EVM.State.replaceStackAndIncrPC])
      hsloadGas
  have hstopStep :
      EvmSemantics.EVM.stepFE s2 = .ok s3 :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_stop_at_ok hstopAt
  exact ProofForge.Backend.Evm.PowdrExec.executionSegment_three_reductions
    ({ running := hpushAt.ready.running, step := hpushStep } : StepFEReduction s0 s1)
    ({ running := hsloadAt.ready.running, step := hsloadStep } : StepFEReduction s1 s2)
    ({ running := hstopAt.ready.running, step := hstopStep } : StepFEReduction s2 s3)
    (by
      exact
        ⟨hpushAt, hsloadAt, hsloadGas, hstopAt, rfl⟩)

theorem twoSlotReader_getBalance_stepFEPath
    {s0 : State}
    (hpushAt :
      ReadyOpcodeAt twoSlotReaderCode 0 (.Push twoSlotReaderPush1Op)
        (some (twoSlotReaderBalanceSlot, 1)) s0)
    (hsloadAt :
      ReadyOpcodeAt twoSlotReaderCode 2
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps))
        none (pushBalanceSlotPost s0 hpushAt.ready))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushAt.ready) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushAt.ready).gasAvailable)
    (hstopAt :
      ReadyOpcodeAt twoSlotReaderCode 3
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps))
        none
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready)
          hsloadGas)) :
    StepFEPath s0 3
      (stopPost
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready) hsloadGas)) :=
  (twoSlotReader_getBalance_executionSegment hpushAt
    hsloadAt hsloadGas hstopAt).path

def twoSlotReaderGetBalanceSegmentProvider :
    SegmentProvider twoSlotReaderGetBalancePre 3
      twoSlotReaderGetBalancePost where
  segment := by
    intro s0 hpre
    rcases hpre with
      ⟨hpushAt, hsloadAt, hsloadGas, hstopAt, _⟩
    refine
      ⟨stopPost
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready)
          hsloadGas), ?_⟩
    exact twoSlotReader_getBalance_executionSegment hpushAt
      hsloadAt hsloadGas hstopAt

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
    (hpushAt :
      ReadyOpcodeAt twoSlotReaderCode 0 (.Push twoSlotReaderPush1Op)
        (some (twoSlotReaderBalanceSlot, 1)) s0)
    (hsloadAt :
      ReadyOpcodeAt twoSlotReaderCode 2
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps))
        none (pushBalanceSlotPost s0 hpushAt.ready))
    (hsloadGas :
      EvmSemantics.EVM.Gas.sloadTotal
          (pushBalanceSlotPost s0 hpushAt.ready) twoSlotReaderBalanceSlot ≤
        (pushBalanceSlotPost s0 hpushAt.ready).gasAvailable)
    (hstopAt :
      ReadyOpcodeAt twoSlotReaderCode 3
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps))
        none
        (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready)
          hsloadGas)) :
    ProofForge.Backend.Evm.PowdrExec.runSteps s0 3 =
      .ok
        (stopPost
          (sloadBalanceSlotPost (pushBalanceSlotPost s0 hpushAt.ready) hsloadGas),
          (#[] : Array ProofForge.Backend.Evm.PowdrExec.ObservableStep)) :=
  ProofForge.Backend.Evm.PowdrExec.runSteps_of_executionSegment
    (twoSlotReader_getBalance_executionSegment hpushAt
      hsloadAt hsloadGas hstopAt)

theorem mstore_word_runSteps
    {s0 : State} {offset value : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady s0
        (.StackMemFlow (.MSTORE : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      s0.decoded =
        some (.StackMemFlow (.MSTORE : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : s0.stack = offset :: value :: rest)
    (hmem :
      (s0.consumeGas
        (EvmSemantics.EVM.Gas.baseCost s0.fork
          (.StackMemFlow (.MSTORE : EvmSemantics.Operation.StackMemFlowOps) :
            Operation)) hready.gas).canExpandMemory offset.toNat 32) :
    ProofForge.Backend.Evm.PowdrExec.runSteps s0 1 =
      .ok
        (({ (s0.consumeGas
          (EvmSemantics.EVM.Gas.baseCost s0.fork
            (.StackMemFlow (.MSTORE : EvmSemantics.Operation.StackMemFlowOps) :
              Operation)) hready.gas).consumeMemExp offset.toNat 32 hmem with
          toMachineState :=
            EvmSemantics.MachineState.mstore
              ((s0.consumeGas
                (EvmSemantics.EVM.Gas.baseCost s0.fork
                  (.StackMemFlow (.MSTORE : EvmSemantics.Operation.StackMemFlowOps) :
                    Operation)) hready.gas).consumeMemExp offset.toNat 32 hmem).toMachineState
              offset value }.replaceStackAndIncrPC rest),
          (#[] : Array ProofForge.Backend.Evm.PowdrExec.ObservableStep)) := by
  have hstep :=
    ProofForge.Backend.Evm.PowdrExec.stepFE_mstore_ok
      hready hdecoded hstack hmem
  exact ProofForge.Backend.Evm.PowdrExec.runSteps_of_stepFEPath_done
    (ProofForge.Backend.Evm.PowdrExec.stepFEPath_single
      hready.running hstep)

end ProofForge.Backend.Evm.PowdrExecSmoke
