/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable cross-contract intent shared across primary targets.

Authors write `remoteCall` only — never CPI metas, Promise chains, or
STATICCALL. Backends materialize:

  --target evm              → CALL
  --target solana-sbpf-asm  → sol_invoke_signed_c CPI packing
  --target wasm-near        → promise_create (needs nearCrosscallStrings for
                              account/method names when using address indices)

  lake env proof-forge build --target evm --root . \
    -o build/portable-remote-call/RemoteCall.bin \
    Examples/Shared/RemoteCall.lean

  lake env proof-forge build --target solana-sbpf-asm --root . \
    -o build/portable-remote-call/RemoteCall.s \
    Examples/Shared/RemoteCall.lean

See `just crosscall-materialize` for the IR multi-target gate (includes NEAR
string-pool portable path via NearCrosscallProbe.portableModule).
-/
import ProofForge.Contract.Source

namespace Examples.Shared.RemoteCall

open ProofForge.Contract.Source

contract_source RemoteCall do
  state marker : .u64

  entry «initialize» do
    marker := u64 0;

  -- Portable remote invoke: target + method as u64 handles, no args.
  entry call_remote (target : .u64, method : .u64) returns(.u64) do
    return ProofForge.Contract.Surface.remoteCall (expr target) (expr method) #[];

  -- Portable remote invoke with two u64 args packed by the target backend.
  entry call_with_args (target : .u64, method : .u64, amount : .u64, fee : .u64)
      returns(.u64) do
    return ProofForge.Contract.Surface.remoteCall (expr target) (expr method)
      #[expr amount, expr fee];

end Examples.Shared.RemoteCall
