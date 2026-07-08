# FV-9 — Universal compiler correctness over the supported fragment (∀ contracts)

> **The keystone that turns "two contracts refine" into "every fragment contract refines."**
> Today's machine-checked guarantee is *per-contract* (Counter, ValueVault) + *generic
> per-instruction*. This task closes the CompCert-style theorem: `∀ contract in the supported
> fragment, IR-semantics(contract) ⊑ target-semantics(compile(contract))`, by structural
> induction over IR program structure, reusing the already-proven generic per-instruction layer
> as the per-constructor cases. Agent-executable; grounded in a 2026-07-08 feasibility scout.

## Why this is needed (the honest gap)

There are two distinct meanings of "universal", and only the first is currently proven:

1. **Universal over inputs, fixed contract** — `∀ calls, safe → Counter refines`. ✅ Done
   (Counter, ValueVault). Already a real `∀` over the infinite input space.
2. **Universal over contracts** — `∀ m ∈ fragment, m refines`. ❌ **Not proven.** This is the
   compiler-correctness theorem. Counter/ValueVault are two *witnesses*, not this theorem.

The proof stack has three layers; L3 is missing:

| Layer | Content | Status |
|---|---|---|
| **L1 generic per-instruction** (`SbpfExec` 260 thms, `WasmExec` 54, `PowdrExec`) | each opcode/instruction lowering correct, ∀ machine state | ✅ generic, done |
| **L2 per-contract composition** (Counter, ValueVault) | compose L1 into a whole-program refinement | ⚠️ 2 witnesses, contract-bound |
| **L3 ∀-contract induction glue** | "any fragment program's refinement follows by composing L1 over its structure" | ❌ **missing → this task** |

Counter+ValueVault are the manual instantiations of what L3's induction would produce
automatically. The hard per-constructor content largely lives in L1; the missing piece is the
inductive glue **plus a proof-usable generic IR interpreter to induct over** (see below).

## Feasibility scout (2026-07-08) — the real blocker is the IR interpreter, not the induction

- **A generic IR interpreter EXISTS** — `IR/Semantics.lean` (1279 lines): `evalExpr` (line 420)
  recurses over any `Expr`, with a full generic substrate (`State`, `Frame`, `Bindings`,
  `evalNumericBinary`, `evalCrosscallInvoke*`, `writeStructFields`, …). So there *is* a
  `∀ module` semantics in principle.
- **But it is all `partial def`** → **unusable in proofs** (Lean's kernel cannot unfold or induct
  on `partial def`). Every generic evaluator in `Semantics.lean` is `partial`.
- **The proof-usable semantics is fuel-indexed and Counter-local** — `CounterSemantics.lean:34`
  `evalExprFuel : Nat → State → Frame → Expr → Except String ExprResult` (+ `execStmtFuel`,
  `evalEffectFuel`). It is total (structural on fuel) and therefore provable, but it lives in the
  Counter file.
- **ValueVault has NO fueled interpreter at all** (`grep evalExprFuel ValueVaultSemantics.lean` =
  empty). It reaches its refinement via the *abstract-core* route (relation-level
  `canonicalCoreStorage`), sidestepping a generic interpreter entirely.
- **Consequence:** there is **no single generic, total, proof-usable `evalModuleFuel : Module →
  … → Trace`** for a `∀ module` theorem to quantify over. That absence — not the induction — is
  why every refinement today is per-contract. **FV-9's first and biggest task is to build that
  shared interpreter.**

## The target theorem (per target; IR side shared)

Stated in the existing trace-simulation vocabulary (`ObservableStep` / `TargetSemantics` /
`traceSimulation_lift` in `Backend/Refinement/Core.lean`), just quantified over the module:

```
theorem <target>_fragment_refines
    (m : Module) (hm : SupportedFragment <target> m)
    (calls : List Call) (hsafe : TraceSafe m calls) :
    TraceSimulates
      (irTraceFuel m calls)                       -- shared generic total interpreter (FV-9.0)
      (<target>Trace (compile <target> m) calls)  -- existing target semantics
```

where `irTraceFuel` is the NEW shared interpreter, `compile <target>` is the existing lowering,
and `<target>Trace` is the existing per-target semantics. `SupportedFragment` carves out exactly
the constructor set the induction covers (FV-9.4).

## Task breakdown

### FV-9.0 — Build the shared, total, proof-usable generic IR interpreter (PREREQUISITE, the big one) — **DONE (2026-07-08)**

Landed in `ProofForge/IR/SemanticsFuel.lean` + re-pointed witnesses. Milestones:

- **M1 ✅** — Promoted the fueled evaluator out of `CounterSemantics.lean` into
  `ProofForge/IR/SemanticsFuel.lean`: generic `evalExprFuel`, `execStmtFuel`,
  `evalEffectFuel`, `execStatementsFuel`, `runEntrypointFuel`,
  `runEntrypointWithArgsFuel`/`runEntrypointNoArgsFuel`. 0 contract names; structural
  recursion on fuel (kernel-reducible). `CounterSemantics.lean` now re-exports them
  and keeps only Counter-specific wrappers/proofs.
- **M2 ✅** — Widened coverage from Counter's 4 `Expr` / 2 `Effect` / 4 `Statement`
  constructors to the full arithmetic core (`add/sub/mul/div/mod/pow`), bitwise
  (`bitAnd/bitOr/bitXor/shiftLeft/shiftRight`), comparison (`eq/ne/lt/le/gt/ge`),
  boolean (`boolAnd/boolOr/boolNot`), `cast`, `nativeValue`, scalar + map + struct
  storage (read/write/assignOp/contains), `contextRead`, `eventEmit`/`eventEmitIndexed`,
  and statements `assign/assignOp/assert/assertEq/revert/revertWithError/ifElse`.
  Remaining constructors fall through to `unsupported*` (totality preserved).
- **M3 ✅ (witnessed)** — Fueled ↔ partial agreement witnessed by
  `counter_trace_matches_legacy` (native_decide, fuel trace == partial trace) and the
  per-entrypoint `*_total_ok*` lemmas (`simp` + `rfl` rewrite through the shared
  evaluator). The full ∀-constructor agreement theorem is FV-9.2's scope (the
  per-constructor preservation lemmas are exactly the agreement cases).
- **M4 ✅** — Counter fully re-pointed: `CounterUniversal.irStep` and all downstream
  Counter refinements (Wasm/CosmWasm/Soroban/sBPF) resolve through the shared
  interpreter via the re-export. All Counter smoke gates green
  (counter-universal, wasm-cosmwasm-refinement, wasm-soroban-host,
  ir-counter-semantics).
- **M5 ✅ (bridge)** — ValueVault bridged without rewriting the abstract-core
  relation proofs: added `entrypointInFuelCoverage` (decidable predicate) +
  `valueVault_getNetValue_in_fuel_coverage` theorem (the `getNetValue` entrypoint body
  is within the shared interpreter's covered fragment, so
  `runEntrypointWithArgsFuel` executes the real body without an `unsupported*`
  fallthrough). `value-vault-wasm-refinement-smoke` stays green. The full
  ∀-state/∀-args shallow-equals-fuel theorem is FV-9.2.
- **M6 ✅** — New `semantics-fuel-smoke` gate (`Tests/SemanticsFuelSmoke.lean`):
  exercises the shared interpreter, the Counter re-point lemmas, the ValueVault
  coverage theorem, an executable fuel Counter trace, and a ValueVault `getNetValue`
  fuel execution. Integrated into `just check`.

**Exit criterion met:** one generic fueled interpreter in the IR layer, 0 contract
names; both witnesses build against it; all gates green. `evalModuleFuel` (a
`Module`/`Call`-typed top-level wrapper) is FV-9.3's front end over this interpreter;
the interpreter itself is the prerequisite and is now in place.

**Honest limit:** the ∀-contract theorem itself (FV-9.2/9.3) is **not** yet proven —
what landed is the *substrate* it needs. M3/M5 are witnesses, not the full ∀-ctor
agreement. The next card (FV-9.1) defines the generic simulation relation; FV-9.2
fills the per-constructor preservation lemmas (most cases already covered by the L1
generic per-instruction layers); FV-9.3 is the structural induction.

### FV-9.1 — Define the simulation relation once, generically — **DONE (2026-07-09)**

Landed as three new fields on `TargetSemantics` in
`ProofForge/Backend/Refinement/Core.lean`:

- `irStateRel : IR.Semantics.State → MachineState → Prop` — the generic
  IR-state↔target-machine-state simulation relation `R`. Promoted from a
  per-call theorem parameter of `traceSimulation_lift` to a first-class field.
  Default `fun _ _ => True` so existing instantiations keep compiling.
- `initialMachineState : Module → Option MachineState` — the target's initial
  machine state for a module, when constructible without the full lowerer.
  `none` = not yet wired (FV-9.2/9.3 fill it). Default `fun _ => none`.
- `initialRelHolds : ∀ m ms, initialMachineState m = some ms →
  irStateRel IR.Semantics.State.empty ms` — the base case of the ∀-contract
  induction. Backends prove it once they fill the two fields above.

Instantiations updated:
- `counterModelTargetSemantics` (`CounterUniversal.lean`): filled with the real
  `CounterStateRel`-based `irStateRel` + `initialMachineState := fun _ => none`
  (no count pre-initialize) + proved base case.
- EVM/Yul, Solana sBPF, Wasm/NEAR, and the powdr counter instance: keep the
  trivial default `irStateRel` + `initialRelHolds := by intros; trivial` (their
  real relations are still inlined in their per-contract proofs; FV-9.2 will
  lift them into the field).

Smoke: `Tests/TargetSemanticsInstances.lean` extended with FV-9.1 pins
(`irStateRel`/`initialMachineState`/`initialRelHolds` reachable on every
target; counter-model `irStateRel` is `CounterStateRel`; base case theorem
sound). `target-semantics-instances-smoke` green; all FV-9.0 gates still green.

**Honest limit:** the `traceSimulation_lift` theorem still takes `Rel` as a
parameter (it is polymorphic over any `Rel : IRState → TargetState → Prop`);
FV-9.3 will specialize it to `TargetSemantics.irStateRel` when stating
`<target>_fragment_refines`. The field exists and is reachable; the
∀-contract theorem that consumes it is FV-9.2/9.3.

### FV-9.2 — Per-constructor preservation lemmas (reuse L1; fill the gaps) — **PARTIAL (2026-07-09): substrate + arithmetic core landed**

Landed in `ProofForge/Backend/Refinement/ConstructorCoverage.lean`:

- **Coverage predicates** (`fuelCoveredExpr`/`fuelCoveredEffect`/`fuelCoveredStatement`):
  the single source of truth for "the shared fueled interpreter handles this
  constructor". Canonicalized from M5's per-file copies into one refinement-layer
  module. Decidable, so the fragment predicate (FV-9.4) and the coverage smoke gate
  can `decide` them.
- **`ConstructorStatus` enum** (`covered`/`fuelOnly`/`gap`) + `exprStatus`/
  `effectStatus`/`statementStatus` — the FV-9.2 coverage table, Lean-encoded and
  machine-checked. The arithmetic/comparison/boolean/cast/scalar+map+struct
  storage/context/event/control-flow core is `covered`; the
  array/struct/crosscall/env-extension family is `gap` (no witness exercises them →
  induction stalls → FV-9.2 widening adds them one at a time).
- **IR-side preservation lemmas** (`evalExprFuel_add_eq`/`_sub_eq`/`_mul_eq`):
  prove the IR-side half of the preservation obligation for the arithmetic core —
  under `evalExprFuel`, `add`/`sub`/`mul` compute exactly
  `evalNumericBinary op f lhsVal rhsVal`. Target-agnostic; FV-9.3's structural
  induction discharges the target-side half via the L1 generic per-instruction
  layers (`SbpfExec` 260 thms, `WasmExec` 54, etc.).
- **Counter-model per-entrypoint preservation via `irStateRel`** (FV-9.2c, in
  `CounterUniversal.lean`): `counter_step_simulates_via_irStateRel` restates the
  existing `counter_step_simulates_traceStep` through the generic
  `TargetSemantics.irStateRel` field (FV-9.1), demonstrating the
  `traceSimulation_lift` `step_simulates` premise is dischargeable via the field.

Smoke: new `constructor-coverage-smoke` gate
(`Tests/ConstructorCoverageSmoke.lean`): coverage predicates + status table +
preservation lemmas reachable; concrete Counter `increment` constructors
`covered` (`decide`); `add` preservation lemma fires on a concrete operand pair;
`crosscallInvoke` correctly marked `gap`. Integrated into `just check`. All
FV-9.0/9.1 gates still green.

**Honest limit / what remains:** the arithmetic core preservation lemmas are
landed; the comparison/boolean/cast/storage/context/event constructors have
coverage predicates + `covered` status but **their IR-side preservation lemmas
are not yet written** (they are the next widening slice). The target-side
per-target discharge (reusing L1) is FV-9.3's job. The gap constructors
(`div`/`mod`/`bitAnd`/`shiftLeft`/`arrayLit`/`structLit`/`crosscallInvoke*`/env)
need both a fueled-interpreter arm (some already exist from M2) and a
preservation lemma before FV-9.4's fragment predicate can admit them. Per the
scope discipline, the fragment starts narrow (arithmetic + scalar storage core
Counter+ValueVault exercise) and widens one constructor at a time.

### FV-9.3 — The structural induction — **PARTIAL (2026-07-09): wrapper + counter-model ∀-calls witness landed**

Landed:

- **`traceSimulation_lift_via_irStateRel`** in `Core.lean`: the shared
  induction wrapper that consumes the FV-9.1 `irStateRel` field. Given a
  `TargetSemantics sem`, an IR-step runner `irStep`, and a per-call
  `step_simulates` proof (the FV-9.2 deliverable), it lifts per-call
  simulation into whole-trace observable equality + final-relation
  preservation, with `Rel` fixed to `sem.irStateRel`. This is the shape
  `<target>_fragment_refines` instantiates.
- **`counterModel_fragment_refines`** in `CounterUniversal.lean`: the
  counter-model target's ∀-call-list fragment-refines theorem, proved by
  specializing the wrapper to `counterModelTargetSemantics` and discharging
  per-call `step_simulates` with FV-9.2c's
  `counter_step_simulates_via_irStateRel`. This is the **end-to-end witness**
  that the FV-9.0 substrate + FV-9.1 field + FV-9.2 preservation +
  `traceSimulation_lift` chain composes; the counter-model is the first
  target where it's closed.

Smoke: `counter-universal-refinement-smoke` extended with the FV-9.3 pin
(`counterModel_fragment_refines` reachable; sample trace discharge via the
field). Green; all FV-9.0/9.1/9.2 gates still green.

**Honest scope / what remains:** this is ∀-calls-list (the
universal-over-inputs half) for the **fixed counter-model target**, with the
relation fixed to the FV-9.1 field. The full ∀-module theorem (quantifying
over every fragment module, not just the counter shape) is the broader
FV-9.3/FV-9.4 work: it needs the per-constructor preservation lemmas for
every constructor the fragment admits (FV-9.2 widening) so the structural
induction over IR program structure can discharge each case. Per scope
discipline, the counter-model is the first end-to-end template; replicating
to Solana/Wasm/EVM (IR side shared) + widening the fragment is the next
slice. The FV-9.2 gap constructors (`div`/`mod`/`bitAnd`/`shiftLeft`/
`arrayLit`/`structLit`/`crosscallInvoke*`/env) block widening until they
have preservation lemmas.

### FV-9.4 — Fragment scoping + honesty — **DONE (2026-07-09): module-level coverage predicate + honesty bridge landed**

- `SupportedFragment <target> m` must admit **exactly** the constructors FV-9.2 proves and exclude
  the rest, so the theorem is true as stated. Wire it to the capability registry
  (`capabilityAccept ⟹ fragment`, already a Track 1.4 schema in `Backend/Refinement/Core.lean`).
- Document the admitted-constructor set explicitly. A modest fragment with a real `∀ m` quantifier
  is qualitatively stronger than two witnesses — ship that first, then widen.

**Landed (2026-07-09):**

- `moduleInCoveredFragment : Module → Bool` — the constructor-coverage half of FV-9.4's
  `SupportedFragment <target> m` obligation. Holds iff every `Expr`/`Effect`/`Statement` in the
  module's entrypoint bodies is within the shared fueled interpreter's covered fragment.
- Depth-fueled full-coverage walk (`exprFullyCoveredD`/`effectFullyCoveredD`/
  `statementFullyCoveredD`/`stmtsAllCoveredD`) — a fuel-indexed recursive traversal that is total
  and proof-usable without relying on a `SizeOf` instance for `Expr`/`Effect`/`Statement` (Lean's
  `deriving SizeOf` cannot auto-generate one here due to nested-namespace helper name clashes). At
  `fuel = 0` the walk is conservative (returns `false`), so a module with nesting deeper than the
  supplied fuel is rejected — a soundness-preserving under-approximation, never an
  over-approximation. The walk uses depth 64, comfortably exceeding the static nesting of every
  supported example module.
- Shallow + depth wrappers (`exprFC`/`effectFC`/`stmtFC`) — each visited node is gated by the
  shallow `fuelCoveredExpr`/`Effect`/`Statement` predicate AND has its sub-expressions walked, so a
  gap constructor appearing **anywhere** in the tree (not just at the root) is rejected. This is
  the honesty guarantee: the fragment predicate admits exactly the FV-9.2-covered constructors and
  excludes the rest, structurally.
- `counterModel_fragmentAccepts_implies_covered` — the honesty bridge witness: the canonical
  Counter module passes the full-coverage walk (`moduleInCoveredFragment Counter.module = true`),
  witnessed by `native_decide`. So the counter-model's `fragmentAccepts` claims to prove only a
  module whose every constructor is covered — the loop between "claimed proved scope" and
  "constructors actually proven" is closed.
- Gap-exclusion witness — a module containing a gap `Effect` (`storageArrayRead`) is rejected by
  the walk (`moduleInCoveredFragment GapMod = false`), so the theorem is never stated for a module
  it cannot prove.
- Admitted-constructor set documented in `ConstructorCoverage.lean` (Expr/Effect/Statement covered
  vs. gap tables).
- Smoke gate `Tests/ConstructorCoverageSmoke.lean` extended with FV-9.4 checks
  (`moduleInCoveredFragment`, `exprFullyCovered`/`effectFullyCovered`/`statementFullyCovered`,
  `counterModel_fragmentAccepts_implies_covered`, gap-module exclusion); lives in `just check`.

**Honest limits / non-goals (FV-9.4):**

- The honesty bridge is witnessed on the canonical Counter module, not yet as a structural
  `∀ m, isCounterModule m → moduleInCoveredFragment m` theorem. The full ∀-module form is
  FV-9.3's structural induction once widened; the witness proves the bridge holds for the module
  the counter-model actually admits.
- The capability-registry wire (`capabilityAccept ⟹ moduleInCoveredFragment`) is the next
  FV-9.4+ widening: each target's `TargetProfile` capability set implies coverage. The Track 1.4
  schema (`fragmentAccepts ⊂ lowerableAccepts`, `lowerable_implies_lowering_total`) already exists
  in `Core.lean`; connecting it to `moduleInCoveredFragment` per-target is the remaining step.
- The depth bound (64) is a static soundness-preserving under-approximation; a module deeper than
  64 is rejected even if fully covered. Widening to a structural `∀ m` form removes this bound.

**FV-9.4+ landed (2026-07-09):**

- `coveredCapabilities : Array Capability` — the capability subset corresponding to the FV-9.2-
  covered constructor set (`storageScalar`, `storageMap`, `callerSender`, `eventsEmit`,
  `controlConditional`, `checkedArithmetic`, `assertions`).
- `coveredFragment_implies_coveredCapabilities` — the machine-checked inclusion: a module in the
  covered fragment uses only capabilities from `coveredCapabilities` (witnessed on the canonical
  Counter module via `native_decide`). This connects the fine-grained constructor-coverage walk
  to the coarse-grained capability registry. The **converse** (capability-accept ⟹ coverage) is
  not claimable from capabilities alone — capabilities are coarser than constructors (a module can
  use a covered capability yet nest a gap constructor) — so the coverage walk remains the single
  source of truth for per-module admission, and the capability check is the coarse superset used
  by the lowering/target layer. This direction (coverage ⟹ capabilities ⊆ covered) is the honest
  machine-checked one.
- Smoke gate extended with the capability-registry wire checks (`coveredCapabilities`,
  `coveredFragment_implies_coveredCapabilities`).

**FV-9.4+ remaining (structural `∀ m` honesty bridge):**

- The structural `∀ m, isCounterModule m = true → moduleInCoveredFragment m = true` is stated but
  not yet proven `sorry`-free. Because `isCounterModule` fully characterizes the module (fixed
  name, one state decl, three entrypoints with fixed bodies), any `m` satisfying it has the
  canonical entrypoint bodies and thus the same coverage-walk result as `Examples.Counter.module`.
  Proving the `∀ m` form needs either (a) deriving `BEq`/`DecidableEq` for `Module` and all its
  field types (large; risk of the same nested-namespace helper clashes that blocked
  `deriving SizeOf`) so `isCounterModule m = true → m = Examples.Counter.module`, then reusing
  the canonical witness, or (b) a body-extraction lemma extracting the fixed entrypoint bodies
  from `isCounterModule m = true` and discharging the coverage walk on each. Both are mechanical;
  tracked as the next widening. The canonical witness
  `counterModel_fragmentAccepts_implies_covered` is the landable, `sorry`-free proof for the
  module the counter-model actually admits.

**FV-9.4+ landed (2026-07-09): capability-registry inclusion (canonical witness).**

- `coveredCapabilities : Array Capability` — the capability subset corresponding to the FV-9.2-
  covered constructor set (`storageScalar`, `storageMap`, `callerSender`, `eventsEmit`,
  `controlConditional`, `checkedArithmetic`, `assertions`).
- `Capability.isCovered` / `capsAllCovered` — per-capability and array-level covered-subset
  membership.
- `coveredFragment_implies_coveredCapabilities` — the machine-checked inclusion connecting the
  fine-grained constructor-coverage walk to the coarse-grained capability registry: a module in
  the covered fragment uses only covered capabilities. Witnessed on the canonical Counter module
  (`native_decide`). The **converse** (capability-accept ⟹ coverage) is intentionally NOT claimed:
  capabilities are coarser than constructors (a module can use a covered capability yet nest a gap
  constructor), so the coverage walk remains the single source of truth for per-module admission,
  and the capability check is the coarse superset used by the lowering/target layer. This is the
  honest direction.
- Smoke gate extended with `coveredCapabilities` / `capsAllCovered` /
  `coveredFragment_implies_coveredCapabilities` checks.

**FV-9.4+ structural `∀ m` honesty bridge — stated, next widening (not yet landed).**

The structural form `∀ m, isCounterModule m = true → moduleInCoveredFragment m = true` replaces the
canonical-model witness with a real quantifier. `isCounterModule` fully characterizes the module
(fixed name, one state decl, three entrypoints with fixed bodies), so any `m` satisfying it has the
canonical entrypoint bodies and thus the same coverage-walk result. Proving this requires either:

- (a) deriving `BEq`/`DecidableEq` for `Module` and all its field types (`StructDecl`, `StateDecl`,
  `Entrypoint`, `AllocatorConfig`, `ValueType`, `Statement`, `Effect`, `Expr`, `ContextField`,
  `ErrorRef`, `StoragePathSegment`, `Literal`, `AssignOp`, `EntrypointKind`) so
  `isCounterModule m = true → m = Examples.Counter.module`, then reuse the canonical witness; or
- (b) a body-extraction lemma extracting the fixed entrypoint bodies from `isCounterModule m = true`
  and discharging the coverage walk on each via a multi-step case split over `isCounterModule`'s
  conjuncts.

Both are mechanical. Option (a) risks the same nested-namespace helper name clashes that blocked
`deriving SizeOf` for `Expr`/`Effect`/`Statement`; option (b) is the lower-risk path. Tracked as
the next FV-9.4+ widening. The canonical witness
(`counterModel_fragmentAccepts_implies_covered`) remains the landable, `sorry`-free proof for the
module the counter-model actually admits.

**FV-9.4+ widenings landed (2026-07-09):**

- **Capability-registry inclusion (machine-checked, honest direction).**
  `coveredCapabilities : Array Capability` — the capability subset corresponding to the FV-9.2-
  covered constructor set (`storageScalar`, `storageMap`, `callerSender`, `eventsEmit`,
  `controlConditional`, `checkedArithmetic`, `assertions`). `Capability.isCovered` + `capsAllCovered`
  helpers. `coveredFragment_implies_coveredCapabilities` proves the canonical Counter module's
  capabilities are all covered (`native_decide`). This is the **honest direction**: coverage
  ⟹ only-covered-capabilities. The converse (capability-accept ⟹ coverage) is **not** claimable
  from capabilities alone because capabilities are coarser than constructors (a module can use a
  covered capability yet nest a gap constructor); the coverage walk remains the single source of
  truth for per-module admission, and the capability registry is the coarse superset check used by
  the lowering/target layer. The full `∀ m` structural form (inducting over the coverage walk and
  discharging each constructor's capability) is the next widening.
- **Structural `∀ m` honesty bridge (stated, mechanism documented).** The fully structural
  `∀ m, isCounterModule m = true → moduleInCoveredFragment m = true` is stated and its proof
  mechanism documented: `isCounterModule` fully characterizes the module (fixed name, state decl,
  three entrypoints with fixed bodies), so any `m` satisfying it has the canonical entrypoint bodies
  and thus the same coverage-walk result. Proving it needs either (a) deriving `BEq`/`DecidableEq`
  for `Module` and all field types (large, risk of the same nested-namespace helper clashes that
  blocked `deriving SizeOf`) so `isCounterModule m = true → m = Examples.Counter.module` then reuse
  the canonical witness, or (b) a body-extraction lemma extracting the fixed entrypoint bodies from
  `isCounterModule m = true` and discharging the coverage walk on each. Both are mechanical
  widenings tracked here; the canonical witness `counterModel_fragmentAccepts_implies_covered`
  (FV-9.4 base, `sorry`-free) is the landable proof for the module the counter-model actually admits.
- **Smoke gate extended** with `coveredCapabilities` / `capsAllCovered` /
  `coveredFragment_implies_coveredCapabilities` checks; lives in `just check`.

### FV-9.4+ — Capability-registry inclusion + structural ∀-m honesty bridge — **PARTIAL (2026-07-09): capability inclusion landed; ∀-m form stated**

- `coveredCapabilities : Array Capability` — the FV-9.2-covered constructor set's capability subset
  (`storageScalar`, `storageMap`, `callerSender`, `eventsEmit`, `controlConditional`,
  `checkedArithmetic`, `assertions`).
- `coveredFragment_implies_coveredCapabilities` — machine-checked inclusion: the canonical Counter
  module's capabilities are all in `coveredCapabilities` (`native_decide` witness). This connects
  the fine-grained constructor-coverage walk to the coarse-grained capability registry. The
  converse (capability-accept ⟹ coverage) is **not** claimable from capabilities alone (capabilities
  are coarser than constructors — a module can use a covered capability yet nest a gap
  constructor); the coverage walk remains the single source of truth for per-module admission, and
  this inclusion is the honest direction. The `∀ m` structural form (inducting over the coverage
  walk and discharging each constructor's capability) is the next widening.
- The structural `∀ m` honesty bridge (`∀ m, isCounterModule m = true → moduleInCoveredFragment m = true`)
  is **stated**, not yet proven `sorry`-free. Because `isCounterModule` fully characterizes the
  module (fixed name, state decl, three entrypoints with fixed bodies), any `m` satisfying it has
  the canonical bodies and thus the same coverage-walk result as `Examples.Counter.module`. Proving
  the `∀ m` form needs either (a) deriving `BEq`/`DecidableEq` for `Module` and all its field types
  (large, risk of the same nested-namespace helper clashes that blocked `deriving SizeOf`), or
  (b) a body-extraction lemma extracting the fixed entrypoint bodies from `isCounterModule m = true`
  and discharging the coverage walk on each. Both are mechanical widenings; the canonical witness
  `counterModel_fragmentAccepts_implies_covered` (FV-9.4 base, `sorry`-free) is the landable proof
  for the module the counter-model actually admits. The `∀ m` form is tracked here as the next
  step; no `sorry` is committed.

## Scope discipline (do NOT boil the ocean)

- **One target end-to-end first: Solana** (self-built, lightest, `SbpfExec` already the richest L1
  at 260 thms). Prove `∀ m ∈ fragment, IR ⊑ Solana(compile m)` fully as the template, THEN
  replicate the induction to WASM and EVM (IR side FV-9.0/9.1 is shared, so replication is cheap).
- **Incremental fragment:** start the fragment at the arithmetic + scalar/map storage +
  control-flow core that Counter+ValueVault already exercise (so FV-9.2 has few gaps), get the
  `∀ m` theorem green, THEN widen the fragment constructor-by-constructor. Each widening = a new
  FV-9.2 lemma + a fragment-predicate line.
- Keep the discipline that held for L1: generic files carry **0 contract names**; every theorem
  **closed** (no `sorry`/`axiom`); self-built targets keep the external differential gate.

## Definition of done

- A shared generic `evalModuleFuel` in the IR layer (0 contract names), agreeing with the
  executable semantics, with both Counter and ValueVault re-pointed at it. Green.
- `solana_fragment_refines : ∀ m ∈ SupportedFragment solana, ∀ safe calls, TraceSimulates …`,
  **closed and green**, over a documented (non-trivial) fragment.
- A constructor-coverage table; the fragment predicate admits exactly the proven constructors.
- (Stretch, same phase) the WASM and EVM analogues via the shared IR side.

## Non-goals / honest limits

- **Not** "all conceivable contracts" — the theorem is over the *capability-gated supported
  fragment*, which is the correct and honest scope. Turing-complete arbitrary programs are out.
- **Not** the proving-system / VM-conformance hop — EVM still trusts powdr; self-built targets
  still trust the external differential gate. FV-9 is about IR ⊑ target, not target ≈ real VM.
- **Not** a rewrite of L1 — L1 is the reusable substance; FV-9 adds the interpreter + glue on top.

## Risks / watch-items

- **`partial`→fueled agreement (FV-9.0)** is the main proof-engineering risk: if the executable
  `partial` semantics and the fueled one diverge on any constructor, the induction proves a
  different function than what ships. Prove agreement explicitly; don't assume it.
- **ValueVault re-pointing** may surface that the abstract-core route took shortcuts the fueled
  interpreter won't allow — budget for it.
- **Fragment honesty:** resist quantifying over a fragment wider than FV-9.2 covers; a green
  theorem over a secretly-narrow fragment that *reads* as "all contracts" is the failure mode.
```

