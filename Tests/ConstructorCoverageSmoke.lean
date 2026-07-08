import ProofForge.Backend.Refinement.ConstructorCoverage
import ProofForge.Backend.Refinement.CounterUniversal

/-! ## FV-9.2: constructor coverage table + IR-side preservation smoke gate

Exercises the FV-9.2 deliverable: the constructor coverage predicates, the
status table, the IR-side fueled-eval preservation lemmas (arithmetic core),
and the counter-model per-entrypoint preservation restated through
`TargetSemantics.irStateRel` (FV-9.1 field). This gate is the FV-9.2 deliverable
and lives in `just check`.
-/

open ProofForge.IR
open ProofForge.IR.Semantics
open ProofForge.IR.SemanticsFuel
open ProofForge.Backend.Refinement
open ProofForge.Backend.Refinement.ConstructorCoverage
open ProofForge.Backend.Refinement.CounterUniversal

-- 1. Coverage predicates exist and are decidable.
#check (fuelCoveredExpr : Expr → Bool)
#check (fuelCoveredEffect : Effect → Bool)
#check (fuelCoveredStatement : Statement → Bool)

-- 2. Status table maps covered constructors to `.covered`.
#check (exprStatus : Expr → ConstructorStatus)
#check (effectStatus : Effect → ConstructorStatus)
#check (statementStatus : Statement → ConstructorStatus)

-- 3. IR-side preservation lemmas (arithmetic core) exist.
#check evalExprFuel_add_eq
#check evalExprFuel_sub_eq
#check evalExprFuel_mul_eq

-- 4. Counter-model per-entrypoint preservation consumes irStateRel (FV-9.2c).
#check counter_step_simulates_via_irStateRel

-- 5. Concrete coverage witnesses: the Counter `increment` body's
-- arithmetic + storage constructors are all `covered` (decidable check).
theorem counter_increment_add_covered :
    fuelCoveredExpr (.add (.local "current") (.local "amount") true) = true := by
  decide

theorem counter_increment_storageScalarRead_covered :
    fuelCoveredEffect (.storageScalarRead "balance") = true := by
  decide

theorem counter_increment_letBind_covered :
    fuelCoveredStatement
      (.letBind "next" .u64 (.add (.local "current") (.local "amount"))) = true := by
  decide

-- 6. The `add` preservation lemma fires on a concrete operand pair.
theorem counter_increment_add_preservation_witness
    (fuel : Nat) (state : Semantics.State) (frame : Semantics.Frame)
    (hLhs : evalExprFuel fuel state frame (.local "current") = .ok (state, .u64 5))
    (hRhs : evalExprFuel fuel state frame (.local "amount") = .ok (state, .u64 3)) :
    evalExprFuel (fuel + 1) state frame (.add (.local "current") (.local "amount") true) =
      .ok (state, .u64 8) := by
  exact evalExprFuel_add_eq fuel state frame _ _ true hLhs hRhs

-- 7. A gap constructor is correctly marked `gap`.
theorem crosscallInvoke_is_gap :
    exprStatus (.crosscallInvoke (.local "t") (.local "m") #[]) = .gap := by
  decide

-- 8. FV-9.4 module-level fragment scoping: the module coverage predicate and
-- the honesty bridge exist.
#check (moduleInCoveredFragment : Module → Bool)
#check (exprFullyCovered : Expr → Bool)
#check (effectFullyCovered : Effect → Bool)
#check (statementFullyCovered : Statement → Bool)

-- 9. The counter-model's fragment is covered: the canonical Counter module
-- passes the depth-fueled full-coverage walk, so every constructor it uses is
-- within FV-9.2's covered set. This is the honesty bridge witness — the module
-- the counter-model claims to prove only uses covered constructors.
#check counterModel_fragmentAccepts_implies_covered

-- 10. A module containing a gap constructor is rejected by the coverage walk
-- (honesty: the fragment predicate excludes modules it cannot prove).
theorem gap_module_not_covered :
    moduleInCoveredFragment
      ({ name := "GapMod", structs := #[], state := #[],
         entrypoints := #[{ name := "bad", body := #[.effect (.storageArrayRead "a" (.literal (.u64 0)))] }] }
        : Module) = false := by
  native_decide

def main : IO UInt32 := do
  IO.println "constructor-coverage-smoke: FV-9.2 coverage table + IR-side preservation lemmas + counter-model irStateRel preservation + FV-9.4 module-level fragment scoping + honesty bridge checked"
  return 0