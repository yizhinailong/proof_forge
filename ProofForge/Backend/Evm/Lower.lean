import ProofForge.Backend.Evm.Plan
import ProofForge.Backend.Evm.Validate
import ProofForge.IR.Contract
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

/-! # EVM semantic plan lowering (IR -> ModulePlan)

This module is the `Lower` pass from RFC 0004. It consumes a portable IR
`Module` together with the pure validation/type-inference from `Validate.lean`
and produces a fully populated `Plan.ModulePlan` with:

- `EntrypointPlan` nodes (selector, ABI params, return plan, body)
- `EventPlan` nodes (signature, indexed/data field layout)
- `CrosscallHelperSpec` and `CreateHelperSpec` discovered from the IR
- Local-array-get and nested-local-array-get helper requirements
- The checked-arithmetic flag
- A `MetadataPlan` summarizing the module for artifact/deploy metadata

The plan is then consumed by `ToYul.lean` (helper emission) and `IR.lean`
(Yul AST construction). Keeping plan construction separate from Yul AST
construction is the core architectural goal of RFC 0004. -/

namespace ProofForge.Backend.Evm.Lower

open ProofForge.IR
open ProofForge.Target
open ProofForge.Backend.Evm.Plan
open ProofForge.Backend.Evm.Validate

/-! ## Entrypoint plan construction -/

def abiParamPlan
    (module : Module)
    (context : String)
    (name : String)
    (type : ValueType) : Except LowerError AbiParamPlan := do
  let wordTypes ← abiValueWordTypes module s!"{context} parameter `{name}`" type
  .ok { name, type, wordTypes }

def entrypointParamPlans (module : Module) (entrypoint : Entrypoint) :
    Except LowerError (Array AbiParamPlan) :=
  entrypoint.params.foldlM (init := #[]) fun acc param => do
    .ok (acc.push (← abiParamPlan module s!"entrypoint `{entrypoint.name}`" param.fst param.snd))

def returnPlan (module : Module) (context : String) (returnType : ValueType) :
    Except LowerError ReturnPlan := do
  let wordTypes ←
    match returnType with
    | .unit => .ok #[]
    | _ => abiValueWordTypes module s!"{context} return value" returnType
  .ok { returnType, wordTypes }

def entrypointSelector (entrypoint : Entrypoint) : Except LowerError String :=
  match entrypoint.selector? with
  | some selector => .ok selector
  | none => .error { message := s!"entrypoint `{entrypoint.name}` has no EVM selector metadata" }

/-! Entrypoint body plans carry the IR statements as opaque `StmtPlan` markers.

The full `StmtPlan`/`ExprPlan` lowering (RFC 0004 Stage 3-5) replaces the direct
Yul construction inside `IR.lean` over time. During the staged migration the
body is carried as an empty array while the Yul pass in `IR.lean` remains the
authoritative lowering; the plan records the ABI surface, selector, and return
shape so metadata and dispatch planning can consume it without re-discovering
facts from rendered Yul. -/

def buildEntrypointPlan (module : Module) (entrypoint : Entrypoint) :
    Except LowerError EntrypointPlan := do
  let selector ← entrypointSelector entrypoint
  let params ← entrypointParamPlans module entrypoint
  let returns ← returnPlan module s!"entrypoint `{entrypoint.name}`" entrypoint.returns
  .ok { name := entrypoint.name, selector, params, returns, body := #[] }

def buildEntrypointPlans (module : Module) : Except LowerError (Array EntrypointPlan) :=
  module.entrypoints.foldlM (init := #[]) fun acc entrypoint => do
    .ok (acc.push (← buildEntrypointPlan module entrypoint))

/-! ## Event plan construction

Event plans are built by walking each entrypoint's body with a growing type
environment (params + let-bound locals), matching the same pattern used by
`Cli.lean` for event ABI extraction. This ensures event field expressions can
reference locals bound earlier in the same entrypoint. -/

structure EventCollector where
  plans : Array EventPlan := #[]
  deriving Repr

def EventCollector.find (collector : EventCollector) (name : String) : Option EventPlan :=
  collector.plans.find? (fun plan => plan.name == name)

def EventCollector.add (collector : EventCollector) (plan : EventPlan) : EventCollector :=
  match collector.find plan.name with
  | some _ => collector
  | none => { plans := collector.plans.push plan }

mutual
  partial def collectEventPlansFromExpr
      (module : Module)
      (env : TypeEnv)
      (collector : EventCollector) :
      Expr → Except LowerError EventCollector
    | .literal _ | .local _ | .nativeValue => pure collector
    | .arrayLit _ values =>
        values.foldlM (init := collector) (collectEventPlansFromExpr module env)
    | .arrayGet array index => do
        let collector ← collectEventPlansFromExpr module env collector array
        collectEventPlansFromExpr module env collector index
    | .structLit _ fields =>
        fields.foldlM (init := collector) fun acc field =>
          collectEventPlansFromExpr module env acc field.snd
    | .field base _ => collectEventPlansFromExpr module env collector base
    | .add lhs rhs | .sub lhs rhs | .mul lhs rhs | .div lhs rhs | .mod lhs rhs
    | .pow lhs rhs | .bitAnd lhs rhs | .bitOr lhs rhs | .bitXor lhs rhs
    | .shiftLeft lhs rhs | .shiftRight lhs rhs | .eq lhs rhs | .ne lhs rhs
    | .lt lhs rhs | .le lhs rhs | .gt lhs rhs | .ge lhs rhs
    | .boolAnd lhs rhs | .boolOr lhs rhs | .hashTwoToOne lhs rhs => do
        let collector ← collectEventPlansFromExpr module env collector lhs
        collectEventPlansFromExpr module env collector rhs
    | .cast value _ | .boolNot value | .hash value =>
        collectEventPlansFromExpr module env collector value
    | .hashValue a b c d => do
        let collector ← collectEventPlansFromExpr module env collector a
        let collector ← collectEventPlansFromExpr module env collector b
        let collector ← collectEventPlansFromExpr module env collector c
        collectEventPlansFromExpr module env collector d
    | .crosscallInvoke _ _ _ | .crosscallInvokeTyped _ _ _ _ | .crosscallInvokeValueTyped _ _ _ _ _
    | .crosscallInvokeStaticTyped _ _ _ _ | .crosscallInvokeDelegateTyped _ _ _ _ => pure collector
    | .crosscallCreate _ _ | .crosscallCreate2 _ _ _ => pure collector
    | .effect effect => collectEventPlansFromEffect module env collector effect

  partial def collectEventPlansFromEffect
      (module : Module)
      (env : TypeEnv)
      (collector : EventCollector) :
      Effect → Except LowerError EventCollector
    | .storageScalarRead _ => pure collector
    | .storageScalarWrite _ value | .storageScalarAssignOp _ _ value =>
        collectEventPlansFromExpr module env collector value
    | .storageMapContains _ key | .storageMapGet _ key =>
        collectEventPlansFromExpr module env collector key
    | .storageMapInsert _ key value | .storageMapSet _ key value => do
        let collector ← collectEventPlansFromExpr module env collector key
        collectEventPlansFromExpr module env collector value
    | .storageArrayRead _ index => collectEventPlansFromExpr module env collector index
    | .storageArrayWrite _ index value | .storageArrayStructFieldWrite _ index _ value => do
        let collector ← collectEventPlansFromExpr module env collector index
        collectEventPlansFromExpr module env collector value
    | .storageArrayStructFieldRead _ index _ => collectEventPlansFromExpr module env collector index
    | .storageStructFieldRead _ _ => pure collector
    | .storageStructFieldWrite _ _ value => collectEventPlansFromExpr module env collector value
    | .storagePathRead _ path =>
        path.foldlM (init := collector) fun acc segment =>
          match segment with
          | .mapKey key => collectEventPlansFromExpr module env acc key
          | .index index => collectEventPlansFromExpr module env acc index
          | .field _ => pure acc
    | .storagePathWrite _ path value | .storagePathAssignOp _ path _ value => do
        let collector ← path.foldlM (init := collector) fun acc segment =>
          match segment with
          | .mapKey key => collectEventPlansFromExpr module env acc key
          | .index index => collectEventPlansFromExpr module env acc index
          | .field _ => pure acc
        collectEventPlansFromExpr module env collector value
    | .contextRead _ => pure collector
    | .eventEmit name fields => do
        let signature ← eventSignature module env name fields
        let mut fieldPlans : Array EventFieldPlan := #[]
        for field in fields do
          let fieldType ← inferEventFieldExprType module env field.snd
          fieldPlans := fieldPlans.push (EventFieldPlan.mk field.fst fieldType false)
        pure (collector.add (EventPlan.mk name signature fieldPlans))
    | .eventEmitIndexed name indexedFields dataFields => do
        validateIndexedEventFieldCount name indexedFields.size
        let mut fieldPlans : Array EventFieldPlan := #[]
        for field in indexedFields do
          let fieldType ← inferEventFieldExprType module env field.snd
          fieldPlans := fieldPlans.push (EventFieldPlan.mk field.fst fieldType true)
        for field in dataFields do
          let fieldType ← inferEventFieldExprType module env field.snd
          fieldPlans := fieldPlans.push (EventFieldPlan.mk field.fst fieldType false)
        let signature ← eventSignature module env name (indexedFields ++ dataFields)
        pure (collector.add (EventPlan.mk name signature fieldPlans))

  partial def collectEventPlansFromStatements
      (module : Module)
      (env : TypeEnv)
      (collector : EventCollector) :
      Array Statement → Except LowerError EventCollector
    | #[] => pure collector
    | statements => do
      let mut current := env
      let mut acc := collector
      for stmt in statements do
        match stmt with
        | .letBind name type value => do
            ensureType s!"let binding `{name}`" type (← inferExprType module current value)
            current ← addLocal current name type false
            acc ← collectEventPlansFromExpr module current acc value
        | .letMutBind name type value => do
            ensureType s!"mutable let binding `{name}`" type (← inferExprType module current value)
            current ← addLocal current name type true
            acc ← collectEventPlansFromExpr module current acc value
        | .assign target value | .assignOp target _ value => do
            acc ← collectEventPlansFromExpr module current acc target
            acc ← collectEventPlansFromExpr module current acc value
        | .effect effect => do
            acc ← collectEventPlansFromEffect module current acc effect
        | .assert condition _ _ => do
            acc ← collectEventPlansFromExpr module current acc condition
        | .assertEq lhs rhs _ _ => do
            acc ← collectEventPlansFromExpr module current acc lhs
            acc ← collectEventPlansFromExpr module current acc rhs
        | .release _ => pure ()
        | .ifElse condition thenBody elseBody => do
            acc ← collectEventPlansFromExpr module current acc condition
            acc ← collectEventPlansFromStatements module current acc thenBody
            acc ← collectEventPlansFromStatements module current acc elseBody
        | .boundedFor indexName _ _ body => do
            let loopEnv ← addLocal current indexName .u32 false
            acc ← collectEventPlansFromStatements module loopEnv acc body
        | .return value => do
            acc ← collectEventPlansFromExpr module current acc value
      pure acc
end

def buildEventPlans (module : Module) : Except LowerError (Array EventPlan) := do
  let mut collector : EventCollector := {}
  for entrypoint in module.entrypoints do
    collector ← collectEventPlansFromStatements module (entrypointTypeEnv entrypoint) collector entrypoint.body
  .ok collector.plans

/-! ## Module plan assembly -/

def buildFullModulePlan (module : Module) : Except LowerError ModulePlan := do
  let basePlan ←
    match buildModulePlan module with
    | .ok plan => .ok plan
    | .error err => .error (planError err)
  let entrypointPlans ← buildEntrypointPlans module
  let eventPlans ← buildEventPlans module
  let metadata := {
    moduleName := module.name
    entrypoints := entrypointPlans
    events := eventPlans
    capabilities := basePlan.targetPlan.capabilities
  }
  .ok { basePlan with
    entrypoints := entrypointPlans
    events := eventPlans
    metadata := metadata
  }

def buildFullModulePlanWithTargetPlan
    (module : Module)
    (targetPlan : CapabilityPlan) :
    Except LowerError ModulePlan := do
  let basePlan ←
    match buildModulePlanWithTargetPlan module targetPlan with
    | .ok plan => .ok plan
    | .error err => .error (planError err)
  let entrypointPlans ← buildEntrypointPlans module
  let eventPlans ← buildEventPlans module
  let metadata := {
    moduleName := module.name
    entrypoints := entrypointPlans
    events := eventPlans
    capabilities := basePlan.targetPlan.capabilities
  }
  .ok { basePlan with
    entrypoints := entrypointPlans
    events := eventPlans
    metadata := metadata
  }

end ProofForge.Backend.Evm.Lower