/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable Counter example for the unified EVM entry path.

Compile:
`lake env proof-forge build --target evm --root . -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean`
-/
import ProofForge.Contract.Source

namespace Counter

open ProofForge.Contract.Source

contract_source Counter do
  constructor_param initial : .u64;

  state count : .u64

  entry «initialize» do
    count := u64 0;

  entry increment do
    let n : .u64 := count;
    count := n +! u64 1;

  query get returns(.u64) do
    return count;

end Counter
