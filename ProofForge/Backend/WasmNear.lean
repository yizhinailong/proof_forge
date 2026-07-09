/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Compatibility shim (deprecated name)

The multi-host EmitWat backend lives at **`ProofForge.Backend.WasmHost`**.

Historical name `WasmNear` implied a single chain; the same lowering core now
serves the Wasm family via `ProofForge.Target.HostBridge` (`.near` ·
`.soroban` · …). Prefer:

```lean
import ProofForge.Backend.WasmHost
-- or
import ProofForge.Backend.WasmHost.EmitWat
```

**Registry target ids stay chain-specific** (`wasm-near`,
`wasm-stellar-soroban`, …). Only the *backend package* was renamed.
-/
import ProofForge.Backend.WasmHost
