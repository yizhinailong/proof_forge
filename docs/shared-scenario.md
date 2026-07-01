# Shared Contract Scenario: Counter

Status: **Draft spec (Phase 1–2)**

The Counter scenario is the first cross-target acceptance test. It exercises
portable scalar state without chain-specific account models in the Lean business
core.

Related: [Portable IR](portable-ir.md),
[Capability registry](capability-registry.md),
[Decisions](decisions.md).

## Scenario Definition

A contract maintains a single unsigned 64-bit counter.

| Operation | Behavior |
|---|---|
| `initialize` | Set counter to `0` |
| `increment` | Add `1` to counter |
| `get` | Return current counter value |

No native token transfer, no cross-contract calls, no events required for v0
(optional `events.emit` in v1).

## Required Capabilities

| Capability id | Used by |
|---|---|
| `storage.scalar` | all operations |
| `caller.sender` | optional access control in v1 |

## Target-Specific Adaptation

Each target adapter maps the same logical scenario to native mechanics:

| Target | State representation | Smoke test |
|---|---|---|
| `evm` | contract storage slot | Foundry + `vm.etch` |
| `wasm-cosmwasm` | string-key `"count"` in host KV | `cosmwasm-check` + instantiate/execute/query |
| `solana-sbpf-asm` | account data field | `sbpf test` (Mollusk) or `solana-test-validator` |
| `move-aptos` | `Counter` resource under signer account | `aptos move test` |
| `psy-dpn` | Psy storage field, likely `Felt`/`U32` in v0 | `dargo compile` + in-memory smoke |

Target-specific account schemas and manifests are adapter concerns — not hidden
inside portable Lean logic. See [solana-sbpf-asm.md](targets/solana-sbpf-asm.md)
for instruction manifest format and the direct-assembly route (D-026).

## Phase 2 Acceptance Criteria

Phase 2 is complete when **both** parallel spikes pass independently:

### CosmWasm (`wasm-cosmwasm`)

- [ ] Counter Wasm exports required CosmWasm entrypoints.
- [ ] `cosmwasm-check` passes.
- [ ] instantiate → increment → query returns expected count.
- [ ] Artifact metadata records `target: wasm-cosmwasm` and capabilities used.

### Solana (`solana-sbpf-asm`)

- [ ] `--emit-sbpf-asm` produces valid `.s` accepted by `sbpf build`.
- [ ] `sbpf build` produces a loadable eBPF ELF (`.so`).
- [ ] initialize → increment → read counter in `sbpf test` (Mollusk) or
      `solana-test-validator`.
- [ ] Instruction manifest (`manifest.toml`) documents account layout.
- [ ] Capability checker rejects unsupported capabilities with target-id diagnostic.

### Joint (after both spikes)

- [ ] Same portable IR module lowers to EVM + at least one non-EVM target.
- [ ] Document lists capabilities supported per target for this scenario.

## ZK Target Experimental Criteria

`psy-dpn` is not part of Phase 2 exit criteria, but it now reuses the Counter
scenario through generated `.psy` source and Dargo validation.

- [x] Counter IR can be represented in a Psy-compatible scalar type.
- [x] Generated `.psy` package compiles with `dargo compile`.
- [x] DPN circuit JSON is emitted and recorded in artifact metadata.
- [x] Smoke path is documented and runnable through `dargo test`,
      `dargo compile`, `dargo execute`, `dargo generate-abi`, and artifact
      metadata validation.

## Example Locations

| Target | Path | Status |
|---|---|---|
| EVM | `Examples/Evm/Contracts/Counter.lean` | **In repo** |
| CosmWasm | `Examples/CosmWasm/Counter.lean` | Planned, not in repo |
| Solana | `Examples/Solana/Counter.lean` + manifest | Planned, not in repo (Workstream 7) |
| Aptos | `Examples/Move/Aptos/Counter/` | Planned, not in repo |
| Psy DPN | `Examples/Psy/*.golden.psy`, `scripts/psy/*-smoke.sh` | **In repo** |

## Out of Scope for v0

- PDA derivation
- CPI / submessages
- Access control / ownership
- Overflow beyond U64 (targets may cap lower)
