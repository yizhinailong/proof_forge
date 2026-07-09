/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Product — deployable ERC-4626 vault body (Layer C)

You *are* the vault (stdlib mixin). Honest bounds: **pro-rata** exchange rate
(`shares = assets * totalSupply / totalAssets`, empty vault 1:1, floor),
IERC20 transferFrom pull on deposit/mint, transfer push on withdraw/redeem,
`vaultSelf` init param (portable `address(this)`). For *calling* a peer vault
use `external_vault` instead.

```bash
just product-erc4626-vault
```
-/
import ProofForge.Contract.Stdlib.ERC4626

namespace Examples.Product.ERC4626Vault

def spec := ProofForge.Contract.Stdlib.ERC4626.spec
def module := ProofForge.Contract.Stdlib.ERC4626.module

end Examples.Product.ERC4626Vault
