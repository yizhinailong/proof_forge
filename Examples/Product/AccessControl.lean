/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Shared facade for AccessControl role mixin (portable u64 role map path).

Note: `Stdlib.AccessControl` uses `.address` account params (EVM-shaped ABI).
For fully portable handle keys without address ABI, prefer the role map pattern
in `Examples/Product/RoleGatedToken.lean` (`.u64` keys + `pathWriteRole`).

  lake env proof-forge build --target evm --root . \
    -o build/portable-access-control/AccessControl \
    Examples/Product/AccessControl.lean
-/
import ProofForge.Contract.Stdlib.AccessControl

namespace Examples.Product.AccessControl

def spec : ProofForge.Contract.ContractSpec :=
  ProofForge.Contract.Stdlib.AccessControl.spec

def module : ProofForge.IR.Module :=
  spec.module

end Examples.Product.AccessControl
