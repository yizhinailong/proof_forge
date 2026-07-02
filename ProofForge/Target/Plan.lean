import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Target.Capability

namespace ProofForge.Target

structure CapabilityCall where
  capability : Capability
  operation : String
  source? : Option String := none
  deriving Repr

def CapabilityCall.fromCapability (capability : Capability) (source? : Option String := none) : CapabilityCall := {
  capability := capability
  operation := capability.id
  source? := source?
}

structure TargetMetadata where
  key : String
  value : String
  deriving Repr

structure CapabilityPlan where
  targetId : String
  calls : Array CapabilityCall
  metadata : Array TargetMetadata := #[]
  deriving Repr

def CapabilityPlan.capabilities (plan : CapabilityPlan) : Array Capability :=
  plan.calls.map (fun call => call.capability)

end ProofForge.Target
