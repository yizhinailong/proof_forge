import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.IR.Contract

namespace ProofForge.Backend.Evm.Plan

open ProofForge.IR

structure PlanError where
  message : String
  deriving Repr, Inhabited

def PlanError.render (err : PlanError) : String :=
  err.message

def stateSlotSpan (module : Module) (state : StateDecl) : Nat :=
  match state.kind, state.type with
  | .scalar, .structType typeName =>
      match module.structs.find? (fun decl => decl.name == typeName) with
      | some decl => decl.fields.size
      | none => 1
  | .array length, .structType typeName =>
      match module.structs.find? (fun decl => decl.name == typeName) with
      | some decl => length * decl.fields.size
      | none => length
  | .array length, _ => length
  | .scalar, _ | .map _ _, _ => 1

structure StorageStatePlan where
  id : String
  slot : Nat
  span : Nat
  kind : StateKind
  type : ValueType
  deriving Repr

structure StorageLayout where
  states : Array StorageStatePlan
  deriving Repr

def storageLayout (module : Module) : StorageLayout := {
  states := go 0 0 module.state #[]
}
where
  go (idx slot : Nat) (states : Array StateDecl) (acc : Array StorageStatePlan) : Array StorageStatePlan :=
    if h : idx < states.size then
      let state := states[idx]
      let span := stateSlotSpan module state
      go (idx + 1) (slot + span) states (acc.push {
        id := state.id
        slot
        span
        kind := state.kind
        type := state.type
      })
    else
      acc

def StorageLayout.find? (layout : StorageLayout) (stateId : String) : Option StorageStatePlan :=
  layout.states.find? (fun state => state.id == stateId)

def stateInfo? (module : Module) (stateId : String) : Option (Nat × StateDecl) :=
  go 0 0 module.state
where
  go (idx slot : Nat) (states : Array StateDecl) : Option (Nat × StateDecl) :=
    if h : idx < states.size then
      let state := states[idx]
      if state.id == stateId then
        some (slot, state)
      else
        go (idx + 1) (slot + stateSlotSpan module state) states
    else
      none

def stateSlot? (module : Module) (stateId : String) : Option Nat :=
  match stateInfo? module stateId with
  | some (slot, _) => some slot
  | none => none

inductive Helper where
  | mapSlot
  | mapPresenceSlot
  | mapWrite
  | mapSetReturn
  deriving BEq, DecidableEq, Repr

def Helper.name : Helper → String
  | .mapSlot => "__proof_forge_map_slot"
  | .mapPresenceSlot => "__proof_forge_map_presence_slot"
  | .mapWrite => "__proof_forge_map_write"
  | .mapSetReturn => "__proof_forge_map_set_return"

abbrev HelperSet := Array Helper

namespace HelperSet

def contains (helpers : HelperSet) (helper : Helper) : Bool :=
  helpers.any (fun existing => existing == helper)

def insert (helpers : HelperSet) (helper : Helper) : HelperSet :=
  if contains helpers helper then
    helpers
  else
    helpers.push helper

end HelperSet

inductive ValuePlan where
  | irExpr (expr : Expr)
  deriving Repr

def ValuePlan.fromExpr (expr : Expr) : ValuePlan :=
  .irExpr expr

inductive StorageSlotPlan where
  | scalarSlot (slot : Nat)
  | mapValueSlot (rootSlot : Nat) (keys : Array ValuePlan)
  | mapPresenceSlot (rootSlot : Nat) (keys : Array ValuePlan)
  deriving Repr

def StorageSlotPlan.keyCount : StorageSlotPlan → Nat
  | .scalarSlot _ => 0
  | .mapValueSlot _ keys => keys.size
  | .mapPresenceSlot _ keys => keys.size

def StorageSlotPlan.requiredHelpers : StorageSlotPlan → HelperSet
  | .scalarSlot _ => #[]
  | .mapValueSlot _ _ => #[Helper.mapSlot]
  | .mapPresenceSlot _ keys =>
      let helpers : HelperSet := #[Helper.mapPresenceSlot]
      if keys.size > 1 then
        HelperSet.insert helpers Helper.mapSlot
      else
        helpers

structure MapStatePlan where
  stateId : String
  rootSlot : Nat
  keyType : ValueType
  valueType : ValueType
  capacity : Nat
  deriving Repr

def requireState (module : Module) (stateId : String) : Except PlanError (Nat × StateDecl) :=
  match stateInfo? module stateId with
  | some info => .ok info
  | none => .error { message := s!"unknown EVM state '{stateId}'" }

def requireMapState (module : Module) (stateId : String) : Except PlanError MapStatePlan := do
  let (slot, state) ← requireState module stateId
  match state.kind with
  | .map keyType capacity => .ok {
      stateId
      rootSlot := slot
      keyType
      valueType := state.type
      capacity
    }
  | .scalar | .array _ =>
      .error { message := s!"EVM storage state '{stateId}' is not a map" }

def scalarSlotPlan (module : Module) (stateId : String) : Except PlanError StorageSlotPlan := do
  let (slot, state) ← requireState module stateId
  match state.kind with
  | .scalar => .ok (.scalarSlot slot)
  | .map _ _ | .array _ =>
      .error { message := s!"EVM storage state '{stateId}' is not a scalar slot" }

def mapValueSlotPlan (module : Module) (stateId : String) (keys : Array Expr) : Except PlanError StorageSlotPlan := do
  let mapState ← requireMapState module stateId
  if keys.isEmpty then
    .error { message := s!"EVM map storage path for '{stateId}' must contain at least one mapKey segment" }
  else
    .ok (.mapValueSlot mapState.rootSlot (keys.map ValuePlan.fromExpr))

def mapPresenceSlotPlan (module : Module) (stateId : String) (keys : Array Expr) : Except PlanError StorageSlotPlan := do
  let mapState ← requireMapState module stateId
  if keys.isEmpty then
    .error { message := s!"EVM map storage path for '{stateId}' must contain at least one mapKey segment" }
  else
    .ok (.mapPresenceSlot mapState.rootSlot (keys.map ValuePlan.fromExpr))

def storagePathMapKeys? (path : Array StoragePathSegment) : Option (Array Expr) :=
  go 0 #[]
where
  go (idx : Nat) (acc : Array Expr) : Option (Array Expr) :=
    if h : idx < path.size then
      match path[idx] with
      | .mapKey key => go (idx + 1) (acc.push key)
      | .field _ | .index _ => none
    else if acc.isEmpty then
      none
    else
      some acc

def storagePathMapValueSlotPlan
    (module : Module)
    (stateId : String)
    (path : Array StoragePathSegment) : Except PlanError StorageSlotPlan :=
  match storagePathMapKeys? path with
  | some keys => mapValueSlotPlan module stateId keys
  | none =>
      .error { message := "EVM plan supports map storage paths only as one or more mapKey segments" }

def storagePathMapPresenceSlotPlan
    (module : Module)
    (stateId : String)
    (path : Array StoragePathSegment) : Except PlanError StorageSlotPlan :=
  match storagePathMapKeys? path with
  | some keys => mapPresenceSlotPlan module stateId keys
  | none =>
      .error { message := "EVM plan supports map storage paths only as one or more mapKey segments" }

end ProofForge.Backend.Evm.Plan
