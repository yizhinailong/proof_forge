/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable SimpleToken for the unified EVM entry path. Composes stdlib Ownable and
ERC-20 mixins via the official `compose` merge API (CS-2.7).
-/
import ProofForge.Contract.Source
import ProofForge.Contract.Compose
import ProofForge.Contract.Stdlib.Compose.Specs
import ProofForge.Contract.Stdlib.Ownable
import ProofForge.Contract.Stdlib.ERC20

namespace SimpleToken

open ProofForge.Contract.Source
open ProofForge.Contract.Stdlib.Ownable
open ProofForge.Contract.Stdlib.ERC20

contract_source SimpleToken do
  compose ProofForge.Contract.Stdlib.Ownable;
  compose ProofForge.Contract.Stdlib.ERC20;

  entry init (supply : .u64) do
    do ProofForge.Contract.Surface.requireZero «owner» "already initialized";
    «owner» := caller;
    tokenDecimals := u64 18;
    totalSupply := supply;
    let who : .address := caller;
    do mapWrite balances who supply;

end SimpleToken
