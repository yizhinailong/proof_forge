# Target Notes

This directory contains target-family notes that sit below the RFCs and above
implementation tasks. They are meant to be edited as research turns into code.

Related: [Documentation index](../INDEX.md),
[RFC 0002](../rfcs/0002-target-implementation-design.md),
[Implementation backlog](../implementation-backlog.md),
[Design decisions](../decisions.md).

## Target Lifecycle

| Stage | Meaning |
|---|---|
| Research | We understand the chain model and toolchain shape, but no local backend exists. |
| Spike | A minimal artifact is being produced, usually for one Counter example. |
| Experimental | A target has SDK, build, and smoke tests, but capability coverage is narrow. |
| Supported | A target has stable CLI, artifact metadata, CI, docs, and shared scenario tests. |

## Stage Exit Criteria

- `Research` exits only when a target profile draft, required-tool list, and
  minimal spike acceptance criteria are documented.
- `Spike` exits only when a reproducible local command or script exists and
  the target note records the result.
- `Experimental` exits only when SDK/build/smoke coverage exists for a narrow
  capability set and docs name artifact metadata, CI or optional CI,
  capability support, and examples.
- `Supported` requires stable CLI, artifact metadata, CI, docs, and at least
  one shared scenario test.

**Experimental** does not mean "broken" — EVM has CI and Foundry smoke but lacks
target registry and portable IR integration.

## Current Target Status

| Target | Stage | Notes |
|---|---|---|
| [EVM](evm.md) | Experimental | Baseline through Yul, `solc`, Foundry smoke. |
| NEAR | Research | Reference in local Lean fork; not yet ported into this repo. |
| CosmWasm | Research | Strong Wasm spike candidate; reuses NEAR lessons. |
| Solana sBPF-linker | Research | Preferred Solana path (`solana-sbpf-linker` id). |
| Solana Zig fork | Research | Fallback reference from `solana-sdk-mono`. |
| Sui Move | Research | Source-generation; follows Aptos POC. |
| Aptos Move | Research | First Move POC target. |
| Psy DPN | Research | ZK circuit sourcegen target through generated `.psy` and Dargo. |

## Documents

- [EVM](evm.md)
- [Wasm family](wasm-family.md)
- [Solana sBPF](solana-sbf.md) — notes for target id `solana-sbpf-linker`
- [Move family](move-family.md)
- [Psy DPN ZK target](psy-dpn.md)
