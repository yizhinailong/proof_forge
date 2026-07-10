# ProofForge vs Native Benchmark Matrix

Status: **Active (B1.0 skeleton)**
Plan: [post-review execution plan](superpowers/plans/2026-07-10-post-review-execution.md) wave **B1**

## Why

ProofForge claims one portable business path can lower to multiple chains.
Correctness gates (`just product`, testkit) are necessary but not sufficient:
we also need **behavior parity and native cost comparison** against hand-written
contracts on each chain.

This document is the SOT for that matrix. Results (when generated) live under
`build/benchmarks/` and may be snapshotted into `docs/generated/`.

## Non-goals

- A single cross-chain “score” that averages gas + CU + fuel + circuit ops.
- Using Anchor-heavy Solana programs as the “native efficient” baseline without
  labeling them (prefer Pinocchio-class / minimal sBPF for efficiency claims).
- Treating Psy/Aleo metrics as comparable to EVM gas.

## Implementations

| Tag | Meaning |
|-----|---------|
| `proofforge` | Artifact from `proof-forge` + target toolchain |
| `native` | Hand-written reference checked into `benchmarks/native/` (B1.2+) or pinned external source |

## Cost dimensions (native only)

| Target | Behavior oracle | Cost fields | Artifact size |
|--------|-----------------|-------------|---------------|
| `evm` | Foundry / revm / Anvil | `evm_gas` | runtime bytecode bytes |
| `solana-sbpf-asm` | Mollusk / Surfpool | `solana_cu` | ELF bytes |
| `wasm-near` | offline-host / sandbox | `wasmtime_fuel_*` and/or `near_gas` when real | Wasm bytes |
| `psy-dpn` (optional) | `dargo execute` | `dpn_definition_count`, `dpn_op_count`, execute wall time | DPN JSON bytes |
| `aleo-leo` (optional) | `leo` / snarkVM | constraint/proof metrics when available | `.aleo` / package bytes |

## Scenario set

| Id | PF source | Native references | Priority |
|----|-----------|-------------------|----------|
| `bm-counter` | `Examples/Product/Counter.lean` | Solidity / Pinocchio-or-Rust / near-sdk Counter | P0 first |
| `bm-value-vault` | `Examples/Product/ValueVault.lean` | hand-written triad vaults | P1 |
| `bm-ownable` | `Examples/Product/Ownable.lean` | OZ-style / Anchor-like / NEAR owner | P1 |
| `bm-ft-transfer` | Token / FT product path | ERC-20 / SPL / NEP-141 | P2 after N1 |
| `bm-remote-call` | `Examples/Product/RemoteCall.lean` | CALL / CPI / Promise peers | P2 |
| `bm-psy-counter` | IR Counter → psy-dpn | hand `.psy` Counter | Experimental |
| `bm-aleo-counter` | IR Counter → aleo | hand Leo Counter | Experimental |

## Result schema (B1.1 draft)

Each run emits one JSON object per (scenario, target, implementation):

```json
{
  "schemaVersion": 1,
  "scenario": "bm-counter",
  "target": "evm",
  "implementation": "proofforge",
  "commit": "<git sha>",
  "toolVersions": {
    "proof-forge": "...",
    "solc": "...",
    "sbpf": "...",
    "dargo": "..."
  },
  "behavior": {
    "ok": true,
    "steps": [
      { "name": "initialize", "return": null },
      { "name": "increment", "return": null },
      { "name": "get", "return": "1" }
    ]
  },
  "costs": {
    "evm_gas": { "initialize": 0, "increment": 0, "get": 0 }
  },
  "artifactBytes": 0,
  "notes": ""
}
```

Validation rules:

1. `implementation` is only `proofforge` or `native`.
2. `costs` keys must be from the target’s allowed cost dimensions.
3. Behavior steps for the same scenario must match across implementations on
   the **same** target before cost ratios are reported.
4. Missing tools → skip row with `behavior.ok = false` and honest `notes`, never
   fake zeros as success.

## Tolerances (initial)

- Behavior: exact match on returns / storage / events for the scenario script.
- Cost regression band (optional CI later): start at **±15%** vs the pinned
  native baseline for the same target; tighten after the corpus stabilizes.
- Solana native baseline policy: document whether native is Pinocchio-class or
  Anchor-class in the row `notes`.

## Layout (to create in B1.2+)

```text
benchmarks/
  README.md                 # points here
  native/
    evm/Counter.sol
    solana/counter/         # minimal program
    near/counter/           # near-sdk or equivalent
  scripts/
    run-counter.sh          # just benchmark-counter
  schema/
    result.schema.json
```

## Commands (target state)

```sh
just benchmark-counter   # B1.3/B1.4 — not implemented yet
# → build/benchmarks/counter-*.json
# → optional docs/generated/benchmark-counter.md
```

Until those recipes exist, reuse seeds:

```sh
just testkit             # Counter/ValueVault budgets (not full native matrix)
just product             # multi-target compile matrix
```

## Wave checklist

| Task | Status |
|------|--------|
| B1.0 Spec + layout (this doc) | **done (skeleton)** |
| B1.1 Schema checker | pending |
| B1.2 Native Counter corpus | pending |
| B1.3 PF Counter runner | pending |
| B1.4 Native Counter runner | pending |
| B1.5 Behavior gate | pending |
| B1.6 Cost table snapshot | pending |
| B1.7 Expand scenarios | pending |
| B1.8 ZK optional rows | pending |

## Related

- [shared-scenario.md](shared-scenario.md) — Counter/ValueVault budgets
- [validation-gates.md](validation-gates.md) — runnable gates
- [targets/psy-dpn.md](targets/psy-dpn.md) — DPN bytecode lower boundary
- [targets/aleo-leo.md](targets/aleo-leo.md) — Aleo Instructions path
