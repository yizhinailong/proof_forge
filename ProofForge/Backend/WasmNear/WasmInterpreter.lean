import ProofForge.Backend.Refinement.Core
import ProofForge.Backend.WasmNear.EmitWat
import ProofForge.Backend.WasmNear.Layout
import ProofForge.Backend.WasmNear.Memory
import ProofForge.Target.HostBridge

namespace ProofForge.Backend.WasmNear.WasmInterpreter

open ProofForge.IR
open ProofForge.Backend.Refinement
open ProofForge.Compiler.Wasm
open ProofForge.Backend.WasmNear.EmitWat
open ProofForge.Backend.WasmNear.Layout
open ProofForge.Backend.WasmNear.Memory

abbrev Bytes := Array Nat
abbrev LinearMemory := Array (Nat × Nat)
abbrev Locals := Array (String × Nat)
abbrev Registers := Array (Nat × Bytes)
abbrev Storage := Array (Bytes × Bytes)
abbrev WasmModule := ProofForge.Compiler.Wasm.Module

def defaultFuel : Nat := 5000

def writeByte (memory : LinearMemory) (addr value : Nat) : LinearMemory :=
  (memory.filter (fun entry => entry.fst != addr)).push (addr, value % 256)

def readByte (memory : LinearMemory) (addr : Nat) : Nat :=
  match memory.find? (fun entry => entry.fst == addr) with
  | some entry => entry.snd
  | none => 0

def writeBytes (memory : LinearMemory) (ptr : Nat) (bytes : Bytes) : LinearMemory := Id.run do
  let mut memory := memory
  for byte in bytes, idx in [0:bytes.size] do
    memory := writeByte memory (ptr + idx) byte
  return memory

def readBytes (memory : LinearMemory) (ptr len : Nat) : Bytes := Id.run do
  let mut bytes := #[]
  for idx in [0:len] do
    bytes := bytes.push (readByte memory (ptr + idx))
  return bytes

def natToLEBytes (byteCount value : Nat) : Bytes :=
  (List.range byteCount).map (fun idx => (value / (256 ^ idx)) % 256) |>.toArray

def leBytesToNat (bytes : Bytes) : Nat :=
  Id.run do
    let mut value := 0
    let mut idx := 0
    for byte in bytes do
      value := value + byte * (256 ^ idx)
      idx := idx + 1
    return value

def readNatLE (memory : LinearMemory) (ptr byteCount : Nat) : Nat :=
  leBytesToNat (readBytes memory ptr byteCount)

def writeNatLE (memory : LinearMemory) (ptr byteCount value : Nat) : LinearMemory :=
  writeBytes memory ptr (natToLEBytes byteCount value)

def stringBytes (value : String) : Bytes :=
  value.toList.foldl (fun acc ch => acc.push ch.toNat) #[]

def initDataSegment (memory : LinearMemory) (segment : DataSegment) : LinearMemory :=
  writeBytes memory segment.offset (stringBytes segment.bytes)

def initLinearMemory (mod : WasmModule) : LinearMemory :=
  mod.dataSegments.foldl initDataSegment #[]

def lookupLocal? (locals : Locals) (name : String) : Option Nat :=
  locals.find? (fun entry => entry.fst == name) |>.map fun entry => entry.snd

def writeLocal (locals : Locals) (name : String) (value : Nat) : Locals :=
  (locals.filter (fun entry => entry.fst != name)).push (name, value)

def lookupRegister? (registers : Registers) (id : Nat) : Option Bytes :=
  registers.find? (fun entry => entry.fst == id) |>.map fun entry => entry.snd

def writeRegister (registers : Registers) (id : Nat) (bytes : Bytes) : Registers :=
  (registers.filter (fun entry => entry.fst != id)).push (id, bytes)

def lookupStorage? (storage : Storage) (key : Bytes) : Option Bytes :=
  storage.find? (fun entry => entry.fst == key) |>.map fun entry => entry.snd

def writeStorage (storage : Storage) (key value : Bytes) : Storage :=
  (storage.filter (fun entry => entry.fst != key)).push (key, value)

structure HostState where
  bridge : ProofForge.Target.HostBridge := .near
  input : Bytes := #[]
  registers : Registers := #[]
  storage : Storage := #[]
  returnValue : Bytes := #[]
  signerAccountId : Bytes := stringBytes "alice.testnet"
  attachedDeposit : Nat := 0
  deriving Repr, Inhabited

def HostState.beginCall (host : HostState) (input : Bytes := #[]) : HostState :=
  { host with input, registers := #[], returnValue := #[] }

structure WasmState where
  valueStack : Array Nat := #[]
  locals : Locals := #[]
  memory : LinearMemory := #[]
  host : HostState := {}
  deriving Repr, Inhabited

inductive Control where
  | continue
  | branch (depth : Nat)
  | return_
  deriving Repr, BEq

def stackPush (state : WasmState) (value : Nat) : WasmState :=
  { state with valueStack := state.valueStack.push value }

def stackPop (state : WasmState) : Except String (Nat × WasmState) :=
  match state.valueStack.back? with
  | none => .error "Wasm stack underflow"
  | some value => .ok (value, { state with valueStack := state.valueStack.pop })

def stackPeek (state : WasmState) : Except String Nat :=
  match state.valueStack.back? with
  | some value => .ok value
  | none => .error "Wasm stack underflow"

def splitStackArgs (state : WasmState) (argCount : Nat) :
    Except String (Array Nat × WasmState) := do
  if state.valueStack.size < argCount then
    .error s!"Wasm call expected {argCount} stack argument(s)"
  else
    let splitAt := state.valueStack.size - argCount
    let args := state.valueStack.extract splitAt state.valueStack.size
    let rest := state.valueStack.extract 0 splitAt
    .ok (args, { state with valueStack := rest })

def bindParams (params : Array Local) (args : Array Nat) : Locals := Id.run do
  let mut locals := #[]
  for param in params, idx in [0:params.size] do
    locals := locals.push (param.name, args.getD idx 0)
  return locals

def findFunc? (mod : WasmModule) (name : String) : Option Func :=
  mod.funcs.find? (fun func => func.name == name)

def findExportedFunc? (mod : WasmModule) (exportName : String) : Option Func :=
  mod.funcs.find? (fun func => func.exportName == some exportName)

def natValue? (value : String) : Except String Nat :=
  match value.toNat? with
  | some n => .ok n
  | none => .error s!"Wasm numeric literal `{value}` is not a Nat"

def loadByteCount : String → Except String Nat
  | "i64.load" => .ok 8
  | "i32.load" => .ok 4
  | "i32.load8_u" => .ok 1
  | other => .error s!"unsupported Wasm load `{other}`"

def storeByteCount : String → Except String Nat
  | "i64.store" => .ok 8
  | "i32.store" => .ok 4
  | "i32.store8" => .ok 1
  | other => .error s!"unsupported Wasm store `{other}`"

def applyUnaryPlain (name : String) (value : Nat) : Option Nat :=
  match name with
  | "i64.extend_i32_u" => some value
  | "i32.wrap_i64" => some (value % (2 ^ 32))
  | "i32.eqz" => some (if value == 0 then 1 else 0)
  | _ => none

def applyBinaryPlain (name : String) (lhs rhs : Nat) : Option Nat :=
  match name with
  | "i64.add" | "i32.add" => some (lhs + rhs)
  | "i64.sub" | "i32.sub" => some (lhs - rhs)
  | "i64.mul" | "i32.mul" => some (lhs * rhs)
  | "i64.and" | "i32.and" => some (Nat.land lhs rhs)
  | "i64.or" | "i32.or" => some (Nat.lor lhs rhs)
  | "i64.xor" | "i32.xor" => some (Nat.xor lhs rhs)
  | "i64.shl" | "i32.shl" => some (Nat.shiftLeft lhs rhs)
  | "i64.shr_u" | "i32.shr_u" => some (Nat.shiftRight lhs rhs)
  | "i64.eq" | "i32.eq" => some (if lhs == rhs then 1 else 0)
  | "i64.ne" | "i32.ne" => some (if lhs != rhs then 1 else 0)
  | "i64.lt_u" | "i32.lt_u" => some (if lhs < rhs then 1 else 0)
  | "i64.le_u" | "i32.le_u" => some (if lhs <= rhs then 1 else 0)
  | "i64.gt_u" | "i32.gt_u" => some (if lhs > rhs then 1 else 0)
  | "i64.ge_u" | "i32.ge_u" => some (if lhs >= rhs then 1 else 0)
  | "i64.div_u" | "i32.div_u" => if rhs == 0 then none else some (lhs / rhs)
  | "i64.rem_u" | "i32.rem_u" => if rhs == 0 then none else some (lhs % rhs)
  | _ => none

def evalPlain (state : WasmState) (name : String) : Except String WasmState := do
  match applyUnaryPlain name (← stackPeek state) with
  | some value =>
      let (_, state) ← stackPop state
      .ok (stackPush state value)
  | none =>
      let (rhs, state) ← stackPop state
      let (lhs, state) ← stackPop state
      match applyBinaryPlain name lhs rhs with
      | some value => .ok (stackPush state value)
      | none => .error s!"unsupported Wasm plain instruction `{name}`"

def hostReadRegister (state : WasmState) (registerId ptr : Nat) : WasmState :=
  match lookupRegister? state.host.registers registerId with
  | none => state
  | some bytes => { state with memory := writeBytes state.memory ptr bytes }

def runNearHostCall (name : String) (args : Array Nat) (state : WasmState) :
    Except String WasmState := do
  match name with
  | "input" =>
      let registerId := args.getD 0 0
      .ok { state with
        host := { state.host with
          registers := writeRegister state.host.registers registerId state.host.input
        }
      }
  | "read_register" =>
      let registerId := args.getD 0 0
      let ptr := args.getD 1 0
      .ok (hostReadRegister state registerId ptr)
  | "storage_read" =>
      let keyLen := args.getD 0 0
      let keyPtr := args.getD 1 0
      let registerId := args.getD 2 0
      let key := readBytes state.memory keyPtr keyLen
      match lookupStorage? state.host.storage key with
      | some value =>
          let host := { state.host with
            registers := writeRegister state.host.registers registerId value
          }
          .ok (stackPush { state with host } 1)
      | none =>
          .ok (stackPush state 0)
  | "storage_write" =>
      let keyLen := args.getD 0 0
      let keyPtr := args.getD 1 0
      let valueLen := args.getD 2 0
      let valuePtr := args.getD 3 0
      let registerId := args.getD 4 0
      let key := readBytes state.memory keyPtr keyLen
      let value := readBytes state.memory valuePtr valueLen
      let old? := lookupStorage? state.host.storage key
      let registers :=
        match old? with
        | some old => writeRegister state.host.registers registerId old
        | none => state.host.registers
      let host := { state.host with
        storage := writeStorage state.host.storage key value
        registers := registers
      }
      .ok (stackPush { state with host } (if old?.isSome then 1 else 0))
  | "value_return" =>
      let len := args.getD 0 0
      let ptr := args.getD 1 0
      let host := { state.host with returnValue := readBytes state.memory ptr len }
      .ok { state with host }
  | "signer_account_id" =>
      let registerId := args.getD 0 0
      let host := { state.host with
        registers := writeRegister state.host.registers registerId state.host.signerAccountId
      }
      .ok { state with host }
  | "attached_deposit" =>
      .ok (stackPush state state.host.attachedDeposit)
  | other =>
      .error s!"unsupported NEAR host call `{other}`"

def hostArity (bridge : ProofForge.Target.HostBridge) (name : String) :
    Except String Nat :=
  match bridge, name with
  | .near, "input" => .ok 1
  | .near, "read_register" => .ok 2
  | .near, "storage_read" => .ok 3
  | .near, "storage_write" => .ok 5
  | .near, "value_return" => .ok 2
  | .near, "signer_account_id" => .ok 1
  | .near, "attached_deposit" => .ok 0
  | .cosmWasm, _ => .error "CosmWasm host calls are not modeled by the NEAR Counter interpreter"
  | _, other => .error s!"unsupported host call `{other}`"

def runHostCall (name : String) (state : WasmState) : Except String WasmState := do
  let arity ← hostArity state.host.bridge name
  let (args, state) ← splitStackArgs state arity
  match state.host.bridge with
  | .near => runNearHostCall name args state
  | .cosmWasm => .error "CosmWasm host calls are not modeled by the NEAR Counter interpreter"

mutual

partial def evalFunc (mod : WasmModule) (func : Func) (args : Array Nat)
    (fuel : Nat) (caller : WasmState) : Except String (Nat × WasmState) := do
  let savedLocals := caller.locals
  let callerStack := caller.valueStack
  let localState := { caller with valueStack := #[], locals := bindParams func.params args }
  let (fuel, localState, control) ← evalBlock mod func.body fuel localState
  match control with
  | .branch depth => .error s!"Wasm branch escaped function `{func.name}` at depth {depth}"
  | .continue | .return_ =>
      let resultCount := func.results.size
      if localState.valueStack.size < resultCount then
        .error s!"Wasm function `{func.name}` produced too few result values"
      else
        let splitAt := localState.valueStack.size - resultCount
        let results := localState.valueStack.extract splitAt localState.valueStack.size
        .ok (fuel, { localState with valueStack := callerStack ++ results, locals := savedLocals })

partial def evalBlock (mod : WasmModule) (block : Block)
    (fuel : Nat) (state : WasmState) : Except String (Nat × WasmState × Control) := do
  let rec loop : Nat → List Insn → WasmState → Except String (Nat × WasmState × Control)
    | 0, _, _ => .error "Wasm interpreter fuel exhausted"
    | fuel + 1, [], state => .ok (fuel, state, .continue)
    | fuel + 1, insn :: rest, state => do
        let (fuel, state, control) ← evalInsn mod insn fuel state
        match control with
        | .continue => loop fuel rest state
        | _ => .ok (fuel, state, control)
  loop fuel block.insns.toList state

partial def evalLoop (mod : WasmModule) (body : Block)
    (fuel : Nat) (state : WasmState) : Except String (Nat × WasmState × Control) := do
  match fuel with
  | 0 => .error "Wasm interpreter loop fuel exhausted"
  | fuel + 1 =>
      let (fuel, state, control) ← evalBlock mod body fuel state
      match control with
      | .continue => .ok (fuel, state, .continue)
      | .return_ => .ok (fuel, state, .return_)
      | .branch 0 => evalLoop mod body fuel state
      | .branch (depth + 1) => .ok (fuel, state, .branch depth)

partial def evalInsn (mod : WasmModule) (insn : Insn)
    (fuel : Nat) (state : WasmState) : Except String (Nat × WasmState × Control) := do
  match fuel with
  | 0 => .error "Wasm interpreter fuel exhausted"
  | fuel + 1 =>
      match insn with
      | .nop => .ok (fuel, state, .continue)
      | .drop =>
          let (_, state) ← stackPop state
          .ok (fuel, state, .continue)
      | .return_ =>
          .ok (fuel, state, .return_)
      | .br depth =>
          .ok (fuel, state, .branch depth)
      | .brIf depth =>
          let (cond, state) ← stackPop state
          if cond != 0 then
            .ok (fuel, state, .branch depth)
          else
            .ok (fuel, state, .continue)
      | .const _ value =>
          .ok (fuel, stackPush state (← natValue? value), .continue)
      | .localGet name =>
          match lookupLocal? state.locals name with
          | some value => .ok (fuel, stackPush state value, .continue)
          | none => .error s!"unknown Wasm local `{name}`"
      | .localSet name =>
          let (value, state) ← stackPop state
          .ok (fuel, { state with locals := writeLocal state.locals name value }, .continue)
      | .localTee name =>
          let value ← stackPeek state
          .ok (fuel, { state with locals := writeLocal state.locals name value }, .continue)
      | .plain name =>
          .ok (fuel, ← evalPlain state name, .continue)
      | .load name offset =>
          let (ptr, state) ← stackPop state
          let byteCount ← loadByteCount name
          .ok (fuel, stackPush state (readNatLE state.memory (ptr + offset) byteCount), .continue)
      | .store name offset =>
          let (value, state) ← stackPop state
          let (ptr, state) ← stackPop state
          let byteCount ← storeByteCount name
          .ok (fuel, { state with memory := writeNatLE state.memory (ptr + offset) byteCount value }, .continue)
      | .call name =>
          match findFunc? mod name with
          | some func =>
              let (args, state) ← splitStackArgs state func.params.size
              let (fuel, state) ← evalFunc mod func args fuel state
              .ok (fuel, state, .continue)
          | none =>
              .ok (fuel, ← runHostCall name state, .continue)
      | .block_ body =>
          let (fuel, state, control) ← evalBlock mod body fuel state
          match control with
          | .branch 0 => .ok (fuel, state, .continue)
          | .branch (depth + 1) => .ok (fuel, state, .branch depth)
          | other => .ok (fuel, state, other)
      | .loop_ body =>
          evalLoop mod body fuel state
      | .if_ thenBody elseBody =>
          let (cond, state) ← stackPop state
          evalBlock mod (if cond != 0 then thenBody else elseBody) fuel state
      | .globalGet name | .globalSet name =>
          .error s!"Wasm global `{name}` is not modeled in the Counter interpreter"
      | .unreachable =>
          .error "Wasm unreachable executed"
      | .select =>
          .error "Wasm select is not modeled in the Counter interpreter"

end

def borshValueBytes : ProofForge.IR.Semantics.Value → Except String Bytes
  | .unit => .ok #[]
  | .bool value => .ok #[if value then 1 else 0]
  | .u8 value => .ok (natToLEBytes 1 value)
  | .u32 value => .ok (natToLEBytes 4 value)
  | .u64 value => .ok (natToLEBytes 8 value)
  | .address value => .ok (natToLEBytes 8 value)
  | .hash a b c d =>
      .ok (natToLEBytes 8 a ++ natToLEBytes 8 b ++
        natToLEBytes 8 c ++ natToLEBytes 8 d)
  | _ => .error "Wasm interpreter Borsh inputs only model scalar values"

def borshArgsBytes (args : Array ProofForge.IR.Semantics.Value) :
    Except String Bytes := do
  let mut bytes := #[]
  for arg in args do
    bytes := bytes ++ (← borshValueBytes arg)
  .ok bytes

def runExport (mod : WasmModule) (state : WasmState) (call : TraceCall) :
    Except String WasmState := do
  let func ←
    match findExportedFunc? mod call.entrypoint.name with
    | some func => .ok func
    | none => .error s!"Wasm export `{call.entrypoint.name}` not found"
  let input ← borshArgsBytes call.args
  let state := { state with host := state.host.beginCall input, valueStack := #[], locals := #[] }
  let (_, state) ← evalFunc mod func #[] defaultFuel state
  .ok state

def observeEntrypoint (entrypoint : Entrypoint) (state : WasmState) :
    Except String ObservableReturn :=
  match entrypoint.returns with
  | .unit => .ok .none
  | .u64 => .ok (.u64 (leBytesToNat state.host.returnValue))
  | .u32 => .ok (.u32 (leBytesToNat state.host.returnValue))
  | .bool => .ok (.bool (leBytesToNat state.host.returnValue != 0))
  | other => .error s!"Wasm interpreter only models Unit/U64/U32/Bool returns, got `{other.name}`"

def runTraceList (mod : WasmModule) :
    List TraceCall → WasmState → Except String (WasmState × Array ObservableStep)
  | [], state => .ok (state, #[])
  | call :: rest, state => do
      let state ← runExport mod state call
      let returnValue ← observeEntrypoint call.entrypoint state
      let step : ObservableStep := {
        entrypointName := call.entrypoint.name
        returnValue
      }
      let (state, steps) ← runTraceList mod rest state
      .ok (state, #[step] ++ steps)

def initialState (mod : WasmModule) (bridge : ProofForge.Target.HostBridge := .near) :
    WasmState :=
  { memory := initLinearMemory mod, host := { bridge := bridge } }

def runTrace (mod : WasmModule) (obligation : TraceObligation) :
    Except String (Array ObservableStep) := do
  let (_, steps) ← runTraceList mod obligation.calls.toList (initialState mod)
  .ok steps

def executableTraceOk (obligation : TraceObligation) : Bool :=
  match EmitWat.lowerModule obligation.module with
  | .error _ => false
  | .ok wasm =>
      match runTrace wasm obligation with
      | .ok actual => actual == obligation.expected
      | .error _ => false

def storageKeyBytes? (mod : ProofForge.IR.Module) (stateId : String) : Option Bytes :=
  let layout := stateLayout mod
  match findScalarState? layout stateId with
  | none => none
  | some info => some (stringBytes info.id)

def hostStorageU64? (host : HostState) (key : Bytes) : Option Nat :=
  lookupStorage? host.storage key |>.map leBytesToNat

def irU64State? (state : ProofForge.IR.Semantics.State) (stateId : String) : Option Nat :=
  match ProofForge.IR.Semantics.State.read state stateId with
  | some (.u64 value) => some value
  | _ => none

def R (mod : ProofForge.IR.Module) (stateId : String)
    (irState : ProofForge.IR.Semantics.State) (wasmState : WasmState) : Bool :=
  match irU64State? irState stateId, storageKeyBytes? mod stateId with
  | some expected, some key =>
      match hostStorageU64? wasmState.host key with
      | some actual => actual == expected
      | none => false
  | _, _ => false

def runIrEntrypointState (state : ProofForge.IR.Semantics.State)
    (entrypoint : Entrypoint) : Except String ProofForge.IR.Semantics.State :=
  match ProofForge.IR.Semantics.runEntrypointWithArgsResult state entrypoint #[] with
  | .ok (nextState, _) => .ok nextState
  | .reverted message => .error s!"IR entrypoint `{entrypoint.name}` reverted: {message}"
  | .error message => .error message

def counterRAfterInitialize : Bool :=
  match EmitWat.lowerModule ProofForge.IR.Examples.Counter.module with
  | .error _ => false
  | .ok wasm =>
      match runIrEntrypointState ProofForge.IR.Semantics.State.empty
          ProofForge.IR.Examples.Counter.initializeEntrypoint with
      | .error _ => false
      | .ok irState =>
          let call : TraceCall := { entrypoint := ProofForge.IR.Examples.Counter.initializeEntrypoint }
          match runExport wasm (initialState wasm) call with
          | .ok wasmState => R ProofForge.IR.Examples.Counter.module "count" irState wasmState
          | .error _ => false

def counterRAfterIncrement : Bool :=
  match EmitWat.lowerModule ProofForge.IR.Examples.Counter.module with
  | .error _ => false
  | .ok wasm =>
      match runIrEntrypointState ProofForge.IR.Semantics.State.empty
          ProofForge.IR.Examples.Counter.initializeEntrypoint with
      | .error _ => false
      | .ok irAfterInit =>
          match runIrEntrypointState irAfterInit ProofForge.IR.Examples.Counter.increment with
          | .error _ => false
          | .ok irAfterIncrement =>
              let initCall : TraceCall := { entrypoint := ProofForge.IR.Examples.Counter.initializeEntrypoint }
              let incCall : TraceCall := { entrypoint := ProofForge.IR.Examples.Counter.increment }
              match runExport wasm (initialState wasm) initCall with
              | .error _ => false
              | .ok wasmState =>
                  match runExport wasm wasmState incCall with
                  | .ok wasmState =>
                      R ProofForge.IR.Examples.Counter.module "count" irAfterIncrement wasmState
                  | .error _ => false

def counterInterpreterSmoke : Bool :=
  match EmitWat.lowerModule ProofForge.IR.Examples.Counter.module with
  | .error _ => false
  | .ok wasm =>
      let calls := traceCallsFromEntrypoints #[
        ProofForge.IR.Examples.Counter.initializeEntrypoint,
        ProofForge.IR.Examples.Counter.get,
        ProofForge.IR.Examples.Counter.increment,
        ProofForge.IR.Examples.Counter.get
      ]
      match runTraceList wasm calls.toList (initialState wasm) with
      | .ok _ => true
      | .error _ => false

theorem counter_interpreter_smoke_ok :
    counterInterpreterSmoke = true := by
  native_decide

theorem counter_R_after_initialize_ok :
    counterRAfterInitialize = true := by
  native_decide

theorem counter_R_after_increment_ok :
    counterRAfterIncrement = true := by
  native_decide

end ProofForge.Backend.WasmNear.WasmInterpreter
