/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

E1.4 negative fixture: `upgrade_policy_authority` without `proxy_pattern_uups`.
Product EVM build must fail closed (see `just evm-upgrade-policy-honesty`).
Do **not** add this module to `scripts/evm/build-examples.sh`.
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
