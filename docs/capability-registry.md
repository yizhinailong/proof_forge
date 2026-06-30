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

| Capability id | Portable meaning | EVM | NEAR | CosmWasm | Solana | Aptos | Sui |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `storage.scalar` | Single persistent scalar | Y | Y | Y | Y | Y | Y |
| `storage.map` | Key-value or mapping storage | Y | Y | Y | P | P | P |
| `caller.sender` | Transaction signer/caller | Y | Y | Y | Y | Y | Y |
| `value.native` | Native token attached to call | Y | Y | Y | Y | Y | Y |
| `events.emit` | Structured log/event output | Y | Y | Y | Y | Y | Y |
| `crosscall.invoke` | Call another contract/program | Y | Y | Y | Y | Y | Y |
| `env.block` | Block height/time/chain id reads | Y | P | P | P | P | P |
| `crypto.hash` | Host or library hashing | Y | Y | Y | Y | Y | Y |
| `account.explicit` | Named account/object/resource binding | N | N | N | Y | Y | Y |
| `storage.pda` | Program-derived address state | N | N | N | Y | N | N |
| `crosscall.cpi` | Solana CPI with account metas | N | N | N | Y | N | N |

## Id Naming Rules

- Format: `<domain>.<operation>` or `<domain>.<variant>` (lowercase, dot-separated).
- Domains: `storage`, `caller`, `value`, `events`, `crosscall`, `env`, `crypto`, `account`.
- Artifact metadata lists the ids used by a build (see RFC 0002 artifact schema).
- Diagnostics must cite capability id and target id on rejection.

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
