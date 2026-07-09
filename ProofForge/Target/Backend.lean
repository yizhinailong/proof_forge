import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Target

/-- Registry-backed target driver (PF-P1-01).

Each backend owns its `TargetProfile` and capability `resolve` step today.
Later PF-P1 slices attach real validate / plan / package / artifact-validation
hooks while **retaining per-target plan types** (RFC 0014). CLI legacy-flag
translation lives in `ProofForge.Cli.TargetDriver` and looks up by the same
target id so adding a target does not require a central target-id match in
`TargetFirst.lean`. -/
structure TargetBackend where
  profile : TargetProfile
  resolve : ProofForge.Contract.ContractSpec → Except Diagnostic CapabilityPlan

def TargetBackend.ofProfile (profile : TargetProfile) : TargetBackend := {
  profile := profile
  resolve := defaultResolve profile
}

/-- One backend per active registry profile. Deprecated profiles are excluded
(same policy as `knownIds` / `--list-targets`). -/
def allBackends : Array TargetBackend :=
  all.map TargetBackend.ofProfile

def findBackend? (id : String) : Option TargetBackend :=
  allBackends.find? (fun backend => backend.profile.id == id)

/-- Capability resolve via the backend registry. Equivalent to
`resolveSpec` on the profile when the id is known. -/
def resolveViaBackend (id : String) (spec : ProofForge.Contract.ContractSpec) :
    Except Diagnostic CapabilityPlan :=
  match findBackend? id with
  | some backend => backend.resolve spec
  | none => .error {
      message := s!"unknown target `{id}`: no TargetBackend is registered"
    }

end ProofForge.Target
