/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

E1.4 negative fixture: authority policy without a UUPS proxy pattern.
This lives outside Examples so the positive EVM example catalog stays buildable.
-/
import ProofForge.Contract.Source

namespace BadUpgradeAuth

open ProofForge.Contract.Source

contract_source BadUpgradeAuth do
  upgrade_policy_authority admin;

  state x : .u64

  entry set (v : .u64) do
    x := v;

end BadUpgradeAuth
