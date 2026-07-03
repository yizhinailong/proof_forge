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

**Status: Open** (behavior largely met; budgets and the current validation
baseline are incomplete)

### Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| G0-1 | Counter behavior parity on 3 targets | ✅ met | `just testkit` → `counter trace parity: ok (3 target(s))` |
| G0-2 | ValueVault behavior parity on 3 targets | 🟡 partial | Prior `just testkit` evidence covered three targets; current local evidence may skip the EVM branch when Foundry `cast` is unavailable, so a clean all-tools run still needs to be recorded |
| G0-3 | Counter resource budgets: `solana_cu`, `evm_gas`, `near_gas` | 🟡 partial | `testkit/scenarios/counter.toml` has `solana_cu` + `evm_gas` baselines; **`near_gas` not implemented in any scenario** |
| G0-4 | ValueVault resource budgets on 3 targets | ❌ unmet | `testkit/scenarios/value-vault.toml` has **no `[step.expect.budget]` blocks** |
| G0-5 | Unsupported-capability diagnostic parity | ✅ met | `just testkit` → `unsupported-crosscall ... diagnostic crosscall.invoke unsupported: ok` |
| G0-6 | `just check` green (build + lint + gates) | ❌ unmet | Latest remote CI on `main` (`28654051741`, `cd0b049`) fails in `just build`; local docs sync also required repair before this record can claim green |

### Remaining work to close Gate G0

1. **Restore the validation baseline**: commit the missing
   `ProofForge/Target/HostBridge.lean`, keep `ProofForge/Target/*` from being
   ignored by the root `target/` ignore rule, repair the Rust toolchain action,
   and re-record `just check` / CI evidence only after the run is green.
2. **NEAR gas budget implementation** (RFC 0010): wire `near_gas` (burnt gas /
   gas used) into the `harness-near` outcome and add a `near_gas` baseline +
   tolerance to every Counter and ValueVault step. Highest priority — this is
   the only budget dimension entirely missing.
3. **ValueVault budget baselines**: measure and pin `solana_cu`, `evm_gas`,
   (and `near_gas` once implemented) for all ValueVault steps across the three
   targets.
4. (Carry-over, non-blocking for the gate but on the Tier-0 hardening track)
   EVM semantic-plan migration (Workstream 3: ExprPlan/StmtPlan/
   EntrypointPlan/EventPlan/CrosscallPlan/MetadataPlan) and Solana Pinocchio
   CI equivalence (Workstream 7).

### Sign-off

Not yet closed. Closing requires G0-1 through G0-6 all ✅, recorded here with
the closing commit and `just testkit` + `just check` evidence.

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
