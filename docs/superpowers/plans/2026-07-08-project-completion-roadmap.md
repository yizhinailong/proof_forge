# Project Completion Roadmap — what's done, what's left, agent handoff (2026-07-08)

> Single hand-off page: the current state of ProofForge's FV + correctness + breadth work,
> in phases an agent can execute IN ORDER. Each item points to its detailed task card.
> Detailed plans: [FV target-semantics](2026-07-07-fv-target-semantics.md),
> [ZK sourcegen](2026-07-08-zk-sourcegen-spike.md),
> [execution-plan §7](../../zh/execution-plan-2026-07.md),
> [platform gaps](../../platform-gaps-2026-07.md).

## ✅ DONE — the big achievement: three-chain universal FV

Machine-checked, universally-quantified (`∀ safe input`) IR↔target refinement, green, no `sorry`:

- **EVM** — against `powdr-labs/evm-semantics` (import; heavy ~13k lines, but strongest trust —
  powdr is conformance-tested vs `ethereum/tests`).
- **Solana** — against a self-built sBPF interpreter (light ~6k lines; Counter universal C-proof +
  ValueVault genericity 283 thms + full-opcode audit; two-hop trust via Mollusk/Surfpool).
- **WASM/NEAR** — Counter universal C-proof CLOSED + green; ValueVault Wasm abstract-core
  trace + canonical anchor landed; CosmWasm host dispatch + chain-axis proof
  (`counterCosmWasm_*_simulates`) landed + smoke gated in `just check`. WASM-5 done.

The self-build path (Solana/WASM) is ~⅓ the size of the import path (EVM) and builds in seconds —
that asymmetry is settled and expected. This is the platform's differentiator, delivered on the 3
primary chains.

## Phase 1 — Finish the FV C-proof lane (DONE — 2026-07-08) — 1 agent

WASM-5 (the double genericity test) is now closed on both axes:

- **ValueVault WASM (contract axis):** `ValueVaultWasmExec.lean` /
  `ValueVaultWasmRefinement.lean` close the abstract-core path — `valueVaultWasm_step_simulates`
  (all 7 entrypoints), `valueVaultWasm_trace_simulates` (arbitrary calls), `after_initialize`,
  and the `initialize 10 → deposit 5 → getNetValue` full-prefix anchor. This is the **abstract-core
  route** (relation-level `canonicalCoreStorage` + one-step simulate + trace lift), intentionally
  lighter than Solana's 283 per-instruction theorems — the asymmetry is by design, not a gap.
- **CosmWasm (chain axis — the killer test):** `CounterCosmWasmRefinement.lean` proves Counter
  reuses the SAME host-agnostic `counterWasmCoreTraceStep` with only the host swapped
  (`counterCosmWasm_*_simulates` + `counterCosmWasm_host_db_write_step_preserves_rel`).
  `WasmInterpreter.runHostCall` dispatches `.cosmWasm` → `runCosmWasmHostCall`
  (`db_read`/`db_write`/`set_return_data`). Smoke gate `just wasm-cosmwasm-refinement-smoke`
  (in `just check`) is green.
- Card: WASM-5 in [FV target-semantics plan](2026-07-07-fv-target-semantics.md).
- **Exit:** all 3 chains have complete universal C-proof + double genericity, green. ✅

## Phase 2 — Close the Track 0 correctness bugs (IMPORTANT — FV did NOT touch these) — 1 agent

The FV proves "IR ⟷ target", but the **IR itself still has the original-review bugs**. Fixing them
is what makes the FV meaningful (you want to prove a *correct* IR, not one with silent
divergences). **All three verified STILL OPEN (2026-07-08):**

- **0.1 overflow, node-level** — DONE (2026-07-08). `IR.Expr.add/.sub/.mul` now carry an
  `overflowChecked : Bool := true` field (default checked, matching Solidity 0.8 / EVM
  semantics). `Builder.add/sub/mul` and `Surface.add/sub/mul` default to `:= true` and
  forward to the constructor; `+!`/`-!`/`*!` use this default. The EVM lowering reads the
  per-node flag (`arithExpr oc op` in `Backend/Evm/ToYul/Helpers.lean`) and emits
  checked-revert (`__pf_checked_*`) when `true`, wrapping Yul builtins when `false`.
  `ExprPlan.checkedArith` carries the flag through to the Yul emit path
  (`Backend/Evm/ToYul/Effect.lean`). Per the cross-target portability decision (wrap on
  non-EVM), `Expr.capabilities` does **not** emit `.checkedArithmetic` from the node flag
  (so a portable contract using `+!` still resolves to all targets and wraps on
  Solana/NEAR, which ignore `oc`). The module-level `Module.overflowChecked` remains the
  capability gate path used by FV-5 (`checkedCounterModule` fixture). All existing gates
  green: `just evm-semantic-plan`, `just fv5-overflow-smoke`, `just value-vault-wasm-refinement-smoke`,
  `just solana-lean`, `just shared-validate-smoke`, `just ir-counter-semantics-smoke`,
  `just counter-universal-refinement-smoke`. (Note: `just docs-check` remains red as a
  pre-existing `docs/targets/README.md` translation-sync staleness, now also flagging
  `docs/capability-registry.md` whose `arith.checked` section was updated to describe the
  new node-level field.)
- **0.2 capability derivation** — DONE (2026-07-08, commit `9dbaef3b`). `capabilityCallsForSpec`
  was intent-OR-module (`if calls.size == 0`), dropping module-derived capabilities whenever any
  intent declared a capability. Replaced with a deduplicated `intent ∪ module` union so module
  capabilities are always checked. Added `BEq` deriving to `TargetMetadata` and `CapabilityCall` to
  support dedup. File: `Target/Adapter.lean`.
- **0.3 `nearCrosscallInvokePool`** — DONE (2026-07-08, commit `9dbaef3b`). Mapped to the unique
  `.nearPromise` capability (like its sibling `nearPromiseThen`), so the capability layer now
  rejects it on non-NEAR targets (EVM/Solana); the pre-existing hardcoded EVM `Validate` arms
  remain as defense-in-depth. File: `IR/Contract.lean`.
- Card: Track 0 in [execution-plan §1](../../zh/execution-plan-2026-07.md).
- **Phase 2 exit:** all three Track 0 correctness bugs fixed + green. ✅

## Phase 3 — Complete the FV foundation (Track 1 remainder) — 1 agent

- **1.4 supported-fragment predicate** — DONE (2026-07-08). Generalized the
  fragment machinery beyond the single Counter enumeration into a two-predicate
  per-target scheme on `TargetSemantics`:
  - `fragmentAccepts : Module → Bool` — the *proven* refinement scope (the set of
    modules whose IR↔target refinement is machine-checked; currently `isCounterModule`
    for the Counter universal C-proof).
  - `lowerableAccepts : Module → Bool` — the *lowerable* scope (the set of modules
    the target can successfully lower; a superset of `fragmentAccepts`).
  Three Track 1.4 theorems instantiated for EVM, Solana sBPF, and Wasm/NEAR on the
  canonical Counter module, replacing the ad-hoc `check-ir-coverage-manifest.py`
  scripts for the Counter proven fragment:
  1. `*_counter_lowering_total` — `lowerModule Counter.module = .ok _` (`native_decide`
     bridge; lowerable ⇒ lowering-total).
  2. `*_proven_subset_lowerable_counter` / `*_fragment_subset_lowerable_counter` —
     `fragmentAccepts ⊂ lowerableAccepts` (proven ⇒ lowerable; currently reflexive
     since both predicates are `isCounterModule`).
  3. `*_capability_accept_implies_lowerable_counter` — `resolveModule profile
     Counter.module = .ok _` ⇒ `lowerableAccepts Counter.module = true`
     (capability-accept ⇒ lowerable).
  New gate `just track14-fragment-theorems-smoke` (in `just check`) exercises all
  three theorems across the three backends. The `∀ module ∈ fragment` universal
  form currently discharges on the concrete Counter module via `native_decide`
  (the `isCounterModule` predicate fixes the Counter structure); a structural
  `∀ module` invariant over lowering remains future work (documented in the
  theorem docstrings). All existing gates green; `docs-check` still red as a
  pre-existing translation-sync staleness.
- **1.5 ownership soundness (FV-3)** — total-ize `IR/Ownership.lean`; prove no-use-after-release,
  no double-release (justifies the divergent `release` lowerings).
- **1.6 native_decide→decide audit** — downgrade what can be kernel-checked; add a TCB doc entry
  ("EVM trusts powdr + `native_decide`; self-built targets trust the interpreter + the external
  differential gate").
- **1.7 FV-8 user invariants (product differentiator)** — authors state invariants next to
  `contract_source`, proven pre-codegen against the IR semantics; turn `ValueVaultInvariant` from a
  worked example into a reusable authoring surface. **Highest product value in this phase.**
  - **DONE (Track 1.7).** Added `ProofForge.Contract.LeanInvariant` (reusable machinery:
    `InvariantSpec`, `ContractInvariants`, `ScenarioStep`, `runScenario`,
    `verifyInvariantsAfterScenario`, `invariants_hold_after_scenario` soundness witness).
  - Refactored `ProofForge.Contract.Examples.ValueVaultInvariant` from a one-off scenario
    test into the canonical authoring example: invariants are now `State → Bool` predicates
    bundled into a `ContractInvariants`, machine-checked via
    `verifyInvariantsAfterScenario` (`value_vault_invariants_hold_after_scenario`, proven by
    `native_decide`). Backward-compatible `runScenario`/`expectedReturns`/`defaultScenario*`
    shims keep the Wasm/NEAR offline-host refinement consumers unaffected.
  - Added `ProofForge.Contract.Examples.CounterInvariant` as the second authoring example
    (`countBounded` + `countNonNegative` Lean invariants, `counter_invariants_sound`).
  - Added `lean_invariant` `contract_source` annotation (parallel to `quint_invariant`),
    storing `(name, predicate function qualified name)` in a new `leanInvariants` field on
    `ContractSpec`/`ModuleBuilder` (documentation link to the predicate `def`; the machine
    check happens in the gate, not by string parsing).
  - Wired `Examples/Shared/Counter.lean` with `lean_invariant countBounded`/`countNonNegative`.
  - New gate `lean-invariants-smoke` (`Tests/LeanInvariantsSmoke.lean`), integrated into
    `just check`, exercises the ValueVault + Counter invariant theorems.
  - Scope: pure-Lean, backend-agnostic. The `invariants_hold_after_scenario` witness is
    currently scenario-bound (`native_decide` on the concrete scenario); a universal
    `∀ state` form over the IR interpreter remains future work (structural invariant
    over `runEntrypointWithArgs`).

  **DONE (2026-07-08).** Delivered:
  - `ProofForge.Contract.LeanInvariant`: reusable authoring machinery — `InvariantSpec`
    (`State → Bool` predicate + name), `ContractInvariants` bundle, `ScenarioStep`/`runScenario`
    (generic entrypoint trace), `verifyInvariantsAfterScenario` (Bool check), and the
    `invariants_hold_after_scenario` soundness theorem (the `verified = true ⟹ ∃ finalState,
    allInvariantsHold ∧ runScenario = .ok` bridge, discharged structurally — no `native_decide` on
    the bridge itself; the `verified = true` premise is discharged by `native_decide` per
    contract/scenario).
  - `contract_source` macro gains a `lean_invariant <name> := "<predicateFnQualifiedName>"` item
    (parallel to `quint_invariant`). It stores the predicate's *qualified name* in a new
    `ContractSpec.leanInvariants : Array (String × String)` field (documentation link; the
    predicate is a separate top-level `def`, not embedded — functions are not storable in the
    serialized spec). This is the author-facing declaration surface.
  - `ProofForge.Contract.Examples.ValueVaultInvariant` refactored from a one-off scenario test
    into the canonical authoring example: declares three Lean invariants (`accounting`,
    `net_value`, `final_storage`), runs the canonical `initialize → deposit → charge_fee →
    release → snapshot` scenario from the empty state, and proves `value_vault_invariants_hold
    _after_scenario` + `value_vault_invariants_sound`. Backward-compatible scenario API
    (`runScenario inputs`, `expectedReturns`, `accountingInvariantHolds`, `finalStorageMatches`,
    `defaultScenarioTraceOk/AccountingOk/NetValueOk`) preserved so the Wasm/NEAR offline-host
    refinement (`ProofForge.Backend.WasmNear.Refinement.Core`) is unaffected.
  - `ProofForge.Contract.Examples.CounterInvariant`: Counter authoring example — `countBounded`
    + `countNonNegative` invariants over an `initialize → increment×n` scenario; the Counter
    `contract_source` now carries `lean_invariant` annotations linking to these predicates.
  - `Tests/LeanInvariantsSmoke.lean` + `just lean-invariants-smoke` gate (in `just check`):
    machine-checks the invariant theorems for both contracts and verifies the Counter
    `lean_invariant` annotations are registered.
  - Pure-Lean, backend-agnostic, no Quint-MBT or per-target lowering dependency — the FV-8
    product surface. Future work: a `∀ state` (scenario-free) form requires a structural
    invariant over the IR interpreter; the scenario-bound form is the current machine-checked
    authoring surface.
  **DONE (2026-07-08):** added `ProofForge.Contract.LeanInvariant` reusable machinery
  (`InvariantSpec`, `ContractInvariants`, `ScenarioStep`, `runScenario`, `verifyInvariantsAfterScenario`,
  and the `invariants_hold_after_scenario` soundness theorem). Refactored `ValueVaultInvariant` from a
  one-off scenario test into the authoring mode (declares `accounting`/`net_value`/`final_storage`
  Lean invariants, machine-checked via `native_decide`). Added `CounterInvariant` as the Counter
  instance (`countBounded`/`countNonNegative`). Added a `lean_invariant` contract-source item syntax
  (parallel to `quint_invariant`) that stores the predicate function qualified name in
  `ContractSpec.leanInvariants` (documentation link; the predicate is a separate top-level `def`
  verified by the gate). Added `lean-invariants-smoke` gate (`just check`). Backward-compatible
  scenario API shims keep the Wasm/NEAR offline-host refinement (`ProofForge.Backend.WasmNear.Refinement.Core`)
  consuming `ValueVaultInvariant.runScenario`/`expectedReturns`/`defaultScenario*Ok` unchanged. The
  universal `∀ state` invariant form requires a structural invariant over the IR interpreter; the
  scenario-bound `native_decide` form is the machine-checked authoring surface today.

  **DONE (Track 1.7 / FV-8).** Delivered a pure-Lean, backend-agnostic authoring surface for
  user-declared invariants, machine-checked pre-codegen:
  - New reusable machinery in `ProofForge/Contract/LeanInvariant.lean`:
    `InvariantSpec` (`name` + `State → Bool` predicate), `ContractInvariants` bundle,
    `ScenarioStep`/`runScenario`/`verifyInvariantsAfterScenario`, and the soundness theorem
    `invariants_hold_after_scenario` (scenario-bound witness; a structural `∀ state` form is
    future work once a structural IR-interpreter invariant is proven).
  - Refactored `ValueVaultInvariant.lean` from a one-off scenario test into the canonical
    authoring example: declares `accounting` / `net_value` / `final_storage` Lean invariants,
    bundles them, defines a canonical `initialize → deposit → charge_fee → release → snapshot`
    scenario, and machine-checks `value_vault_invariants_hold_after_scenario` (`native_decide`)
    plus `value_vault_invariants_sound`. Backward-compatible scenario API (`runScenario inputs`,
    `expectedReturns`, `accountingInvariantHolds`, `finalStorageMatches`,
    `defaultScenario*Ok`, `value_vault_default_trace_ok`) preserved so the Wasm/NEAR offline-host
    refinement pipeline is unaffected.
  - New `CounterInvariant.lean` authoring example: `countBounded` + `countNonNegative` Lean
    invariants over the canonical Counter, machine-checked after an increment scenario.
  - New `lean_invariant <name> := "<predicateFnQualifiedName>"` `contract_source` item
    (parallel to `quint_invariant`), stored on `ContractSpec.leanInvariants` as a documentation
    link to a top-level `State → Bool` predicate; verified pre-codegen by
    `LeanInvariant.verifyInvariantsAfterScenario`.
  - New `lean-invariants-smoke` `just` recipe + `Tests/LeanInvariantsSmoke.lean`, wired into
    `just check`. The Counter `contract_source` exposes `lean_invariant countBounded` /
    `countNonNegative` annotations, exercising the full authoring → verify loop.

## Phase 4 — Breadth (after the primaries are solid) — parallelizable

- **WASM host families** — add Soroban / MultiversX / Casper / … hosts, each a thin `*Host.lean`
  reusing the SAME `WasmExec` (one CosmWasm host already serves the whole Cosmos ecosystem). Order
  + fit: the WASM host-family map in [FV target-semantics plan](2026-07-07-fv-target-semantics.md).
- **ZK lane** — Road 1 codegen (Noir `NR-1..4` first — pure-function, cleanest — then Cairo
  `CR-1..4`), then Road 2 FV-import (Cairo→`starkware-libs/formal-proofs`, Noir→`reilabs/lampe`,
  copying the EVM E-lane; each ZK target has a ready Lean 4 semantics). Card:
  [ZK sourcegen spike](2026-07-08-zk-sourcegen-spike.md); target notes:
  [noir-aztec](../../targets/noir-aztec.md), [starknet-cairo](../../targets/starknet-cairo.md).

## Phase 5 — Platform gaps + structural debt (docs-first, parallelizable)

- **WS30** versioning/compat policy · **WS32** deploy lifecycle / upgrade-policy intent / signing ·
  **WS33a** portable runtime error model · **WS33b** unified client generation (the "调用文档"
  layer). Scoped in [platform-gaps-2026-07](../../platform-gaps-2026-07.md) +
  [execution-plan §3/§4](../../zh/execution-plan-2026-07.md).
- **Structural debt:** finish RFC 0014 `LoweringError` instance migration · rename `Lean.Evm` →
  `ProofForge.*` · CLI flag-zoo → target-first M3/M4.

## Recommended order for agents (hand each agent ONE phase, or one task within it)

1. **Phase 1 (WASM-5)** — ✅ CLOSED 2026-07-08: both axes landed + gated.
2. **Phase 2 (Track 0 bugs)** — real shipping bugs, small + high value; makes the FV meaningful.
3. **Phase 3 (FV foundation)** — `1.7` FV-8 is the product differentiator; `1.4/1.5/1.6` harden the TCB.
4. **Phase 4 / 5** — parallelizable once 1–3 land; ZK + client + platform gaps are docs-first, low risk.

Discipline that held for EVM/Solana/WASM and must continue: generic exec layers carry **0 contract
names**; every universal theorem is **closed** (obligations constructed, not hypothesized) and
**green**; **no `sorry`**; self-built targets **keep the external differential gate** (Mollusk /
Surfpool / wasmtime) for the "interpreter ≈ real VM" hop.
