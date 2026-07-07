# Solana sBPF Executable Trace — Design Note (FV-4)

Status: **Design / future work** (2026-07). Tracks the next Solana refinement
step after the artifact-surface anchor landed in #77 / #78.

## Where we are today

`ProofForge/Backend/Solana/Refinement.lean` pins two Solana FV-4 anchors:

1. **IR observable trace** (`counter_ir_observable_trace_ok`,
   `revert_rollback_ir_trace_ok`) — the Counter scenario and the revert-rollback
   invariant are checked against the shared `IR.Semantics`.
2. **sBPF artifact-surface** (`counter_sbpf_artifact_surface_ok`) — the rendered
   sBPF assembly *contains* a dispatch label for every IR entrypoint name.

The artifact-surface check is a text-containment test against
`SbpfAsm.renderModule`. It catches dropped/renamed entrypoints but proves
nothing about what the assembly *does*. This note scopes the lift to an
**executable sBPF trace**: a small Lean interpreter over a subset of the sBPF
instruction set, and a differential gate that checks the interpreter's
observable output against the IR reference trace.

## Goal (non-goal)

**Goal:** for the Counter scenario, the sBPF interpreter and the IR reference
semantics produce the same observable return words (`get → 0`, then
`get → 1`), checked by a `native_decide` theorem. This moves Solana from
"artifact-surface only" toward Tier C-diff (see
[formal-verification.md](formal-verification.md)).

**Non-goal:** a complete sBPF model. We cover the instruction subset the
Counter lowering actually emits. Full sBPF semantics (CPI, syscalls, account
model) stays in the external differential-testing trust boundary (Mollusk /
Surfpool), out of scope for the Lean proof.

## Existing structured representation (already in the repo)

The interpreter targets the structured AST that already exists; no new IR:

- `ProofForge/Backend/Solana/Asm.lean`:
  - `Reg` (`r0`..`r10`, with `r10` = frame pointer / stack)
  - `Imm` (`num` / `sym`), `MemOff`
  - `Opcode` (64/32-bit ALU, loads, stores, endian, control flow, `call`,
    `exit`) — see `Opcode.isRegOp` / `isLoad` / `isStore` / `isStoreReg` /
    `isCondJump` / `isEndian` helpers.
  - `Inst` (`opcode`, `dst`, `src`, `off`, `imm`)
  - `AstNode` (`sectionDecl` / `globalDecl` / `equDecl` / `label` /
    `instruction` / `data` / `comment` / `blankLine`)
- `ProofForge/Backend/Solana/SbpfAsm.lean`:
  - `lowerModule : IR.Module → Except LowerError (Array AstNode)` (the lowering
    whose output we interpret).
  - `renderModule : IR.Module → Except LowerError String` (current
    artifact-surface input).

So the executable-trace work consumes `lowerModule`'s `Array AstNode` directly
instead of its rendered text.

## Interpreter design

### Machine state

```lean
structure SbpfState where
  regs    : Array Nat       -- index 0..10 (r10 is the stack frame pointer)
  stack   : Array Nat       -- scratch / local slots, addressed via r10 + off
  entryR0 : Nat             -- observable return word (r0 at `exit`)
  pc      : Nat             -- program counter into the flattened instruction list
```

A label table maps `entry_<name>` labels to instruction indices, built by a
pre-pass over the `AstNode` array. `equDecl`s resolve symbol immediates
(`Imm.sym`) to `Nat`.

### Instruction subset (Counter coverage)

The Counter lowering (`SbpfAsm.Stmt` + `SbpfAsm.Expr`) emits, for the
`initialize` / `get` / `increment` entrypoints:

| Opcode class | Subset to model | Why |
|---|---|---|
| ALU 64-bit | `mov64`, `add64`, `sub64`, `mul64`, `lsh64` | counter arithmetic, address computation |
| Load immediate | `lddw` (split into two pseudo-insns) | loading constants |
| Load register-relative | `ldxdw` (`ldxw` if 32-bit) | reading scratch slots |
| Store register-relative | `stxdw` (`stxw`) | writing scratch slots (the counter slot) |
| Control flow | `ja`, `jeq`, `exit` | entrypoint dispatch tail, unconditional/conditional jump, return |
| Syscall stub | `call` (only to the dispatch + a stubbed storage read/write) | Counter reads/writes one scalar slot |

Storage model for the scalar counter: a single named slot, pre-initialised to
`0`. The `call` instruction is modelled only for the
"storage-scalar-read/write" syscall index used by Counter; other syscall
indices are interpreter errors (out of the covered subset). This mirrors how
the EVM Yul-subset interpreter models `sload`/`sstore`.

### Entrypoint dispatch

The Solana lowering emits a dispatch prologue that compares an account-input
discriminator and jumps to `entry_<name>`. The interpreter:

1. Sets `r1` to the discriminator bytes for the entrypoint under test.
2. Runs from the program start until the dispatch `jeq` fires and transfers to
   `entry_<name>`.
3. Runs the entrypoint body until `exit`.
4. Records `r0` at `exit` as the observable return.

### Observable projection

```lean
def SbpfState.observableReturn (entrypoint : IR.Entrypoint) (st : SbpfState) :
    ObservableReturn :=
  match entrypoint.returns with
  | .u64 => .u64 st.entryR0
  | .unit => .none
  | _ => .error "sBPF interpreter subset only models U64/Unit returns"
```

This reuses the existing `ObservableReturn` from `Solana/Refinement.lean`
(now including `.reverted` from #78).

## Differential gate

```lean
def TraceObligation.sbpfExecutableTraceOk (obligation : TraceObligation) : Bool :=
  match lowerModule obligation.module with
  | .error _ => false
  | .ok nodes =>
    match SbpfInterpreter.runTrace nodes obligation.entrypoints with
    | .error _ => false
    | .ok actual => actual == obligation.expected

theorem counter_sbpf_executable_trace_ok :
    counterTraceObligation.sbpfExecutableTraceOk = true := by
  native_decide
```

`SbpfInterpreter.runTrace` threads `SbpfState` across entrypoints so the
counter persists across `initialize → get → increment → get`, mirroring the IR
trace layer.

## Risks / unknowns

- **Dispatch prologue shape.** The dispatch label naming is owned by
  `SbpfAsm.lowerModuleCoreWithSeed`; if it changes, the interpreter's label
  lookup must track it (same lockstep risk as the current
  `hasEntrypointDispatch`). Mitigation: the interpreter reads labels from the
  lowered `AstNode` array, not a hard-coded string.
- **`call` syscall coverage.** Only the Counter scalar read/write syscall is
  modelled. Maps / arrays / structs (used by ValueVault) are out of the first
  slice; adding them is a second slice and needs the storage-abstract-slot
  model the IR semantics already has.
- **Termination.** The interpreter must terminate on the Counter instruction
  subset. `boundedFor` lowers to a fixed-trip loop, so a step budget
  (configurable, default a few thousand) makes the interpreter total; exceeding
  the budget is an interpreter error, not a hang.

## Phasing

1. **Slice A (this note's MVP):** Counter-only, scalar storage, U64/Unit
   returns, ALU/load/store/jump/exit subset. One `native_decide` theorem.
2. **Slice B:** ValueVault scalar fields (multiple named slots, the accounting
   invariant observed at the sBPF layer).
3. **Slice C:** maps / arrays — requires porting the IR storage-slot model to
   the sBPF scratch memory.
4. **Slice D (research):** account-validation prologue obligation, PDA
   derivation syscall sequence obligation — these stay differential gates
   against Mollusk/Surfpool unless a fuller sBPF model lands.

## Acceptance

- `Solana/Refinement.lean` gains `sbpfExecutableTraceOk` and
  `counter_sbpf_executable_trace_ok` (native_decide).
- The interpreter lives in `ProofForge/Backend/Solana/SbpfInterpreter.lean`
  (pure Lean, total via step budget, no external tools).
- `solana-refinement-smoke` is extended to `#check` the executable-trace
  theorem; `just solana-light` runs it locally without `sbpf`/`surfpool`.
- `docs/formal-verification.md` Tier C-diff row for `solana-sbpf-asm` is
  updated from "artifact-surface only" to "executable-trace (Counter subset)".
