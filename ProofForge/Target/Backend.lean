import ProofForge.IR.Contract
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Target

/-- Registry-backed target driver (PF-P1-01).

Each backend owns its `TargetProfile` and capability `resolve` step. Optional
`validateModule?` / `ensurePlan?` hooks attach real backend stages while
**retaining per-target plan types** (RFC 0014): hooks discard typed plans and
only surface success or a `Diagnostic`. CLI legacy-flag translation lives in
`ProofForge.Cli.TargetDriver` and looks up by the same target id. -/
structure TargetBackend where
  profile : TargetProfile
  resolve : ProofForge.Contract.ContractSpec → Except Diagnostic CapabilityPlan
  /-- Backend-owned module validation beyond shared capability resolve. -/
  validateModule? : Option (ProofForge.IR.Module → Except Diagnostic Unit) := none
  /-- Succeeds when a target-specific plan can be built (typed plan stays private). -/
  ensurePlan? : Option (ProofForge.IR.Module → Except Diagnostic Unit) := none

def TargetBackend.ofProfile (profile : TargetProfile) : TargetBackend := {
  profile := profile
  resolve := defaultResolve profile
}

def TargetBackend.hasValidate (backend : TargetBackend) : Bool :=
  backend.validateModule?.isSome

def TargetBackend.hasPlan (backend : TargetBackend) : Bool :=
  backend.ensurePlan?.isSome

/-- Run validate when the backend exposes one; otherwise fail closed with a
stable diagnostic (callers must not invent a silent pass). -/
def TargetBackend.validateModule (backend : TargetBackend) (module : ProofForge.IR.Module) :
    Except Diagnostic Unit :=
  match backend.validateModule? with
  | some validate => validate module
  | none => .error {
      message :=
        s!"target `{backend.profile.id}` has no TargetBackend.validateModule hook; \
backend-owned validation is not registered"
    }

/-- Run plan-stage smoke when the backend exposes one. -/
def TargetBackend.ensurePlan (backend : TargetBackend) (module : ProofForge.IR.Module) :
    Except Diagnostic Unit :=
  match backend.ensurePlan? with
  | some ensure => ensure module
  | none => .error {
      message :=
        s!"target `{backend.profile.id}` has no TargetBackend.ensurePlan hook; \
backend-owned plan stage is not registered"
    }

end ProofForge.Target
