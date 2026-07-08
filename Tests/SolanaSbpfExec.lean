import ProofForge.Backend.Solana.SbpfExec
import ProofForge.Backend.Solana.SbpfExecSmoke

/-! Contract-agnostic sBPF step-lemma smoke (SOL-1 active surface). -/

namespace ProofForge.Tests.SolanaSbpfExec

open ProofForge.Backend.Solana.SbpfExec
open ProofForge.Backend.Solana.SbpfExecSmoke

example : True := by
  have _ := @step_mov64_imm_ok
  have _ := @step_mov32_imm_ok
  have _ := @step_add64_reg_ok
  have _ := @step_add64_imm_ok
  have _ := @step_sub64_reg_ok
  have _ := @step_sub64_imm_ok
  have _ := @step_mul64_reg_ok
  have _ := @step_div64_reg_ok
  have _ := @step_mod64_reg_ok
  have _ := @step_lsh64_reg_ok
  have _ := @step_rsh64_reg_ok
  have _ := @step_ldxdw_ok
  have _ := @step_ldxb_ok
  have _ := @step_ldxw_ok
  have _ := @step_stdw_ok
  have _ := @step_stxdw_ok
  have _ := @step_xor64_reg_ok
  have _ := @step_xor64_imm_ok
  have _ := @step_jge_reg_taken_ok
  have _ := @step_jlt_imm_taken_ok
  have _ := @step_jgt_reg_taken_ok
  have _ := @step_jle_reg_taken_ok
  have _ := @step_exit_ok
  have _ := @step_syscall_set_return_data_ok
  have _ := @runSteps_of_stepPath_done
  have _ := @ProofForge.Backend.Solana.SbpfExec.ReadyOpcodeAt
  have _ := @ProofForge.Backend.Solana.SbpfExec.StepReductionChain
  have _ := @ProofForge.Backend.Solana.SbpfExec.ReductionChainProvider
  have _ := @runSteps_of_reductionChain
  have _ := @reduction_mov64_imm_at_ok
  have _ := @reduction_and64_reg_at_ok
  have _ := @reduction_or64_reg_at_ok
  have _ := @reduction_add64_imm_at_ok
  have _ := @reduction_sub64_imm_at_ok
  have _ := @reduction_mul64_reg_at_ok
  have _ := @reduction_div64_reg_at_ok
  have _ := @reduction_mod64_reg_at_ok
  have _ := @reduction_lsh64_reg_at_ok
  have _ := @reduction_rsh64_reg_at_ok
  have _ := @reduction_xor64_reg_at_ok
  have _ := @reduction_xor64_imm_at_ok
  have _ := @reduction_ldxb_at_ok
  have _ := @reduction_ldxw_at_ok
  have _ := @reduction_stdw_at_ok
  have _ := @reduction_jeq_imm_taken_at_ok
  have _ := @reduction_jeq_reg_taken_at_ok
  have _ := @reduction_jne_imm_taken_at_ok
  have _ := @reduction_jne_reg_taken_at_ok
  have _ := @reduction_jge_reg_taken_at_ok
  have _ := @reduction_jlt_imm_taken_at_ok
  have _ := @reduction_jgt_reg_taken_at_ok
  have _ := @reduction_jle_reg_taken_at_ok
  have _ := @loweredOpcodeSet_covered_by_sbpfExec
  have _ := @smoke_runSteps
  have _ := @smoke_runSteps_via_provider
  have _ := @jump_taken_reductionChain
  have _ := @jeq_taken_reductionChain
  have _ := @smoke_jump_jne_taken_runSteps
  have _ := @smoke_jump_jeq_taken_runSteps
  have _ := @smoke_jump_jne_taken_runSteps_via_provider
  have _ := @smoke_jump_jeq_taken_runSteps_via_provider
  exact True.intro

end ProofForge.Tests.SolanaSbpfExec

def main : IO UInt32 := do
  IO.println "solana-sbpf-exec: generic step lemmas checked"
  return 0
