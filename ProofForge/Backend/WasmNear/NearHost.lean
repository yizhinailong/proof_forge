import ProofForge.Backend.WasmNear.WasmExec

/-!
NEAR host-model lemmas for the generic Wasm execution core.

`WasmExec.lean` stays chain-agnostic: it proves stack/local/memory effects and
the host-call hook. This file is the first host instantiation layer. Later
CosmWasm/Soroban-style hosts should mirror this shape without changing the
generic Wasm core.
-/

namespace ProofForge.Backend.WasmNear.NearHost

open ProofForge.Backend.WasmNear.WasmInterpreter
open ProofForge.Backend.WasmNear.WasmExec

set_option linter.unusedSimpArgs false

abbrev Bytes := WasmExec.Bytes
abbrev Storage := WasmExec.Storage
abbrev State := WasmExec.State

theorem runHostCall_near_eq_hook (state : State) (name : String)
    (hbridge : state.host.bridge = .near) :
    runHostCall name state =
      runHostCallWith (hostArity .near) runNearHostCall name state := by
  unfold runHostCall
  rw [hbridge]

theorem nearHost_input_ok (state : State) (registerId : Nat) :
    runNearHostCall "input" #[registerId] state =
      .ok { state with
        host := { state.host with
          registers := writeRegister state.host.registers registerId state.host.input } } := by
  rfl

theorem nearHost_read_register_hit_ok
    (state : State) (registerId ptr : Nat) (bytes : Bytes)
    (hlookup : lookupRegister? state.host.registers registerId = some bytes) :
    runNearHostCall "read_register" #[registerId, ptr] state =
      .ok { state with memory := writeBytes state.memory ptr bytes } := by
  simp [runNearHostCall, hostReadRegister, hlookup]

theorem nearHost_read_register_miss_ok
    (state : State) (registerId ptr : Nat)
    (hlookup : lookupRegister? state.host.registers registerId = none) :
    runNearHostCall "read_register" #[registerId, ptr] state = .ok state := by
  simp [runNearHostCall, hostReadRegister, hlookup]

theorem nearHost_storage_read_hit_ok
    (state : State) (keyLen keyPtr registerId : Nat) (value : Bytes)
    (hlookup :
      lookupStorage? state.host.storage (readBytes state.memory keyPtr keyLen) = some value) :
    runNearHostCall "storage_read" #[keyLen, keyPtr, registerId] state =
      .ok (stackPush
        { state with
          host := { state.host with
            registers := writeRegister state.host.registers registerId value } }
        1) := by
  simp [runNearHostCall, hlookup]

theorem nearHost_storage_read_miss_ok
    (state : State) (keyLen keyPtr registerId : Nat)
    (hlookup :
      lookupStorage? state.host.storage (readBytes state.memory keyPtr keyLen) = none) :
    runNearHostCall "storage_read" #[keyLen, keyPtr, registerId] state =
      .ok (stackPush state 0) := by
  simp [runNearHostCall, hlookup]

theorem nearHost_storage_write_fresh_ok
    (state : State) (keyLen keyPtr valueLen valuePtr registerId : Nat)
    (hlookup :
      lookupStorage? state.host.storage (readBytes state.memory keyPtr keyLen) = none) :
    runNearHostCall "storage_write"
        #[keyLen, keyPtr, valueLen, valuePtr, registerId] state =
      .ok (stackPush
        { state with
          host := { state.host with
            storage :=
              writeStorage state.host.storage
                (readBytes state.memory keyPtr keyLen)
                (readBytes state.memory valuePtr valueLen),
            registers := state.host.registers } }
        0) := by
  simp [runNearHostCall, hlookup]

theorem nearHost_storage_write_replace_ok
    (state : State) (keyLen keyPtr valueLen valuePtr registerId : Nat)
    (old : Bytes)
    (hlookup :
      lookupStorage? state.host.storage (readBytes state.memory keyPtr keyLen) = some old) :
    runNearHostCall "storage_write"
        #[keyLen, keyPtr, valueLen, valuePtr, registerId] state =
      .ok (stackPush
        { state with
          host := { state.host with
            storage :=
              writeStorage state.host.storage
                (readBytes state.memory keyPtr keyLen)
                (readBytes state.memory valuePtr valueLen),
            registers := writeRegister state.host.registers registerId old } }
        1) := by
  simp [runNearHostCall, hlookup]

theorem nearHost_value_return_ok (state : State) (len ptr : Nat) :
    runNearHostCall "value_return" #[len, ptr] state =
      .ok { state with
        host := { state.host with returnValue := readBytes state.memory ptr len } } := by
  rfl

theorem nearHost_log_utf8_ok (state : State) (len ptr : Nat) :
    runNearHostCall "log_utf8" #[len, ptr] state =
      .ok { state with
        host := { state.host with
          logs := state.host.logs.push (readBytes state.memory ptr len) } } := by
  rfl

theorem nearHost_block_index_ok (state : State) :
    runNearHostCall "block_index" #[] state =
      .ok (stackPush state state.host.blockIndex) := by
  rfl

theorem nearHost_signer_account_id_ok (state : State) (registerId : Nat) :
    runNearHostCall "signer_account_id" #[registerId] state =
      .ok { state with
        host := { state.host with
          registers :=
            writeRegister state.host.registers registerId state.host.signerAccountId } } := by
  rfl

theorem nearHost_attached_deposit_ok (state : State) :
    runNearHostCall "attached_deposit" #[] state =
      .ok (stackPush state state.host.attachedDeposit) := by
  rfl

theorem nearHost_hook_ok
    (name : String) (state argsState finalState : State)
    (argCount : Nat) (args : Array Nat)
    (harity : hostArity .near name = .ok argCount)
    (hsplit : splitStackArgs state argCount = .ok (args, argsState))
    (hrun : runNearHostCall name args argsState = .ok finalState) :
    runHostCallWith (hostArity .near) runNearHostCall name state = .ok finalState :=
  runHostCallWith_ok (hostArity .near) runNearHostCall name state argsState
    finalState argCount args harity hsplit hrun

theorem nearHost_storage_read_after_write_same
    (storage : NearHost.Storage) (key value : Bytes) :
    lookupStorage? (writeStorage storage key value) key = some value :=
  lookupStorage_writeStorage_same storage key value

end ProofForge.Backend.WasmNear.NearHost
