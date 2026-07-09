/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Example contract exercising ERC-165 interface registration and probing.
-/
import ProofForge.Contract.Source
import ProofForge.Contract.Stdlib.ERC165

namespace ERC165Probe

open ProofForge.Contract.Source
open ProofForge.Contract.Stdlib.ERC165

def sampleInterfaceId : Nat := 0x12345678

def sampleInterfaceWord : ProofForge.IR.Expr :=
  .shiftLeft (.literal (.u64 sampleInterfaceId)) (.literal (.u64 224))

contract_source ERC165Probe do
  import ProofForge.Contract.Stdlib.ERC165;

  entry init do
    do mapWrite registeredInterfaces sampleInterfaceWord (u64 1);

end ERC165Probe
