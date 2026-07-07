import EvmRefinement.PowdrAdapter

/-! Contract-agnostic symbolic execution helpers for powdr EVM.

This module is deliberately free of contract-specific names.  It factors the
repeated top-level `stepFE` branches (running state, precompile dispatch,
stack-cap check, and base-gas check) into reusable opcode dispatch lemmas.
Contract refinements should compose these lemmas instead of hand-deriving
`runBytecode` one bytecode instruction at a time.
-/

namespace ProofForge.Backend.Evm.PowdrExec

set_option linter.unusedSimpArgs false

abbrev State := ProofForge.Backend.Evm.PowdrAdapter.State
abbrev ObservableStep := ProofForge.Backend.Evm.PowdrAdapter.ObservableStep
abbrev StepFEPath := ProofForge.Backend.Evm.PowdrAdapter.StepFEPath
abbrev UInt256 := EvmSemantics.UInt256
abbrev Operation := EvmSemantics.Operation

def runSteps : State → Nat → Except String (State × Array ObservableStep) :=
  ProofForge.Backend.Evm.PowdrAdapter.runBytecode

theorem runSteps_zero (state : State) :
    runSteps state 0 = .ok (state, #[]) := rfl

theorem runSteps_stepFE_succ
    {state nextState finalState : State}
    {observations : Array ObservableStep} {fuel : Nat}
    (hrunning : state.halt = .Running)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState)
    (hrun : runSteps nextState fuel = .ok (finalState, observations)) :
    runSteps state (fuel + 1) = .ok (finalState, observations) := by
  exact ProofForge.Backend.Evm.PowdrAdapter.runBytecode_stepFE_succ
    hrunning hstep hrun

theorem runSteps_of_stepFEPath_done {fuel : Nat} {state finalState : State}
    (path : StepFEPath state fuel finalState) :
    runSteps state fuel = .ok (finalState, (#[] : Array ObservableStep)) := by
  exact ProofForge.Backend.Evm.PowdrAdapter.runBytecode_of_stepFEPath_done path

theorem stepFEPath_single {state nextState : State}
    (hrunning : state.halt = .Running)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    StepFEPath state 1 nextState := by
  exact ProofForge.Backend.Evm.PowdrAdapter.StepFEPath.cons
    hrunning hstep
    (ProofForge.Backend.Evm.PowdrAdapter.StepFEPath.nil nextState)

theorem stepFEPath_append {state midState finalState : State}
    {prefixFuel suffixFuel : Nat}
    (prefixPath : StepFEPath state prefixFuel midState)
    (suffixPath : StepFEPath midState suffixFuel finalState) :
    StepFEPath state (prefixFuel + suffixFuel) finalState := by
  exact ProofForge.Backend.Evm.PowdrAdapter.stepFEPath_append
    prefixPath suffixPath

structure StepFEReady (state : State) (op : Operation) : Prop where
  running : state.halt = .Running
  notPrecompile :
    EvmSemantics.EVM.Precompile.isPrecompile state.executionEnv.fork
      state.executionEnv.codeAddr = false
  stackOk :
    ¬ state.stack.length + op.pushArity > 1024 + op.popArity
  gas :
    EvmSemantics.EVM.Gas.baseCost state.fork op ≤ state.gasAvailable

theorem stepFE_push_dispatch
    {state : State} {op : EvmSemantics.Operation.PushOp}
    {argOpt : Option (UInt256 × Nat)}
    (hready : StepFEReady state (.Push op))
    (hdecoded : state.decoded = some (.Push op, argOpt)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.push state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Push op : Operation)) hready.gas)
        op argOpt := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  unfold EvmSemantics.EVM.stepFE
  simp only [Id.run]
  split
  · split
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas]
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem stepFE_dup_dispatch
    {state : State} {op : EvmSemantics.Operation.DupOp}
    (hready : StepFEReady state (.Dup op))
    (hdecoded : state.decoded = some (.Dup op, none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.dup state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Dup op : Operation)) hready.gas)
        op := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  unfold EvmSemantics.EVM.stepFE
  simp only [Id.run]
  split
  · split
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas]
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem stepFE_swap_dispatch
    {state : State} {op : EvmSemantics.Operation.SwapOp}
    (hready : StepFEReady state (.Swap op))
    (hdecoded : state.decoded = some (.Swap op, none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.swap state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Swap op : Operation)) hready.gas)
        op := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  unfold EvmSemantics.EVM.stepFE
  simp only [Id.run]
  split
  · split
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas]
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem stepFE_stopArith_dispatch
    {state : State} {op : EvmSemantics.Operation.StopArithOps}
    (hready : StepFEReady state (.StopArith op))
    (hdecoded : state.decoded = some (.StopArith op, none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.stopArith state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StopArith op : Operation)) hready.gas)
        op := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  unfold EvmSemantics.EVM.stepFE
  simp only [Id.run]
  split
  · split
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas]
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem stepFE_compBit_dispatch
    {state : State} {op : EvmSemantics.Operation.CompareBitwiseOps}
    (hready : StepFEReady state (.CompBit op))
    (hdecoded : state.decoded = some (.CompBit op, none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.compBit state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.CompBit op : Operation)) hready.gas)
        op := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  unfold EvmSemantics.EVM.stepFE
  simp only [Id.run]
  split
  · split
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas]
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem stepFE_env_dispatch
    {state : State} {op : EvmSemantics.Operation.EnvOps}
    (hready : StepFEReady state (.Env op))
    (hdecoded : state.decoded = some (.Env op, none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.env state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Env op : Operation)) hready.gas)
        op := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  unfold EvmSemantics.EVM.stepFE
  simp only [Id.run]
  split
  · split
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas]
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem stepFE_stackMemFlow_dispatch
    {state : State} {op : EvmSemantics.Operation.StackMemFlowOps}
    (hready : StepFEReady state (.StackMemFlow op))
    (hdecoded : state.decoded = some (.StackMemFlow op, none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.stackMemFlow state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow op : Operation)) hready.gas)
        op := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  unfold EvmSemantics.EVM.stepFE
  simp only [Id.run]
  split
  · split
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas]
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem stepFE_system_dispatch
    {state : State} {op : EvmSemantics.Operation.SystemOps}
    (hready : StepFEReady state (.System op))
    (hdecoded : state.decoded = some (.System op, none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.system state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.System op : Operation)) hready.gas)
        op := by
  rcases hready with ⟨hrunning, hprecompile, hstackOk, hgas⟩
  unfold EvmSemantics.EVM.stepFE
  simp only [Id.run]
  split
  · split
    · rename_i hprecompileActual
      rw [hprecompile] at hprecompileActual
      contradiction
    · simp [hdecoded, hstackOk, hgas]
  · rename_i hnotRunning
    rw [hrunning] at hnotRunning
    contradiction

theorem stepFE_push0_ok
    {state : State} {op : EvmSemantics.Operation.PushOp}
    {argOpt : Option (UInt256 × Nat)}
    (hwidth : op.width.val = 0)
    (hready : StepFEReady state (.Push op))
    (hdecoded : state.decoded = some (.Push op, argOpt)) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Push op : Operation)) hready.gas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.ofNat 0 :: state.stack)) := by
  rw [stepFE_push_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.push
  simp [hwidth, EvmSemantics.UInt256.ofNat]

theorem stepFE_push_data_ok
    {state : State} {op : EvmSemantics.Operation.PushOp}
    {value : UInt256} {argBytes widthPred : Nat}
    (hwidth : op.width.val = widthPred + 1)
    (hready : StepFEReady state (.Push op))
    (hdecoded : state.decoded = some (.Push op, some (value, argBytes))) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Push op : Operation)) hready.gas).replaceStackAndIncrPC
        (value :: state.stack) (pcΔ := argBytes + 1)) := by
  rw [stepFE_push_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.push
  simp [hwidth]

theorem stepFE_dup_ok
    {state : State} {op : EvmSemantics.Operation.DupOp}
    {value : UInt256}
    (hready : StepFEReady state (.Dup op))
    (hdecoded : state.decoded = some (.Dup op, none))
    (hindex : state.stack[op.idx.val]? = some value) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Dup op : Operation)) hready.gas).replaceStackAndIncrPC
        (value :: state.stack)) := by
  rw [stepFE_dup_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.dup
  simp [hindex]

theorem stepFE_swap_ok
    {state : State} {op : EvmSemantics.Operation.SwapOp}
    {stack' : List UInt256}
    (hready : StepFEReady state (.Swap op))
    (hdecoded : state.decoded = some (.Swap op, none))
    (hexchange : state.stack.exchange 0 (op.idx.val + 1) = some stack') :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Swap op : Operation)) hready.gas).replaceStackAndIncrPC
        stack') := by
  rw [stepFE_swap_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.swap
  simp [hexchange]

theorem stepFE_calldataload_ok
    {state : State} {offset : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps)))
    (hdecoded :
      state.decoded =
        some (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps), none))
    (hstack : state.stack = offset :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.Env (.CALLDATALOAD : EvmSemantics.Operation.EnvOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.ofNat
          (EvmSemantics.Data.Bytes.bytesToBigEndianNat
            (EvmSemantics.MachineState.readPadded
              state.executionEnv.calldata offset.toNat 32)) :: rest)) := by
  rw [stepFE_env_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.env
  simp [hstack]

theorem stepFE_eq_ok
    {state : State} {a b : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps)))
    (hdecoded :
      state.decoded =
        some (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = a :: b :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.CompBit (.EQ : EvmSemantics.Operation.CompareBitwiseOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.eq a b :: rest)) := by
  rw [stepFE_compBit_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.compBit
  simp [hstack]

theorem stepFE_shl_ok
    {state : State} {shift value : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps)))
    (hdecoded :
      state.decoded =
        some (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = shift :: value :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.CompBit (.SHL : EvmSemantics.Operation.CompareBitwiseOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.shiftLeft value shift :: rest)) := by
  rw [stepFE_compBit_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.compBit
  simp [hstack]

theorem stepFE_shr_ok
    {state : State} {shift value : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps)))
    (hdecoded :
      state.decoded =
        some (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = shift :: value :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.CompBit (.SHR : EvmSemantics.Operation.CompareBitwiseOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.shiftRight value shift :: rest)) := by
  rw [stepFE_compBit_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.compBit
  simp [hstack]

theorem stepFE_not_ok
    {state : State} {value : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps)))
    (hdecoded :
      state.decoded =
        some (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = value :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.CompBit (.NOT : EvmSemantics.Operation.CompareBitwiseOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.lnot value :: rest)) := by
  rw [stepFE_compBit_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.compBit
  simp [hstack]

theorem stepFE_and_ok
    {state : State} {a b : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps)))
    (hdecoded :
      state.decoded =
        some (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = a :: b :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.CompBit (.AND : EvmSemantics.Operation.CompareBitwiseOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.land a b :: rest)) := by
  rw [stepFE_compBit_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.compBit
  simp [hstack]

theorem stepFE_or_ok
    {state : State} {a b : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps)))
    (hdecoded :
      state.decoded =
        some (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps), none))
    (hstack : state.stack = a :: b :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.CompBit (.OR : EvmSemantics.Operation.CompareBitwiseOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        (EvmSemantics.UInt256.lor a b :: rest)) := by
  rw [stepFE_compBit_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.compBit
  simp [hstack]

theorem stepFE_add_ok
    {state : State} {a b : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StopArith (.ADD : EvmSemantics.Operation.StopArithOps)))
    (hdecoded :
      state.decoded =
        some (.StopArith (.ADD : EvmSemantics.Operation.StopArithOps), none))
    (hstack : state.stack = a :: b :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StopArith (.ADD : EvmSemantics.Operation.StopArithOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        ((a + b) :: rest)) := by
  rw [stepFE_stopArith_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.stopArith
  simp [hstack]

theorem stepFE_sub_ok
    {state : State} {a b : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps)))
    (hdecoded :
      state.decoded =
        some (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps), none))
    (hstack : state.stack = a :: b :: rest) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StopArith (.SUB : EvmSemantics.Operation.StopArithOps) :
              Operation)) hready.gas).replaceStackAndIncrPC
        ((a - b) :: rest)) := by
  rw [stepFE_stopArith_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.stopArith
  simp [hstack]

theorem stepFE_stop_ok
    {state : State}
    (hready :
      StepFEReady state
        (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps)))
    (hdecoded :
      state.decoded =
        some (.StopArith (.STOP : EvmSemantics.Operation.StopArithOps), none)) :
    EvmSemantics.EVM.stepFE state =
      .ok { state with halt := .Success, hReturn := .empty } := by
  rw [stepFE_stopArith_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.stopArith
  rfl

theorem stepFE_jumpdest_ok
    {state : State}
    (hready :
      StepFEReady state
        (.StackMemFlow (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow
          (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps), none)) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow
              (.JUMPDEST : EvmSemantics.Operation.StackMemFlowOps) :
              Operation)) hready.gas).incrPC) := by
  rw [stepFE_stackMemFlow_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.stackMemFlow
  rfl

theorem stepFE_jump_ok
    {state : State} {dest : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = dest :: rest)
    (hvalid :
      EvmSemantics.EVM.Decode.isValidJumpDest state.executionEnv.code
        dest.toNat = true) :
    EvmSemantics.EVM.stepFE state =
      .ok { state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow (.JUMP : EvmSemantics.Operation.StackMemFlowOps) :
              Operation)) hready.gas with
        pc := dest
        stack := rest } := by
  rw [stepFE_stackMemFlow_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.stackMemFlow
  simp [hstack, hvalid]

theorem stepFE_jumpi_taken_ok
    {state : State} {dest cond : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = dest :: cond :: rest)
    (hcond : cond.toNat ≠ 0)
    (hvalid :
      EvmSemantics.EVM.Decode.isValidJumpDest state.executionEnv.code
        dest.toNat = true) :
    EvmSemantics.EVM.stepFE state =
      .ok { state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps) :
              Operation)) hready.gas with
        pc := dest
        stack := rest } := by
  rw [stepFE_stackMemFlow_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.stackMemFlow
  simp [hstack, hcond, hvalid]

theorem stepFE_jumpi_not_taken_ok
    {state : State} {dest cond : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = dest :: cond :: rest)
    (hcond : cond.toNat = 0) :
    EvmSemantics.EVM.stepFE state =
      .ok ((state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow (.JUMPI : EvmSemantics.Operation.StackMemFlowOps) :
              Operation)) hready.gas).replaceStackAndIncrPC rest) := by
  rw [stepFE_stackMemFlow_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.stackMemFlow
  simp [hstack, hcond]

theorem stepFE_sload_ok
    {state : State} {key : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = key :: rest)
    (hgasTotal : EvmSemantics.EVM.Gas.sloadTotal state key ≤ state.gasAvailable) :
    EvmSemantics.EVM.stepFE state =
      .ok ({ (state.consumeGas (EvmSemantics.EVM.Gas.sloadTotal state key)
              hgasTotal) with
          substate := state.substate.addAccessedStorageKey
            (state.executionEnv.address, key) }.replaceStackAndIncrPC
        ((state.accountMap state.executionEnv.address).storage key :: rest)) := by
  rw [stepFE_stackMemFlow_dispatch hready hdecoded]
  unfold EvmSemantics.EVM.stepF.stackMemFlow
  simp [hstack, hgasTotal, EvmSemantics.EVM.State.consumeGas]

theorem stepFE_sload_success_stack_ok
    {state nextState : State} {key : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = key :: rest)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.stack =
      (state.accountMap state.executionEnv.address).storage key :: rest := by
  rw [stepFE_stackMemFlow_dispatch hready hdecoded] at hstep
  unfold EvmSemantics.EVM.stepF.stackMemFlow at hstep
  simp [hstack] at hstep
  by_cases hgasTotal :
      EvmSemantics.EVM.Gas.sloadTotal state key ≤ state.gasAvailable
  · simp [hgasTotal, EvmSemantics.EVM.State.consumeGas,
      EvmSemantics.EVM.State.replaceStackAndIncrPC] at hstep
    cases hstep
    simp [EvmSemantics.EVM.State.consumeGas,
      EvmSemantics.EVM.State.replaceStackAndIncrPC]
  · simp [hgasTotal] at hstep

theorem stepFE_sload_success_callStack_ok
    {state nextState : State} {key : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow (.SLOAD : EvmSemantics.Operation.StackMemFlowOps), none))
    (hstack : state.stack = key :: rest)
    (hstep : EvmSemantics.EVM.stepFE state = .ok nextState) :
    nextState.callStack = state.callStack := by
  rw [stepFE_stackMemFlow_dispatch hready hdecoded] at hstep
  unfold EvmSemantics.EVM.stepF.stackMemFlow at hstep
  simp [hstack] at hstep
  by_cases hgasTotal :
      EvmSemantics.EVM.Gas.sloadTotal state key ≤ state.gasAvailable
  · simp [hgasTotal, EvmSemantics.EVM.State.consumeGas,
      EvmSemantics.EVM.State.replaceStackAndIncrPC] at hstep
    cases hstep
    simp [EvmSemantics.EVM.State.consumeGas,
      EvmSemantics.EVM.State.replaceStackAndIncrPC]
  · simp [hgasTotal] at hstep

theorem stepFE_sstore_dispatch_ok
    {state : State}
    (hready :
      StepFEReady state
        (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps), none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.stackMemFlow state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
              Operation)) hready.gas)
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) := by
  exact stepFE_stackMemFlow_dispatch hready hdecoded

theorem stepF_sstore_ok
    {state gasState : State} {key value : UInt256} {rest : List UInt256}
    (hmut : state.executionEnv.permitStateMutation = true)
    (hsentry :
      EvmSemantics.EVM.Gas.sstoreSentry state.fork gasState.gasAvailable = false)
    (hstack : state.stack = key :: value :: rest)
    (hcost :
      (let addr := state.executionEnv.address
       let acc := state.accountMap addr
       let current := acc.storage key
       let original := state.substate.originalStorage addr key
       EvmSemantics.EVM.Gas.sstoreCost state.fork original current value +
         EvmSemantics.EVM.Gas.sstoreColdSurcharge state key) ≤
        gasState.gasAvailable) :
    EvmSemantics.EVM.stepF.stackMemFlow state gasState
        (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) =
      .ok
        (let addr := state.executionEnv.address
         let acc := state.accountMap addr
         let current := acc.storage key
         let original := state.substate.originalStorage addr key
         let cost :=
           EvmSemantics.EVM.Gas.sstoreCost state.fork original current value +
             EvmSemantics.EVM.Gas.sstoreColdSurcharge state key
         let acc' := { acc with storage := acc.storage.set key value }
         let σ' := state.accountMap.set addr acc'
         let refDelta :=
           EvmSemantics.EVM.Gas.sstoreRefund state.fork original current value
         let rb : Int := (state.substate.refundBalance.toNat : Int) + refDelta
         let rb' : Nat := if rb < 0 then 0 else rb.toNat
         let sub' : EvmSemantics.Substate :=
           { state.substate.addAccessedStorageKey (addr, key) with
             refundBalance := EvmSemantics.UInt256.ofNat rb' }
         ({ (gasState.consumeGas cost hcost) with
             accountMap := σ'
             substate := sub' }.replaceStackAndIncrPC rest)) := by
  unfold EvmSemantics.EVM.stepF.stackMemFlow
  simp [hmut, hsentry, hstack, hcost]

theorem stepFE_sstore_ok
    {state : State} {key value : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps)))
    (hdecoded :
      state.decoded =
        some (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps), none))
    (hmut : state.executionEnv.permitStateMutation = true)
    (hsentry :
      EvmSemantics.EVM.Gas.sstoreSentry state.fork
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
              Operation)) hready.gas).gasAvailable = false)
    (hstack : state.stack = key :: value :: rest)
    (hcost :
      (let addr := state.executionEnv.address
       let acc := state.accountMap addr
       let current := acc.storage key
       let original := state.substate.originalStorage addr key
       EvmSemantics.EVM.Gas.sstoreCost state.fork original current value +
         EvmSemantics.EVM.Gas.sstoreColdSurcharge state key) ≤
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
              Operation)) hready.gas).gasAvailable) :
    EvmSemantics.EVM.stepFE state =
      .ok
        (let gasState := state.consumeGas
            (EvmSemantics.EVM.Gas.baseCost state.fork
              (.StackMemFlow (.SSTORE : EvmSemantics.Operation.StackMemFlowOps) :
                Operation)) hready.gas
         let addr := state.executionEnv.address
         let acc := state.accountMap addr
         let current := acc.storage key
         let original := state.substate.originalStorage addr key
         let cost :=
           EvmSemantics.EVM.Gas.sstoreCost state.fork original current value +
             EvmSemantics.EVM.Gas.sstoreColdSurcharge state key
         let acc' := { acc with storage := acc.storage.set key value }
         let σ' := state.accountMap.set addr acc'
         let refDelta :=
           EvmSemantics.EVM.Gas.sstoreRefund state.fork original current value
         let rb : Int := (state.substate.refundBalance.toNat : Int) + refDelta
         let rb' : Nat := if rb < 0 then 0 else rb.toNat
         let sub' : EvmSemantics.Substate :=
           { state.substate.addAccessedStorageKey (addr, key) with
             refundBalance := EvmSemantics.UInt256.ofNat rb' }
         ({ (gasState.consumeGas cost hcost) with
             accountMap := σ'
             substate := sub' }.replaceStackAndIncrPC rest)) := by
  rw [stepFE_sstore_dispatch_ok hready hdecoded]
  exact stepF_sstore_ok hmut hsentry hstack hcost

theorem stepFE_return_dispatch_ok
    {state : State}
    (hready :
      StepFEReady state
        (.System (.RETURN : EvmSemantics.Operation.SystemOps)))
    (hdecoded :
      state.decoded =
        some (.System (.RETURN : EvmSemantics.Operation.SystemOps), none)) :
    EvmSemantics.EVM.stepFE state =
      EvmSemantics.EVM.stepF.system state
        (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.System (.RETURN : EvmSemantics.Operation.SystemOps) :
              Operation)) hready.gas)
        (.RETURN : EvmSemantics.Operation.SystemOps) := by
  exact stepFE_system_dispatch hready hdecoded

theorem stepF_return_ok
    {state gasState : State} {offset size : UInt256} {rest : List UInt256}
    (hstack : state.stack = offset :: size :: rest)
    (hmem : gasState.canExpandMemory offset.toNat size.toNat) :
    EvmSemantics.EVM.stepF.system state gasState
        (.RETURN : EvmSemantics.Operation.SystemOps) =
      .ok { gasState.consumeMemExp offset.toNat size.toNat hmem with
        halt := .Returned
        hReturn := EvmSemantics.MachineState.readPadded state.memory
          offset.toNat size.toNat
        stack := rest } := by
  unfold EvmSemantics.EVM.stepF.system EvmSemantics.EVM.chargeMem
  simp [hstack, hmem]

theorem stepFE_return_ok
    {state : State} {offset size : UInt256} {rest : List UInt256}
    (hready :
      StepFEReady state
        (.System (.RETURN : EvmSemantics.Operation.SystemOps)))
    (hdecoded :
      state.decoded =
        some (.System (.RETURN : EvmSemantics.Operation.SystemOps), none))
    (hstack : state.stack = offset :: size :: rest)
    (hmem :
      (state.consumeGas
        (EvmSemantics.EVM.Gas.baseCost state.fork
          (.System (.RETURN : EvmSemantics.Operation.SystemOps) :
            Operation)) hready.gas).canExpandMemory offset.toNat size.toNat) :
    EvmSemantics.EVM.stepFE state =
      .ok { (state.consumeGas
          (EvmSemantics.EVM.Gas.baseCost state.fork
            (.System (.RETURN : EvmSemantics.Operation.SystemOps) :
              Operation)) hready.gas).consumeMemExp offset.toNat size.toNat hmem with
        halt := .Returned
        hReturn := EvmSemantics.MachineState.readPadded state.memory
          offset.toNat size.toNat
        stack := rest } := by
  rw [stepFE_return_dispatch_ok hready hdecoded]
  exact stepF_return_ok hstack hmem

end ProofForge.Backend.Evm.PowdrExec
