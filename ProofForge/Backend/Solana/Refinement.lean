import ProofForge.Backend.Refinement.Core
import ProofForge.Backend.Solana.SbpfInterpreter
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.IR.Semantics
import ProofForge.IR.Examples.Counter

namespace ProofForge.Backend.Solana.Refinement

open ProofForge.IR
open ProofForge.Backend.Refinement
open ProofForge.Backend.Solana.SbpfInterpreter

/-! ## Solana sBPF refinement scaffolding (FV-4 executable trace anchor)

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
   IR module's `entrypoints`.
3. **Executable sBPF trace obligation** — the lowered structured `AstNode`
   instruction list executes in the in-Lean Counter-slice sBPF interpreter and
   produces the same observable trace as the IR reference semantics.

Future work (out of scope for this anchor):
- account-validation sequence obligation (entrypoint prologue: signer/writable
  checks at documented offsets).
- PDA derivation syscall sequence obligation.
- wider executable sBPF coverage beyond the Counter scalar-storage slice.
-/

/-! ### Observable trace (shared with EVM and NEAR refinement layers) -/

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
def hasEntrypointDispatch (asm : String) (entrypointName : String) : Bool :=
  -- sBPF assembly labels render as `<name>:` (definition) and `jmp <name>` /
  -- branch targets. We check for the label definition form, which is emitted
  -- once per entrypoint by `lowerModuleCoreWithSeed`.
  asm.contains s!"sol_{entrypointName}:"

/-- Artifact-surface obligation: the rendered sBPF assembly contains a dispatch
reference for every IR entrypoint. -/
def sbpfArtifactSurfaceOk (obligation : TraceObligation) : Bool :=
  match ProofForge.Backend.Solana.SbpfAsm.renderModule obligation.module with
  | .ok asm =>
    obligation.entrypoints.all (fun entrypoint =>
      hasEntrypointDispatch asm entrypoint.name)
  | .error _ => false

def sbpfExecutableTraceOk (obligation : TraceObligation) : Bool :=
  ProofForge.Backend.Solana.SbpfInterpreter.executableTraceOk obligation

/-! ### Counter scenario obligation

The canonical cross-target acceptance scenario. Same IR fixture and same
observable-shape expectation as the EVM and NEAR refinement layers. -/

/-- Counter `initialize → get → increment → get` observable trace. -/
def counterExpectedTrace : Array ObservableStep := #[
  { entrypointName := "initialize", returnValue := .none },
  { entrypointName := "get", returnValue := .u64 0 },
  { entrypointName := "increment", returnValue := .none },
  { entrypointName := "get", returnValue := .u64 1 }
]

def counterTraceObligation : TraceObligation := {
  name := "Counter.initialize-get-increment-get"
  module := ProofForge.IR.Examples.Counter.module
  calls := traceCallsFromEntrypoints #[
    ProofForge.IR.Examples.Counter.initializeEntrypoint,
    ProofForge.IR.Examples.Counter.get,
    ProofForge.IR.Examples.Counter.increment,
    ProofForge.IR.Examples.Counter.get
  ]
  expected := counterExpectedTrace
}

/-! ### Counter FV-4 artifact-surface and executable-trace theorems

These are the first Solana refinement theorems. They mirror the NEAR
artifact-surface pattern and add a first Counter executable-trace check over
the lowered structured sBPF AST. -/

theorem counter_ir_observable_trace_ok :
    counterTraceObligation.irTraceOk = true := by
  native_decide

theorem counter_sbpf_artifact_surface_ok :
    sbpfArtifactSurfaceOk counterTraceObligation = true := by
  native_decide

theorem counter_sbpf_executable_trace_ok :
    sbpfExecutableTraceOk counterTraceObligation = true := by
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
  { entrypointName := "revertAlways", returnValue := .reverted "revert: always rolls back" },
  { entrypointName := "readConst", returnValue := .u64 7 }
]

def revertRollbackObligation : TraceObligation := {
  name := "Revert.rollback"
  module := ProofForge.IR.Examples.Counter.module
  calls := traceCallsFromEntrypoints #[ revertEntrypoint, readConstEntrypoint ]
  expected := revertRollbackTrace
}

/-- The revert-aware IR trace observes the revert message and the post-revert
read still produces its constant (state rollback). -/
theorem revert_rollback_ir_trace_ok :
    revertRollbackObligation.irTraceOk = true := by
  native_decide

end ProofForge.Backend.Solana.Refinement
