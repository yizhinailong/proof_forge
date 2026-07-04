/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Portable ArrayExample for the unified EVM entry path.

Demonstrates local fixed-array literals, element access, and reductions
in `contract_source` syntax.
-/
import ProofForge.Contract.Source

namespace ArrayExample

open ProofForge.Contract.Source

contract_source ArrayExample do
  query sizeOf3 returns(.u64) do
    return u64 3;

  query getElem returns(.u64) do
    fixedu64x3 xs (10, 20, 30);
    return array_get xs (u64 1);

  query sumOf3 returns(.u64) do
    fixedu64x3 xs (10, 20, 30);
    return array_get xs (u64 0) +! array_get xs (u64 1) +! array_get xs (u64 2);

end ArrayExample
