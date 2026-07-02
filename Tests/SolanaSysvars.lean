import ProofForge.Backend.Solana.Package
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Solana.Examples.Clock
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Tests.SolanaSysvars

open ProofForge.Target

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

def hasCapability (plan : CapabilityPlan) (capability : Capability) : Bool :=
  plan.capabilities.any (fun c => c == capability)

def main : IO UInt32 := do
  let spec := ProofForge.Solana.Examples.Clock.spec
  let plan ←
    match resolveSpec solanaSbpfAsm spec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError s!"Solana clock sysvar routing failed: {err.render}"

  require (hasCapability plan .envBlock)
    "Solana clock sysvar plan missing env.block capability"
  require (hasCapability plan .storageScalar)
    "Solana clock sysvar plan missing storage.scalar capability"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "solana-clock-sysvar" spec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "clock sysvar package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "clock sysvar package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "name = \"record\"")
        "clock sysvar manifest missing record entrypoint"
      require (contains asm "solana.sysvar.clock: sol_get_clock_sysvar -> Clock.slot")
        "assembly missing clock sysvar marker"
      require (contains asm "call sol_get_clock_sysvar")
        "assembly missing sol_get_clock_sysvar syscall"
      require (contains asm "jne r0, 0, error_syscall")
        "assembly missing clock sysvar failure branch"
      require (contains asm ".equ LAST_SLOT_DATA")
        "assembly missing last_slot offset symbol"
      require (contains asm "stxdw [r1+")
        "assembly missing last_slot state write"
  | .error err =>
      throw <| IO.userError s!"Solana clock sysvar package render failed: {err.render}"

  IO.println "solana-sysvars: ok"
  return 0

end ProofForge.Tests.SolanaSysvars

def main : IO UInt32 :=
  ProofForge.Tests.SolanaSysvars.main
