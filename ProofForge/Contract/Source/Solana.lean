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
  binding amount : .u64
  binding vault_bump : .u64
  -- Values used as PDA/CPI seeds or amount_source MUST appear as entry params
  -- so Solana valueBindings resolve (honest materialize; no silent zero packs):
  entry touch (amount : .u64, vault_bump : .u64) do
    ...
```

Allowed locations:

* `ProofForge/Solana/Examples/*`
* `Examples/Backend/Solana/*` (chain-specific goldens / probes)
* Internal backend tests that deliberately exercise extension surface

Not allowed: `Examples/Product/*`, stdlib portable mixins, product tutorials.
-/
import ProofForge.Contract.Source
import ProofForge.Solana.Surface
import ProofForge.Solana
