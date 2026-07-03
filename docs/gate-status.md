# Gate Completion Records

Status: **Live (2026-07-03)**

This page is the authoritative per-gate completion ledger for the tiered
portfolio ([target-roadmap](target-roadmap.md), D-034). Each Gate has one
record listing its acceptance criteria, per-criterion status, evidence, and
sign-off date. A Gate is **closed** only when every criterion is **met**; a
single unmet criterion blocks the next tier (D-044 completion-first rule).

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

**Status: Open** (acceptance criteria are implemented locally; closing waits
for the current commit's remote CI/sign-off evidence)

### Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| G0-1 | Counter behavior parity on 3 targets | ✅ met | `just testkit` → `counter trace parity: ok (3 target(s))` |
| G0-2 | ValueVault behavior parity on 3 targets | ✅ met | Remote CI `28655651561` (`12a007b`) `build-test` → `Run unified testkit` succeeded with Foundry/cast installed |
| G0-3 | Counter resource budgets: `solana_cu`, `evm_gas`, `near_gas` | ✅ met | `testkit/scenarios/counter.toml` pins all three budgets; `CAST="$PWD/build/tools/cast-shim" cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --scenario counter --trace` |
| G0-4 | ValueVault resource budgets on 3 targets | ✅ met | `testkit/scenarios/value-vault.toml` pins `solana_cu`, `evm_gas`, and `near_gas` for all 11 calls; `CAST="$PWD/build/tools/cast-shim" cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --scenario value-vault --trace` |
| G0-5 | Unsupported-capability diagnostic parity | ✅ met | `just testkit` → `unsupported-crosscall ... diagnostic crosscall.invoke unsupported: ok` |
| G0-6 | `just check` green (build + lint + gates) | ✅ met | `CAST="$PWD/build/tools/cast-shim" just check` passed locally; remote CI `28655651561` (`12a007b`) also completed successfully after the CI baseline fixes |

### Remaining work to close Gate G0

1. Re-run remote CI on the current closing commit and record the successful run
   in Sign-off before marking Gate G0 closed.
2. (Carry-over, non-blocking for the gate but on the Tier-0 hardening track)
   EVM semantic-plan migration (Workstream 3: ExprPlan/StmtPlan/
   EntrypointPlan/EventPlan/CrosscallPlan/MetadataPlan) and Solana Pinocchio
   CI equivalence (Workstream 7).

### Sign-off

Not yet closed. G0-1 through G0-6 are implemented; closing requires recording
the current commit and successful `just testkit` + `just check`/CI evidence.

---

## Gate G1a — CosmWasm M4 (frozen, D-044)

**Status: Frozen.** Per D-044, the `wasm-cosmwasm` spike stays at its current
M1/M2 state until Gate G0 closes. No registry-stage advancement, no M3/M4.

## Gate G1b — Aptos M4 (frozen, D-044)

**Status: Frozen.** Per D-044, the `move-aptos` spike stays at its current
M1/M2 state (Counter printer + golden + test gate, B1 state-id fidelity) until
Gate G0 closes. No M3 (testkit CLI-wrapped executor), no M4 (registry stage →
Experimental), no `move-sui` start.

## Gate G2 — both Tier-1 exits (not started)

**Status: Not started.** Opens only after G1a *and* G1b close, which themselves
require Gate G0 to close first (D-044).
