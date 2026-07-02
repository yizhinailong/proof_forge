import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.IR.Contract
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Backend.Evm.Plan

open ProofForge.IR
open ProofForge.Target

structure PlanError where
  message : String
  deriving Repr, Inhabited

def PlanError.render (err : PlanError) : String :=
  err.message

def PlanError.fromDiagnostic (err : Diagnostic) : PlanError := {
  message := err.render
}

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
  | mapAssign (op : AssignOp)
  | arraySlot
  | structArraySlot
  | hashWord
  | hashPair
  deriving BEq, DecidableEq, Repr

def assignOpHelperSuffix : AssignOp → String
  | .add => "add"
  | .sub => "sub"
  | .mul => "mul"
  | .div => "div"
  | .mod => "mod"
  | .bitAnd => "and"
  | .bitOr => "or"
  | .bitXor => "xor"
  | .shiftLeft => "shl"
  | .shiftRight => "shr"

def Helper.name : Helper → String
  | .mapSlot => "__proof_forge_map_slot"
  | .mapPresenceSlot => "__proof_forge_map_presence_slot"
  | .mapWrite => "__proof_forge_map_write"
  | .mapSetReturn => "__proof_forge_map_set_return"
  | .mapAssign op => s!"__proof_forge_map_assign_{assignOpHelperSuffix op}"
  | .arraySlot => "__proof_forge_array_slot"
  | .structArraySlot => "__proof_forge_struct_array_slot"
  | .hashWord => "__proof_forge_hash_word"
  | .hashPair => "__proof_forge_hash_pair"

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

def isStorageWordType : ValueType → Bool
  | .u32 | .u64 | .bool | .hash => true
  | .unit | .fixedArray _ _ | .structType _ => false

def findStruct? (module : Module) (name : String) : Option StructDecl :=
  module.structs.find? (fun decl => decl.name == name)

def isSupportedMapState (state : StateDecl) : Bool :=
  match state.kind, state.type with
  | .map keyType _, valueType => isStorageWordType keyType && isStorageWordType valueType
  | _, _ => false

def moduleUsesSupportedMap (module : Module) : Bool :=
  module.state.any isSupportedMapState

def isSupportedArrayState (state : StateDecl) : Bool :=
  match state.kind, state.type with
  | .array length, elementType => length > 0 && isStorageWordType elementType
  | _, _ => false

def moduleUsesSupportedArray (module : Module) : Bool :=
  module.state.any isSupportedArrayState

def moduleUsesSupportedStructArray (module : Module) : Bool :=
  module.state.any fun state =>
    match state.kind, state.type with
    | .array length, .structType typeName =>
        length > 0 && (findStruct? module typeName).isSome
    | _, _ => false

def moduleUsesHash (module : Module) : Bool :=
  module.capabilities.contains .cryptoHash

def pushAssignOpIfMissing (acc : Array AssignOp) (value : AssignOp) : Array AssignOp :=
  if acc.any (fun existing => existing == value) then acc else acc.push value

def mergeAssignOpSets (lhs rhs : Array AssignOp) : Array AssignOp :=
  rhs.foldl pushAssignOpIfMissing lhs

mutual
  partial def storagePathAssignOpsStatement : Statement → Array AssignOp
    | .effect (.storagePathAssignOp _ _ op _) =>
        #[op]
    | .ifElse _ thenBody elseBody =>
        mergeAssignOpSets (storagePathAssignOpsStatements thenBody) (storagePathAssignOpsStatements elseBody)
    | .boundedFor _ _ _ body =>
        storagePathAssignOpsStatements body
    | _ =>
        #[]

  partial def storagePathAssignOpsStatements (statements : Array Statement) : Array AssignOp :=
    statements.foldl (init := #[]) fun acc stmt =>
      mergeAssignOpSets acc (storagePathAssignOpsStatement stmt)
end

def moduleStoragePathAssignOps (module : Module) : Array AssignOp :=
  module.entrypoints.foldl (init := #[]) fun acc entrypoint =>
    mergeAssignOpSets acc (storagePathAssignOpsStatements entrypoint.body)

def baseMapHelpers : HelperSet := #[
  .mapSlot,
  .mapPresenceSlot,
  .mapWrite,
  .mapSetReturn
]

def moduleHelpers (module : Module) : HelperSet :=
  let helpers : HelperSet :=
    if moduleUsesSupportedMap module then baseMapHelpers else #[]
  let helpers :=
    if moduleUsesSupportedMap module then
      moduleStoragePathAssignOps module |>.foldl
        (fun acc op => HelperSet.insert acc (.mapAssign op))
        helpers
    else
      helpers
  let helpers :=
    if moduleUsesSupportedArray module then
      HelperSet.insert helpers .arraySlot
    else
      helpers
  let helpers :=
    if moduleUsesSupportedStructArray module then
      HelperSet.insert helpers .structArraySlot
    else
      helpers
  if moduleUsesHash module then
    HelperSet.insert (HelperSet.insert helpers .hashWord) .hashPair
  else
    helpers

def helperMapAssignOps (helpers : HelperSet) : Array AssignOp :=
  helpers.foldl
    (fun acc helper =>
      match helper with
      | .mapAssign op => pushAssignOpIfMissing acc op
      | _ => acc)
    #[]

structure ModulePlan where
  name : String
  targetPlan : CapabilityPlan
  storage : StorageLayout
  helpers : HelperSet
  mapAssignOps : Array AssignOp
  deriving Repr

def ModulePlan.capabilities (plan : ModulePlan) : Array Capability :=
  plan.targetPlan.capabilities

def ModulePlan.hasHelper (plan : ModulePlan) (helper : Helper) : Bool :=
  HelperSet.contains plan.helpers helper

def buildModulePlanWithTargetPlan (module : Module) (targetPlan : CapabilityPlan) :
    Except PlanError ModulePlan := do
  if targetPlan.targetId != Target.evm.id then
    .error {
      message := s!"EVM module plan requires target `{Target.evm.id}`, got `{targetPlan.targetId}`"
    }
  else
    let helpers := moduleHelpers module
    .ok {
      name := module.name
      targetPlan
      storage := storageLayout module
      helpers
      mapAssignOps := helperMapAssignOps helpers
    }

def buildModulePlan (module : Module) : Except PlanError ModulePlan := do
  let targetPlan ←
    match resolveModule Target.evm module with
    | .ok plan => .ok plan
    | .error err => .error (PlanError.fromDiagnostic err)
  buildModulePlanWithTargetPlan module targetPlan

def buildSpecPlan (spec : ProofForge.Contract.ContractSpec) : Except PlanError ModulePlan := do
  let targetPlan ←
    match resolveSpec Target.evm spec with
    | .ok plan => .ok plan
    | .error err => .error (PlanError.fromDiagnostic err)
  buildModulePlanWithTargetPlan spec.module targetPlan

end ProofForge.Backend.Evm.Plan
