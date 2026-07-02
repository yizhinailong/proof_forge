# ProofForge

Lean-first multi-chain smart contract platform.

ProofForge's goal is one verified Lean contract codebase that can be compiled,
tested, and deployed across multiple blockchain target families. Contracts are
written against a chain-neutral Contract Intent API; the compiler lowers them
to a portable IR, routes capabilities per target, and emits chain-native
artifacts. Unsupported target capabilities are rejected at compile time
instead of silently changing semantics.

Start here:

- [docs/INDEX.md](docs/INDEX.md) — full documentation map.
- [RFC 0001](docs/rfcs/0001-multichain-platform.md) — multi-chain architecture
  and roadmap; [RFC 0002](docs/rfcs/0002-target-implementation-design.md) —
  target implementation design.
- [Design decisions](docs/decisions.md) — settled choices (D-001…D-033).
- [Formal verification roadmap](docs/formal-verification.md) — existing proof
  anchors and staged theorem targets.

中文文档：

- [中文文档索引](docs/zh/README.md)
- [架构评审（2026-07）：统一 SDK 输入与分支收敛](docs/zh/architecture-review-2026-07.md)
- [多链愿景可行性分析](docs/zh/feasibility-analysis.md)

## Backend Status

All backends live on `main` (chains are directories and target ids, not
branches). Lifecycle stages follow [docs/targets/README.md](docs/targets/README.md).

| Target id | Pipeline | Stage | Local validation |
|---|---|---|---|
| `evm` | Lean / portable IR → Yul → `solc` → bytecode | Baseline (mature) | golden Yul, diagnostics, Foundry runtime smoke, Anvil deploy |
| `solana-sbpf-asm` | portable IR → sBPF assembly → `sbpf` → ELF | Experimental | Mollusk tests, Surfpool/Web3.js live smokes, Pinocchio equivalence gates |
| `wasm-near` | portable IR → `EmitWat` (Wasm AST → WAT) → `wat2wasm` | Experimental | 45-case diagnostics, IR coverage manifests, formal trace obligations, offline host smoke |
| `psy-dpn` | portable IR → `.psy` → Dargo → DPN circuit JSON | Experimental (restricted subset) | golden sources, diagnostics, `dargo` execute smokes |
| `aleo-leo` | portable IR → Leo package → `leo build`/`leo test` | Research spike | Counter/PureMath golden fixtures and smokes |
| `wasm-cloudflare-workers` | portable IR → TypeScript Worker | Research (off-chain host, D-033) | `tsc` type-check, `wrangler` dry-run |

The multi-chain Token SDK (`TokenSpec`, [RFC 0006](docs/rfcs/0006-multichain-token-sdk.md))
routes one token intent to ERC-20 bytecode on EVM or SPL Token / Token-2022
deployment plans on Solana.

## Getting Started

Install `just` from [casey/just](https://github.com/casey/just); the root
`justfile` is the developer-facing command catalog and CI entrypoint.

```sh
just --list        # all recipes
just build         # lake build
just check         # fast static gates (Lean + EVM + Psy)
just evm-all       # full EVM gates: examples, Foundry smoke, Anvil deploy
just ci            # the full CI sequence locally
```

Build directly with Lake:

```sh
lake build
```

Compile the EVM Counter example to runtime bytecode:

```sh
lake env proof-forge --evm-bytecode --root . --module contract \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean
```

Emit artifacts for other targets from built-in portable IR fixtures:

```sh
lake env proof-forge --emit-counter-emitwat -o build/wasm-near   # NEAR Wasm
lake env proof-forge --solana-elf -o build/solana/counter.so     # Solana ELF
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
lake env proof-forge --emit-counter-ir-leo -o build/aleo         # Aleo Leo
lake env proof-forge --emit-counter-ir-ts -o build/ts/Counter.ts # CF Workers
```

The complete, per-target list of runnable validation commands and their tool
prerequisites (Foundry, `solc`, `sbpf`, `wat2wasm`, `dargo`, `leo`,
`wrangler`, …) lives in [docs/validation-gates.md](docs/validation-gates.md).
Cloud/agent environment notes are in [AGENTS.md](AGENTS.md).

## Architecture

```mermaid
flowchart TB
  subgraph authoring ["Authoring (user-facing, chain-neutral)"]
    SDK["Lean SDK<br/>contract_source / Contract Intent API"]
    TOK["Token SDK<br/>TokenSpec"]
    LEARN[".learn parser<br/>(frozen compatibility)"]
  end

  subgraph core ["Compiler-owned core"]
    SPEC["ContractSpec"]
    IR["Portable IR<br/>+ AllocatorConfig + ownership rules"]
    SEM["IR semantics + formal anchors<br/>(FV roadmap)"]
  end

  subgraph routing ["Target routing (--target)"]
    REG["Target registry<br/>profiles + allocator bindings"]
    CAP["Capability check<br/>reject unsupported intents"]
    EXT["Target Extension SDKs<br/>Solana accounts/PDA/CPI, ..."]
  end

  subgraph backends ["Backends"]
    EVM["EVM<br/>Plan → Yul → solc"]
    SOL["Solana<br/>sBPF asm → ELF"]
    NEAR["NEAR<br/>EmitWat → WAT → wasm"]
    PSY["Psy/DPN<br/>.psy → Dargo"]
    ALEO["Aleo<br/>Leo package"]
    CFW["CF Workers<br/>TypeScript"]
  end

  subgraph artifacts ["Artifacts + validation"]
    ART["bytecode/ELF/wasm/circuit + ABI/IDL<br/>artifact + deploy manifests + TS clients"]
    GATES["Gates: Lean tests · testkit (planned, RFC 0007)<br/>Foundry · Mollusk/Surfpool · offline host · dargo/leo"]
  end

  SDK --> SPEC
  TOK --> SPEC
  LEARN --> SPEC
  SPEC --> IR
  IR --- SEM
  IR --> CAP
  REG --> CAP
  EXT --> CAP
  CAP --> EVM & SOL & NEAR & PSY & ALEO & CFW
  EVM & SOL & NEAR & PSY & ALEO & CFW --> ART
  ART --> GATES
```

- **Contract Intent API** — the default SDK surface: state, entrypoints,
  events, caller/value access, checked arithmetic, assertions, and proofs,
  without importing a destination-chain module.
- **Target Extension SDKs** — explicit chain-native semantics when a contract
  needs them (Solana accounts/PDA/CPI, allocator selection, …). Extensions
  lower through capability ids and target metadata, never by adding
  chain-only constructors to the portable IR (D-027).
- **Target adapters** — ABI, packaging, test-runner, and deployment logic per
  chain family; `--target` selects the adapter, and unsupported intents are
  rejected before artifact generation (D-028).

See [docs/authoring-model.md](docs/authoring-model.md) for the authoring
layers (the legacy `.learn` parser is a frozen compatibility surface, not a
second product language) and [docs/portable-ir.md](docs/portable-ir.md) for
the IR spec.

## Development Docs

- [Development standards](docs/development-standards.md)
- [Validation gates](docs/validation-gates.md)
- [Implementation backlog](docs/implementation-backlog.md) — Workstream 24
  (post-consolidation follow-ups) and Workstream 25 (formal verification)
  are the current priority.
- [Capability registry](docs/capability-registry.md)
- [Shared scenario: Counter](docs/shared-scenario.md) — the cross-target
  acceptance test; the current phase goal is passing it on `evm`,
  `solana-sbpf-asm`, and `wasm-near`.
- Target notes: [docs/targets/](docs/targets/README.md)

## Module Naming

- **Lake module:** `ProofForge.Evm` (import in contract files).
- **Lean namespace:** `Lean.Evm` (use via `open Lean.Evm` in examples).

This split comes from the Lean fork migration. The rename to a uniform
`ProofForge.*` namespace is tracked in the backlog (Workstream 24), because
`Lean.Evm` shadows the Lean compiler's own `Lean` namespace.

## Roadmap

```text
Phase 0: EVM baseline                      (done)
Phase 1: target registry + portable IR     (done)
Phase 2+: parallel backend spikes          (Solana, NEAR, Psy on main;
                                            Aleo, CF Workers research)
Current:  shared-scenario parity on evm + solana-sbpf-asm + wasm-near,
          consolidation follow-ups (Workstream 24),
          formal verification roadmap (Workstream 25)
Later:    Move family (Aptos first), cloud platform (after two+ targets
          reach Experimental with shared-scenario parity; D-010)
```

Canonical target ids and the full decision log: [docs/decisions.md](docs/decisions.md).
The filename `docs/targets/solana-sbf.md` is a historical alias for the
Solana target notes; the canonical route is `solana-sbpf-asm` (D-026).
