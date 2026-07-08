import ProofForge.Backend.WasmNear.WasmInterpreter

/-!
Chain-agnostic symbolic-execution helpers for the in-Lean Wasm interpreter.

This is the first WASM-1 proof surface: generic state-effect lemmas over the
Wasm stack machine and host-neutral tables. Contract-specific refinement work
should compose these helpers rather than inspect Counter/ValueVault programs.

`WasmInterpreter.evalInsn` is currently a mutual `partial def`, so per-instruction
lemmas over that evaluator need a later refactor that factors a total, reducible
core step out of the interpreter. Keep NEAR/CosmWasm host facts out of this file;
host-specific lemmas belong in thin host modules on top of this core.
-/

namespace ProofForge.Backend.WasmNear.WasmExec

open ProofForge.Backend.WasmNear.WasmInterpreter

abbrev Bytes := WasmInterpreter.Bytes
abbrev LinearMemory := WasmInterpreter.LinearMemory
abbrev Locals := WasmInterpreter.Locals
abbrev Globals := WasmInterpreter.Globals
abbrev Registers := WasmInterpreter.Registers
abbrev Storage := WasmInterpreter.Storage
abbrev HostState := WasmInterpreter.HostState
abbrev State := WasmInterpreter.WasmState

theorem valueStack_stackPush (state : State) (value : Nat) :
    (stackPush state value).valueStack = state.valueStack.push value := rfl

theorem locals_stackPush (state : State) (value : Nat) :
    (stackPush state value).locals = state.locals := rfl

theorem globals_stackPush (state : State) (value : Nat) :
    (stackPush state value).globals = state.globals := rfl

theorem memory_stackPush (state : State) (value : Nat) :
    (stackPush state value).memory = state.memory := rfl

theorem host_stackPush (state : State) (value : Nat) :
    (stackPush state value).host = state.host := rfl

theorem stackPeek_stackPush (state : State) (value : Nat) :
    stackPeek (stackPush state value) = .ok value := by
  simp [stackPeek, stackPush]

theorem stackPop_stackPush (state : State) (value : Nat) :
    stackPop (stackPush state value) = .ok (value, state) := by
  simp [stackPop, stackPush]

theorem lookupLocal_writeLocal_same (locals : Locals) (name : String) (value : Nat) :
    lookupLocal? (writeLocal locals name value) name = some value := by
  simp [lookupLocal?, writeLocal]

theorem lookupGlobal_writeGlobal_same (globals : Globals) (name : String) (value : Nat) :
    lookupGlobal? (writeGlobal globals name value) name = some value := by
  simp [lookupGlobal?, writeGlobal]

theorem lookupRegister_writeRegister_same
    (registers : Registers) (id : Nat) (bytes : Bytes) :
    lookupRegister? (writeRegister registers id bytes) id = some bytes := by
  simp [lookupRegister?, writeRegister]

theorem lookupStorage_writeStorage_same (storage : Storage) (key value : Bytes) :
    lookupStorage? (writeStorage storage key value) key = some value := by
  simp [lookupStorage?, writeStorage]

theorem host_beginCall_input (host : HostState) (input : Bytes) :
    (host.beginCall input).input = input := rfl

theorem host_beginCall_registers (host : HostState) (input : Bytes) :
    (host.beginCall input).registers = #[] := rfl

theorem host_beginCall_returnValue (host : HostState) (input : Bytes) :
    (host.beginCall input).returnValue = #[] := rfl

end ProofForge.Backend.WasmNear.WasmExec
