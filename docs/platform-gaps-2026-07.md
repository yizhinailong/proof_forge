# Platform Gap Analysis (2026-07)

Status: **Draft planning survey**

The current planning corpus covers architecture convergence (Workstream 24),
formal verification (25), the unified testkit (26), allocator unification
(27), and the target portfolio (28). This page records the dimensions that
are **not yet planned anywhere** and would become expensive if the queued
work lands first. Each gap states why it must be planned *now*, its current
state in the repo, and the recommended next step. Items graduate into their
own RFC before implementation; backlog tracking is Workstreams 29–33.

Ordered by urgency (how soon queued work bakes in the wrong default).

## Gap 1: CLI product surface (`proof-forge build`) — Workstream 29

**Why now.** `ProofForge/Cli.lean` has grown to ~136 emit modes and ~130
flag patterns; every fixture and target multiplies flags (`--emit-counter-ir-psy`,
`--emit-counter-emitwat`, `--solana-clock-sysvar-elf`, …). Each conflict in
the 2026-07 consolidation was concentrated in this file, and testkit M4
(Workstream 26) is about to wire dozens of these modes into scenario
harnesses. If the testkit binds to the flag zoo, the flag zoo becomes API.

**Current state.** RFC 0001 and the README promise
`proof-forge build --target <id>` as the stable interface; only
`--learn`/`--learn-token` accept `--target` today.

**Recommendation.** RFC before testkit M4: a `build`/`emit`/`check` command
surface where target id, input kind (Lean source, built-in fixture id,
`.learn`), and artifact set are parameters, not modes. Fixture ids become a
registry (`--fixture counter`), collapsing the per-fixture flags. Keep the
legacy flags as thin aliases for one release, then delete. Testkit invokes
only the new surface.

## Gap 2: Versioning and compatibility policy — Workstream 30

**Why now.** The IR has 99 constructors and three coverage manifests already
gate its evolution — but only structurally. The strings `portable-ir-v0` and
artifact `format` fields exist with no stated rules: what is a breaking IR
change, what must a bump preserve, which artifact schema fields are stable
for external consumers (explorers, the future cloud platform), and what the
SDK promises contract authors across releases. Workstreams 26–28 all add
external consumers of these formats.

**Current state.** Ad-hoc version strings in `SbpfAsm.lean`/`Idl.lean`/CLI;
no semver policy for the SDK, IR, capability ids, or
`proof-forge-artifact.json` / `proof-forge-deploy.json` schemas.

**Recommendation.** A short RFC defining: (a) IR versioning rules tied to
the coverage-manifest gate (new constructor = minor, changed semantics =
major + migration note); (b) artifact/deploy schema versioning with a
"consumers must tolerate unknown fields" rule; (c) capability-id stability
(ids are append-only; meaning changes require a new id); (d) an SDK
deprecation policy. Cheap to write now, near-impossible to retrofit.

## Gap 3: Resource budgets as first-class gates — Workstream 31

**Why now.** The Tier-0 parity gate (D-034) is defined as "shared scenario
passes on three targets" — behavior only. A hypothetical contract could
pass Mollusk while exceeding Solana's default budget (200k CU/instruction),
and EVM/NEAR gas is currently listed under "not covered" in every
validation gate. Declaring parity without budgets risks declaring fake
parity, and codegen quality regressions have no tripwire.

**Current state (measured 2026-07-02).** The direct-assembly route is in
fact extremely cheap today — Mollusk-measured Counter baseline
(`--solana-elf`, 1336-byte ELF, loader v3, Mollusk 0.13.4):

| Entrypoint | Compute units |
|---|---:|
| `initialize` | 56 |
| `increment` | 63 |
| `get` (writes return data) | 163 |

That is Pinocchio-class efficiency (hand-optimized native Rust territory;
Anchor equivalents typically cost an order of magnitude more), which is
precisely the advantage a budget gate should lock in: today's numbers are
the baseline, and aggregates/maps/CPI-heavy lowering added later must not
silently erode them. `runtime.compute_units` helpers exist on Solana
(read/log CU), but no gate asserts a budget on any target and the testkit
RFC does not mention budgets yet.

**Recommendation.** Extend the testkit scenario schema (before M2/M3 land)
with optional per-step budgets: `expect.budget = { evm_gas = N,
solana_cu = N, near_gas = N }`, recorded as baselines with a tolerance band
rather than exact numbers. revm, Mollusk, and the NEAR host all expose the
counters already. Budget regressions fail like behavior regressions.

## Gap 4: Deployment lifecycle, upgrades, and signing — Workstream 32

**Why now.** Deploy manifests exist (EVM `proof-forge-deploy.json` with
chain profiles and constructor args; Solana deploy packages with program
keypairs), but the lifecycle *after* first deployment is unmodeled, and the
chains disagree violently: EVM immutability vs proxy patterns, Solana
program upgrade authority (and its revocation), NEAR code redeployment on
the same account, Aleo `@noupgrade`. The Intent API currently cannot express
"this contract is upgradeable by X" — meaning every backend picks an
implicit, divergent default. That is a semantic-silence bug of exactly the
kind the platform promises to reject. Key management is still an open
question from RFC 0001 and blocks the cloud-platform story (D-010).

**Current state.** First-deploy manifests only; no upgradeability intent; no
signing boundary (who holds deploy/upgrade keys, how CI/live gates get
funded keys — currently ad-hoc per smoke script).

**Recommendation.** An RFC defining an upgrade-policy intent
(`immutable | authority(key) | governance(ref)`) that each target either
lowers honestly (Solana upgrade authority, EVM immutable-or-documented-proxy,
NEAR account-key policy, Aleo `@noupgrade`) or rejects at compile time; plus
a signing boundary: ProofForge emits unsigned transactions/manifests, key
custody stays outside (wallet/KMS), live gates document their throwaway-key
convention.

## Gap 5: Portable runtime error model — Workstream 33

**Why now.** `assert`/`assertEq` carry optional messages, and each backend
already invents its own failure surface: EVM reverts (no revert-reason
encoding today), Solana custom program errors / log lines, NEAR panics, Psy
circuit assertion failures. Clients and the testkit need to assert *which*
error occurred; once three more backends harden divergent conventions,
unifying costs a breaking change on every one.

**Current state.** Diagnostics at compile time are excellent; runtime errors
are stringly and per-chain. Testkit RFC asserts success traces but has no
error-expectation vocabulary yet.

**Recommendation.** Small RFC: portable error codes at the IR level
(assertion id + optional user code), per-target encoding table (EVM
`revert` with a compact ABI encoding, Solana custom error codes, NEAR panic
payload, Psy assertion index), and `expect.error = <code>` in testkit
scenarios. Pairs naturally with FV-5 (checked-arithmetic trap semantics).

## Gap 6: Unified client generation (DX) — Workstream 33 (second half)

**Why now.** Solana already generates IDL + TypeScript clients
(`Backend/Solana/Client.lean`); EVM emits ABI JSON; NEAR/Psy/Aleo emit
nothing client-facing. The "one contract, many chains" story is only real if
the *application developer* gets one client interface. Waiting lets each
backend grow a different client idiom, repeating the allocator/testkit
divergence pattern at the DX layer.

**Current state.** Per-chain artifacts with no shared client schema; web3
smokes hand-write per-chain call code.

**Recommendation.** Plan (not build yet) a client-schema layer: one
JSON description of entrypoints/types/errors derived from `ContractSpec`
(the IDL generalized beyond Solana), from which per-chain TS adapters are
generated. Defer implementation until after testkit M3 — the testkit
encoding adapters (selector/instruction/Borsh mapping) are the same logic
and should be written once, then shared with client generation.

## Explicit non-goals to record (so they stop being implicit)

- **Cross-chain interop/bridging** (same contract instances talking across
  chains): out of scope for the platform's current phase; deploying to many
  chains ≠ connecting them. Should be stated in RFC 0001's non-goals when
  next amended.
- **Fuzzing/property-based testing:** a future testkit extension (the
  scenario model must not preclude generated step sequences), not a current
  workstream.
- **Compiler performance:** no planning needed until build times hurt;
  revisit when the fixture registry (Gap 1) lands and `lake build` cost is
  measurable per backend.
- **i18n automation:** translation currently requires manual sync when
  `OLLAMA_API_KEY` is absent; acceptable, tracked inside Workstream 24.

## Sequencing hooks

- Gap 1 (CLI) must be planned **before testkit M4** (Workstream 26).
- Gap 3 (budgets) must be planned **before testkit M2/M3** freeze the
  scenario schema, and before the Tier-0 parity gate (D-034) is declared.
- Gap 5 (errors) should land its scenario vocabulary together with Gap 3's
  schema change to avoid two schema migrations.
- Gaps 2 and 4 are independent of the testkit and can be planned in
  parallel by a docs-focused agent.
- Gap 6 waits for testkit M3 by design.
