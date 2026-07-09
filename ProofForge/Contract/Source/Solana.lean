/-
# Solana extension entrypoint for `contract_source` (**fixture / research only**)

**Product path:** `import ProofForge.Contract.Source` only. Portable Shared
examples must never import this file (`just portable-default`).

Solana account / PDA / CPI / bump-allocator syntax is **not** the product
authoring language. Prefer:

```lean
import ProofForge.Contract.Source
-- business logic only; --target solana-sbpf-asm auto-materializes accounts/CPI
```

Import **this** module only for backend fixtures, Pinocchio/live gates, or
hand-tuned layouts that the portable materializer does not yet cover:

```lean
import ProofForge.Contract.Source.Solana

contract_source MyProgram do
  account vault writable
  ...
```

Allowed locations:

* `ProofForge/Solana/Examples/*`
* `Examples/Solana/*` (chain-specific goldens / probes)
* Internal backend tests that deliberately exercise extension surface

Not allowed: `Examples/Shared/*`, stdlib portable mixins, product tutorials.
-/
import ProofForge.Contract.Source
import ProofForge.Solana.Surface
import ProofForge.Solana
