# Gate Completion Records

Status: **Live (2026-07-03)**

This page is the authoritative per-gate completion ledger for the tiered
portfolio ([target-roadmap](target-roadmap.md), D-034). Each Gate has one
record listing its acceptance criteria, per-criterion status, evidence, and
sign-off date. A Gate is **closed** only when every criterion is **met**; a
single unmet criterion blocks the next tier. Gate P0 records the
primary-chain completion covenant (D-045), which is stricter than the G0
behavior/budget slice.

Unlike [development-log](development-log.md) (a stream of engineering
milestones), this page records the *phase boundary* decisions: whether the
current phase's Definition of Done is satisfied, with auditable evidence.

## How to use

- Add a new `## Gate GN` section when a Gate's first criterion starts.
- Update status to ✅ / ❌ / 🟡 (met / unmet / in-progress) as work lands.
- Record evidence as reproducible commands and commit ranges, not prose.
- A Gate closes with a `**Closed: YYYY-MM-DD**` line; until then it stays
  **Open**.

## Gate G0 — Tier-0 exit (current phase goal)

**Definition of Done:** the shared scenario (Counter, then ValueVault) passes
in [testkit](../testkit/) (RFC 0007) on `evm`, `solana-sbpf-asm`, and
`wasm-near` — behavior parity *and* resource budgets (D-040 / RFC 0010).

**Status: Closed**

**Closed: 2026-07-03**

### Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| G0-1 | Counter behavior parity on 3 targets | ✅ met | `just testkit` → `counter trace parity: ok (3 target(s))` |
| G0-2 | ValueVault behavior parity on 3 targets | ✅ met | Remote CI `28655651561` (`12a007b`) `build-test` → `Run unified testkit` succeeded with Foundry/cast installed |
| G0-3 | Counter resource budgets: `solana_cu`, `evm_gas`, `near_gas` | ✅ met | `testkit/scenarios/counter.toml` pins all three budgets; `CAST="$PWD/build/tools/cast-shim" cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --scenario counter --trace` |
| G0-4 | ValueVault resource budgets on 3 targets | ✅ met | `testkit/scenarios/value-vault.toml` pins `solana_cu`, `evm_gas`, and `near_gas` for all 11 calls; `CAST="$PWD/build/tools/cast-shim" cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --scenario value-vault --trace` |
| G0-5 | Unsupported-capability diagnostic parity | ✅ met | `just testkit` → `unsupported-crosscall ... diagnostic crosscall.invoke unsupported: ok` |
| G0-6 | `just check` green (build + lint + gates) | ✅ met | `CAST="$PWD/build/tools/cast-shim" just check` passed locally; remote CI `28658576786` (`0c52fb8`) completed successfully, including `Run unified testkit`, `Check Solana light gates`, Foundry smokes, and Anvil deploy smoke |

### Carry-over work after Gate G0

Gate G0 closes the shared behavior/resource-budget slice. It does **not** close
Gate P0. The remaining primary-chain production hardening stays active:

1. ~~EVM semantic-plan migration (Workstream 3: ExprPlan/StmtPlan/
   EntrypointPlan/EventPlan/CrosscallPlan/MetadataPlan).~~ ✅ Landed — see P0-2.
2. Solana Pinocchio live dual-deploy equivalence CI/toolchain hardening and
   broader reference coverage (Workstream 7).
3. NEAR/Wasm target-first local execution/deploy metadata sign-off.

### Sign-off

Gate G0 closed on 2026-07-03 at commit `0c52fb8` after GitHub CI run
`28658576786` completed successfully. The closing run validates the current
`just check` CI surface, including the unified testkit, Solana light gates,
EVM Foundry/Anvil gates, and the smoke jobs for the frozen non-primary spikes.

---

## Gate P0 — Primary-chain completion covenant (current product prerequisite)

**Definition of Done:** ProofForge must complete the three priority chains in
implementation order — `solana-sbpf-asm`, `evm` (Ethereum), and `wasm-near`
(NEAR/Wasm) — before any additional chain advances beyond docs-only research or
frozen spike maintenance (D-045).

**Status: Open**

### Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| P0-1 | Solana direct sBPF backend is production-grade | 🟡 in progress | Gate G0 behavior/budget parity is closed; Pinocchio reference-equivalence is included in `just solana-light`; the 2026-07-03 Agave/Solana CLI ELF compatibility blocker was fixed by forwarding target-first `--solana-sbpf-arch v0` into the legacy ELF builder, producing loader-compatible v0 ELFs (`e_flags = 0`, valid section table) from `emit --target solana-sbpf-asm --format elf`; local `just solana-pinocchio-live-equivalence` now passes all five Surfpool dual-deploy scenarios (System transfer/create_account, SPL Token transfer/ops/authority) with `5 passed, 0 skipped, 0 failed`; `.github/workflows/ci.yml` now includes a mandatory `solana-pinocchio-live` job that installs Agave/Solana CLI, SBF platform-tools, `sbpf`, Surfpool, Node/npm, builds ProofForge, and runs the aggregate live suite without allow-skip. Remaining P0 hardening is to observe the remote CI run and finish broader production-grade Solana sign-off. |
| P0-2 | Ethereum/EVM backend is production-grade | ✅ met | EVM semantic-plan migration landed (RFC 0004): `Plan.lean` now defines `ExprPlan`, `StmtPlan`, `EntrypointPlan`, `EventPlan`, `CrosscallPlan`, `MetadataPlan`; `Validate.lean` holds pure validation/type-inference; `Lower.lean` constructs the populated `ModulePlan` (entrypoints, events, crosscalls, creates, checked-arithmetic flag); `Metadata.lean` produces plan-driven artifact/deploy metadata; `IR.lean` is the compatibility facade that builds the full semantic plan before Yul generation. Gates: `just evm-plan`, `just evm-semantic-plan`, `just evm-all` (diagnostics 58 cases, 99 IR coverage entries, 19 IR smokes + Foundry + Anvil deploy), `just check` all green. FV-4 additionally includes decide-checked executable EVM/Yul trace obligations for Counter, ValueVault, EvmExpressionProbe, EvmMapProbe, EvmTypedStorageProbe, EvmStorageStructProbe, and EvmAbiAggregateProbe, covering scalar traces plus map slots, typed storage arrays, storage structs, and aggregate ABI params/returns. FV-2 IR semantics for aggregate/storage shapes remains future formal-roadmap work, not a P0-2 sign-off blocker. |
| P0-3 | NEAR/Wasm backend is production-grade | 🟡 in progress | EmitWat/NEAR diagnostics, IR coverage, offline host smoke, and budget baselines are green; remaining hardening is full target-first local execution/deploy metadata sign-off |
| P0-4 | Additional-chain advancement is frozen | ✅ met | D-044/D-045 freeze Aptos/CosmWasm advancement past M1/M2 and keep other targets docs-first until P0 closes |

### Sign-off

Not yet closed. Closing P0 requires target-by-target evidence that Solana,
Ethereum/EVM, and NEAR/Wasm satisfy the production-grade DoD in D-045. Gate G0
evidence is necessary but not sufficient.

---

## Gate G1a — CosmWasm M4 (frozen, D-044)

**Status: Frozen.** Per D-044/D-045, the `wasm-cosmwasm` spike stays at its
current M1/M2 state until Gate P0 closes. No registry-stage advancement, no
M3/M4.

## Gate G1b — Aptos M4 (frozen, D-044)

**Status: Frozen.** Per D-044/D-045, the `move-aptos` spike stays at its current
M1/M2 state (Counter printer + golden + test gate, B1 state-id fidelity) until
Gate P0 closes. No M3 (testkit CLI-wrapped executor), no M4 (registry stage →
Experimental), no `move-sui` start.

## Gate G2 — both Tier-1 exits (not started)

**Status: Not started.** Opens only after G1a *and* G1b close, which themselves
require Gate P0 to close first (D-045).
