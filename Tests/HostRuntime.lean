/-
HostRuntime catalog smoke: primary triad bindings + support counts.
-/
import ProofForge.Target.HostRuntime

namespace ProofForge.Tests.HostRuntime

open ProofForge.Target.HostRuntime

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then pure () else throw (IO.userError message)

def main : IO UInt32 := do
  require (catalogId == "host.runtime") "catalog id"
  require (allEffects.size >= 16) "expected full effect catalog"
  require (primaryTargetIds.contains "evm") "primary includes evm"
  require (primaryTargetIds.contains "solana-sbpf-asm") "primary includes solana"
  require (primaryTargetIds.contains "wasm-near") "primary includes near"

  -- Every effect has three primary rows (even if symbol is n/a).
  for e in allEffects do
    require (e.bindings.size >= 3) s!"{e.id} should list ≥3 host bindings"
    for tid in primaryTargetIds do
      require ((bindingsForTarget e tid).size == 1)
        s!"{e.id} should have exactly one binding row for {tid}"

  -- Core portable surface must be supported on all three.
  for e in #[HostEffect.storageRead, .storageWrite, .logEmit, .caller,
      .remoteInvoke, .assertFail, .returnDataSet] do
    require (supports e "evm") s!"evm must support {e.id}"
    require (supports e "solana-sbpf-asm") s!"solana must support {e.id}"
    require (supports e "wasm-near") s!"near must support {e.id}"

  -- PDA is Solana-native; NEAR n/a.
  require (supports .pda "solana-sbpf-asm") "solana PDA"
  require (!supports .pda "wasm-near") "near has no PDA"

  -- Capability linkage for storage / remote.
  require (HostEffect.storageRead.capability? == some .storageScalar)
    "storageRead → storageScalar"
  require (HostEffect.remoteInvoke.capability? == some .crosscallInvoke)
    "remoteInvoke → crosscallInvoke"
  require (HostEffect.remoteInvokeSigned.capability? == some .crosscallCpi)
    "remoteInvokeSigned → crosscallCpi"

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

  let evmN := supportedCount "evm"
  let solN := supportedCount "solana-sbpf-asm"
  let nearN := supportedCount "wasm-near"
  require (evmN >= 14) s!"evm support count low: {evmN}"
  require (solN >= 16) s!"solana support count low: {solN}"
  require (nearN >= 12) s!"near support count low: {nearN}"

  IO.println s!"host-runtime: ok (effects={allEffects.size} evm={evmN} solana={solN} near={nearN})"
  pure 0

end ProofForge.Tests.HostRuntime

def main : IO UInt32 :=
  ProofForge.Tests.HostRuntime.main
