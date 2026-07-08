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

set_option linter.unusedSimpArgs false

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

theorem evalPlain_unary_stackPush
    (state : State) (name : String) (value result : Nat)
    (happly : applyUnaryPlain name value = some result) :
    evalPlain (stackPush state value) name = .ok (stackPush state result) := by
  unfold evalPlain
  simp [Bind.bind, Except.bind, stackPeek_stackPush, stackPop_stackPush, happly]

theorem evalPlain_binary_stackPush
    (state : State) (name : String) (lhs rhs result : Nat)
    (hunary : applyUnaryPlain name rhs = none)
    (happly : applyBinaryPlain name lhs rhs = some result) :
    evalPlain (stackPush (stackPush state lhs) rhs) name =
      .ok (stackPush state result) := by
  unfold evalPlain
  simp [Bind.bind, Except.bind, stackPeek_stackPush, stackPop_stackPush, hunary, happly]

theorem execDrop_stackPush (state : State) (value : Nat) :
    execDrop (stackPush state value) = .ok state := by
  simp [execDrop, stackPop_stackPush, Bind.bind, Except.bind]

theorem execConst_ok (state : State) (text : String) (value : Nat)
    (hvalue : natValue? text = .ok value) :
    execConst state text = .ok (stackPush state value) := by
  simp [execConst, hvalue, Bind.bind, Except.bind]

theorem execLocalGet_ok (state : State) (name : String) (value : Nat)
    (hlookup : lookupLocal? state.locals name = some value) :
    execLocalGet state name = .ok (stackPush state value) := by
  simp [execLocalGet, hlookup]

theorem execLocalSet_stackPush (state : State) (name : String) (value : Nat) :
    execLocalSet (stackPush state value) name =
      .ok { state with locals := writeLocal state.locals name value } := by
  simp [execLocalSet, stackPop_stackPush, Bind.bind, Except.bind]

theorem execLocalTee_stackPush (state : State) (name : String) (value : Nat) :
    execLocalTee (stackPush state value) name =
      .ok { stackPush state value with
        locals := writeLocal state.locals name value } := by
  simp [execLocalTee, stackPeek_stackPush, locals_stackPush, Bind.bind, Except.bind]

theorem execGlobalGet_ok (state : State) (name : String) (value : Nat)
    (hlookup : lookupGlobal? state.globals name = some value) :
    execGlobalGet state name = .ok (stackPush state value) := by
  simp [execGlobalGet, hlookup]

theorem execGlobalSet_stackPush (state : State) (name : String) (value : Nat) :
    execGlobalSet (stackPush state value) name =
      .ok { state with globals := writeGlobal state.globals name value } := by
  simp [execGlobalSet, stackPop_stackPush, Bind.bind, Except.bind]

theorem execLoad_stackPush
    (state : State) (name : String) (offset ptr byteCount : Nat)
    (hload : loadByteCount name = .ok byteCount) :
    execLoad (stackPush state ptr) name offset =
      .ok (stackPush state (readNatLE state.memory (ptr + offset) byteCount)) := by
  simp [execLoad, stackPop_stackPush, hload, Bind.bind, Except.bind]

theorem execStore_stackPush
    (state : State) (name : String) (offset ptr value byteCount : Nat)
    (hstore : storeByteCount name = .ok byteCount) :
    execStore (stackPush (stackPush state ptr) value) name offset =
      .ok { state with memory := writeNatLE state.memory (ptr + offset) byteCount value } := by
  simp [execStore, stackPop_stackPush, hstore, Bind.bind, Except.bind]

theorem runHostCallWith_ok
    (arity : String → Except String Nat)
    (run : String → Array Nat → State → Except String State)
    (name : String) (state argsState finalState : State)
    (argCount : Nat) (args : Array Nat)
    (harity : arity name = .ok argCount)
    (hsplit : splitStackArgs state argCount = .ok (args, argsState))
    (hrun : run name args argsState = .ok finalState) :
    runHostCallWith arity run name state = .ok finalState := by
  simp [runHostCallWith, harity, hsplit, hrun, Bind.bind, Except.bind]

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
