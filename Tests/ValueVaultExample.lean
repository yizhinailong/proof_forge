import ProofForge.Backend.Evm.IR
import ProofForge.Backend.Solana.Package
import ProofForge.Contract.Examples.ValueVault
import ProofForge.Target.Adapter
import ProofForge.Target.Registry

namespace ProofForge.Tests.ValueVaultExample

open ProofForge.Target

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

def hasCapability (plan : CapabilityPlan) (capability : Capability) : Bool :=
  plan.capabilities.any (fun item => item == capability)

def requireCapability (plan : CapabilityPlan) (capability : Capability) : IO Unit :=
  require (hasCapability plan capability)
    s!"ValueVault plan for `{plan.targetId}` missing capability `{capability.id}`"

def noSolanaMetadata (plan : CapabilityPlan) : Bool :=
  plan.calls.all (fun call =>
    call.metadata.all (fun item => !item.key.startsWith "solana."))

def routableTargets : Array TargetProfile := #[
  evm,
  wasmNear,
  wasmCosmWasm,
  solanaSbpfAsm,
  solanaSbpfLinker,
  solanaZigFork,
  moveAptos,
  moveSui,
  psyDpn
]

def requireRoutableTarget (profile : TargetProfile) : IO Unit := do
  let plan ←
    match resolveSpec profile ProofForge.Contract.Examples.ValueVault.spec with
    | .ok plan => pure plan
    | .error err => throw <| IO.userError s!"ValueVault routing failed for `{profile.id}`: {err.render}"
  require (plan.targetId == profile.id) s!"ValueVault target id mismatch for `{profile.id}`"
  requireCapability plan .storageScalar
  requireCapability plan .eventsEmit
  requireCapability plan .envBlock
  require (noSolanaMetadata plan)
    s!"ValueVault should not carry Solana target-extension metadata for `{profile.id}`"

def requireModuleShape : IO Unit := do
  let module := ProofForge.Contract.Examples.ValueVault.module
  require (module.name == "ValueVault") "ValueVault module name mismatch"
  require (module.state.size == 6) "ValueVault should have six scalar state fields"
  require (module.entrypoints.size == 7) "ValueVault should have seven entrypoints"
  let names := module.entrypoints.map (fun entrypoint => entrypoint.name)
  require (names == #[
    "initialize",
    "deposit",
    "charge_fee",
    "release",
    "snapshot",
    "get_balance",
    "get_net_value"
  ]) s!"ValueVault entrypoint order mismatch: {names}"

def requireEvmRender : IO Unit := do
  match ProofForge.Backend.Evm.IR.renderModule ProofForge.Contract.Examples.ValueVault.module with
  | .ok yul =>
      require (contains yul "object \"ValueVault\"")
        "ValueVault EVM render missing object name"
      require (contains yul "function f_ValueVault_deposit")
        "ValueVault EVM render missing deposit function"
      require (contains yul "function f_ValueVault_snapshot")
        "ValueVault EVM render missing snapshot function"
      require (contains yul "log1")
        "ValueVault EVM render missing event log lowering"
      require (contains yul "number()")
        "ValueVault EVM render missing checkpoint/block lowering"
  | .error err =>
      throw <| IO.userError s!"ValueVault EVM render failed: {err.render}"

def requireSolanaRender : IO Unit := do
  match ProofForge.Backend.Solana.Package.renderPackageForSpec
      "portable-value-vault" ProofForge.Contract.Examples.ValueVault.spec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "ValueVault Solana package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "ValueVault Solana package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "name = \"deposit\"")
        "ValueVault Solana manifest missing deposit instruction"
      require (contains manifest "name = \"charge_fee\"")
        "ValueVault Solana manifest missing charge_fee instruction"
      require (contains manifest "name = \"snapshot\"")
        "ValueVault Solana manifest missing snapshot instruction"
      require (contains manifest "{ name = \"amount\", type = \"U64\", offset = 1, byte_size = 8, encoding = \"le-u64\" }")
        "ValueVault Solana manifest missing amount parameter schema"
      require (contains asm "solana.event.emit ValueDeposited: sol_log_64_ scalar fields")
        "ValueVault Solana assembly missing ValueDeposited event"
      require (contains asm "solana.event.emit ValueSnapshot: sol_log_64_ scalar fields")
        "ValueVault Solana assembly missing ValueSnapshot event"
      require (contains asm "solana.sysvar.clock: sol_get_clock_sysvar -> Clock.slot")
        "ValueVault Solana assembly missing checkpoint lowering"
      require (contains asm "call sol_log_64_")
        "ValueVault Solana assembly missing event log syscall"
      require (contains asm "call sol_get_clock_sysvar")
        "ValueVault Solana assembly missing clock sysvar syscall"
  | .error err =>
      throw <| IO.userError s!"ValueVault Solana render failed: {err.render}"

def main : IO UInt32 := do
  requireModuleShape
  for profile in routableTargets do
    requireRoutableTarget profile
  requireEvmRender
  requireSolanaRender
  IO.println "value-vault-example: ok"
  return 0

end ProofForge.Tests.ValueVaultExample

def main : IO UInt32 :=
  ProofForge.Tests.ValueVaultExample.main
