/-
# Solana extension entrypoint for `contract_source` (opt-in)

Import **this** module when a contract intentionally uses Solana-native
account / PDA / CPI / bump-allocator syntax:

```lean
import ProofForge.Contract.Source.Solana

contract_source MyProgram do
  account vault writable
  ...
```

Portable Shared examples must keep:

```lean
import ProofForge.Contract.Source
```

and must not import this file (`just portable-default` enforces that).

This module is a thin re-export: it loads the shared `contract_source` elaborator
together with Solana Surface/Builders so expanded account/PDA/CPI terms resolve.
-/
import ProofForge.Contract.Source
import ProofForge.Solana.Surface
import ProofForge.Solana
