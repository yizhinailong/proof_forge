import ProofForge.Backend.WasmNear.NearHost

/-! ## NEAR host-model smoke

Pins the first Wasm host instantiation layer. The generic `WasmExec` hook stays
host-neutral; these checks prove NEAR storage/register/return/context host ops
compose through that hook.
-/

namespace ProofForge.Tests.WasmNearHost

open ProofForge.Backend.WasmNear.WasmInterpreter
open ProofForge.Backend.WasmNear.NearHost

abbrev Bytes := ProofForge.Backend.WasmNear.NearHost.Bytes
abbrev State := ProofForge.Backend.WasmNear.NearHost.State

def key : Bytes := #[1, 2, 3]
def value : Bytes := #[9, 8, 7]

def storedState : State :=
  { memory := writeBytes (writeBytes #[] 10 key) 20 value
    host := { storage := #[(key, value)], signerAccountId := #[42], attachedDeposit := 55 } }

theorem storedState_read_value :
    readBytes storedState.memory 20 3 = value := by
  native_decide

example : True := by
  have _ := @runHostCall_near_eq_hook
  have _ := @nearHost_input_ok
  have _ := @nearHost_read_register_hit_ok
  have _ := @nearHost_read_register_miss_ok
  have _ := @nearHost_storage_read_hit_ok
  have _ := @nearHost_storage_read_miss_ok
  have _ := @nearHost_storage_write_fresh_ok
  have _ := @nearHost_storage_write_replace_ok
  have _ := @nearHost_value_return_ok
  have _ := @nearHost_log_utf8_ok
  have _ := @nearHost_block_index_ok
  have _ := @nearHost_signer_account_id_ok
  have _ := @nearHost_attached_deposit_ok
  have _ := @nearHost_hook_ok
  have _ := @runHostCall_near_input_stack_ok
  have _ := @runHostCall_near_storage_read_hit_stack_ok
  have _ := @runHostCall_near_storage_read_miss_stack_ok
  have _ := @runHostCall_near_storage_write_fresh_stack_ok
  have _ := @runHostCall_near_storage_write_replace_stack_ok
  have _ := @runHostCall_near_value_return_stack_ok
  have _ := @runHostCall_near_attached_deposit_stack_ok
  have _ := @nearHost_storage_read_after_write_same
  exact True.intro

theorem run_host_storage_read_hit_sample :
    runHostCall "storage_read"
        (stackPush (stackPush (stackPush storedState 3) 10) 0) =
      .ok (stackPush
        { storedState with
          host := { storedState.host with
            registers := writeRegister storedState.host.registers 0 value } }
        1) := by
  exact runHostCall_near_storage_read_hit_stack_ok storedState 3 10 0 value rfl
    (by native_decide)

theorem storage_read_hit_sample :
    runNearHostCall "storage_read" #[3, 10, 0] storedState =
      .ok (stackPush
        { storedState with
          host := { storedState.host with
            registers := writeRegister storedState.host.registers 0 value } }
        1) := by
  exact nearHost_storage_read_hit_ok storedState 3 10 0 value (by native_decide)

theorem value_return_sample :
    runNearHostCall "value_return" #[3, 20] storedState =
      .ok { storedState with host := { storedState.host with returnValue := value } } := by
  rw [storedState_read_value.symm]
  exact nearHost_value_return_ok storedState 3 20

theorem run_host_value_return_sample :
    runHostCall "value_return" (stackPush (stackPush storedState 3) 20) =
      .ok { storedState with host := { storedState.host with returnValue := value } } := by
  rw [storedState_read_value.symm]
  exact runHostCall_near_value_return_stack_ok storedState 3 20 rfl

theorem attached_deposit_sample :
    runNearHostCall "attached_deposit" #[] storedState =
      .ok (stackPush storedState 55) := by
  exact nearHost_attached_deposit_ok storedState

theorem run_host_attached_deposit_sample :
    runHostCall "attached_deposit" storedState =
      .ok (stackPush storedState 55) := by
  exact runHostCall_near_attached_deposit_stack_ok storedState rfl

end ProofForge.Tests.WasmNearHost

def main : IO UInt32 := do
  IO.println "wasm-near-host-smoke: NEAR host hook lemmas checked"
  return 0
