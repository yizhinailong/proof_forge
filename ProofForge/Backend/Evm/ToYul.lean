import ProofForge.Backend.Evm.Plan
import ProofForge.Compiler.Yul.AST

namespace ProofForge.Backend.Evm.ToYul

open ProofForge.IR
open ProofForge.Backend.Evm.Plan

def slotExpr (slot : Nat) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.Expr.num slot

def helperCall (helper : Helper) (args : Array Lean.Compiler.Yul.Expr) : Lean.Compiler.Yul.Expr :=
  Lean.Compiler.Yul.call helper.name args

def lowerValuePlan
    {ε : Type}
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr) :
    ValuePlan → Except ε Lean.Compiler.Yul.Expr
  | .irExpr expr => lowerExpr expr

def lowerMapValueSlotExpr
    {ε : Type}
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (rootSlot : Nat)
    (keys : Array ValuePlan) : Except ε Lean.Compiler.Yul.Expr := do
  let mut current := slotExpr rootSlot
  for key in keys do
    current := helperCall Helper.mapSlot #[current, ← lowerValuePlan lowerExpr key]
  .ok current

def lowerMapPresenceSlotExpr
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr)
    (rootSlot : Nat)
    (keys : Array ValuePlan) : Except ε Lean.Compiler.Yul.Expr := do
  match keys.toList.reverse with
  | [] => .error (mkError "EVM map presence slot plan requires at least one key")
  | last :: parentKeysReversed =>
      let mut parent := slotExpr rootSlot
      for key in parentKeysReversed.reverse do
        parent := helperCall Helper.mapSlot #[parent, ← lowerValuePlan lowerExpr key]
      .ok (helperCall Helper.mapPresenceSlot #[parent, ← lowerValuePlan lowerExpr last])

def storageSlotExpr
    {ε : Type}
    (mkError : String → ε)
    (lowerExpr : Expr → Except ε Lean.Compiler.Yul.Expr) :
    StorageSlotPlan → Except ε Lean.Compiler.Yul.Expr
  | .scalarSlot slot => .ok (slotExpr slot)
  | .mapValueSlot rootSlot keys =>
      if keys.isEmpty then
        .error (mkError "EVM map value slot plan requires at least one key")
      else
        lowerMapValueSlotExpr lowerExpr rootSlot keys
  | .mapPresenceSlot rootSlot keys =>
      lowerMapPresenceSlotExpr mkError lowerExpr rootSlot keys
  | .arraySlot rootSlot length index => do
      .ok (helperCall Helper.arraySlot #[
        slotExpr rootSlot,
        Lean.Compiler.Yul.Expr.num length,
        ← lowerValuePlan lowerExpr index
      ])
  | .structArrayFieldSlot rootSlot length fieldCount fieldOffset index => do
      .ok (helperCall Helper.structArraySlot #[
        slotExpr rootSlot,
        Lean.Compiler.Yul.Expr.num length,
        Lean.Compiler.Yul.Expr.num fieldCount,
        Lean.Compiler.Yul.Expr.num fieldOffset,
        ← lowerValuePlan lowerExpr index
      ])

/-! ## Plan-driven helper requirements

`StorageSlotPlan.requiredHelpers` lets the plan declare which EVM helper functions
a given slot plan needs, without `ToYul` re-discovering them from Yul text. -/

def slotHelperRequirements (slot : StorageSlotPlan) : HelperSet :=
  slot.requiredHelpers

def storageLayoutHelpers (layout : StorageLayout) : HelperSet :=
  layout.states.foldl (init := #[]) fun acc state =>
    match state.kind with
    | .map _ _ => HelperSet.insert (HelperSet.insert acc Helper.mapSlot) Helper.mapPresenceSlot
    | _ => acc

end ProofForge.Backend.Evm.ToYul
