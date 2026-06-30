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
| `solana-sbpf-linker` | account data field | Mollusk or `solana-test-validator` |
| `move-aptos` | `Counter` resource under signer account | `aptos move test` |
| `psy-dpn` | Psy storage field, likely `Felt`/`U32` in v0 | `dargo compile` + in-memory smoke |

Target-specific account schemas and manifests are adapter concerns — not hidden
inside portable Lean logic. See [solana-sbf.md](targets/solana-sbf.md) for
instruction manifest format.

## Phase 2 Acceptance Criteria

Phase 2 is complete when **both** parallel spikes pass independently:

### CosmWasm (`wasm-cosmwasm`)

- [ ] Counter Wasm exports required CosmWasm entrypoints.
- [ ] `cosmwasm-check` passes.
- [ ] instantiate → increment → query returns expected count.
- [ ] Artifact metadata records `target: wasm-cosmwasm` and capabilities used.

### Solana (`solana-sbpf-linker`)

- [ ] Minimal `entrypoint.bc` from stock Zig.
- [ ] `sbpf-linker` produces loadable `.so`.
- [ ] initialize → increment → read counter in Mollusk or validator.
- [ ] Instruction manifest documents account layout.

### Joint (after both spikes)

- [ ] Same portable IR module lowers to EVM + at least one non-EVM target.
- [ ] Document lists capabilities supported per target for this scenario.

## ZK Target Research Criteria

`psy-dpn` is not part of Phase 2 exit criteria, but it should reuse the Counter
scenario once the sourcegen spike starts.

- [ ] Counter IR can be represented in a Psy-compatible scalar type.
- [ ] Generated `.psy` package compiles with `dargo compile`.
- [ ] DPN circuit JSON is emitted and recorded in artifact metadata.
- [ ] Smoke path is documented as `dargo execute`, `dargo test`, `psy-wasm`, or
      local Psy node/prover tooling.

## Example Locations

| Target | Path | Status |
|---|---|---|
| EVM | `Examples/Evm/Contracts/Counter.lean` | **In repo** |
| CosmWasm | `Examples/CosmWasm/Counter.lean` | Planned, not in repo |
| Solana | `Examples/Solana/Counter.lean` | Planned, not in repo |
| Aptos | `Examples/Move/Aptos/Counter/` | Planned, not in repo |
| Psy DPN | `Examples/Psy/Counter/` | Planned, not in repo |

## Out of Scope for v0

- PDA derivation
- CPI / submessages
- Access control / ownership
- Overflow beyond U64 (targets may cap lower)
