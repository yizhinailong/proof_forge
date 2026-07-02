# Target Portfolio Roadmap

Status: **Draft (2026-07)**

This page is the portfolio-level plan for the ~15 docs-first research targets:
which ones to build, in what order, under which preconditions, and which ones
deliberately stay parked. Per-target architecture lives in
[docs/targets/](targets/README.md); this page only sequences them.

Scheduling here is expressed as **gates and dependencies, not dates**: a tier
opens when its precondition gate is met, and within a tier work is sized in
milestones that map one-to-one onto implementing branches.

## Tier model

```text
Tier 0  Active on main today
Tier 1  Next: opens when the Tier-0 parity gate passes
Tier 2  Conditional: opens when its listed enabler lands
Tier 3  Parked research: docs stay current, no registry/code work
```

**Tier-0 parity gate (the current phase goal):** the shared scenario
(Counter, then ValueVault) passes in testkit (RFC 0007) on `evm`,
`solana-sbpf-asm`, and `wasm-near`. Nothing in Tier 1 starts before this,
because every later target reuses the artifacts this gate hardens: the
portable IR surface, capability routing, EmitWat, and the scenario harness.

## Tier 0 — active (no new planning needed)

| Target | State |
|---|---|
| `evm` | Baseline; product pipeline decision tracked in Workstream 24 |
| `solana-sbpf-asm` | Experimental; live gates + Pinocchio equivalence growing |
| `wasm-near` | Experimental; EmitWat canonical (D-031) |
| `psy-dpn` | Experimental restricted subset; continues opportunistically |
| `aleo-leo` | Research spike per D-032; continues on its own track |
| `wasm-cloudflare-workers` | Off-chain host demo (D-033); no expansion planned |

## Tier 1 — next two targets

### 1a. `wasm-cosmwasm` — the EmitWat generality proof

Already settled direction (D-003/D-006): CosmWasm is the first new Wasm
spike. The consolidation strengthened the case — EmitWat now exists, and
`AllocatorConfig` already defines `cosmWasmRegion` as a dormant binding
(RFC 0008). CosmWasm is the cheapest possible second Wasm host:

- Reuses: `Compiler/Wasm/AST+Printer`, EmitWat lowering, allocator model,
  IR coverage manifests, testkit NEAR harness pattern (wasmtime + host shim).
- New work: CosmWasm host import set (`db_read`/`db_write`/…), region
  allocator ABI exports, JSON message encoding for entrypoints,
  `cosmwasm-check` gate, testkit `harness-cosmwasm`.
- Milestones: M1 host-import + region ABI in EmitWat; M2 Counter artifact
  passes `cosmwasm-check`; M3 testkit scenario green + cross-target
  equivalence vs `wasm-near`; M4 registry stage → Experimental.

Exit meaning: if the same EmitWat core serves two Wasm hosts with only
import/ABI adapters swapped, the Wasm-family architecture claim is proven,
and Soroban/ICP become adapter projects instead of research projects.

### 1b. `move-aptos` — the first sourcegen POC (parallel track)

Settled by D-007/D-008 (Aptos before Sui; generated Move source, proofs stay
in Lean). Unlike the Wasm targets it shares no emitter with EmitWat, which is
exactly why it is worth doing early in parallel: it exercises the
portable-IR → *source package* route that Tezos/Cardano/TON/Starknet would
also use, with the most mature tooling of that group.

- Milestones: M1 IR → Move module printer for the Counter subset (scalar
  state, entrypoints, events); M2 `aptos move test` gate + golden fixture;
  M3 testkit integration (CLI-wrapped executor); M4 capability matrix row
  flips from planned to validated; Sui follows only after Aptos exits.

## Tier 2 — conditional targets (enabler listed per target)

| Target | Enabler (gate) | Marginal work once enabled | Recommendation |
|---|---|---|---|
| `wasm-stellar-soroban` | CosmWasm M4 (proves host-adapter split) | Soroban host imports, XDR/contract-spec ABI, storage TTL model as target metadata, Stellar CLI gate | Do after CosmWasm; second-cheapest Wasm host |
| `wasm-icp-canister` | CosmWasm M4 **plus** an async/inter-canister design note | Candid ABI, update/query split, cycles metadata; its async call model does not fit the current synchronous IR effect set | Defer; hardest Wasm host — do not start on adapter momentum alone |
| `move-sui` | Aptos M4 | Object model as target extension (parallel to Solana accounts), Sui CLI gates | Follows Aptos per D-007 |
| `starknet-cairo` | Aptos M4 (sourcegen pattern proven) + one maintainer with Cairo depth | Cairo/Scarb package printer, Sierra/CASM artifact + class-hash metadata | First non-Move sourcegen candidate; ZK-adjacent knowledge partially shared with Psy/Aleo |
| `ton-tvm`, `algorand-avm`, `cardano-plutus-aiken`, `tezos-michelson-ligo` | Starknet or equivalent second sourcegen exit | Each is a source-package printer + native-CLI gate on the same pattern | Keep docs current; pick **at most one at a time**, chosen by ecosystem demand, not architecture need |

Rule for the sourcegen research lane (worth keeping from the decision log):
one active sourcegen spike at a time. Every target in this lane uses the same
skeleton — restricted portable IR subset → generated source package → native
toolchain gate → testkit CLI-wrapped executor — so parallel spikes duplicate
learning instead of accelerating it.

## Tier 3 — the Bitcoin/UTXO family: a different product, same platform

`bitcoin-script-miniscript`, `bch-cashscript`, `zcash-shielded`, and
`kaspa-toccata` are **not smart-contract execution targets** and must not be
routed through the contract pipeline. The honest architectural fit (already
sketched in [bitcoin-script-miniscript](targets/bitcoin-script-miniscript.md),
D-021/D-022, and the review checklist) is a separate **policy family**:

```text
Contract family (today):
  Intent API -> ContractSpec/IR -> capability routing -> execution artifact

Policy family (Bitcoin lane, when opened):
  Policy Intent API (pure spending predicates: signatures, thresholds,
  hash preimages, absolute/relative timelocks, Taproot script paths)
    -> policy IR (no storage, no events, no crosscall, no entrypoints —
       a predicate tree, not a program)
    -> Miniscript / descriptor generation (rust-miniscript)
    -> Script / Tapscript artifact + PSBT scenario manifest
    -> Bitcoin Core regtest / testmempoolaccept gate (testkit CLI executor)
```

Design consequences to record when this lane opens:

- **New capability domain, not reuse:** `policy.*` ids (e.g. `policy.sig`,
  `policy.threshold`, `policy.timelock.absolute`, `policy.hashlock`,
  `policy.taproot_path`) instead of pretending `storage.*`/`events.emit`
  apply. The capability registry gains a policy section; contract-family
  capabilities are all `—` (not applicable) for these targets.
- **Lean's value is different here:** not state-machine proofs but policy
  properties — "funds are recoverable after timelock T along some path",
  "no spending path omits participant X", miniscript-level non-malleability
  conditions. These are decidable checks over a small predicate tree:
  well-suited to the FV roadmap style (decide-checked theorems).
- **What ProofForge adds over raw Miniscript:** one verified policy source
  that emits Bitcoin descriptors *and* (later) BCH CashScript or Kaspa
  covenant forms, with the same cross-target equivalence testing testkit
  gives contracts.
- **Zcash ordering:** `zcash-shielded` stays behind
  `bitcoin-script-miniscript` — it adds a proving/nullifier boundary on top
  of the same UTXO policy shape (D-022) and should inherit a working policy
  lane first. `kaspa-toccata` waits for covenant/transaction-v1 semantics to
  stabilize upstream (D-012).

**Recommendation:** keep the whole family parked until both Tier-1 targets
exit. When opened, `bitcoin-script-miniscript` goes first, as a deliberately
small vertical: policy IR + rust-miniscript emission + regtest gate, Counter
has no meaning here — the shared scenario for the policy family is a 2-of-3
multisig with a timelock recovery path.

## Explicit non-plans

- `wasm-polkadot` / ink! stays research-only (D-009) — revisit only on
  concrete demand.
- No new chain profile targets beyond `evm` reuse (D-024 pattern) need
  planning; EVM-compatible chains are metadata, not backends.
- The cloud platform remains gated by D-010 (two-plus targets at
  Experimental with shared-scenario parity), unchanged by this roadmap.

## Sequencing summary (gates, not dates)

```text
Gate G0: testkit M3 + shared-scenario parity on evm/solana/wasm-near   (Tier-0 exit)
  ├── opens 1a wasm-cosmwasm  (M1..M4)
  └── opens 1b move-aptos     (M1..M4, parallel)
Gate G1a: cosmwasm M4  -> opens wasm-stellar-soroban; ICP needs +async design note
Gate G1b: aptos M4     -> opens move-sui; opens sourcegen lane (starknet first pick)
Gate G2:  both Tier-1 exits -> opens Bitcoin policy family (miniscript first)
Sourcegen lane rule: at most one active spike at a time
```

Tracked as Workstream 28 in the
[implementation backlog](implementation-backlog.md); tiering and the policy
family classification recorded as D-034 in [decisions](decisions.md).
