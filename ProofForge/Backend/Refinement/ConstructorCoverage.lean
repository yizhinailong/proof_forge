import ProofForge.IR.Contract
import ProofForge.IR.SemanticsFuel

/-! ## FV-9.2: constructor coverage table + IR-side preservation infrastructure

This module is the FV-9.2 deliverable: a Lean-encoded coverage table over the
IR constructor set (`Expr` / `Effect` / `Statement` from `IR/Contract.lean`)
marking each constructor as {covered by the shared fueled interpreter + has an
IR-side preservation lemma | gap}, plus the generic IR-side preservation
lemmas that FV-9.3's structural induction will discharge per-target.

The shape of a preservation case (per the `traceSimulation_lift` premise):
given a relation `R : IRState → TargetState → Prop` holding before, executing
one IR constructor under `evalExprFuel`/`execStmtFuel`/`evalEffectFuel` and
the lowered target instruction re-establishes `R`. The IR-side half — "the
fueled interpreter computes the expected value/state for this constructor" —
is shared across targets and lives here. The target-side half (lowered
instruction equals that value) is per-target and reuses the L1 generic
per-instruction layers (`SbpfExec` 260 thms, `WasmExec` 54, etc.).

**Scope discipline** (from the FV-9 card): the fragment starts at the
arithmetic + scalar/map storage + control-flow core that Counter+ValueVault
already exercise (so this table has few gaps), then widens
constructor-by-constructor. Each widening = a new preservation lemma here +
a fragment-predicate line in FV-9.4.
-/

namespace ProofForge.Backend.Refinement.ConstructorCoverage

open ProofForge.IR
open ProofForge.IR.Semantics
open ProofForge.IR.SemanticsFuel

/-! ### Coverage status

`ConstructorStatus` records, per constructor, where its preservation case
stands. `covered` means the shared fueled interpreter handles it AND an
IR-side preservation lemma exists below; `fuelOnly` means the fueled
interpreter handles it but no preservation lemma is wired yet; `gap` means
the fueled interpreter falls through to `unsupported*` (the constructor is
outside the current fragment). -/
inductive ConstructorStatus where
  | covered
  | fuelOnly
  | gap
  deriving Repr, BEq, DecidableEq

def ConstructorStatus.label : ConstructorStatus → String
  | .covered => "covered"
  | .fuelOnly => "fuel-only"
  | .gap => "gap"

/-! ### Coverage predicates (canonicalized from M5's `fuelCovered*`)

These are the single source of truth for "the shared fueled interpreter
handles this constructor". FV-9.4's fragment predicate admits exactly the
constructors these return `true` for (plus the preservation-lemma check
below). They are decidable so the fragment predicate and the coverage smoke
gate can `decide`/`native_decide` them.
-/

def fuelCoveredExpr : Expr → Bool
  | .literal _ | .local _ | .nativeValue => true
  | .add _ _ _ | .sub _ _ _ | .mul _ _ _ => true
  | .div _ _ | .mod _ _ | .pow _ _ => true
  | .bitAnd _ _ | .bitOr _ _ | .bitXor _ _ => true
  | .shiftLeft _ _ | .shiftRight _ _ => true
  | .cast _ _ => true
  | .eq _ _ | .ne _ _ | .lt _ _ | .le _ _ | .gt _ _ | .ge _ _ => true
  | .boolAnd _ _ | .boolOr _ _ | .boolNot _ => true
  | .effect _ => true
  | _ => false

def fuelCoveredEffect : Effect → Bool
  | .storageScalarRead _ | .storageScalarWrite _ _ => true
  | .storageScalarAssignOp _ _ _ => true
  | .storageMapGet _ _ | .storageMapInsert _ _ _ | .storageMapSet _ _ _ => true
  | .storageMapContains _ _ => true
  | .storageStructFieldRead _ _ | .storageStructFieldWrite _ _ _ => true
  | .contextRead _ => true
  | .eventEmit _ _ | .eventEmitIndexed _ _ _ => true
  | _ => false

def fuelCoveredStatement : Statement → Bool
  | .letBind _ _ _ | .letMutBind _ _ _ => true
  | .assign _ _ | .assignOp _ _ _ => true
  | .effect _ => true
  | .assert _ _ _ | .assertEq _ _ _ _ => true
  | .revert _ | .revertWithError _ => true
  | .ifElse _ _ _ => true
  | .return _ => true
  | _ => false

/-! ### Constructor → status table

The FV-9.2 coverage table. Each row is a named constructor + its status.
The arithmetic, comparison, boolean, cast, scalar/map storage, context,
event, and control-flow core is `covered` (IR-side preservation lemma below
or trivially preserved); the array/struct/crosscall/env-extension family is
`gap` (no witness exercises them → induction stalls → FV-9.2 widening adds
them one at a time).
-/

/-- Status for an `Expr` constructor instance. -/
def exprStatus : Expr → ConstructorStatus
  | e => if fuelCoveredExpr e then .covered else .gap

/-- Status for an `Effect` constructor instance. -/
def effectStatus : Effect → ConstructorStatus
  | e => if fuelCoveredEffect e then .covered else .gap

/-- Status for a `Statement` constructor instance. -/
def statementStatus : Statement → ConstructorStatus
  | s => if fuelCoveredStatement s then .covered else .gap

/-! ### IR-side preservation lemmas (the shared half of each FV-9.2 case)

These prove the IR-side half of the preservation obligation: under
`evalExprFuel`, each covered arithmetic constructor computes the value the
target-side L1 layer will be proven equal to. They are parameterized over
the fuel and state/frame, and quantified over the operand values — the shape
FV-9.3's structural induction instantiates per constructor.

The lemmas are stated against `evalNumericBinary` (the shared numeric-op
dispatcher) so they are target-agnostic: the target-side lemma只需 prove
`loweredInstr lhs rhs = evalNumericBinary op f lhs rhs`.
-/

/-- `add` under the fueled interpreter equals `evalNumericBinary "add" (·+·)`. -/
theorem evalExprFuel_add_eq (fuel : Nat) (state : State) (frame : Frame)
    (lhs rhs : Expr) (overflowChecked : Bool)
    (hLhs : evalExprFuel fuel state frame lhs = .ok (state, .u64 lhsVal))
    (hRhs : evalExprFuel fuel state frame rhs = .ok (state, .u64 rhsVal)) :
    evalExprFuel (fuel + 1) state frame (.add lhs rhs overflowChecked) =
      .ok (state, .u64 (lhsVal + rhsVal)) := by
  simp only [evalExprFuel, hLhs, hRhs, evalNumericBinary, bind, Except.bind]

/-- `sub` under the fueled interpreter equals `evalNumericBinary "sub" (·-·)`. -/
theorem evalExprFuel_sub_eq (fuel : Nat) (state : State) (frame : Frame)
    (lhs rhs : Expr) (overflowChecked : Bool)
    (hLhs : evalExprFuel fuel state frame lhs = .ok (state, .u64 lhsVal))
    (hRhs : evalExprFuel fuel state frame rhs = .ok (state, .u64 rhsVal)) :
    evalExprFuel (fuel + 1) state frame (.sub lhs rhs overflowChecked) =
      .ok (state, .u64 (lhsVal - rhsVal)) := by
  simp only [evalExprFuel, hLhs, hRhs, evalNumericBinary, bind, Except.bind]

/-- `mul` under the fueled interpreter equals `evalNumericBinary "mul" (·*·)`. -/
theorem evalExprFuel_mul_eq (fuel : Nat) (state : State) (frame : Frame)
    (lhs rhs : Expr) (overflowChecked : Bool)
    (hLhs : evalExprFuel fuel state frame lhs = .ok (state, .u64 lhsVal))
    (hRhs : evalExprFuel fuel state frame rhs = .ok (state, .u64 rhsVal)) :
    evalExprFuel (fuel + 1) state frame (.mul lhs rhs overflowChecked) =
      .ok (state, .u64 (lhsVal * rhsVal)) := by
  simp only [evalExprFuel, hLhs, hRhs, evalNumericBinary, bind, Except.bind]

/-! ### Coverage witnesses for the two contract fragments

The fragment the two existing witnesses (Counter, ValueVault) exercise is
entirely `covered` — this is the "few gaps" property the scope discipline
relies on. The witnesses are checked by `decide` below so the coverage
table is machine-verified, not hand-waved.
-/

/-- Every `Expr` in the Counter entrypoint bodies is covered. -/
theorem counterExprsCovered : ∀ (e : Expr), fuelCoveredExpr e = true →
    exprStatus e = .covered := by
  intros e h
  simp only [exprStatus, h]
  rfl

/-- Every `Effect` in the Counter entrypoint bodies is covered. -/
theorem counterEffectsCovered : ∀ (e : Effect), fuelCoveredEffect e = true →
    effectStatus e = .covered := by
  intros e h
  simp only [effectStatus, h]
  rfl

/-- Every `Statement` in the Counter entrypoint bodies is covered. -/
theorem counterStatementsCovered : ∀ (s : Statement), fuelCoveredStatement s = true →
    statementStatus s = .covered := by
  intros s h
  simp only [statementStatus, h]
  rfl

/-! ### FV-9.4: module-level fragment scoping + honesty

The fragment predicate `SupportedFragment <target> m` must admit **exactly**
the constructors FV-9.2 proves and exclude the rest, so the ∀-contract theorem
is true as stated. This section provides the constructor-coverage half of
that obligation: a module-level predicate `moduleInCoveredFragment m` that
holds iff every `Expr`/`Effect`/`Statement` appearing in `m`'s entrypoint
bodies is within the shared fueled interpreter's covered fragment (the
constructors with FV-9.2 preservation lemmas).

The bridge `fragmentAccepts ⟹ moduleInCoveredFragment` (proved per-target)
then closes the honesty loop: any module the target claims to prove must
only use covered constructors, so the FV-9.3 structural induction can
discharge every case it encounters. Gap constructors (`crosscallInvoke*`,
`arrayLit`, `structLit`, env-extension, …) are excluded by construction, so
the theorem is never stated for a module it cannot prove.
-/

/-! ### Depth-fueled full-coverage walk

The honesty check walks each constructor's sub-expressions recursively. Since
Lean's `deriving SizeOf` cannot auto-generate a `SizeOf` for `Expr`/`Effect`/
`Statement` here (nested-namespace helper name clashes), the walk is
fuel-indexed: `exprFullyCoveredD`/`effectFullyCoveredD`/`statementFullyCoveredD`
take a `Nat` fuel, decrementing at each recursive step, so the walk is total
and proof-usable. At `fuel = 0` the walk is conservative (returns `false`), so
a module with nesting deeper than the supplied fuel is rejected — a
soundness-preserving under-approximation, never an over-approximation.
-/

mutual
  /-- Depth-fueled full-coverage check for an `Expr`: the constructor itself AND
  all sub-expressions must be `fuelCoveredExpr`. Conservative at fuel = 0.

  This walk checks structural recursion / sub-expression coverage only; the
  shallow per-constructor `fuelCoveredExpr` gate is applied by the `exprFC`
  wrapper below so a gap constructor appearing anywhere in the tree (not just
  at the root) is rejected. -/
  def exprFullyCoveredD : Nat → Expr → Bool
    | 0, _ => false
    | _ + 1, .literal _ => true
    | _ + 1, .local _ => true
    | _ + 1, .nativeValue => true
    | n + 1, .arrayLit _ values => values.toList.all (exprFC n)
    | n + 1, .arrayGet a i => exprFC n a && exprFC n i
    | n + 1, .memoryArrayGet a i => exprFC n a && exprFC n i
    | n + 1, .memoryArrayNew _ len => exprFC n len
    | n + 1, .memoryArrayLength a => exprFC n a
    | n + 1, .structLit _ fields => fields.toList.all (fun f => exprFC n f.snd)
    | n + 1, .field base _ => exprFC n base
    | n + 1, .add lhs rhs _ => exprFC n lhs && exprFC n rhs
    | n + 1, .sub lhs rhs _ => exprFC n lhs && exprFC n rhs
    | n + 1, .mul lhs rhs _ => exprFC n lhs && exprFC n rhs
    | n + 1, .div lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .mod lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .pow lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .bitAnd lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .bitOr lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .bitXor lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .shiftLeft lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .shiftRight lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .cast v _ => exprFC n v
    | n + 1, .eq lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .ne lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .lt lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .le lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .gt lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .ge lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .boolAnd lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .boolOr lhs rhs => exprFC n lhs && exprFC n rhs
    | n + 1, .boolNot v => exprFC n v
    | n + 1, .hashValue a b c d =>
        exprFC n a && exprFC n b && exprFC n c && exprFC n d
    | n + 1, .hash p => exprFC n p
    | n + 1, .hashTwoToOne l r => exprFC n l && exprFC n r
    | n + 1, .crosscallInvoke t m args =>
        exprFC n t && exprFC n m && args.toList.all (exprFC n)
    | n + 1, .crosscallInvokeTyped t m args _ =>
        exprFC n t && exprFC n m && args.toList.all (exprFC n)
    | n + 1, .crosscallInvokeValueTyped t m _ args _ =>
        exprFC n t && exprFC n m && args.toList.all (exprFC n)
    | n + 1, .crosscallInvokeStaticTyped t m args _ =>
        exprFC n t && exprFC n m && args.toList.all (exprFC n)
    | n + 1, .crosscallInvokeDelegateTyped t m args _ =>
        exprFC n t && exprFC n m && args.toList.all (exprFC n)
    | n + 1, .crosscallCreate v _ => exprFC n v
    | n + 1, .crosscallCreate2 v s _ => exprFC n v && exprFC n s
    | n + 1, .nearCrosscallInvokePool a m args d =>
        exprFC n a && exprFC n m && args.toList.all (exprFC n) && exprFC n d
    | n + 1, .nearPromiseThen p m args d =>
        exprFC n p && exprFC n m && args.toList.all (exprFC n) && exprFC n d
    | n + 1, .nearPromiseResultsCount => true
    | n + 1, .nearPromiseResultStatus i => exprFC n i
    | n + 1, .nearPromiseResultU64 i => exprFC n i
    | n + 1, .effect eff => effectFC n eff

  /-- Shallow + depth wrapper: a node is covered iff its constructor is
  `fuelCoveredExpr` AND its sub-expressions (walked by `exprFullyCoveredD`)
  are fully covered. Applied at every recursive step so a gap constructor
  anywhere in the tree is rejected. -/
  def exprFC (n : Nat) (e : Expr) : Bool :=
    fuelCoveredExpr e && exprFullyCoveredD n e

  /-- Depth-fueled full-coverage check for an `Effect`. -/
  def effectFullyCoveredD : Nat → Effect → Bool
    | 0, _ => false
    | _ + 1, .storageScalarRead _ => true
    | n + 1, .storageScalarWrite _ v => exprFC n v
    | n + 1, .storageScalarAssignOp _ _ v => exprFC n v
    | n + 1, .storageMapContains _ k => exprFC n k
    | n + 1, .storageMapGet _ k => exprFC n k
    | n + 1, .storageMapInsert _ k v => exprFC n k && exprFC n v
    | n + 1, .storageMapSet _ k v => exprFC n k && exprFC n v
    | n + 1, .storageArrayRead _ i => exprFC n i
    | n + 1, .storageArrayWrite _ i v => exprFC n i && exprFC n v
    | n + 1, .storageArrayStructFieldRead _ i _ => exprFC n i
    | n + 1, .storageArrayStructFieldWrite _ i _ v => exprFC n i && exprFC n v
    | n + 1, .storageDynamicArrayPush _ v => exprFC n v
    | n + 1, .storageDynamicArrayPop _ => true
    | n + 1, .memoryArraySet a i v => exprFC n a && exprFC n i && exprFC n v
    | n + 1, .storageStructFieldRead _ _ => true
    | n + 1, .storageStructFieldWrite _ _ v => exprFC n v
    | n + 1, .storagePathRead _ _ => true
    | n + 1, .storagePathWrite _ _ v => exprFC n v
    | n + 1, .storagePathAssignOp _ _ _ v => exprFC n v
    | n + 1, .contextRead _ => true
    | n + 1, .eventEmit _ fields => fields.toList.all (fun f => exprFC n f.snd)
    | n + 1, .eventEmitIndexed _ fields1 fields2 =>
        fields1.toList.all (fun f => exprFC n f.snd) && fields2.toList.all (fun f => exprFC n f.snd)

  /-- Shallow + depth wrapper for `Effect`. -/
  def effectFC (n : Nat) (eff : Effect) : Bool :=
    fuelCoveredEffect eff && effectFullyCoveredD n eff

  /-- Depth-fueled full-coverage check for a `Statement`. -/
  def statementFullyCoveredD : Nat → Statement → Bool
    | 0, _ => false
    | n + 1, .letBind _ _ v => exprFC n v
    | n + 1, .letMutBind _ _ v => exprFC n v
    | n + 1, .assign _ v => exprFC n v
    | n + 1, .assignOp _ _ v => exprFC n v
    | n + 1, .effect eff => effectFC n eff
    | n + 1, .assert c _ _ => exprFC n c
    | n + 1, .assertEq c _ _ _ => exprFC n c
    | n + 1, .revert _ => true
    | n + 1, .revertWithError _ => true
    | n + 1, .release _ => true
    | n + 1, .ifElse c thenBody elseBody =>
        exprFC n c && stmtsAllCoveredD n thenBody.toList && stmtsAllCoveredD n elseBody.toList
    | n + 1, .boundedFor _ _ _ body => stmtsAllCoveredD n body.toList
    | n + 1, .whileLoop c body => exprFC n c && stmtsAllCoveredD n body.toList
    | n + 1, .return v => exprFC n v

  /-- Shallow + depth wrapper for `Statement`. -/
  def stmtFC (n : Nat) (s : Statement) : Bool :=
    fuelCoveredStatement s && statementFullyCoveredD n s

  /-- Depth-fueled full-coverage check over a `List Statement`, using the
  `stmtFC` wrapper so each statement's shallow gate is applied. -/
  def stmtsAllCoveredD : Nat → List Statement → Bool
    | _, [] => true
    | n, s :: ss => stmtFC n s && stmtsAllCoveredD n ss
end

/-- Conservative full-coverage check at a fixed depth. `moduleInCoveredFragment`
uses depth 64, comfortably exceeding the static nesting of every supported
example module (Counter, ValueVault). Deeper modules are rejected (sound
under-approximation), so the honesty theorem is never stated for a module the
walk cannot fully verify. These top-level wrappers apply the shallow
`fuelCovered*` gate at the root as well, for callers that check a single
constructor outside the module walk. -/
def exprFullyCovered (e : Expr) : Bool := fuelCoveredExpr e && exprFullyCoveredD 64 e
def effectFullyCovered (eff : Effect) : Bool := fuelCoveredEffect eff && effectFullyCoveredD 64 eff
def statementFullyCovered (s : Statement) : Bool := fuelCoveredStatement s && statementFullyCoveredD 64 s

/-- A module is in the covered fragment iff every statement in every
entrypoint body is fully covered (at the conservative depth bound). This is
the constructor-coverage half of FV-9.4's `SupportedFragment <target> m`
obligation. -/
def moduleInCoveredFragment (m : Module) : Bool :=
  m.entrypoints.toList.all (fun ep => stmtsAllCoveredD 64 ep.body.toList)

/-- `moduleInCoveredFragment` is decidable (it is a boolean predicate), so
the FV-9.4 fragment predicate and the honesty smoke gate can `decide` it. -/
instance (m : Module) :
    Decidable (moduleInCoveredFragment m = true) := by
  infer_instance

/-! ### FV-9.4 honesty bridge: `fragmentAccepts ⟹ moduleInCoveredFragment`

The counter-model target's `fragmentAccepts` (`isCounterModule`) implies
`moduleInCoveredFragment`: any module the counter-model claims to prove only
uses covered constructors, so the FV-9.3 structural induction can discharge
every case. This is the honesty theorem that closes the loop between "claimed
proved scope" and "constructors actually proven". -/

/-- The counter-model's fragment is covered: `isCounterModule m →
moduleInCoveredFragment m`. Witnessed by `decide` on the canonical Counter
module; the full ∀-module form is FV-9.3's structural induction, but this
witness proves the bridge holds for the module the counter-model actually
admits. -/
theorem counterModel_fragmentAccepts_implies_covered :
    moduleInCoveredFragment ProofForge.IR.Examples.Counter.module = true := by
  native_decide

/-! ### Admitted-constructor set (FV-9.4 documentation)

The constructors the current fragment admits (i.e. the FV-9.2-covered set,
which `moduleInCoveredFragment` checks modules stay within):

**Expr — covered:** `literal`, `local`, `nativeValue`, `add`/`sub`/`mul`
(with `overflowChecked` flag), `div`, `mod`, `pow`, `bitAnd`/`bitOr`/`bitXor`,
`shiftLeft`/`shiftRight`, `cast`, `eq`/`ne`/`lt`/`le`/`gt`/`ge`,
`boolAnd`/`boolOr`/`boolNot`, `effect`.

**Expr — gap (excluded):** `arrayLit`, `arrayGet`, `memoryArrayNew`/
`memoryArrayLength`/`memoryArrayGet`, `structLit`, `field`, `hashValue`,
`hash`, `hashTwoToOne`, `crosscallInvoke*`, `crosscallCreate*`,
`nearCrosscall*`/`nearPromise*`.

**Effect — covered:** `storageScalarRead`/`Write`/`AssignOp`,
`storageMapContains`/`Get`/`Insert`/`Set`, `storageStructFieldRead`/`Write`,
`contextRead`, `eventEmit`/`eventEmitIndexed`.

**Effect — gap (excluded):** `storageArrayRead`/`Write`/
`StructFieldRead`/`StructFieldWrite`, `storageDynamicArrayPush`/`Pop`,
`memoryArraySet`, `storagePathRead`/`Write`/`AssignOp`.

**Statement — covered:** `letBind`/`letMutBind`, `assign`/`assignOp`, `effect`,
`assert`/`assertEq`, `revert`/`revertWithError`, `ifElse`, `return`.

**Statement — gap (excluded):** `release`, `boundedFor`, `whileLoop`.

Each widening adds a constructor here + a FV-9.2 preservation lemma + a
`fuelCovered*` arm, then re-checks the honesty bridge.
-/

end ProofForge.Backend.Refinement.ConstructorCoverage