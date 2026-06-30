# ProofForge Design Decisions

This document records architecture decisions that are settled enough to guide
implementation. Open questions stay in RFCs and target notes until resolved here.

See also: [Review checklist (English)](review-checklist.md),
[Review checklist (中文)](zh/review-checklist.md).

## Decision Log

| ID | Date | Decision | Rationale |
|---|---|---|---|
| D-001 | 2026-06-30 | RFC 0001 and RFC 0002 are **Accepted** as the engineering direction | Detailed target and backlog docs exist; Draft status was misleading |
| D-002 | 2026-06-30 | Phase 1 (target registry + portable IR + artifact metadata) must complete before non-EVM spikes | Spikes need capability checks and shared scenario definitions |
| D-003 | 2026-06-30 | CosmWasm and Solana spikes run **in parallel** after Phase 1 | No fixed order between the two; both validate different backend families |
| D-004 | 2026-06-30 | Canonical Solana target id is **`solana-sbpf-linker`** | Stock Zig + sbpf-linker fits platform tooling; `solana-sbf` is a filename alias only |
| D-005 | 2026-06-30 | Keep **`solana-zig-fork`** as fallback/reference track | Mature SDK reference from solana-sdk-mono; not the primary product path |
| D-006 | 2026-06-30 | NEAR is the Wasm-host **reference**; CosmWasm is the first new Wasm spike in-repo | Fork lessons inform structure; CosmWasm validates host adapter generality |
| D-007 | 2026-06-30 | Move POC starts with **Aptos only**; Sui follows | Aptos account resources are simpler; Sui object model tests abstraction harder |
| D-008 | 2026-06-30 | Move targets use **source generation**, not Lean runtime on MoveVM | Proofs stay in Lean; Move carries executable logic only |
| D-009 | 2026-06-30 | **`wasm-polkadot` / ink!** stays research-only | Not in the target registry until a spike is scheduled |
| D-010 | 2026-06-30 | Cloud platform waits until **two or more targets** reach Experimental stage | Avoid building a UI shell before local backends are real |

## Target Family Classification

| Family | Targets | Backend pattern |
|---|---|---|
| Direct compiler | `evm` | Lean → LCNF → Yul → solc |
| Wasm host | `wasm-near`, `wasm-cosmwasm` | Lean → EmitZig → Wasm + chain host bridge |
| Binary toolchain | `solana-sbpf-linker`, `solana-zig-fork` | Lean → EmitZig → bitcode → sbpf-linker |
| Source codegen | `move-aptos`, `move-sui` | Portable IR → Move package source |

## Roadmap Summary

```text
Phase 0: EVM baseline (done)
Phase 1: Target registry + portable IR + artifact metadata + capability errors
Phase 2: Parallel spikes — CosmWasm (wasm-cosmwasm) + Solana (solana-sbpf-linker)
Phase 3: Move sourcegen — Aptos POC first, then Sui
Phase 4: Cross-target shared scenario hardening
Phase 5: Cloud platform
```

Detailed tasks: [Implementation backlog](implementation-backlog.md).

## Authoritative Specs

| Topic | Document |
|---|---|
| Portable Contract IR | [portable-ir.md](portable-ir.md) |
| Capability IDs | [capability-registry.md](capability-registry.md) |
| Counter shared scenario | [shared-scenario.md](shared-scenario.md) |
| Target engineering shape | [RFC 0002](rfcs/0002-target-implementation-design.md) |
| CosmWasm SDK spike sketch | [targets/wasm-family.md](targets/wasm-family.md) |
| Solana instruction manifest | [targets/solana-sbf.md](targets/solana-sbf.md) |

## Superseded Positions

These earlier doc positions are no longer authoritative:

- RFC 0001 Phase 2 = Solana only, Phase 3 = Wasm only — replaced by parallel Phase 2 spikes (D-003).
- Milestone 3 = Solana as the single second target — replaced by parallel CosmWasm + Solana (D-003).
- CLI id `solana-sbf` — use `solana-sbpf-linker` (D-004).
- Move POC generates both Sui and Aptos packages at once — Aptos first (D-007).
