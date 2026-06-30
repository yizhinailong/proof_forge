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
| `storage.array` | Fixed-size indexed storage array | N | N | N | N | N | N | P |
| `caller.sender` | Transaction signer/caller | Y | Y | Y | Y | Y | Y | P |
| `value.native` | Native token attached to call | Y | Y | Y | Y | Y | Y | P |
| `events.emit` | Structured log/event output | Y | Y | Y | Y | Y | Y | P |
| `crosscall.invoke` | Call another contract/program | Y | Y | Y | Y | Y | Y | P |
| `env.block` | Block height/time/chain id reads | Y | P | P | P | P | P | P |
| `control.bounded_loop` | Static bounded loops that can be flattened or unrolled by the target | N | N | N | N | N | N | P |
| `data.fixed_array` | Fixed-size array value type, literals, and index expressions | N | N | N | N | N | N | P |
| `crypto.hash` | Host or library hashing | Y | Y | Y | Y | Y | Y | Y |
| `assertions.check` | Runtime or circuit assertions emitted from portable IR statements | N | N | N | N | N | N | P |
| `account.explicit` | Named account/object/resource binding | N | N | N | Y | Y | Y | P |
| `storage.pda` | Program-derived address state | N | N | N | Y | N | N | N |
| `crosscall.cpi` | Solana CPI with account metas | N | N | N | Y | N | N | N |
| `zk.circuit` | Compile entrypoints into target circuit definitions | N | N | N | N | N | N | Y |
| `zk.proof` | Target proof generation or verification flow | N | N | N | N | N | N | P |

## Id Naming Rules

- Format: `<domain>.<operation>` or `<domain>.<variant>` (lowercase, dot-separated).
- Domains: `storage`, `caller`, `value`, `events`, `crosscall`, `env`, `control`, `data`, `crypto`, `assertions`, `account`, `zk`.
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

### Stellar Soroban

See [Stellar Soroban target](targets/stellar-soroban.md).

Most Soroban behavior can start from the existing Wasm-host capability set, but
several target semantics are not covered by the current registry.

| Candidate id | Portable meaning | Why it is separate |
|---|---|---|
| `auth.require` | A contract requires an address-level authorization payload | Stronger and more structured than reading a caller/sender |
| `auth.account_contract` | A contract account validates authorization through target-native account logic | Needed for Soroban account-contract flows |
| `storage.ttl` | State entries have TTL extension, archival, and restoration behavior | Not captured by scalar/map storage alone |
| `artifact.contract_spec` | Build output includes contract interface/spec metadata used by tooling and bindings | Artifact-level requirement, not runtime storage |
| `asset.stellar` | Contract uses Stellar Asset Contract or token-interface integration | Native asset surface differs from generic `value.native` |

### Internet Computer

See [Internet Computer target](targets/internet-computer.md).

ICP canisters overlap with the Wasm-host family, but several canister semantics
need explicit representation before a target profile is added.

| Candidate id | Portable meaning | Why it is separate |
|---|---|---|
| `abi.candid` | Build emits and validates a Candid service interface | Public ABI is not only exported Wasm symbols |
| `canister.method_mode` | Entry points distinguish update, query, and composite query methods | Call mode affects persistence, consensus, and call restrictions |
| `storage.stable_memory` | State uses stable memory or stable structures across upgrades | Not captured by scalar/map storage alone |
| `storage.orthogonal_persistence` | State follows Motoko-style orthogonal persistence semantics | Different from explicit key-value stores |
| `principal.id` | Caller/canister/user identity is a Principal | Not an EVM address or generic account id |
| `cycles.manage` | Target can inspect, accept, send, or account for cycles | Cycles are resource accounting, not ordinary `value.native` |
| `crosscall.async` | Cross-canister calls are asynchronous message flows | Different from synchronous contract calls |
| `canister.lifecycle` | Target supports install, upgrade, stop/start, and lifecycle hooks | Lifecycle is part of deployment and state safety |
| `certified.data` | Target exposes certified variables or certified data responses | Needed for IC certification patterns |
| `management.canister` | Target can call the virtual management canister | System lifecycle APIs are target-native |

### Algorand AVM

See [Algorand AVM target](targets/algorand-avm.md).

Algorand overlaps with generic contract capabilities, but AVM programs,
storage classes, transaction groups, and explicit resource references need
separate representation before a target profile is added.

| Candidate id | Portable meaning | Why it is separate |
|---|---|---|
| `avm.application` | Target emits stateful application approval and clear-state programs | Application artifacts have two AVM programs and app lifecycle semantics |
| `avm.logicsig` | Target emits a stateless LogicSig program | LogicSig is a separate stateless authorization artifact, not an app call |
| `abi.arc4` | Build emits or validates ARC-4 ABI/app-spec metadata | Public method shape is tooling-visible metadata, not only exported code |
| `storage.global` | Contract uses application global state | Different limits and access rules from local or box state |
| `storage.local` | Contract uses account-local application state | State is keyed by account and app, not by a global contract map |
| `storage.box` | Contract uses box storage with explicit box references | Box access requires resource references and budget planning |
| `tx.group` | Contract depends on atomic transaction group ordering or inspection | Group semantics are target-native transaction context |
| `tx.resource_refs` | App call requires explicit accounts, assets, apps, or boxes references | Resource availability affects whether AVM execution can access data |
| `itxn.submit` | Application submits inner transactions | Inner effects are transaction-level, not synchronous method calls |
| `asset.asa` | Contract handles Algorand Standard Assets | Native asset model differs from generic `value.native` |
| `gas.avm_budget` | Lowering tracks AVM opcode budget, costs, and program limits | AVM budget constraints are not EVM gas or Wasm host fuel |
| `artifact.algokit` | Build emits AlgoKit/Puya app artifacts and validation metadata | Target tooling requires app spec and bytecode package metadata |

### TON TVM

See [TON TVM target](targets/ton-tvm.md).

TON overlaps with generic contract capabilities, but TVM cells, messages, and
actions need explicit representation before a target profile is added.

| Candidate id | Portable meaning | Why it is separate |
|---|---|---|
| `storage.cell` | Contract state is encoded as TVM cells, slices, and builders | Not EVM slot storage or host KV |
| `abi.tlb` | Build emits or validates TL-B/cell layout metadata | Public data shape is cell-oriented |
| `message.recv` | Contract handles internal or external inbound messages | Entrypoint shape is message-driven |
| `message.send` | Contract emits outbound messages through action semantics | Not synchronous cross-contract calls |
| `method.get` | Contract exposes off-chain get methods | Different from state-changing message handlers |
| `action.list` | Target effects are accumulated in TVM action lists | Needed for send/deploy/reserve effects |
| `state.init` | Deployment requires code/data `StateInit` handling | Deployment artifact is target-native |
| `account.status` | Account lifecycle/status affects behavior | Needed for uninit/active/frozen/deleted handling |
| `gas.tvm` | TVM gas and fee model is explicit | Not generic EVM gas or host fee metering |
| `asset.jetton` | Contract integrates TON jetton/token standards | Native token standards differ from `value.native` |

### Bitcoin Cash CashScript

See [Bitcoin Cash CashScript target](targets/bitcoin-cash-cashscript.md).

BCH/CashScript overlaps with UTXO covenant targets, but its CashVM,
transaction-introspection, CashTokens, and transaction-builder semantics need
explicit representation before a target profile is added.

| Candidate id | Portable meaning | Why it is separate |
|---|---|---|
| `storage.utxo` | State and value live in spendable UTXOs | Not account/object storage or global contract state |
| `script.p2sh` | Contract deployment/addressing uses P2SH locking scripts | Deployment/address surface is target-native |
| `script.unlocker` | Contract calls are unlocking scripts for selected UTXOs | Not ordinary method dispatch |
| `tx.introspection` | Contract reads current transaction inputs/outputs and active input data | Core covenant mechanism in BCH CashVM |
| `covenant.introspection` | Contract constrains successor outputs through introspection | Needed for covenant-style state transitions |
| `storage.local_state` | Local state is simulated through script data or CashTokens commitments | Not persistent global storage |
| `asset.cashtoken` | Contract handles CashTokens category, capability, NFT commitment, and token amount | Native asset model differs from generic `value.native` |
| `timelock.locktime` | Contract depends on locktime, sequence, or age checks | Separate from ordinary block reads |
| `signature.checksig` | Contract verifies signatures as spend conditions | UTXO spend authorization is script-level |
| `artifact.cashscript` | Build emits a CashScript artifact JSON and bytecode metadata | Target tooling requirement |
| `tx.builder` | Validation includes building and evaluating a spend transaction | Practical target semantics require transaction construction |

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
