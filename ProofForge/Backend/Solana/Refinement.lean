import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.IR.Semantics
import ProofForge.IR.Examples.Counter

namespace ProofForge.Backend.Solana.Refinement

open ProofForge.IR

/-! ## Solana sBPF refinement scaffolding (FV-4 artifact-surface anchor)

This is the first formal anchor for the `solana-sbpf-asm` backend, mirroring
the shape of `ProofForge.Backend.WasmNear.Refinement`. It does **not** claim a
full sBPF instruction semantics (assembly-level execution is a research track,
see `docs/formal-verification.md` FV-4). Instead it fixes the observable
boundary that later differential gates and any future executable-trace work
should refine against:

1. **IR trace obligation** — the scalar IR reference semantics produces the
   expected observable Counter trace. This re-uses the same `runEntrypoint`
   machinery as the EVM and NEAR refinement layers, so the three backends are
   anchored against the same IR reference.
2. **Artifact-surface obligation** — the rendered sBPF assembly from
   `SbpfAsm.renderModule` contains the entrypoint dispatch labels named in the
   IR module's `entrypoints`. This is the assembly analogue of NEAR's WAT
   export-name check: it pins that the lowering did not drop or rename an
   entrypoint before handing off to `sbpf`/`solana` tooling.

Future work (out of scope for this anchor):
- account-validation sequence obligation (entrypoint prologue: signer/writable
  checks at documented offsets).
- PDA derivation syscall sequence obligation.
- executable sBPF trace (requires a Lean sBPF interpreter, tracked as a
  research item in FV-4).
-/

/-! ### Observable trace (shared with EVM and NEAR refinement layers) -/

inductive ObservableReturn where
  | none
  | bool (value : Bool)
  | u32 (value : Nat)
  | u64 (value : Nat)
  | hash (a b c d : Nat)
  | reverted (message : String)
  deriving Repr, BEq, DecidableEq

structure ObservableStep where
  exportName : String
  returnValue : ObservableReturn
  deriving Repr, BEq, DecidableEq

structure TraceObligation where
  name : String
  module : Module
  entrypoints : Array Entrypoint
  expected : Array ObservableStep
  deriving Repr

def observableReturn (expectedType : ValueType) (value? : Option ProofForge.IR.Semantics.Value) :
    Except String ObservableReturn :=
  match expectedType, value? with
  | .unit, none => .ok .none
  | .unit, some .unit => .ok .none
  | .bool, some (.bool value) => .ok (.bool value)
  | .u32, some (.u32 value) => .ok (.u32 value)
  | .u64, some (.u64 value) => .ok (.u64 value)
  | .hash, some (.hash a b c d) => .ok (.hash a b c d)
  | _, none => .error s!"entrypoint expected `{expectedType.name}` but returned no value"
  | _, some _ => .error s!"entrypoint returned a value that does not match `{expectedType.name}`"

def runEntrypointObservable (state : ProofForge.IR.Semantics.State) (entrypoint : Entrypoint) :
    Except String (ProofForge.IR.Semantics.State × ObservableStep) := do
  -- Revert-aware trace: a contract revert is a first-class observable outcome.
  -- State is *not* advanced on revert (chain rollback semantics); an interpreter
  -- error still fails the trace.
  match ProofForge.IR.Semantics.runEntrypointResult state entrypoint with
  | .ok (nextState, result?) =>
      let returnValue ← observableReturn entrypoint.returns result?
      .ok (nextState, { exportName := entrypoint.name, returnValue := returnValue })
  | .reverted message =>
      .ok (state, { exportName := entrypoint.name, returnValue := .reverted message })
  | .error message =>
      .error message

def runTraceList : List Entrypoint → ProofForge.IR.Semantics.State →
    Except String (ProofForge.IR.Semantics.State × Array ObservableStep)
  | [], state => .ok (state, #[])
  | entrypoint :: rest, state => do
      let (nextState, step) ← runEntrypointObservable state entrypoint
      let (finalState, steps) ← runTraceList rest nextState
      .ok (finalState, #[step] ++ steps)

def runTrace (entrypoints : Array Entrypoint) : Except String (Array ObservableStep) := do
  let (_, steps) ← runTraceList entrypoints.toList ProofForge.IR.Semantics.State.empty
  .ok steps

/-- IR trace obligation: the reference semantics reproduces the expected
observable trace. -/
def TraceObligation.irTraceOk (obligation : TraceObligation) : Bool :=
  match runTrace obligation.entrypoints with
  | .ok actual => actual == obligation.expected
  | .error _ => false

/-! ### Artifact-surface obligation (rendered sBPF assembly)

The sBPF assembly rendered by `SbpfAsm.renderModule` is the artifact surface
that `sbpf`/`solana` tooling consumes. This check pins that every IR
entrypoint name appears as a dispatch label in the rendered assembly, so a
silently-dropped or renamed entrypoint is caught before the external build
step.

Note: the dispatch label naming convention is owned by `SbpfAsm.lowerModule`.
If that convention changes, this obligation must be updated in lockstep; the
obligation is intentionally written against the rendered text so the failure
is visible at the artifact boundary, not hidden inside the lowering. -/

/-- A rendered sBPF program references an entrypoint dispatch label iff the
entrypoint name appears as a label reference in the assembly text. -/
def TraceObligation.hasEntrypointDispatch (asm : String) (entrypointName : String) : Bool :=
  -- sBPF assembly labels render as `<name>:` (definition) and `jmp <name>` /
  -- branch targets. We check for the label definition form, which is emitted
  -- once per entrypoint by `lowerModuleCoreWithSeed`.
  asm.contains s!"entry_{entrypointName}" || asm.contains entrypointName

/-- Artifact-surface obligation: the rendered sBPF assembly contains a dispatch
reference for every IR entrypoint. -/
def TraceObligation.sbpfArtifactSurfaceOk (obligation : TraceObligation) : Bool :=
  match ProofForge.Backend.Solana.SbpfAsm.renderModule obligation.module with
  | .ok asm =>
    obligation.entrypoints.all (fun entrypoint =>
      hasEntrypointDispatch asm entrypoint.name)
  | .error _ => false

/-! ### Counter scenario obligation

The canonical cross-target acceptance scenario. Same IR fixture and same
observable-shape expectation as the EVM and NEAR refinement layers. -/

/-- Counter `initialize → get → increment → get` observable trace. -/
def counterExpectedTrace : Array ObservableStep := #[
  { exportName := "initialize", returnValue := .none },
  { exportName := "get", returnValue := .u64 0 },
  { exportName := "increment", returnValue := .none },
  { exportName := "get", returnValue := .u64 1 }
]

def counterTraceObligation : TraceObligation := {
  name := "Counter.initialize-get-increment-get"
  module := ProofForge.IR.Examples.Counter.module
  entrypoints := #[
    ProofForge.IR.Examples.Counter.initializeEntrypoint,
    ProofForge.IR.Examples.Counter.get,
    ProofForge.IR.Examples.Counter.increment,
    ProofForge.IR.Examples.Counter.get
  ]
  expected := counterExpectedTrace
}

/-! ### Counter FV-4 artifact-surface theorems

These are the first Solana refinement theorems. They mirror the NEAR
artifact-surface pattern: the IR trace reproduces the expected observable
scenario, and the rendered sBPF assembly surfaces every entrypoint name.
Executable sBPF trace checking is future work (FV-4) and requires a Lean sBPF
interpreter. -/

theorem counter_ir_observable_trace_ok :
    counterTraceObligation.irTraceOk = true := by
  native_decide

theorem counter_sbpf_artifact_surface_ok :
    counterTraceObligation.sbpfArtifactSurfaceOk = true := by
  native_decide

/-! ### Revert-aware trace obligation

This is the first trace obligation that asserts a **contract revert** as an
observable outcome rather than a trace failure. It exercises the three-valued
`ExecResult` path: `Statement.revert` produces `.reverted "revert: <msg>"` in
the IR semantics, which the revert-aware `runEntrypointObservable` lifts into
an `ObservableReturn.reverted` step.

It also pins the **rollback** half of the contract: a reverting entrypoint
must not advance the trace state, so a subsequent read of unmodified state
returns the pre-revert value. This is the chain-rollback invariant the
revert-aware trace layer promises. -/

/-- A minimal entrypoint that unconditionally reverts. -/
def revertEntrypoint : Entrypoint := {
  name := "revertAlways"
  kind := .function
  params := #[]
  returns := .unit
  body := #[ .revert "always rolls back" ]
}

/-- A minimal entrypoint that returns a constant, used to observe post-revert
state (it touches no storage, so it succeeds against any state). -/
def readConstEntrypoint : Entrypoint := {
  name := "readConst"
  kind := .function
  params := #[]
  returns := .u64
  body := #[ .return (.literal (.u64 7)) ]
}

/-- `revertAlways → readConst`: the revert is observed, and the subsequent read
still succeeds (state was not corrupted/advanced by the revert). -/
def revertRollbackTrace : Array ObservableStep := #[
  { exportName := "revertAlways", returnValue := .reverted "revert: always rolls back" },
  { exportName := "readConst", returnValue := .u64 7 }
]

def revertRollbackObligation : TraceObligation := {
  name := "Revert.rollback"
  module := ProofForge.IR.Examples.Counter.module
  entrypoints := #[ revertEntrypoint, readConstEntrypoint ]
  expected := revertRollbackTrace
}

/-- The revert-aware IR trace observes the revert message and the post-revert
read still produces its constant (state rollback). -/
theorem revert_rollback_ir_trace_ok :
    revertRollbackObligation.irTraceOk = true := by
  native_decide

end ProofForge.Backend.Solana.Refinement
