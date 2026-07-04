/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable SimpleToken for the unified EVM entry path.
-/
import ProofForge.Contract.Source

namespace SimpleToken

open ProofForge.Contract.Source

contract_source SimpleToken do
  state «owner» : .u64
  state totalSupply : .u64
  mapping balances from .u64 to .u64

  entry init (supply : .u64) do
    «owner» := caller;
    totalSupply := supply;
    let who : .u64 := caller;
    do mapWrite balances who supply;

  query getOwner returns(.u64) do
    return «owner»;

  query totalSupply returns(.u64) do
    return totalSupply;

  query balanceOf (addr : .u64) returns(.u64) do
    return mapRead balances addr;

  entry transfer (to : .u64, amount : .u64) do
    let sender : .u64 := caller;
    let bal : .u64 := mapRead balances sender;
    do ProofForge.Contract.Surface.requireGe (ProofForge.Contract.Surface.ref bal) (ProofForge.Contract.Surface.ref amount) "insufficient balance";
    do mapWrite balances sender (bal -! amount);
    let recvBal : .u64 := mapRead balances to;
    do mapWrite balances to (recvBal +! amount);

end SimpleToken
