import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Contract.Spec
import ProofForge.Target.Check
import ProofForge.Target.Plan

namespace ProofForge.Target

structure Diagnostic where
  message : String
  deriving Repr, Inhabited

def Diagnostic.render (diagnostic : Diagnostic) : String :=
  diagnostic.message

def Diagnostic.fromCapabilityError (err : CapabilityError) : Diagnostic := {
  message := err.render
}

def intentCapabilityCalls (spec : ProofForge.Contract.ContractSpec) : Array CapabilityCall :=
  spec.intents.foldl
    (fun calls intent =>
      match intent.capability? with
      | some capability => calls.push {
          capability := capability
          operation := intent.label
          source? := intent.source?
        }
      | none => calls)
    #[]

def moduleCapabilityCalls (module : ProofForge.IR.Module) : Array CapabilityCall :=
  module.capabilities.map (fun capability => CapabilityCall.fromCapability capability)

def capabilityCallsForSpec (spec : ProofForge.Contract.ContractSpec) : Array CapabilityCall :=
  let calls := intentCapabilityCalls spec
  if calls.size == 0 then
    moduleCapabilityCalls spec.module
  else
    calls

def defaultMetadata (profile : TargetProfile) (spec : ProofForge.Contract.ContractSpec) : Array TargetMetadata := #[
  { key := "contract", value := spec.name },
  { key := "target", value := profile.id },
  { key := "resolver", value := "ir-capability-plan-v0" }
]

def defaultResolve (profile : TargetProfile) (spec : ProofForge.Contract.ContractSpec) :
    Except Diagnostic CapabilityPlan := do
  let plan : CapabilityPlan := {
    targetId := profile.id
    calls := capabilityCallsForSpec spec
    metadata := defaultMetadata profile spec
  }
  match requireCapabilities profile plan.capabilities with
  | .ok () => .ok plan
  | .error err => .error (Diagnostic.fromCapabilityError err)

structure TargetAdapter where
  profile : TargetProfile
  resolve : ProofForge.Contract.ContractSpec -> Except Diagnostic CapabilityPlan

def TargetAdapter.default (profile : TargetProfile) : TargetAdapter := {
  profile := profile
  resolve := defaultResolve profile
}

def resolveSpec (profile : TargetProfile) (spec : ProofForge.Contract.ContractSpec) :
    Except Diagnostic CapabilityPlan :=
  (TargetAdapter.default profile).resolve spec

def resolveModule (profile : TargetProfile) (module : ProofForge.IR.Module) :
    Except Diagnostic CapabilityPlan :=
  resolveSpec profile (ProofForge.Contract.ContractSpec.fromIR module)

end ProofForge.Target
