import Init.Data.Array.Basic
import Init.Data.String.Basic
import ProofForge.Target.Registry

namespace ProofForge.Target

structure CapabilityError where
  targetId : String
  capability : Capability
  message : String
  deriving Repr

def CapabilityError.render (err : CapabilityError) : String :=
  s!"target `{err.targetId}` does not support capability `{err.capability.id}`: {err.message}"

def requireCapability (profile : TargetProfile) (capability : Capability) : Except CapabilityError Unit :=
  if hasCapability profile capability then
    .ok ()
  else
    .error {
      targetId := profile.id
      capability := capability
      message := "capability is not present in the target profile"
    }

def requireCapabilities (profile : TargetProfile) (capabilities : Array Capability) : Except CapabilityError Unit := do
  for capability in capabilities do
    requireCapability profile capability

end ProofForge.Target

