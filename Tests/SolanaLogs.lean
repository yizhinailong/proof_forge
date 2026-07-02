import ProofForge.Backend.Solana.Package
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Solana.Examples.LogEvent
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Tests.SolanaLogs

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
  let spec := ProofForge.Solana.Examples.LogEvent.spec
  let plan ←
    match resolveSpec solanaSbpfAsm spec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError s!"Solana log event routing failed: {err.render}"

  require (hasCapability plan .eventsEmit)
    "Solana log event plan missing events.emit capability"
  require (hasCapability plan .storageScalar)
    "Solana log event plan missing storage.scalar capability"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "solana-log-event" spec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "log event package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "log event package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      let tag := ProofForge.Backend.Solana.SbpfAsm.stableEventTag "AmountEvent"
      require (contains manifest "name = \"emit\"")
        "log event manifest missing emit entrypoint"
      require (contains manifest "min_data_len = 9")
        "log event manifest missing parameter payload length"
      require (contains manifest "{ name = \"amount\", type = \"U64\", offset = 1, byte_size = 8, encoding = \"le-u64\" }")
        "log event manifest missing amount parameter schema"
      require (contains asm "solana.event.emit AmountEvent: sol_log_64_ scalar fields")
        "assembly missing event emission marker"
      require (contains asm s!"solana.event.field AmountEvent.amount: tag={tag} index=0")
        "assembly missing event field marker"
      require (contains asm s!"mov64 r1, {tag}")
        "assembly missing event tag argument"
      require (contains asm "mov64 r2, 0")
        "assembly missing event field index argument"
      require (contains asm "mov64 r3, r2")
        "assembly missing event field value argument"
      require (contains asm "call sol_log_64_")
        "assembly missing sol_log_64_ syscall"
  | .error err =>
      throw <| IO.userError s!"Solana log event package render failed: {err.render}"

  IO.println "solana-logs: ok"
  return 0

end ProofForge.Tests.SolanaLogs

def main : IO UInt32 :=
  ProofForge.Tests.SolanaLogs.main
