# Examples & Tests taxonomy (Product vs Backend)

Status: **Normative (2026-07-09)**  
Related: [product-authoring-architecture](product-authoring-architecture.md),
[authoring-model](authoring-model.md).

## Product thesis

```text
Author writes:  business logic only
Author chooses: --target <id>
Platform does:  chain materialization (ABI, accounts, CPI, host, token standard)
```

## Directory roles

| Path | Role | Who cares |
|------|------|-----------|
| **`Examples/Product/`** | Portable business contracts + TokenSpec intents | Application authors, product CI |
| **`Examples/Backend/`** | Chain probes, goldens, Source.Solana/NEAR fixtures, research spikes | Compiler / backend engineers |
| **`Tests/Product/`** | Multi-target materialize matrix on Product sources | Primary product gate (`just product`) |
| **`Tests/Backend/`** (phased) | Solana/EmitWat/Evm unit probes | Backend depth gates |
| **`Tests/*` (IR/Cli/Sdk)** | Compiler internals, formal, CLI | Engineering CI |
| **`ProofForge/IR/Examples/`** | IR fixtures for semantics (not author tutorials) | Formal / IR tests |

## Hard rules

1. **Product** sources import only `ProofForge.Contract.Source` or
   `ProofForge.Contract.Token` (plus stdlib mixins composed as business policy).
2. **Product** never requires `Source.Solana`, selectors, CREATE2, or Promise APIs
   (`just portable-default` / product-default enforces this).
3. **Backend** may use chain Surfaces and golden diffs; they are **not** the
   product API and must not lead tutorials.
4. One business source per contract name. Chain directories hold **artifacts**
   (goldens/manifests), not forked business logic.

## Primary command

```bash
just product
```

Runs the product gate (portable-default + multi-target materialize path).
Full engineering suite remains `just check` (product + backend + formal).

## Migration note

Formerly `Examples/Shared` is `Examples/Product`. Chain trees under
`Examples/{Evm,Solana,…}` live under `Examples/Backend/`.
