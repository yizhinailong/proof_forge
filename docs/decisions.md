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
| D-011 | 2026-06-30 | Add **`psy-dpn`** as a Research target under ZK circuit source generation | Psy has no public Yul-like IR; first integration should generate `.psy` and call Dargo |
| D-012 | 2026-07-01 | Classify **`kaspa-toccata`** as a docs-first Research candidate, not a ZK circuit sourcegen target | Toccata is Kaspa L1 programmability through transaction v1, covenants, inline proof verification, and based-app settlement; code registry changes wait until UTXO/covenant capabilities are reviewed |
| D-013 | 2026-07-01 | Classify **`wasm-stellar-soroban`** as a docs-first Wasm-host Research candidate | Soroban emits Wasm but has Stellar-specific storage TTL, authorization, contract spec, deployment, and CLI semantics; registry changes wait until the first spike path is chosen |
| D-014 | 2026-07-01 | Classify **`wasm-icp-canister`** as a docs-first Wasm-host Research candidate | Internet Computer canisters emit Wasm but have Candid, principal identity, update/query call modes, cycles, stable memory, async inter-canister calls, and lifecycle semantics; registry changes wait until a canister spike path is chosen |
| D-015 | 2026-07-01 | Classify **`ton-tvm`** as a docs-first TVM/Tolk sourcegen Research candidate | TON contracts target TVM with cells, TL-B serialization, message handlers, get methods, action lists, account lifecycle, and TVM gas semantics; registry changes wait until a sourcegen spike path is chosen |
| D-016 | 2026-07-01 | Classify **`bch-cashscript`** as a docs-first UTXO script/covenant sourcegen Research candidate | Bitcoin Cash contracts through CashScript lock and spend UTXOs with BCH Script, transaction introspection, CashTokens, and SDK transaction-builder semantics; registry changes wait until a CashScript spike path is chosen |
| D-017 | 2026-07-01 | Classify **`algorand-avm`** as a docs-first AVM/TEAL sourcegen Research candidate | Algorand contracts target AVM approval/clear-state or LogicSig programs with ARC-4 ABI, global/local/box storage, resource references, atomic transaction groups, inner transactions, and AVM budget semantics; registry changes wait until an Algorand package spike path is chosen |
| D-018 | 2026-07-01 | Classify **`cardano-plutus-aiken`** as a docs-first eUTXO validator sourcegen Research candidate | Cardano contracts validate eUTXO spends through datum, redeemer, script context, Plutus/UPLC artifacts, execution units, Plutus blueprints, and off-chain transaction-building semantics; registry changes wait until an Aiken sourcegen spike path is chosen |
| D-019 | 2026-07-01 | Classify **`tezos-michelson-ligo`** as a docs-first Michelson/LIGO sourcegen Research candidate | Tezos contracts target Michelson with typed storage, parameters, entrypoints, views/events, operation lists, `big_map`, tickets, Sapling, gas, and storage-burn semantics; registry changes wait until a LIGO sourcegen spike path is chosen |
| D-020 | 2026-07-01 | Classify **`starknet-cairo`** as a docs-first Cairo/Sierra/CASM sourcegen Research candidate | Starknet contracts compile through Cairo into Sierra/CASM with ABI, class hashes, declaration/deployment metadata, Starknet storage/events, account abstraction, syscalls, and L1/L2 messaging semantics; registry changes wait until a Cairo package spike path is chosen |
| D-021 | 2026-07-01 | Classify **`bitcoin-script-miniscript`** as a docs-first Bitcoin base-layer spending-policy Research candidate | Bitcoin Script is intentionally limited to UTXO locking/unlocking policy with signatures, hash locks, timelocks, descriptors, Miniscript, Taproot/Tapscript, PSBT flows, and standardness/fee constraints; registry changes wait until a Miniscript/descriptor spike path is chosen |
| D-022 | 2026-07-01 | Classify **`zcash-shielded`** as a docs-first privacy UTXO/ZK payment Research candidate | Zcash is Bitcoin-derived but shielded support depends on Sapling/Orchard notes, nullifiers, anchors, value-balance constraints, viewing/disclosure policy, and protocol-defined ZK proofs; registry changes wait until shielded-note capabilities and a proving/validation boundary are reviewed |
| D-023 | 2026-07-01 | Classify **`aleo-leo`** as a docs-first Aleo ZK application sourcegen Research candidate | Aleo programs combine private off-chain proof execution, public on-chain finalization, encrypted records, public mappings/storage, Aleo Instructions, Aleo VM bytecode, ABI, prover/verifier artifacts, and execute/deploy transactions; registry changes wait until the proof/finalization split is reviewed |

## Target Family Classification

| Family | Targets | Backend pattern |
|---|---|---|
| Direct compiler | `evm` | Lean → LCNF → Yul → solc |
| Wasm host | `wasm-near`, `wasm-cosmwasm`, `wasm-stellar-soroban` (candidate, docs only), `wasm-icp-canister` (candidate, docs only) | Lean → EmitZig → Wasm + chain host bridge, or first-pass target-native source package when that validates semantics faster |
| Binary toolchain | `solana-sbpf-linker`, `solana-zig-fork` | Lean → EmitZig → bitcode → sbpf-linker |
| Source codegen | `move-aptos`, `move-sui` | Portable IR → Move package source |
| AVM sourcegen research | `algorand-avm` (candidate, docs only) | Portable IR → Algorand Python, Algorand TypeScript, or TEAL package → AVM approval/clear-state or LogicSig bytecode + ARC-4/app metadata |
| eUTXO validator sourcegen research | `cardano-plutus-aiken` (candidate, docs only) | Portable IR → Aiken package → UPLC/Plutus validator artifacts + Plutus blueprint + transaction scenario metadata |
| Michelson sourcegen research | `tezos-michelson-ligo` (candidate, docs only) | Portable IR → LIGO package → Michelson contract + parameter/storage schema + operation/view/event manifests |
| Cairo sourcegen research | `starknet-cairo` (candidate, docs only) | Portable IR → Cairo/Scarb package → Sierra/CASM artifacts + ABI/class-hash/deployment metadata |
| Aleo ZK app sourcegen research | `aleo-leo` (candidate, docs only) | Portable IR → Leo package → Aleo Instructions → Aleo VM bytecode + ABI/prover/verifier artifacts + execute/deploy metadata |
| TVM sourcegen research | `ton-tvm` (candidate, docs only) | Portable IR → Tolk or lower-level TON source → TVM/BOC artifact + TL-B/message manifests |
| Bitcoin script policy research | `bitcoin-script-miniscript` (candidate, docs only) | Portable IR → policy/Miniscript/descriptor package → Script/Tapscript output + PSBT/regtest validation metadata |
| Privacy UTXO ZK payment research | `zcash-shielded` (candidate, docs only) | Portable IR → shielded transaction/proving manifest → Zcash transaction with Sapling/Orchard proof bundle + zcashd/library validation metadata |
| UTXO script sourcegen research | `bch-cashscript` (candidate, docs only) | Portable IR → CashScript `.cash` source → cashc artifact JSON + BCH transaction-builder validation |
| ZK circuit sourcegen | `psy-dpn` | Portable IR → `.psy` package → Dargo → DPN circuit JSON |
| UTXO covenant research | `kaspa-toccata` (candidate, docs only) | Portable IR → covenant/Silverscript package + transaction v1 manifest + optional proof settlement metadata |

## Roadmap Summary

```text
Phase 0: EVM baseline (done)
Phase 1: Target registry + portable IR + artifact metadata + capability errors
Phase 2: Parallel spikes — CosmWasm (wasm-cosmwasm) + Solana (solana-sbpf-linker)
Phase 3: Move sourcegen — Aptos POC first, then Sui
Phase 3.5: Psy DPN sourcegen research spike
Research lane: Kaspa Toccata covenant/based-app target note before registry changes
Research lane: Stellar Soroban Wasm-host target note before registry changes
Research lane: Internet Computer canister target note before registry changes
Research lane: Algorand AVM/TEAL target note before registry changes
Research lane: Cardano Plutus/Aiken eUTXO target note before registry changes
Research lane: Tezos Michelson/LIGO target note before registry changes
Research lane: Starknet Cairo target note before registry changes
Research lane: Aleo Leo ZK app target note before registry changes
Research lane: TON TVM/Tolk target note before registry changes
Research lane: Bitcoin Script/Miniscript spending-policy target note before registry changes
Research lane: Zcash shielded privacy payment target note before registry changes
Research lane: Bitcoin Cash CashScript target note before registry changes
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
| Stellar/Soroban target candidate | [targets/stellar-soroban.md](targets/stellar-soroban.md) |
| Internet Computer target candidate | [targets/internet-computer.md](targets/internet-computer.md) |
| Algorand AVM target candidate | [targets/algorand-avm.md](targets/algorand-avm.md) |
| Solana instruction manifest | [targets/solana-sbf.md](targets/solana-sbf.md) |
| Cardano Plutus/Aiken target candidate | [targets/cardano-plutus-aiken.md](targets/cardano-plutus-aiken.md) |
| Tezos Michelson/LIGO target candidate | [targets/tezos-michelson-ligo.md](targets/tezos-michelson-ligo.md) |
| Starknet Cairo target candidate | [targets/starknet-cairo.md](targets/starknet-cairo.md) |
| Aleo Leo target candidate | [targets/aleo-leo.md](targets/aleo-leo.md) |
| TON TVM target candidate | [targets/ton-tvm.md](targets/ton-tvm.md) |
| Bitcoin Script/Miniscript target candidate | [targets/bitcoin-script-miniscript.md](targets/bitcoin-script-miniscript.md) |
| Zcash Shielded target candidate | [targets/zcash-shielded.md](targets/zcash-shielded.md) |
| Bitcoin Cash CashScript target candidate | [targets/bitcoin-cash-cashscript.md](targets/bitcoin-cash-cashscript.md) |
| Psy/DPN ZK target | [targets/psy-dpn.md](targets/psy-dpn.md) |
| Kaspa/Toccata target candidate | [targets/kaspa-toccata.md](targets/kaspa-toccata.md) |

## Superseded Positions

These earlier doc positions are no longer authoritative:

- RFC 0001 Phase 2 = Solana only, Phase 3 = Wasm only — replaced by parallel Phase 2 spikes (D-003).
- Milestone 3 = Solana as the single second target — replaced by parallel CosmWasm + Solana (D-003).
- CLI id `solana-sbf` — use `solana-sbpf-linker` (D-004).
- Move POC generates both Sui and Aptos packages at once — Aptos first (D-007).
