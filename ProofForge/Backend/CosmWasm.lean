/-
Copyright (c) 2026 DaviRain. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

# Compatibility shim (deprecated path)

CosmWasm host adapters live under the Wasm-family package:

```lean
import ProofForge.Backend.WasmHost.CosmWasm.EmitWat
```

`ProofForge.Backend.CosmWasm` re-exports the CosmWasm Counter-spike EmitWat
for older CLI/tests. Prefer `WasmHost.CosmWasm.*` for new code.
-/
import ProofForge.Backend.WasmHost.CosmWasm.EmitWat
