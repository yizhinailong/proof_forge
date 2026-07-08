/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable cross-contract intent shared across primary targets.

Authors write `remoteCall` only — never CPI metas, Promise chains, or
STATICCALL. Backends materialize:

  --target evm              → CALL
  --target solana-sbpf-asm  → sol_invoke_signed_c CPI packing
  --target wasm-near        → promise_create (string pool via registerNearCrosscallString)

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
  -- NEAR host string pool (target metadata). Harmless on EVM/Solana; required
  -- for wasm-near promise_create account/method name resolution.
  do ProofForge.Contract.Surface.registerNearCrosscallString "callee.example.near";
  do ProofForge.Contract.Surface.registerNearCrosscallString "remote_call";

  state marker : .u64

  entry «initialize» do
    marker := u64 0;

  -- Portable remote invoke: address-literal indices into nearCrosscallStrings
  -- (also fine as numeric handles on EVM/Solana).
  entry call_remote returns(.u64) do
    return ProofForge.Contract.Surface.remoteCall
      (ProofForge.Contract.Surface.nearAddressLit 0)
      (ProofForge.Contract.Surface.nearAddressLit 1)
      #[];

  -- Portable remote invoke with two constant u64 args.
  entry call_with_args returns(.u64) do
    return ProofForge.Contract.Surface.remoteCall
      (ProofForge.Contract.Surface.nearAddressLit 0)
      (ProofForge.Contract.Surface.nearAddressLit 1)
      #[u64 42, u64 7];

end Examples.Shared.RemoteCall
