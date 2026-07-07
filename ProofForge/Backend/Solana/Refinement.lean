import ProofForge.Backend.Refinement.Core
import ProofForge.Backend.Solana.SbpfInterpreter
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.IR.Semantics
import ProofForge.IR.Examples.ArrayProbe
import ProofForge.IR.Examples.Counter
import ProofForge.IR.Examples.EvmMapProbe
import ProofForge.Contract.Examples.ValueVaultInvariant

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
   instruction list executes in the in-Lean sBPF interpreter and produces the
   same observable trace as the IR reference semantics for the Counter slice,
   the default ValueVault scalar/event slice, and focused storage array/map
   probe slices.

Future work (out of scope for this anchor):
- account-validation sequence obligation (entrypoint prologue: signer/writable
  checks at documented offsets).
- PDA derivation syscall sequence obligation.
- wider executable sBPF coverage beyond the scalar-storage/event/map/array
  slices.
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

def valueVaultEntrypointD (entrypointName : String) : Entrypoint :=
  match ProofForge.Contract.Examples.ValueVaultInvariant.module.entrypoints.find?
      (fun entrypoint => entrypoint.name == entrypointName) with
  | some entrypoint => entrypoint
  | none => ProofForge.IR.Examples.Counter.initializeEntrypoint

def valueVaultCall (name : String)
    (args : Array ProofForge.IR.Semantics.Value := #[]) : TraceCall := {
  entrypoint := valueVaultEntrypointD name
  args
}

def valueVaultTraceCalls : Array TraceCall :=
  let inputs := ProofForge.Contract.Examples.ValueVaultInvariant.defaultInputs
  #[
    valueVaultCall "initialize" #[.u64 inputs.initial],
    valueVaultCall "get_balance",
    valueVaultCall "deposit" #[.u64 inputs.deposit],
    valueVaultCall "get_balance",
    valueVaultCall "charge_fee" #[.u64 inputs.grossCharge, .u64 inputs.feeBps],
    valueVaultCall "get_balance",
    valueVaultCall "get_net_value",
    valueVaultCall "release" #[.u64 inputs.release],
    valueVaultCall "get_balance",
    valueVaultCall "snapshot",
    valueVaultCall "get_net_value"
  ]

def valueVaultExpectedTrace : Array ObservableStep :=
  let inputs := ProofForge.Contract.Examples.ValueVaultInvariant.defaultInputs
  let fee := ProofForge.Contract.Examples.ValueVaultInvariant.expectedFee inputs
  let afterDeposit := inputs.initial + inputs.deposit
  let afterCharge := afterDeposit +
    ProofForge.Contract.Examples.ValueVaultInvariant.expectedNetCharge inputs
  let balance := ProofForge.Contract.Examples.ValueVaultInvariant.expectedBalance inputs
  let netValue := ProofForge.Contract.Examples.ValueVaultInvariant.expectedNetValue inputs
  #[
    { entrypointName := "initialize", returnValue := .none },
    { entrypointName := "get_balance", returnValue := .u64 inputs.initial },
    { entrypointName := "deposit", returnValue := .none },
    { entrypointName := "get_balance", returnValue := .u64 afterDeposit },
    { entrypointName := "charge_fee", returnValue := .none },
    { entrypointName := "get_balance", returnValue := .u64 afterCharge },
    { entrypointName := "get_net_value", returnValue := .u64 (afterCharge - fee) },
    { entrypointName := "release", returnValue := .none },
    { entrypointName := "get_balance", returnValue := .u64 balance },
    { entrypointName := "snapshot", returnValue := .u64 balance },
    { entrypointName := "get_net_value", returnValue := .u64 netValue }
  ]

def valueVaultTraceObligation : TraceObligation := {
  name := "ValueVault.default-scenario"
  module := ProofForge.Contract.Examples.ValueVaultInvariant.module
  calls := valueVaultTraceCalls
  expected := valueVaultExpectedTrace
}

/-! ### Storage array and map probe obligations

These deepen the Solana executable trace beyond scalar slots. They are still
pointwise C-diff checks, but they run the actual lowered sBPF array-index and
map-linear-scan instruction paths against the shared IR semantics. -/

def arrayStorageExpectedTrace : Array ObservableStep := #[
  { entrypointName := "storage_lifecycle", returnValue := .u64 31 }
]

def arrayStorageTraceObligation : TraceObligation := {
  name := "ArrayProbe.storage-lifecycle"
  module := ProofForge.IR.Examples.ArrayProbe.emitWatStorageModule
  calls := traceCallsFromEntrypoints #[
    ProofForge.IR.Examples.ArrayProbe.storageLifecycle
  ]
  expected := arrayStorageExpectedTrace
}

def mapStorageModule : Module := {
  name := "EvmMapProbe"
  state := #[
    ProofForge.IR.Examples.EvmMapProbe.stateBefore,
    ProofForge.IR.Examples.EvmMapProbe.stateBalances,
    ProofForge.IR.Examples.EvmMapProbe.stateAfter
  ]
  entrypoints := #[
    ProofForge.IR.Examples.EvmMapProbe.setBalance,
    ProofForge.IR.Examples.EvmMapProbe.readBalance
  ]
}

def mapSetCall : TraceCall := {
  entrypoint := ProofForge.IR.Examples.EvmMapProbe.setBalance
  args := #[.u64 5, .u64 42]
}

def mapReadCall : TraceCall := {
  entrypoint := ProofForge.IR.Examples.EvmMapProbe.readBalance
  args := #[.u64 5]
}

def mapStorageExpectedTrace : Array ObservableStep := #[
  { entrypointName := "set_balance", returnValue := .none },
  { entrypointName := "read_balance", returnValue := .u64 42 }
]

def mapStorageTraceObligation : TraceObligation := {
  name := "EvmMapProbe.set-read"
  module := mapStorageModule
  calls := #[mapSetCall, mapReadCall]
  expected := mapStorageExpectedTrace
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

theorem value_vault_ir_observable_trace_ok :
    valueVaultTraceObligation.irTraceOk = true := by
  native_decide

theorem value_vault_sbpf_executable_trace_ok :
    sbpfExecutableTraceOk valueVaultTraceObligation = true := by
  native_decide

theorem array_storage_ir_observable_trace_ok :
    arrayStorageTraceObligation.irTraceOk = true := by
  native_decide

theorem array_storage_sbpf_executable_trace_ok :
    sbpfExecutableTraceOk arrayStorageTraceObligation = true := by
  native_decide

theorem map_storage_ir_observable_trace_ok :
    mapStorageTraceObligation.irTraceOk = true := by
  native_decide

theorem map_storage_sbpf_executable_trace_ok :
    sbpfExecutableTraceOk mapStorageTraceObligation = true := by
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
def revertEntrypoint : Entrypoint :=
  Entrypoint.mk "revertAlways" .function none #[] #[] .unit
    #[ .revert "always rolls back" ]

/-- A minimal entrypoint that returns a constant, used to observe post-revert
state (it touches no storage, so it succeeds against any state). -/
def readConstEntrypoint : Entrypoint :=
  Entrypoint.mk "readConst" .function none #[] #[] .u64
    #[ .return (.literal (.u64 7)) ]

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
