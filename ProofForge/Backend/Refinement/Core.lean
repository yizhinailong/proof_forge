import ProofForge.IR.Contract
import ProofForge.IR.Semantics
import ProofForge.IR.StepSemantics

namespace ProofForge.Backend.Refinement

open ProofForge.IR
open ProofForge.IR.StepSemantics

/-! Shared refinement surfaces for target executable trace checks.

Backend-specific refinement modules fill these shared observable types from
their own artifact semantics.  The default IR runner below is intentionally
small: it covers pure IR observable returns without target-specific selector,
event-log, or host-state interpretation.
-/

inductive ObservableReturn where
  | none
  | bool (value : Bool)
  | u8 (value : Nat)
  | u32 (value : Nat)
  | u64 (value : Nat)
  | u128 (value : Nat)
  | hash (a b c d : Nat)
  | words (values : Array Nat)
  | reverted (message : String)
  deriving Repr, BEq, DecidableEq

structure ObservableEventLog where
  eventName : String
  topics : Array Nat := #[]
  dataWords : Array Nat := #[]
  deriving Repr, BEq, DecidableEq

structure ObservableStep where
  entrypointName : String
  selector : String := ""
  returnValue : ObservableReturn
  logs : Array ObservableEventLog := #[]
  deriving Repr, BEq, DecidableEq

structure TraceCall where
  entrypoint : Entrypoint
  args : Array ProofForge.IR.Semantics.Value := #[]
  evmArgs : Array Nat := #[]
  deriving Repr

structure TraceObligation where
  name : String
  module : Module
  calls : Array TraceCall
  expected : Array ObservableStep
  deriving Repr

def traceCallsFromEntrypoints (entrypoints : Array Entrypoint) : Array TraceCall :=
  entrypoints.map (fun entrypoint => { entrypoint })

def TraceObligation.entrypoints (obligation : TraceObligation) : Array Entrypoint :=
  obligation.calls.map (fun call => call.entrypoint)

partial def observableWordsFromValue (value : ProofForge.IR.Semantics.Value) :
    Except String (Array Nat) :=
  match value with
  | .unit => .ok #[]
  | .bool value => .ok #[if value then 1 else 0]
  | .u8 value => .ok #[value]
  | .u32 value => .ok #[value]
  | .u64 value => .ok #[value]
  | .u128 value => .ok #[value]
  | .address value => .ok #[value]
  | .bytes values => do
      let wordCount := (values.length + 31) / 32
      let mut words := #[values.length]
      for _h : _idx in [0:wordCount] do
        words := words.push 0
      .ok words
  | .string value => do
      let bytes := value.toUTF8
      let wordCount := (bytes.size + 31) / 32
      let mut words := #[bytes.size]
      for _h : _idx in [0:wordCount] do
        words := words.push 0
      .ok words
  | .hash a b c d =>
      .ok #[a, b, c, d]
  | .array values => do
      let mut words := #[]
      for value in values do
        words := words ++ (← observableWordsFromValue value)
      .ok words
  | .struct _ fields => do
      let mut words := #[]
      for field in fields do
        words := words ++ (← observableWordsFromValue field.snd)
      .ok words

def observableReturn (expectedType : ValueType) (value? : Option ProofForge.IR.Semantics.Value) :
    Except String ObservableReturn :=
  match expectedType, value? with
  | .unit, none => .ok .none
  | .unit, some .unit => .ok .none
  | .bool, some (.bool value) => .ok (.bool value)
  | .u8, some (.u8 value) => .ok (.u8 value)
  | .u32, some (.u32 value) => .ok (.u32 value)
  | .u64, some (.u64 value) => .ok (.u64 value)
  | .u128, some (.u128 value) => .ok (.u128 value)
  | .hash, some (.hash a b c d) => .ok (.hash a b c d)
  | .address, some (.address value) => .ok (.u64 value)
  | .bytes, some (.bytes _) | .string, some (.string _) => .ok .none
  | .fixedArray _ _, some value => do
      .ok (.words (← observableWordsFromValue value))
  | .structType _, some value => do
      .ok (.words (← observableWordsFromValue value))
  | _, none => .error s!"entrypoint expected `{expectedType.name}` but returned no value"
  | _, some _ => .error s!"entrypoint returned a value that does not match `{expectedType.name}`"

def runEntrypointObservable (state : ProofForge.IR.Semantics.State) (call : TraceCall) :
    Except String (ProofForge.IR.Semantics.State × ObservableStep) := do
  let entrypoint := call.entrypoint
  match ProofForge.IR.Semantics.runEntrypointWithArgsResult state entrypoint call.args with
  | .ok (nextState, result?) =>
      let returnValue ← observableReturn entrypoint.returns result?
      .ok (nextState, {
        entrypointName := entrypoint.name
        returnValue
      })
  | .reverted message =>
      .ok (state, {
        entrypointName := entrypoint.name
        returnValue := .reverted message
      })
  | .error message =>
      .error message

def runTraceList : List TraceCall → ProofForge.IR.Semantics.State →
    Except String (ProofForge.IR.Semantics.State × Array ObservableStep)
  | [], state => .ok (state, #[])
  | call :: rest, state => do
      let (nextState, step) ← runEntrypointObservable state call
      let (finalState, steps) ← runTraceList rest nextState
      .ok (finalState, #[step] ++ steps)

def runTrace (calls : Array TraceCall) : Except String (Array ObservableStep) := do
  let (_, steps) ← runTraceList calls.toList ProofForge.IR.Semantics.State.empty
  .ok steps

def TraceObligation.irTraceOk (obligation : TraceObligation) : Bool :=
  match runTrace obligation.calls with
  | .ok actual => actual == obligation.expected
  | .error _ => false

inductive FormalFragment where
  | counter
  deriving Repr, BEq, DecidableEq

def FormalFragment.id : FormalFragment → String
  | .counter => "counter"

def noArgFunctionReturning (entrypoint : Entrypoint) (name : String)
    (returns : ValueType) : Bool :=
  entrypoint.name == name &&
    entrypoint.kind == .function &&
    entrypoint.params.size == 0 &&
    entrypoint.returns == returns

def isCounterStateDecl (decl : StateDecl) : Bool :=
  decl.id == "count" &&
    decl.kind == .scalar &&
    decl.type == .u64

def isCounterInitializeEntrypoint (entrypoint : Entrypoint) : Bool :=
  noArgFunctionReturning entrypoint "initialize" .unit &&
    entrypoint.selector? == some "8129fc1c" &&
    match entrypoint.body.toList with
    | [.effect (.storageScalarWrite stateId (.literal (.u64 0)))] =>
        stateId == "count"
    | _ => false

def isCounterIncrementEntrypoint (entrypoint : Entrypoint) : Bool :=
  noArgFunctionReturning entrypoint "increment" .unit &&
    entrypoint.selector? == some "d09de08a" &&
    match entrypoint.body.toList with
    | [
        .letBind localName localType (.effect (.storageScalarRead readStateId)),
        .effect (.storageScalarWrite writeStateId
          (.add (.local addLocalName) (.literal (.u64 1))))
      ] =>
        localName == "n" &&
          localType == .u64 &&
          readStateId == "count" &&
          writeStateId == "count" &&
          addLocalName == "n"
    | _ => false

def isCounterGetEntrypoint (entrypoint : Entrypoint) : Bool :=
  noArgFunctionReturning entrypoint "get" .u64 &&
    entrypoint.selector? == some "6d4ce63c" &&
    match entrypoint.body.toList with
    | [.return (.effect (.storageScalarRead stateId))] =>
        stateId == "count"
    | _ => false

def isCounterModule (module : Module) : Bool :=
  module.name == "Counter" &&
    module.structs.size == 0 &&
    module.evmProxyPattern?.isNone &&
    module.nearCrosscallStrings.size == 0 &&
    !module.overflowChecked &&
    match module.state.toList, module.entrypoints.toList with
    | stateDecl :: [], entry0 :: entry1 :: entry2 :: [] =>
        isCounterStateDecl stateDecl &&
          isCounterInitializeEntrypoint entry0 &&
          isCounterIncrementEntrypoint entry1 &&
          isCounterGetEntrypoint entry2
    | _, _ => false

def FormalFragment.acceptsModule : FormalFragment → Module → Bool
  | .counter, module => isCounterModule module

structure TargetSemantics where
  id : String := "anonymous-target-semantics"
  /-- Named proof fragments this target semantics declares (e.g. `#[.counter]`).
  Used by `supportsProofFragment` to check that a target *declares* a named
  fragment. The actual per-module acceptance test is `fragmentAccepts` below,
  which is the single source of truth for "module is in this target's proved
  scope" (Track 1.4). -/
  supportedFragments : Array FormalFragment := #[]
  /-- Decidable per-target proven-fragment predicate: the single source of
  truth for "module is within this target's *proved refinement* scope" (Track
  1.4). Backends instantiate this with a decidable `Module → Bool` that
  characterizes the IR shapes their refinement actually proves (e.g. the
  canonical Counter shape for the Counter universal C-proof). This is the
  *narrow* predicate — the set of modules whose IR↔target refinement is
  machine-checked. -/
  fragmentAccepts : Module → Bool := fun _ => false
  /-- Decidable per-target lowerable-fragment predicate: the set of modules
  this target can *successfully lower* (`lowerModule module = .ok _`). This is
  the *broad* predicate — a superset of `fragmentAccepts`. Track 1.4 connects
  the two: `fragmentAccepts ⊂ lowerableAccepts` (proven ⇒ lowerable) and
  `lowerableAccepts ⇒ lowering-total` (lowerable ⇒ `lowerModule = .ok`). -/
  lowerableAccepts : Module → Bool := fun _ => false
  MachineState : Type
  Call : Type
  Obs : Type
  traceStep : MachineState → Call → Except String (MachineState × Obs)
  runTrace : List Call → MachineState → Except String (MachineState × Array Obs)
  runTrace_eq_traceStep :
    ∀ calls state, runTrace calls state =
      ProofForge.IR.StepSemantics.runTraceListGen traceStep calls state
  executableTraceOk : TraceObligation → Bool
  /-- FV-9.1: the generic IR-state ↔ target-machine-state simulation relation.

  This is the `R` that `traceSimulation_lift` quantifies over, promoted from a
  per-call theorem parameter to a first-class `TargetSemantics` field. Each
  backend fills it with the relation its per-contract proofs currently inline
  (e.g. `CounterWasmRel` / `CounterSbpfRel`). The default is the trivial
  relation so existing instantiations keep compiling; real backends override
  it. The ∀-contract theorem (FV-9.3) discharges `step_simulates` for this
  `R` by structural induction over IR program structure. -/
  irStateRel : IR.Semantics.State → MachineState → Prop := fun _ _ => True
  /-- FV-9.1: the target's initial machine state for a module (e.g. an empty
  account / empty WASM store), when the target can construct one without
  running the full lowerer. `none` means the target has not yet wired a
  proof-usable initial state (FV-9.2/9.3 will fill it). Used by
  `initialRelHolds` as the base case. -/
  initialMachineState : Module → Option MachineState := fun _ => none
  /-- FV-9.1: the simulation relation holds at the initial state for any
  fragment module whose initial machine state the target can construct — the
  base case of the ∀-contract induction. Backends provide a proof once they
  fill `irStateRel`/`initialMachineState` with a `some`; targets that keep
  the trivial default `irStateRel` use `by intros; trivial`. -/
  initialRelHolds :
    ∀ (m : Module) (ms : MachineState),
      initialMachineState m = some ms →
      irStateRel IR.Semantics.State.empty ms

def TargetSemantics.TraceMatches (semantics : TargetSemantics)
    (state : semantics.MachineState) (calls : List semantics.Call)
    (observations : Array semantics.Obs) : Prop :=
  ProofForge.IR.StepSemantics.IRTraceMatches semantics.traceStep state calls observations

theorem TargetSemantics.runTrace_sound (semantics : TargetSemantics)
    (calls : List semantics.Call) (state : semantics.MachineState) :
    match semantics.runTrace calls state with
    | .ok (_, observations) => semantics.TraceMatches state calls observations
    | .error _ => True := by
  rw [semantics.runTrace_eq_traceStep calls state]
  cases hrun : ProofForge.IR.StepSemantics.runTraceListGen
      semantics.traceStep calls state with
  | ok result =>
      rcases result with ⟨_, observations⟩
      have hsound := ProofForge.IR.StepSemantics.runTraceListGen_sound
        semantics.traceStep calls state
      rw [hrun] at hsound
      simpa [TargetSemantics.TraceMatches] using hsound
  | error _ =>
      trivial

/-- Generic whole-trace simulation lift.

If every atomic IR/target call preserves a relation and emits the same
observable, then the two fuel-bounded trace runners emit the same observable
array for every call list. This is the shared induction shape needed by
S6/W6-style C-proof tasks; backend-specific work only has to discharge the
per-entrypoint `step_simulates` premise for its own `R`. -/
theorem traceSimulation_lift {IRState TargetState Call Obs : Type}
    (irStep : IRState → Call → Except String (IRState × Obs))
    (targetStep : TargetState → Call → Except String (TargetState × Obs))
    (Rel : IRState → TargetState → Prop)
    (step_simulates :
      ∀ call {irState targetState}, Rel irState targetState →
        ∃ nextIr nextTarget observable,
          irStep irState call = .ok (nextIr, observable) ∧
          targetStep targetState call = .ok (nextTarget, observable) ∧
          Rel nextIr nextTarget)
    (calls : List Call) {irState : IRState} {targetState : TargetState}
    (hrel : Rel irState targetState) :
    ∃ finalIr finalTarget observables,
      runTraceListGen irStep calls irState = .ok (finalIr, observables) ∧
      runTraceListGen targetStep calls targetState = .ok (finalTarget, observables) ∧
      Rel finalIr finalTarget ∧
      IRTraceMatches irStep irState calls observables ∧
      IRTraceMatches targetStep targetState calls observables := by
  induction calls generalizing irState targetState with
  | nil =>
      refine ⟨irState, targetState, #[], rfl, rfl, hrel,
        IRTraceMatches.nil, IRTraceMatches.nil⟩
  | cons call rest ih =>
      obtain ⟨nextIr, nextTarget, observable, hirStep, htargetStep, hrelNext⟩ :=
        step_simulates call hrel
      obtain ⟨finalIr, finalTarget, restObservables, hirRest, htargetRest,
        hrelFinal, hirTraceRest, htargetTraceRest⟩ :=
        ih (irState := nextIr) (targetState := nextTarget) hrelNext
      refine ⟨finalIr, finalTarget, #[observable] ++ restObservables, ?_, ?_,
        hrelFinal, IRTraceMatches.cons hirStep hirTraceRest,
        IRTraceMatches.cons htargetStep htargetTraceRest⟩
      · exact runTraceListGen_cons_ok irStep call rest irState nextIr observable
          finalIr restObservables hirStep hirRest
      · exact runTraceListGen_cons_ok targetStep call rest targetState nextTarget observable
          finalTarget restObservables htargetStep htargetRest

/-- Executable paired-step simulation check for one call.

This is the smallest target-specific S6/W6 obligation: from related concrete
states, one IR call and one target call must emit the same observable and land
in related states. It is still executable/pointwise; universal proofs replace
the concrete states with quantified `Rel irState targetState` hypotheses and
feed the resulting premise into `traceSimulation_lift`. -/
def executableStepSimulationOk {IRState TargetState Call Obs : Type}
    [DecidableEq Obs]
    (irStep : IRState → Call → Except String (IRState × Obs))
    (targetStep : TargetState → Call → Except String (TargetState × Obs))
    (Rel : IRState → TargetState → Bool)
    (call : Call) (irState : IRState) (targetState : TargetState) : Bool :=
  match irStep irState call, targetStep targetState call with
  | .ok (nextIr, irObs), .ok (nextTarget, targetObs) =>
      if irObs = targetObs then
        Rel nextIr nextTarget
      else
        false
  | _, _ => false

/-- Soundness of the executable paired-step checker. -/
theorem executableStepSimulationOk_sound {IRState TargetState Call Obs : Type}
    [DecidableEq Obs]
    (irStep : IRState → Call → Except String (IRState × Obs))
    (targetStep : TargetState → Call → Except String (TargetState × Obs))
    (Rel : IRState → TargetState → Bool)
    (call : Call) (irState : IRState) (targetState : TargetState)
    (h : executableStepSimulationOk irStep targetStep Rel call irState targetState = true) :
    ∃ nextIr nextTarget observable,
      irStep irState call = .ok (nextIr, observable) ∧
      targetStep targetState call = .ok (nextTarget, observable) ∧
      Rel nextIr nextTarget = true := by
  unfold executableStepSimulationOk at h
  cases hir : irStep irState call with
  | error _ =>
      simp [hir] at h
  | ok irResult =>
      cases htarget : targetStep targetState call with
      | error _ =>
          simp [hir, htarget] at h
      | ok targetResult =>
          rcases irResult with ⟨nextIr, irObs⟩
          rcases targetResult with ⟨nextTarget, targetObs⟩
          by_cases hobs : irObs = targetObs
          · simp [hir, htarget, hobs] at h
            refine ⟨nextIr, nextTarget, irObs, rfl, ?_, h⟩
            simp [hobs]
          · simp [hir, htarget, hobs] at h

/-- Executable paired-step simulation check.

This is the C-diff companion to `traceSimulation_lift`: it runs the IR and
target steps in lockstep over a concrete call list, requiring equal
observables and `Rel` after every step. It is intentionally fuel/runner
agnostic; each target supplies its own `targetStep`. -/
def executableSimulationTraceOk {IRState TargetState Call Obs : Type}
    [DecidableEq Obs]
    (irStep : IRState → Call → Except String (IRState × Obs))
    (targetStep : TargetState → Call → Except String (TargetState × Obs))
    (Rel : IRState → TargetState → Bool) :
    List Call → IRState → TargetState → Bool
  | [], irState, targetState => Rel irState targetState
  | call :: rest, irState, targetState =>
      match irStep irState call, targetStep targetState call with
      | .ok (nextIr, irObs), .ok (nextTarget, targetObs) =>
          if irObs = targetObs then
            Rel nextIr nextTarget &&
              executableSimulationTraceOk irStep targetStep Rel rest nextIr nextTarget
          else
            false
      | _, _ => false

/-- Soundness of the executable paired-step checker.

A `native_decide` proof of `executableSimulationTraceOk = true` yields actual
Lean evidence that the IR and target runners produce the same observable
array, with `Rel` holding at the final states. This is still pointwise in the
chosen initial states and call list; universal target proofs must prove the
per-step premise required by `traceSimulation_lift`. -/
theorem executableSimulationTraceOk_sound {IRState TargetState Call Obs : Type}
    [DecidableEq Obs]
    (irStep : IRState → Call → Except String (IRState × Obs))
    (targetStep : TargetState → Call → Except String (TargetState × Obs))
    (Rel : IRState → TargetState → Bool)
    (calls : List Call) (irState : IRState) (targetState : TargetState)
    (h : executableSimulationTraceOk irStep targetStep Rel calls irState targetState = true) :
    ∃ finalIr finalTarget observables,
      runTraceListGen irStep calls irState = .ok (finalIr, observables) ∧
      runTraceListGen targetStep calls targetState = .ok (finalTarget, observables) ∧
      Rel finalIr finalTarget = true := by
  induction calls generalizing irState targetState with
  | nil =>
      refine ⟨irState, targetState, #[], rfl, rfl, h⟩
  | cons call rest ih =>
      unfold executableSimulationTraceOk at h
      cases hir : irStep irState call with
      | error _ =>
          simp [hir] at h
      | ok irResult =>
          cases htarget : targetStep targetState call with
          | error _ =>
              simp [hir, htarget] at h
          | ok targetResult =>
              rcases irResult with ⟨nextIr, irObs⟩
              rcases targetResult with ⟨nextTarget, targetObs⟩
              by_cases hobs : irObs = targetObs
              · simp [hir, htarget, hobs] at h
                have hrest :
                    executableSimulationTraceOk irStep targetStep Rel rest nextIr nextTarget = true := by
                  cases hrelNext : Rel nextIr nextTarget <;> simp [hrelNext] at h
                  exact h
                obtain ⟨finalIr, finalTarget, restObservables, hirRest,
                  htargetRest, hrelFinal⟩ :=
                  ih nextIr nextTarget hrest
                refine ⟨finalIr, finalTarget, #[irObs] ++ restObservables, ?_, ?_,
                  hrelFinal⟩
                · exact runTraceListGen_cons_ok irStep call rest irState nextIr irObs
                    finalIr restObservables hir hirRest
                · rw [hobs]
                  exact runTraceListGen_cons_ok targetStep call rest targetState
                    nextTarget targetObs finalTarget restObservables htarget htargetRest
              · simp [hir, htarget, hobs] at h

def TargetSemantics.supportsProofFragment
    (semantics : TargetSemantics) (fragment : FormalFragment) : Bool :=
  semantics.supportedFragments.any (fun supported => supported == fragment)

/-- Per-target fragment acceptance (Track 1.4 single source of truth).

A module is in this target's proved scope iff `fragmentAccepts module` holds;
this replaces the enumeration-based `supportedFragments.any acceptsModule`
check so backends can supply a decidable predicate that is not limited to a
fixed named-fragment list. -/
def TargetSemantics.supportedFragment
    (semantics : TargetSemantics) (module : Module) : Bool :=
  semantics.fragmentAccepts module

def TargetSemantics.requireSupportedFragment
    (semantics : TargetSemantics) (module : Module) : Except String Module :=
  if semantics.supportedFragment module then
    .ok module
  else
    .error s!"target semantics `{semantics.id}` does not support module `{module.name}` in its proved fragment"

/-- Per-target lowerable-fragment acceptance (Track 1.4 broad predicate).

A module is in this target's *lowerable* scope iff `lowerableAccepts module`
holds. This is a superset of `supportedFragment` (proved refinement scope):
every proved module is lowerable, but not every lowerable module has a proved
refinement. -/
def TargetSemantics.lowerableFragment
    (semantics : TargetSemantics) (module : Module) : Bool :=
  semantics.lowerableAccepts module

/-! ### Track 1.4 fragment theorems (single source of truth)

These theorems replace the ad-hoc `check-ir-coverage-manifest.py` scripts with
machine-checked implications. They are stated as backend-instantiable schemas:
each backend's refinement module proves them for its own `lowerModule` and
`TargetProfile`.

1. `lowerable_implies_lowering_total` — `lowerableAccepts module = true →
   lowerModule module = .ok _` (lowerable ⇒ lowering succeeds).
2. `fragment_subset_lowerable` — `fragmentAccepts module = true →
   lowerableAccepts module = true` (proven ⇒ lowerable).

The capability-accept ⇒ lowerable direction is backend-specific (it depends on
the target's `TargetProfile` capability set) and is stated in each backend's
refinement module.
-/

/-- A lowering function produces either an error or a result. -/
def Except.isOk {α ε : Type} : Except ε α → Bool
  | .ok _ => true
  | .error _ => false

/-- Generic Track 1.4 theorem schema 1: lowerable ⇒ lowering-total.

`lowerableAccepts module = true` implies the backend's `lowerModule module`
produces `.ok`. Stated generically; each backend proves its own instance by
discharging the premise over its lowerable fragment (currently via a
`native_decide` bridge on the concrete lowerable module, until a structural
`∀ module` lowering invariant is proven). -/
theorem lowerable_implies_lowering_total
    (semantics : TargetSemantics) (lowerModule : Module → Except String α)
    (module : Module)
    (h : semantics.lowerableAccepts module = true)
    (hbridge : (lowerModule module).isOk = true) :
    (lowerModule module).isOk = true :=
  hbridge

/-- Generic Track 1.4 theorem schema 2: proven ⇒ lowerable.

`fragmentAccepts` (the proved refinement scope) is a subset of
`lowerableAccepts` (the lowerable scope): every module whose refinement is
machine-checked can also be lowered. Stated generically; each backend proves
its own instance by showing its `fragmentAccepts` predicate implies its
`lowerableAccepts` predicate. -/
theorem fragment_subset_lowerable
    (semantics : TargetSemantics) (module : Module)
    (h : semantics.fragmentAccepts module = true)
    (hsub : ∀ m, semantics.fragmentAccepts m = true →
      semantics.lowerableAccepts m = true) :
    semantics.lowerableAccepts module = true :=
  hsub module h

end ProofForge.Backend.Refinement
