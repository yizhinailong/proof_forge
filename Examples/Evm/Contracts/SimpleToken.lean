/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable SimpleToken for the unified EVM entry path. Composes the stdlib
ERC20 mixin and keeps a local owner scalar (avoid dual-mixin composition until
CS-2.7 lands).
-/
import ProofForge.Contract.Source
import ProofForge.Contract.Stdlib.ERC20

namespace SimpleToken

open ProofForge.Contract.Source
open ProofForge.Contract.Stdlib.ERC20

contract_source SimpleToken do
  import ProofForge.Contract.Stdlib.ERC20;

  state «owner» : .u64

  entry init (supply : .u64) do
    do ProofForge.Contract.Surface.requireZero «owner» "already initialized";
    «owner» := caller;
    tokenDecimals := u64 18;
    totalSupply := supply;
    let who : .address := caller;
    do mapWrite balances who supply;

  query getOwner returns(.u64) do
    return «owner»;

end SimpleToken
