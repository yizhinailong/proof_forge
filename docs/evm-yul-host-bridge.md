# EVM Yul-subset ↔ IR Host Bridge

Status: **landed** (2026-07) — mathlib-free IR ↔ in-tree `YulSemantics`
paired simulation for Counter + ValueVault default scenario.

## Goal

Mirror the Solana solanalib host lane for EVM **without** leaving Portable IR
and **without** requiring powdr/mathlib on the default path:

```
Portable IR.Semantics
        │ executableSimulationTraceOk
        ▼
EvmYulMachineState  (lowered Yul object + WordBindings storage)
        │
        ├── product: Yul text → solc → bytecode  (unchanged)
        └── opt-in: EvmRefinement → powdr stepF   (bytecode lane)
```

## What landed

| Piece | Module | Gate |
|-------|--------|------|
| IR ↔ Yul Counter paired simulation | `ProofForge/Backend/Evm/YulHostRefinement.lean` | `just evm-yul-host-refinement-smoke` |
| CounterCall vocabulary lockstep | same | same |
| ValueVault default scenario lockstep | same | same |
| Existing executable-trace anchors re-checked | same | same |

### Storage relation (Counter)

IR `count : U64` relates to Yul storage slot `0` high-64 bits
(`word / 2^192`), matching the EVM packing used by
`EvmRefinement.CounterRefinement`.

### Honest claims

- **Tier C-diff:** fixed Counter and ValueVault scenarios match IR observables
  under `YulSemantics` (pointwise `native_decide`).
- **Not claimed:** universal all-input IR↔Yul refinement; powdr bytecode
  equivalence; solc hop. Those remain opt-in / research.

## Relation to Solana lane

| Solana | EVM |
|--------|-----|
| `BpfEncode` + solanalib host | `IR.lowerModule` + `YulSemantics` |
| `FullProgramHost` | `EvmYulMachineState` (already in `Evm.Refinement`) |
| `CounterHostRefinement` | `YulHostRefinement` |
| `just solana-solanalib-adapter` | `just evm-yul-host-refinement-smoke` |

## Next work

1. Multi-field storage relation for ValueVault (not only observables).
2. Strengthen powdr delivery boundary (opt-in) for Counter bytecode.
3. Optional: yul-compiler integration for verified Yul→bytecode (external).
