/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable cross-contract intent shared across primary targets.

Authors write **logical** peer + method ids only (business / product names):
  - `declareRemoteUnit "peer.callee" "remote_call"`
  - `remoteCall (peerHandle …) (peerHandle …) args`

Host account strings (e.g. NEAR `*.near`) are **deploy-time** via
`ProofForge.Target.PeerMap` — not chain DSL in Shared.

  --target evm              → CALL
  --target solana-sbpf-asm  → sol_invoke_signed_c CPI packing
  --target wasm-near        → promise_create (+ optional PeerMap.nearDemo)
  --target host .soroban    → invoke_contract (+ optional PeerMap)

  lake env proof-forge build --target evm --root . \
    -o build/portable-remote-call/RemoteCall.bin \
    Examples/Shared/RemoteCall.lean

  lake env proof-forge build --target solana-sbpf-asm --root . \
    -o build/portable-remote-call/RemoteCall.s \
    Examples/Shared/RemoteCall.lean

  lake env proof-forge build --target wasm-near --root . \
    -o build/portable-remote-call/near \
    Examples/Shared/RemoteCall.lean

See `just portable-remote-call-multi-target` / `just crosscall-materialize`.
-/
import ProofForge.Contract.Source

namespace Examples.Shared.RemoteCall

open ProofForge.Contract.Source

contract_source RemoteCall do
  -- Logical peer + method (no chain account id in business source).
  -- Deploy: PeerMap.nearDemo rewrites peer.callee → callee.example.near.
  do ProofForge.Contract.Surface.declareRemoteUnit "peer.callee" "remote_call";

  state marker : .u64

  entry «initialize» do
    marker := u64 0;

  -- Handles 0/1 = peer/method from declareRemoteUnit above.
  entry call_remote returns(.u64) do
    return ProofForge.Contract.Surface.remoteCall
      (ProofForge.Contract.Surface.peerHandle 0)
      (ProofForge.Contract.Surface.peerHandle 1)
      #[];

  entry call_with_args returns(.u64) do
    return ProofForge.Contract.Surface.remoteCall
      (ProofForge.Contract.Surface.peerHandle 0)
      (ProofForge.Contract.Surface.peerHandle 1)
      #[u64 42, u64 7];

end Examples.Shared.RemoteCall
