# Capability Registry

Status: **Draft spec (Phase 1)**

Canonical capability ids for target profiles, artifact metadata, and compile-time
rejection. Semantic meanings align with the matrix in
[RFC 0002](rfcs/0002-target-implementation-design.md).

Legend: **Y** supported (planned or implemented), **P** partial/spike only,
**N** not supported, **—** not applicable.

## Relationship to target ids

- Target ids are recorded in `docs/decisions.md` and summarized by
  `docs/rfcs/0002-target-implementation-design.md`.
- This registry owns capability ids, not target lifecycle stages.
- Docs must not invent alternate ids for the same semantics.


## Core Capabilities

| Capability id | Portable meaning | EVM | NEAR | CosmWasm | Solana | Aptos | Sui | Psy DPN |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `storage.scalar` | Single persistent scalar | Y | Y | Y | Y | Y | Y | Y |
| `storage.map` | Key-value or mapping storage | Y | Y | Y | P | P | P | P |
| `caller.sender` | Transaction signer/caller | Y | Y | Y | Y | Y | Y | P |
| `value.native` | Native token attached to call | Y | Y | Y | Y | Y | Y | P |
| `events.emit` | Structured log/event output | Y | Y | Y | Y | Y | Y | P |
| `crosscall.invoke` | Call another contract/program | Y | Y | Y | Y | Y | Y | P |
| `env.block` | Block height/time/chain id reads | Y | P | P | P | P | P | P |
| `crypto.hash` | Host or library hashing | Y | Y | Y | Y | Y | Y | Y |
| `account.explicit` | Named account/object/resource binding | N | N | N | Y | Y | Y | P |
| `storage.pda` | Program-derived address state | N | N | N | Y | N | N | N |
| `crosscall.cpi` | Solana CPI with account metas | N | N | N | Y | N | N | N |
| `zk.circuit` | Compile entrypoints into target circuit definitions | N | N | N | N | N | N | Y |
| `zk.proof` | Target proof generation or verification flow | N | N | N | N | N | N | P |

## Id Naming Rules

- Format: `<domain>.<operation>` or `<domain>.<variant>` (lowercase, dot-separated).
- Domains: `storage`, `caller`, `value`, `events`, `crosscall`, `env`, `crypto`, `account`, `zk`.
- Artifact metadata lists the ids used by a build (see RFC 0002 artifact schema).
- Diagnostics must cite capability id and target id on rejection.

## Candidate Capabilities Not Yet Registered

These candidates are documented for target research only. Do not add them to
`ProofForge.Target.Capability` until a target profile and lowering rules are
accepted.

### Kaspa Toccata

See [Kaspa Toccata target](targets/kaspa-toccata.md).

| Candidate id | Portable meaning | Why it is separate |
|---|---|---|
| `storage.utxo` | State lives in covenant-controlled UTXOs or state commitments | Not account/object storage and not EVM-style slots |
| `covenant.lineage` | Successor outputs remain in an authorized covenant family | Needed for transaction/output validation, not ordinary storage |
| `tx.v1` | Target uses Kaspa transaction v1 semantics | Transaction projection and payload rules affect correctness |
| `tx.compute_budget` | Per-input script compute budget is explicit | Budgeting is part of transaction design, not just gas metering |
| `lane.user` | App operations can use user lanes | Needed for based-app ordering and proof anchoring |
| `zk.verify` | Script verifies an L1-supported proof | Different from compiling the target itself into a circuit |

`zk.circuit` remains reserved for targets whose primary artifact is a circuit or
circuit-oriented source package. Toccata may use proofs, but its base target is
a Kaspa covenant package.

## EVM Mapping (baseline)

| Capability id | EVM lowering |
|---|---|
| `storage.scalar` | `Storage.load` / `Storage.store` (sload/sstore) |
| `storage.map` | `Storage.mapLoad` / `Storage.mapStore` |
| `caller.sender` | `Env.sender` |
| `value.native` | `Env.value` |
| `events.emit` | `log0`–`log2` |
| `crosscall.invoke` | `call`, `staticcall`, `delegatecall`, `create`, `create2` |
| `env.block` | `Env.blockNumber`, etc. |

Implemented today via `ProofForge.Evm` / `Lean.Evm` — see
[targets/evm.md](targets/evm.md).

## Phase 1 Acceptance Criteria

- [ ] Every id in this table appears in `TargetProfile.capabilities` for at least
      one target.
- [ ] EVM Counter build lists `storage.scalar` (and others used) in artifact
      metadata.
- [ ] Attempting `storage.pda` on EVM fails with `capability unsupported` diagnostic.
- [ ] Registry stays in sync when RFC 0002 semantic matrix changes.

## Changelog

| Date | Change |
|---|---|
| 2026-06-30 | Initial registry; supersedes ad hoc ids in Chinese technical plan |
| 2026-06-30 | Added Psy DPN research column and ZK capability ids |
