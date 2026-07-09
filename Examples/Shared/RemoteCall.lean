/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable cross-contract intent shared across primary targets.

Authors write **logical** peer + method once, then call through the ref —
no bare pool indices, no host string-pool APIs:

  let remote ← declareRemote "peer.callee" "remote_call"
  return remoteCallRef remote #[]

Host account strings (e.g. NEAR `*.near`) are **deploy-time** via
`proof-forge … --peer peer.callee=alice.testnet` or `--peers-demo`.

  --target evm              → CALL
  --target solana-sbpf-asm  → sol_invoke_signed_c CPI packing
  --target wasm-near        → promise_create (+ optional PeerMap)
  --target host .soroban    → invoke_contract (+ optional PeerMap)

  lake env proof-forge build --target wasm-near --root . \
    --peers-demo \
    -o build/portable-remote-call/near \
    Examples/Shared/RemoteCall.lean

See `just portable-remote-call-multi-target` / `just crosscall-materialize`.
-/
import ProofForge.Contract.Builder
import ProofForge.Contract.Surface

namespace Examples.Shared.RemoteCall

/-- Portable product path: named `RemoteRef`, never `peerHandle 0/1`. -/
def spec : ProofForge.Contract.ContractSpec :=
  ProofForge.Contract.Builder.build "RemoteCall" do
    let remote ← ProofForge.Contract.Surface.declareRemote "peer.callee" "remote_call"
    ProofForge.Contract.Builder.scalarState "marker" .u64
    ProofForge.Contract.Builder.entry "initialize" do
      ProofForge.Contract.Builder.effect
        (ProofForge.Contract.Builder.storageScalarWrite "marker"
          (ProofForge.Contract.Builder.u64 0))
    ProofForge.Contract.Builder.entryReturns "call_remote" .u64 do
      ProofForge.Contract.Builder.ret
        (ProofForge.Contract.Surface.remoteCallRef remote #[])
    ProofForge.Contract.Builder.entryReturns "call_with_args" .u64 do
      ProofForge.Contract.Builder.ret
        (ProofForge.Contract.Surface.remoteCallRef remote
          #[ProofForge.Contract.Builder.u64 42, ProofForge.Contract.Builder.u64 7])

def module : ProofForge.IR.Module :=
  spec.module

end Examples.Shared.RemoteCall
