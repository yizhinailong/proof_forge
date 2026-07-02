import ProofForge.Backend.Solana.Package
import ProofForge.Backend.Solana.SbpfAsm
import ProofForge.Solana.Examples.Clock
import ProofForge.Solana.Examples.Rent
import ProofForge.Solana.Examples.EpochSchedule
import ProofForge.Solana.Examples.LastRestartSlot
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

def metadataValue? (call : CapabilityCall) (key : String) : Option String :=
  call.metadata.foldl
    (fun found metadata =>
      match found with
      | some _ => found
      | none =>
          if metadata.key == key then
            some metadata.value
          else
            none)
    none

def scopedSysvarCall? (plan : CapabilityPlan) (name entrypoint : String) : Option CapabilityCall :=
  plan.calls.find? fun call =>
    call.capability == .envBlock &&
    metadataValue? call "solana.sysvar.name" == some name &&
    metadataValue? call "proof_forge.entrypoint" == some entrypoint

def requireMetadata (call : CapabilityCall) (key expected : String) : IO Unit :=
  require (metadataValue? call key == some expected)
    s!"metadata `{key}` mismatch for operation `{call.operation}`"

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

  let rentSpec := ProofForge.Solana.Examples.Rent.spec
  let rentPlan ←
    match resolveSpec solanaSbpfAsm rentSpec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError s!"Solana rent sysvar routing failed: {err.render}"

  require (hasCapability rentPlan .envBlock)
    "Solana rent sysvar plan missing env.block capability"
  require (hasCapability rentPlan .storageScalar)
    "Solana rent sysvar plan missing storage.scalar capability"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "solana-rent-sysvar" rentSpec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "rent sysvar package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "rent sysvar package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "name = \"record_rent\"")
        "rent sysvar manifest missing record_rent entrypoint"
      require (contains manifest "[[solana.entrypoint_sysvar]]")
        "rent sysvar manifest missing entrypoint sysvar action"
      require (contains manifest "sysvar = \"read_rent\"")
        "rent sysvar manifest missing read_rent action"
      require (contains manifest "kind = \"rent\"")
        "rent sysvar manifest missing rent kind"
      require (contains manifest "field = \"lamports_per_byte_year\"")
        "rent sysvar manifest missing lamports_per_byte_year field"
      require (contains manifest "output_state = \"lamports_per_byte_year\"")
        "rent sysvar manifest missing lamports_per_byte_year output state"
      require (contains asm "solana.sysvar.rent read_rent: field=lamports_per_byte_year")
        "assembly missing rent sysvar marker"
      require (contains asm "call sol_get_rent_sysvar")
        "assembly missing sol_get_rent_sysvar syscall"
      require (contains asm "error_sysvar")
        "assembly missing rent sysvar failure branch"
      require (contains asm ".equ LAMPORTS_PER_BYTE_YEAR_DATA")
        "assembly missing lamports_per_byte_year offset symbol"
      require (contains asm "stxdw [r5+0], r3")
        "assembly missing rent sysvar state write"
  | .error err =>
      throw <| IO.userError s!"Solana rent sysvar package render failed: {err.render}"

  let epochScheduleSpec := ProofForge.Solana.Examples.EpochSchedule.spec
  let epochSchedulePlan ←
    match resolveSpec solanaSbpfAsm epochScheduleSpec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError s!"Solana epoch schedule sysvar routing failed: {err.render}"

  require (hasCapability epochSchedulePlan .envBlock)
    "Solana epoch schedule sysvar plan missing env.block capability"
  require (hasCapability epochSchedulePlan .storageScalar)
    "Solana epoch schedule sysvar plan missing storage.scalar capability"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "solana-epoch-schedule-sysvar" epochScheduleSpec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "epoch schedule sysvar package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "epoch schedule sysvar package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "name = \"record_epoch_schedule\"")
        "epoch schedule sysvar manifest missing record_epoch_schedule entrypoint"
      require (contains manifest "[[solana.entrypoint_sysvar]]")
        "epoch schedule sysvar manifest missing entrypoint sysvar action"
      require (contains manifest "sysvar = \"read_epoch_schedule\"")
        "epoch schedule sysvar manifest missing read_epoch_schedule action"
      require (contains manifest "kind = \"epoch_schedule\"")
        "epoch schedule sysvar manifest missing epoch_schedule kind"
      require (contains manifest "field = \"slots_per_epoch\"")
        "epoch schedule sysvar manifest missing slots_per_epoch field"
      require (contains manifest "output_state = \"slots_per_epoch\"")
        "epoch schedule sysvar manifest missing slots_per_epoch output state"
      require (contains manifest "sysvar = \"read_leader_schedule_slot_offset\"")
        "epoch schedule sysvar manifest missing read_leader_schedule_slot_offset action"
      require (contains manifest "field = \"leader_schedule_slot_offset\"")
        "epoch schedule sysvar manifest missing leader_schedule_slot_offset field"
      require (contains manifest "output_state = \"leader_schedule_slot_offset\"")
        "epoch schedule sysvar manifest missing leader_schedule_slot_offset output state"
      require (contains manifest "sysvar = \"read_warmup\"")
        "epoch schedule sysvar manifest missing read_warmup action"
      require (contains manifest "field = \"warmup\"")
        "epoch schedule sysvar manifest missing warmup field"
      require (contains manifest "output_state = \"warmup\"")
        "epoch schedule sysvar manifest missing warmup output state"
      require (contains manifest "sysvar = \"read_first_normal_epoch\"")
        "epoch schedule sysvar manifest missing read_first_normal_epoch action"
      require (contains manifest "field = \"first_normal_epoch\"")
        "epoch schedule sysvar manifest missing first_normal_epoch field"
      require (contains manifest "output_state = \"first_normal_epoch\"")
        "epoch schedule sysvar manifest missing first_normal_epoch output state"
      require (contains manifest "sysvar = \"read_first_normal_slot\"")
        "epoch schedule sysvar manifest missing read_first_normal_slot action"
      require (contains manifest "field = \"first_normal_slot\"")
        "epoch schedule sysvar manifest missing first_normal_slot field"
      require (contains manifest "output_state = \"first_normal_slot\"")
        "epoch schedule sysvar manifest missing first_normal_slot output state"
      require (contains asm "solana.sysvar.epoch_schedule read_epoch_schedule: field=slots_per_epoch")
        "assembly missing epoch schedule sysvar marker"
      require (contains asm "solana.sysvar.epoch_schedule read_leader_schedule_slot_offset: field=leader_schedule_slot_offset")
        "assembly missing epoch schedule leader_schedule_slot_offset marker"
      require (contains asm "solana.sysvar.epoch_schedule read_warmup: field=warmup")
        "assembly missing epoch schedule warmup marker"
      require (contains asm "solana.sysvar.epoch_schedule read_first_normal_epoch: field=first_normal_epoch")
        "assembly missing epoch schedule first_normal_epoch marker"
      require (contains asm "solana.sysvar.epoch_schedule read_first_normal_slot: field=first_normal_slot")
        "assembly missing epoch schedule first_normal_slot marker"
      require (contains asm "call sol_get_epoch_schedule_sysvar")
        "assembly missing sol_get_epoch_schedule_sysvar syscall"
      require (contains asm "error_sysvar")
        "assembly missing epoch schedule sysvar failure branch"
      require (contains asm ".equ SLOTS_PER_EPOCH_DATA")
        "assembly missing slots_per_epoch offset symbol"
      require (contains asm ".equ LEADER_SCHEDULE_SLOT_OFFSET_DATA")
        "assembly missing leader_schedule_slot_offset offset symbol"
      require (contains asm ".equ WARMUP_DATA")
        "assembly missing warmup offset symbol"
      require (contains asm ".equ FIRST_NORMAL_EPOCH_DATA")
        "assembly missing first_normal_epoch offset symbol"
      require (contains asm ".equ FIRST_NORMAL_SLOT_DATA")
        "assembly missing first_normal_slot offset symbol"
      require (contains asm "ldxdw r3, [r5+8]")
        "assembly missing leader_schedule_slot_offset field read"
      require (contains asm "ldxb r3, [r5+16]")
        "assembly missing warmup field read"
      require (contains asm "ldxdw r3, [r5+24]")
        "assembly missing first_normal_epoch field read"
      require (contains asm "ldxdw r3, [r5+32]")
        "assembly missing first_normal_slot field read"
      require (contains asm "stxdw [r5+0], r3")
        "assembly missing epoch schedule sysvar state write"
  | .error err =>
      throw <| IO.userError s!"Solana epoch schedule sysvar package render failed: {err.render}"

  let lastRestartSlotSpec := ProofForge.Solana.Examples.LastRestartSlot.spec
  let lastRestartSlotPlan ←
    match resolveSpec solanaSbpfAsm lastRestartSlotSpec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError s!"Solana LastRestartSlot sysvar routing failed: {err.render}"

  require (hasCapability lastRestartSlotPlan .envBlock)
    "Solana LastRestartSlot sysvar plan missing env.block capability"
  require (hasCapability lastRestartSlotPlan .storageScalar)
    "Solana LastRestartSlot sysvar plan missing storage.scalar capability"
  let lastRestartSlotCall ←
    match scopedSysvarCall? lastRestartSlotPlan "read_last_restart_slot" "record_last_restart_slot" with
    | some call => pure call
    | none => throw <| IO.userError "Solana LastRestartSlot plan missing read_last_restart_slot action"
  requireMetadata lastRestartSlotCall "solana.extension" "sysvar"
  requireMetadata lastRestartSlotCall "solana.sysvar.kind" "last_restart_slot"
  requireMetadata lastRestartSlotCall "solana.sysvar.field" "last_restart_slot"
  requireMetadata lastRestartSlotCall "solana.sysvar.output_state" "last_restart_slot"
  requireMetadata lastRestartSlotCall "solana.sysvar.feature_gated" "true"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "solana-last-restart-slot-sysvar" lastRestartSlotSpec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "LastRestartSlot sysvar package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "LastRestartSlot sysvar package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "name = \"record_last_restart_slot\"")
        "LastRestartSlot sysvar manifest missing record_last_restart_slot entrypoint"
      require (contains manifest "[[solana.entrypoint_sysvar]]")
        "LastRestartSlot sysvar manifest missing entrypoint sysvar action"
      require (contains manifest "sysvar = \"read_last_restart_slot\"")
        "LastRestartSlot sysvar manifest missing read_last_restart_slot action"
      require (contains manifest "kind = \"last_restart_slot\"")
        "LastRestartSlot sysvar manifest missing last_restart_slot kind"
      require (contains manifest "field = \"last_restart_slot\"")
        "LastRestartSlot sysvar manifest missing last_restart_slot field"
      require (contains manifest "output_state = \"last_restart_slot\"")
        "LastRestartSlot sysvar manifest missing output state"
      require (contains manifest "feature_gated = true")
        "LastRestartSlot sysvar manifest missing feature gate"
      require (contains asm "solana.sysvar.last_restart_slot read_last_restart_slot: field=last_restart_slot")
        "assembly missing LastRestartSlot sysvar marker"
      require (contains asm "load SysvarLastRestartS1ot1111111111111111111111 id")
        "assembly missing LastRestartSlot sysvar id setup"
      require (contains asm "r1=sysvar_id r2=result r3=offset r4=length")
        "assembly missing LastRestartSlot sol_get_sysvar argument setup"
      require (contains asm "call sol_get_sysvar")
        "assembly missing sol_get_sysvar syscall"
      require (contains asm "error_sysvar")
        "assembly missing LastRestartSlot sysvar failure branch"
      require (contains asm ".equ LAST_RESTART_SLOT_DATA")
        "assembly missing last_restart_slot offset symbol"
      require (contains asm "stxdw [r5+0], r3")
        "assembly missing LastRestartSlot sysvar state write"
  | .error err =>
      throw <| IO.userError s!"Solana LastRestartSlot sysvar package render failed: {err.render}"

  IO.println "solana-sysvars: ok"
  return 0

end ProofForge.Tests.SolanaSysvars

def main : IO UInt32 :=
  ProofForge.Tests.SolanaSysvars.main
