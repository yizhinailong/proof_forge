/-
HostRuntime catalog smoke: primary triad bindings + support counts +
capability vs n/a honesty (shipped requireHostRuntimeHonesty / resolveModule).
-/
import ProofForge.Target.HostRuntime
import ProofForge.Target.Adapter
import ProofForge.Target.Registry
import ProofForge.Contract.Spec
import ProofForge.Contract.Intent
import ProofForge.IR.Contract
import ProofForge.IR.Examples.EventProbe
import ProofForge.Backend.Solana.SbpfAsm

namespace ProofForge.Tests.HostRuntime

open ProofForge.Target
open ProofForge.Target.HostRuntime
open ProofForge.IR
open ProofForge.Contract

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

/-- Spec that *requests* `storage.pda` via intent (Solana-shaped HostEffect).
Uses shipped `resolveSpec` / HostRuntime honesty — not a hand-rolled gate. -/
def pdaClaimSpec : ContractSpec := {
  name := "HostRuntimePdaClaim"
  module := {
    name := "HostRuntimePdaClaim"
    state := #[]
    entrypoints := #[{ name := "touch", body := #[] }]
  }
  intents := #[Intent.capability .storagePda "solana.pda.derive"]
}

def main : IO UInt32 := do
  require (catalogId == "host.runtime") "catalog id"
  require (allEffects.size >= 16) "expected full effect catalog"
  require (primaryTargetIds.contains "evm") "primary includes evm"
  require (primaryTargetIds.contains "solana-sbpf-asm") "primary includes solana"
  require (primaryTargetIds.contains "wasm-near") "primary includes near"
  require (adapterTargetIds.contains "wasm-stellar-soroban") "adapter includes soroban"
  require (adapterTargetIds.contains "wasm-cosmwasm") "adapter includes cosmwasm"
  require (catalogTargetIds.size == 5) "catalog has 5 targets"

  -- Every effect has primary triad + adapter rows (even if symbol is n/a).
  for e in allEffects do
    require (e.bindings.size >= 5) s!"{e.id} should list ≥5 host bindings (3+2)"
    for tid in catalogTargetIds do
      require ((bindingsForTarget e tid).size == 1)
        s!"{e.id} should have exactly one binding row for {tid}"

  -- Core portable surface must be supported on all three.
  for e in #[HostEffect.storageRead, .storageWrite, .logEmit, .caller,
      .remoteInvoke, .assertFail, .returnDataSet] do
    require (supports e "evm") s!"evm must support {e.id}"
    require (supports e "solana-sbpf-asm") s!"solana must support {e.id}"
    require (supports e "wasm-near") s!"near must support {e.id}"

  -- PDA is Solana-native; NEAR n/a; EVM pdaFind n/a.
  require (supports .pda "solana-sbpf-asm") "solana PDA"
  require (!supports .pda "wasm-near") "near has no PDA"
  require (!supports .pdaFind "evm") "evm has no pdaFind"
  require (!supports .pdaFind "wasm-near") "near has no pdaFind"
  require (isNaSymbol "n/a") "n/a symbol helper"
  require (!capabilityHostHonest .storagePda "wasm-near")
    "storagePda not host-honest on near"
  require (capabilityHostHonest .storagePda "solana-sbpf-asm")
    "storagePda host-honest on solana"
  require (!capabilityHostHonest .storagePda "evm")
    "storagePda not fully honest on evm (pdaFind n/a)"

  -- Capability linkage for storage / remote.
  require (HostEffect.storageRead.capability? == some .storageScalar)
    "storageRead → storageScalar"
  require (HostEffect.remoteInvoke.capability? == some .crosscallInvoke)
    "remoteInvoke → crosscallInvoke"
  require (HostEffect.remoteInvokeSigned.capability? == some .crosscallCpi)
    "remoteInvokeSigned → crosscallCpi"
  require ((effectsForCapability .storagePda).any (· == .pda))
    "storagePda maps to host.pda effect"

  -- Spot-check native symbols.
  let logEvm := bindingsForTarget .logEmit "evm"
  require (logEvm.any (fun b => b.kind == .opcode && b.symbol.contains "log"))
    "evm log is opcode"
  let logSol := bindingsForTarget .logEmit "solana-sbpf-asm"
  require (logSol.any (fun b => b.kind == .syscall && b.symbol == "sol_log_64_"))
    "solana log is sol_log_64_"
  let logNear := bindingsForTarget .logEmit "wasm-near"
  require (logNear.any (fun b => b.kind == .hostImport && b.symbol == "env.log_utf8"))
    "near log is env.log_utf8"
  let cpi := bindingsForTarget .remoteInvokeSigned "solana-sbpf-asm"
  require (cpi.any (fun b => b.symbol == "sol_invoke_signed_c"))
    "solana signed remote is sol_invoke_signed_c"
  let call := bindingsForTarget .remoteInvoke "evm"
  require (call.any (fun b => b.symbol == "call")) "evm remote is call"
  let prom := bindingsForTarget .remoteInvoke "wasm-near"
  require (prom.any (fun b => b.symbol == "env.promise_create"))
    "near remote is promise_create"
  -- Wasm adapter remote symbols.
  require (supports .remoteInvoke "wasm-stellar-soroban") "soroban remote"
  require (supports .remoteInvoke "wasm-cosmwasm") "cosmwasm remote"
  require (supports .storageRead "wasm-stellar-soroban") "soroban storage read"
  require (supports .storageRead "wasm-cosmwasm") "cosmwasm storage read"
  require (!supports .pda "wasm-stellar-soroban") "soroban no PDA"
  require (!supports .logEmit "wasm-cosmwasm")
    "cosmwasm log is n/a in HostBridge inventory (honest)"
  let ref := catalogRefComment .logEmit "solana-sbpf-asm"
  require (contains ref "HostRuntime") "catalogRefComment names HostRuntime"
  require (contains ref "host.log.emit") "catalogRefComment names effect id"
  require (contains ref "sol_log_64_") "catalogRefComment names sol_log_64_"

  -- Pure honesty helper: NEAR + storage.pda → clear HostRuntime error.
  match requireHostRuntimeHonesty "wasm-near" #[.storagePda] with
  | .ok () => throw (IO.userError "NEAR+storagePda must not pass HostRuntime honesty")
  | .error msg =>
      require (contains msg "HostRuntime") "reject names HostRuntime"
      require (contains msg "wasm-near") "reject names target"
      require (contains msg "storage.pda" || contains msg "host.pda")
        "reject names capability/effect"
      require (contains msg "n/a" || contains msg "no native binding")
        "reject mentions n/a binding"

  -- EVM + storage.pda fails honesty (pdaFind is n/a) even though create2 exists.
  match requireHostRuntimeHonesty "evm" #[.storagePda] with
  | .ok () => throw (IO.userError "EVM+storagePda must fail HostRuntime honesty (pdaFind n/a)")
  | .error msg =>
      require (contains msg "HostRuntime") "evm reject names HostRuntime"
      require (contains msg "host.pda.find" || contains msg "storage.pda")
        "evm reject names pdaFind or storage.pda"

  -- Solana + storage.pda is honest.
  match requireHostRuntimeHonesty "solana-sbpf-asm" #[.storagePda] with
  | .error msg => throw (IO.userError s!"Solana+storagePda should be honest: {msg}")
  | .ok () => pure ()

  -- Shipped resolveSpec path: PDA intent on NEAR fails with HostRuntime text.
  match resolveSpec wasmNear pdaClaimSpec with
  | .ok _ => throw (IO.userError "resolveSpec NEAR+PDA must fail")
  | .error diag =>
      require (contains diag.message "HostRuntime")
        s!"resolveSpec diagnostic must name HostRuntime, got: {diag.message}"
      require (contains diag.message "wasm-near")
        "resolveSpec diagnostic names target"
      require (
          contains diag.message "storage.pda" ||
          contains diag.message "host.pda"
        ) "resolveSpec diagnostic names PDA effect/cap"

  -- Same intent resolves on Solana (profile has storagePda + HostRuntime honest).
  match resolveSpec solanaSbpfAsm pdaClaimSpec with
  | .error diag =>
      throw (IO.userError s!"resolveSpec Solana+PDA should ok: {diag.message}")
  | .ok plan =>
      require (plan.targetId == "solana-sbpf-asm") "plan target solana"
      require (plan.capabilities.any (· == .storagePda)) "plan keeps storagePda"

  let evmN := supportedCount "evm"
  let solN := supportedCount "solana-sbpf-asm"
  let nearN := supportedCount "wasm-near"
  let sorobanN := supportedCount "wasm-stellar-soroban"
  let cosmwasmN := supportedCount "wasm-cosmwasm"
  require (evmN >= 14) s!"evm support count low: {evmN}"
  require (solN >= 16) s!"solana support count low: {solN}"
  require (nearN >= 12) s!"near support count low: {nearN}"
  require (sorobanN >= 4) s!"soroban support count low: {sorobanN}"
  require (cosmwasmN >= 3) s!"cosmwasm support count low: {cosmwasmN}"

  -- Shipped lowerer emits HostRuntime catalog comment on log path.
  match ProofForge.Backend.Solana.SbpfAsm.renderModule
      ProofForge.IR.Examples.EventProbe.module with
  | .error e => throw (IO.userError s!"EventProbe Solana render failed: {e.message}")
  | .ok asm =>
      require (contains asm "HostRuntime host.log.emit")
        "sBPF lowerer must emit HostRuntime catalog ref for logEmit"
      require (contains asm "sol_log_64_")
        "sBPF lowerer must still call sol_log_64_"
      require (contains asm "syscall:sol_log_64_" || contains asm "sol_log_64_")
        "catalog ref or syscall present"

  IO.println s!"host-runtime: ok (effects={allEffects.size} evm={evmN} solana={solN} near={nearN} soroban={sorobanN} cosmwasm={cosmwasmN}; adapters+catalog-ref)"
  pure 0

end ProofForge.Tests.HostRuntime

def main : IO UInt32 :=
  ProofForge.Tests.HostRuntime.main
