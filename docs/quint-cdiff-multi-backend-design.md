# Quint C-diff multi-backend — feasibility assessment and design

Status: **Draft (research + design; minimal additive stub only)**

Date: 2026-07-07

Target phase: [RFC 0014](rfcs/0014-unified-semantic-lowering-contract.md) Phase 5, Path 5a
(Tier C-diff cross-backend rollout).

Companion documents:

- [RFC 0014](rfcs/0014-unified-semantic-lowering-contract.md) — the unified lowering contract;
  Tier C-diff is defined in the "Four tiers" table and Phase 5.
- [multi-backend-moduleplan-design.md](multi-backend-moduleplan-design.md) — the Tier B
  per-backend `*ModulePlan` audit (Phase 4), whose `*ModulePlan` artifacts are the
  prerequisite for stable C-diff replay.
- [shared-diagnostic-design.md](shared-diagnostic-design.md) — shared `LoweringDiagnostic`.

## 1. Purpose

RFC 0014 Tier C-diff is **differential trace replay**: the Quint MBT backend generates
ITF traces from the portable IR's formal semantics (`ProofForge.IR.Semantics`), and
those traces are replayed against each backend's *actual emitted artifact*
(bytecode/ELF/WAT/Move bytecode), comparing observable behavior. This catches divergence
between the IR's formal semantics and what the backend actually emits — a pragmatic
substitute for a full target-chain formal semantics (Tier C-proof).

Today C-diff covers **EVM only** (`just quint-evm-backend-replay-gate`,
`Tests/Quint/CounterEvmReplay.lean`, `ProofForge.Backend.Quint.EvmReplay.lean`). This
document audits every other backend for C-diff feasibility, picks the easiest next
candidate, specifies the abstract replay interface and the field-level design for the
chosen candidate's replay shim, and records what is deferred and why.

This is a **research + design** step. The only implementation artifact (optional,
additive) is a type-only `NearReplay.lean` stub that does not touch any existing replay
behavior or golden trace (see §7).

## 2. What Quint C-diff is today (the EVM reference)

### 2.1 The pipeline

The current EVM C-diff pipeline (`scripts/quint/evm-backend-replay-gate.sh` →
`Tests/Quint/CounterEvmReplay.lean`) is:

```text
IR.Semantics-derivable Quint model (.qnt)
  -- ProofForge.Backend.Quint.Lower.renderModule : IR.Module -> Scenario.Config -> String
  -> quint run --mbt --out-itf=<itf.json>          -- Quint generates ITF traces
  -> ITF.Trace                                       -- ProofForge.Backend.Quint.ITF.parse
  -> EvmReplay.renderFoundryTest                     -- Lean lowers the trace to a Foundry test
  -> forge test                                      -- Foundry executes against etched bytecode
  -> PASS/FAIL
```

The same ITF trace is *also* replayed through `ProofForge.IR.Semantics` directly
(`Tests/Quint/CounterReplay.lean` → `Replay.replayTrace`) — that is **Tier A** (IR
semantics self-replay). The EVM backend replay is **Tier C-diff**: the same trace is
replayed against the *real EVM artifact* (runtime bytecode etched via `vm.etch`,
executed by Foundry's EVM).

### 2.2 The replay interface — what `EvmReplay` provides

`ProofForge.Backend.Quint.EvmReplay.lean` does **not** execute the artifact itself. It
is a **trace → test-source renderer**: it lowers the ITF trace into a Solidity/Foundry
test that, when compiled and run by `forge`, replays the trace against the etched
bytecode. The observable comparison is "the contract's `get()` return value equals the
ITF-expected value after each step".

The shape is:

```lean
structure EvmReplayConfig where
  bytecodeHex : String           -- the emitted runtime bytecode (hex)
  contractAddress : String        -- where to etch it
  readSignature : String          -- Solidity getter used to read primary state
  primaryStateVar : String        -- ITF/IR state variable name being checked

def renderFoundryTest (irModule : IR.Module) (trace : ITF.Trace)
    (cfg : EvmReplayConfig) : Except EvmReplayError String
```

Key properties of the EVM shim:

1. **Trace-side (Lean):** pure functions over `IR.Module` + `ITF.Trace` that emit a
   target-specific test harness as a string. Reuses `Replay.resolveActionName`,
   `Replay.entrypointMap`, `Replay.buildArgs` from the shared `Replay.lean`.
2. **Artifact-side (external):** the actual execution happens in the target's native
   toolchain (`forge`), not in Lean. The Lean side only renders the harness that drives
   it.
3. **Observation:** a single primary scalar state variable is read back via a known
   getter signature and compared to the ITF-expected value. This is a *v1* limitation
   (see `EvmReplay.renderMutatingStep` — "EVM replay v1 does not encode entrypoint
   args").
4. **Comparison:** `assertEq(readState(target), <expected>)` after each step.

### 2.3 What the shared `Replay.lean` provides (trace interpretation)

`ProofForge.Backend.Quint.Replay.lean` is the **chain-neutral** trace interpreter used
by *both* Tier A (IR replay) and the trace-side of every C-diff shim. It provides:

- `ITF.Value → IR.Semantics.Value` conversion (`itfValueToIr`), including hashes,
  addresses, options.
- `buildInitialState : IR.Module → ITF.State → Except ReplayError State` — projects an
  ITF state into IR storage.
- `resolveActionName : IR.Module → Option String → List (String × ITF.Value) → Except
  ReplayError String` — maps `mbt::actionTaken` + nondet picks to an entrypoint name.
- `buildArgs : Entrypoint → List (String × ITF.Value) → Except ReplayError (Array
  IR.Semantics.Value)` — converts nondet picks to IR argument values.
- `entrypointMap : IR.Module → HashMap String Entrypoint` — sanitized-name lookup.
- `compareStates : State → State → Except ReplayError Unit` — full storage comparison.

A `*Replay` backend shim reuses all of these; it only adds the **artifact-side**
rendering (how to call the compiled artifact and how to read back the observable
state).

### 2.4 The Rust harness side

`testkit/harness-quint/src/lib.rs` (`run_mbt`) is the testkit driver: it checks `quint`
is available, builds `ProofForge.Backend.Quint.Replay`, then runs a Lean replay test
(`lake env lean --run <replay_test>`) and scans its stdout for `PASS` (or configured
needles). It is agnostic to which backend the replay test targets — it just runs the
named Lean file. So a new `*Replay.lean` test plugs into the same harness with a new
scenario TOML entry; no Rust changes are required to add a backend.

## 3. Audit method

For each target backend we ask:

1. **Executable artifact.** What does the backend emit that a C-diff replay could
   execute against? (bytecode/ELF/WAT/Move bytecode/Leo program/TS worker).
2. **Local execution environment.** Is there a deterministic execution environment
   available *locally* (no live network)? Foundry/Anvil for EVM, Mollusk for Solana,
   `runtime/offline-host` (wasmtime) for NEAR, `dargo execute` for Psy, `sui` CLI for
   Move-Sui, `leo` for Aleo, `wrangler`/node for Cloudflare.
3. **Replay shim shape.** What would the Lean-side `*Replay` module look like? Does it
   render a test harness (like EVM → Foundry), render a host invocation script (like
   NEAR → offline-host args), or render an in-process trace (like Mollusk)?
4. **State observation.** How is the primary state read back and compared to the ITF
   expected value? Does the artifact expose a getter, or must the shim read raw
   account/linear-memory/storage state?
5. **IR-trace → artifact-call mapping.** How cleanly do IR entrypoint calls map to
   artifact-level calls? (EVM: 1:1 via ABI selector; Solana: instruction discriminator +
   account meta + instruction data; NEAR: Wasm export + little-endian input bytes).
6. **Difficulty.** Easy / medium / hard, with evidence and blockers.

## 4. Per-backend feasibility table

| Backend | Executable artifact | Local exec env available? | Replay shim shape | IR→artifact call mapping | Difficulty | Recommended order |
|---|---|---|---|---|---|---|
| **EVM** ✅ | Runtime bytecode (hex) | Foundry `forge test` (etched bytecode) | Render Foundry `.t.sol`; `forge` executes | ABI selector via `abi.encodeWithSignature` | Done | — |
| **NEAR (WasmNear)** | WAT → `.wasm` (via `wat2wasm`) | `runtime/offline-host` (wasmtime, in-tree) — runs WAT exports directly, no external RPC | Render offline-host CLI args (`run <wat> <exports...> --inputs-hex <...>`); offline-host executes | Wasm export name = entrypoint name; args = little-endian bytes (matches `portable_input_bytes_le`) | **Easy** | **1st** |
| **Solana** | sBPF ELF `.so` (via `sbpf build`) | Mollusk (Rust crate, in `testkit/harness-solana`) — local sim, no network; needs `sbpf` + `solana-keygen` (installed here) | Render Mollusk invocation as a Rust test OR render a testkit scenario TOML; Mollusk executes | Instruction discriminator (1-byte tag from manifest) + account meta + instruction-data byte stream | **Medium** | 2nd |
| **Psy** | Psy module (executed by `dargo`) | `dargo execute` — **not installed here** per AGENTS.md | Render `dargo execute` invocation script | Psy entrypoint → dargo call | **Medium** (blocked on tool) | 3rd (deferred) |
| **Move-Sui** | Move source module | `sui` CLI (installed here) — but no real lowering; Counter MVP template only | n/a — no real artifact to replay against | n/a | **Hard** (no real lowering) | Deferred |
| **Aleo** | Leo program | `leo` CLI (installed here) — but research spike only | Render `leo run` invocation | Leo transition → entrypoint | **Hard** (research spike) | Deferred |
| **Cloudflare** | TS worker | `wrangler`/`node` (installed here) — but research spike only | Render worker invocation | Worker fetch handler | **Hard** (research spike) | Deferred |
| **CosmWasm** | WAT → `.wasm` | wasmtime/host (not installed) | Clone NEAR pattern | CosmWasm execute msg | **Medium** (no env) | Deferred |

**Summary:** NEAR is the clear next candidate. Its execution environment
(`runtime/offline-host`) is *in-tree*, already used by `just wasm-near-plan` and the
NEAR testkit harness, needs no external RPC, and its CLI interface is a simple
`run <wat> <export> [--inputs-hex <...>]` — the Lean shim just renders that argument
list. Solana is second (Mollusk is in-tree as a Rust dependency and the tools are
installed, but the account-model translation is more involved).

## 5. Chosen next candidate: NEAR (WasmNear)

### 5.1 Why NEAR is easiest — evidence

1. **The execution environment is in-tree.** `runtime/offline-host/` is a wasmtime-based
   host that runs a NEAR WAT module's exports directly, with deterministic inputs
   (`--inputs-hex`, `--attached-deposit`, `--block-timestamp`, etc.) and parses
   `call N:<name>: return_hex=... return_u64=...` lines from stdout. It is already used
   by `scripts/near/emitwat-ci-smoke.sh` and the NEAR testkit harness. No external RPC,
   no `wasmtime` CLI needed (it's a Cargo dependency).
2. **The CLI interface is a flat argument list.** `offline-host run <wat> <export1>
   <export2> ... --inputs-hex <hex1>,<hex2>,...` — exactly the shape a Lean string
   renderer produces. Compare with EVM, which must render a full Solidity test contract.
3. **The IR→artifact call mapping is clean.** NEAR Wasm exports are named after IR
   entrypoints (`ep.name`), and inputs are little-endian-encoded argument bytes
   (`portable_input_bytes_le` already used by the testkit). The offline-host returns
   `return_hex`/`return_u64`/`return_bool`/`return=<none>` per call, which maps to
   `IR.Semantics.Value`.
4. **The WAT artifact is already gated.** `Examples/WasmNear/Counter.golden.wat` and
   `ValueVault.golden.wat` pin byte-stable output; `just wasm-near-plan` and
   `just near-plan-smoke` gate the plan surface. The `NearModulePlan` (Phase 4 Step A)
   makes the layout inspectable. A C-diff replay consumes the *emitted WAT*, not the
   plan — but the plan is what makes the WAT stable enough for trace-level diffing.
5. **`quint` and `wat2wasm` are installed here.** The full pipeline (Quint MBT → ITF →
   Lean shim → offline-host) can run end-to-end in this environment — though the
   offline-host runs WAT directly (it compiles via wasmtime internally), so `wat2wasm`
   is not even strictly required for the replay shim.

### 5.2 What the shim does NOT do

- It does **not** execute the WAT itself (the offline-host does that).
- It does **not** change `Replay.lean`, `EvmReplay.lean`, or any existing golden trace.
- It does **not** require a live NEAR network or `near` CLI.

## 6. Abstract replay interface (generalizing from `EvmReplay`)

Generalizing the EVM shim, every C-diff `*Replay` module provides:

```lean
-- per-backend config: how to find and drive the artifact
structure <Target>ReplayConfig where
  artifactPath : String          -- path to the emitted artifact (bytecode/WAT/ELF/...)
  -- per-backend fields: how to read back primary state (getter signature,
  -- account data offset, Wasm export, ...)

-- per-backend error
structure <Target>ReplayError where
  message : String

-- Render the trace as a *target-specific harness* that, when executed by the
-- target's native toolchain, replays the trace against the artifact and compares
-- observable state. The return type is a string (a test file, a CLI arg list, a
-- script, ...).
def renderReplayHarness (irModule : IR.Module) (trace : ITF.Trace)
    (cfg : <Target>ReplayConfig) : Except <Target>ReplayError String

-- (optional) Parse the harness-execution stdout and compare to ITF expectations.
-- For EVM this is done inside the generated Foundry test (assertEq); for NEAR
-- the offline-host stdout is parsed by the testkit. Both are valid; the contract
-- is "the harness + its executor produce a PASS/FAIL signal".
```

The chain-neutral pieces (`resolveActionName`, `buildArgs`, `entrypointMap`,
`itfValueToIr`, `buildInitialState`, `compareStates`) stay in `Replay.lean` and are
imported by every shim. A shim only adds:

1. **Config** — where the artifact lives and how to observe state.
2. **`renderReplayHarness`** — lower `(IR.Module, ITF.Trace, Config)` to a string that
   drives the target toolchain.
3. **Observation** — how the harness reads back the primary state (a getter call, a
   storage read, a return-value decode) and compares it to the ITF expected value.

This is intentionally *not* a Lean typeclass: each backend's harness shape (Solidity
file vs CLI arg list vs Rust test) differs too much, and the EVM shim already shows
that a per-backend module with shared helpers is enough. A typeclass encoding is a
Phase 7 open question (inherited from RFC 0014).

## 7. Field-level design: `NearReplay`

### 7.1 Config

```lean
structure NearReplayConfig where
  watPath : String                -- path to the emitted WAT artifact
  -- The offline-host reads back state by *calling* an exported getter and decoding
  -- its return value; there is no direct linear-memory introspection in the shim.
  primaryStateExport : String     -- Wasm export used to read primary state (e.g. "get")
  primaryStateVar : String        -- ITF/IR state variable name being checked (e.g. "count")
```

This mirrors `EvmReplayConfig` (`readSignature` / `primaryStateVar`) but with a Wasm
export name instead of a Solidity signature.

### 7.2 State representation

The offline-host is stateful *across calls within one invocation* (it persists the
Wasm store between exports in the same `run` command). So a trace is replayed as a
*single* offline-host invocation with the trace's calls in order:

```text
offline-host run <wat> <export1> <export2> ... <exportN> --inputs-hex <hex1>,<hex2>,...,<hexN>
```

Each `export_i` is the trace step's entrypoint name; `hex_i` is the little-endian
encoding of that step's IR arguments (empty for nullary entrypoints). The offline-host
prints one `call i:<name>: return_hex=...` line per call; the shim (or a wrapping test)
parses these and compares `return_u64` (or `return_hex`) to the ITF-expected value.

This is simpler than EVM: EVM renders a *Solidity test file* and runs `forge`; NEAR
renders a *CLI arg list* and runs `offline-host`. Both are "render a string that drives
the target toolchain".

### 7.3 IR-level trace step → artifact-level call mapping

For each ITF state after the first:

1. `actionName ← resolveActionName module state.actionTaken state.nondetPicks`
   (shared `Replay`).
2. `entrypoint ← entrypointMap module |>.get? actionName` (shared `Replay`).
3. `args ← buildArgs entrypoint state.nondetPicks` (shared `Replay`) — `Array
   IR.Semantics.Value`.
4. `inputBytes ← encodeArgsLe args` — encode each arg as little-endian bytes
   (`IR.Semantics.Value → ByteArray`), concatenated. This is the NEAR-specific step;
   it mirrors `ScenarioStep.portable_input_bytes_le` in the testkit core.
5. The rendered call is just `actionName` (the export name) with its hex appended to
   the `--inputs-hex` comma-list.

The `init` action is special-cased: NEAR's `initialize` is a normal export (unlike
EVM's `initialize()` which must reset state); the offline-host persists state across
calls, so `init` just runs first and sets the primary state to 0.

### 7.4 Observation and comparison

Two options, in increasing fidelity:

- **v1 (single-scalar, mirrors EVM v1):** after each mutating step, append a
  `primaryStateExport` call (e.g. `get`) to the export list with no inputs, and compare
  the offline-host's `return_u64` for that call to the ITF-expected value of
  `primaryStateVar`. This is exactly the EVM v1 shape (read-back-after-each-step) and
  is the recommended first cut.
- **v2 (full state diff):** parse the offline-host's full call log and compare every
  state variable. Deferred — requires the offline-host to expose storage state, which
  it does not today (it only returns call outputs).

v1 is the design in this document. It is tractable, additive, and mirrors the EVM
shim's proven shape.

### 7.5 Rendering shape

```lean
def renderOfflineHostArgs (irModule : IR.Module) (trace : ITF.Trace)
    (cfg : NearReplayConfig) : Except NearReplayError String := do
  -- produces a single string: "run <wat> <export1> <export2> ... --inputs-hex <...>"
  -- with a trailing getter call after each mutating step (v1)
```

The wrapping Lean test (`Tests/Quint/CounterNearReplay.lean`, future) would:

1. emit the Quint model, run `quint run --mbt --out-itf`;
2. emit the WAT (`Tests/EmitWatSmoke.lean` path or `proof-forge emit --target
   wasm-near`);
3. call `NearReplay.renderOfflineHostArgs` to get the arg list;
4. spawn `cargo run --manifest-path runtime/offline-host/Cargo.toml -- <args>`;
5. parse stdout and compare each read-back call's `return_u64` to the ITF expected
   value;
6. print `PASS`/`FAIL`.

### 7.6 What is NOT in the stub (this step)

The stub delivered here (§8) contains only the **type definitions** and a trivial
construction smoke. It does *not*:

- render the full arg list,
- spawn the offline-host,
- wire into CI,
- touch `Replay.lean` or `EvmReplay.lean`.

Those are follow-ups (Step B), gated on the stub compiling cleanly and a parity smoke
passing.

## 8. Optional stub: `NearReplay.lean` (this step)

Because NEAR is confirmed easy and the stub is purely additive (no existing replay
behavior changes), this step delivers a minimal type-only stub:

- `ProofForge/Backend/Quint/NearReplay.lean` — `NearReplayConfig`,
  `NearReplayError`, the arg-encoding helpers (`encodeArgLe`), and a
  `renderOfflineHostArgs` skeleton that builds the arg list for a trace (v1 shape:
  mutating step + trailing getter). It reuses `Replay.resolveActionName` /
  `Replay.entrypointMap` / `Replay.buildArgs` and `ITF.parse`.
- `Tests/Quint/NearReplaySmoke.lean` — constructs a `NearReplayConfig` and renders a
  small synthetic trace's arg list, asserting the arg string contains the expected
  export names. Does **not** spawn `quint` or the offline-host; pure string check.
- `justfile` recipe `quint-near-replay-smoke`, wired into `just check` is **not** added
  (the constraint says do not wire into CI if it can't run end-to-end here; the smoke
  is a pure-Lean string check, so it *can* run here, but we keep it out of `just check`
  to avoid expanding the default gate surface without a parity decision — it is a
  standalone recipe instead).

The stub is **not** wired into any `*-backend-replay-gate.sh`. It only proves the shim
types can be built and the arg-list renderer is deterministic.

## 9. Migration / growth path

```text
EVM (done)  ->  NEAR (this step, stub)  ->  Solana  ->  Psy  ->  (research spikes)
```

- **NEAR (Step B, follow-up):** implement the full `renderOfflineHostArgs` + the
  `CounterNearReplay.lean` test that spawns `quint` + offline-host, add
  `scripts/quint/near-backend-replay-gate.sh` + `just quint-near-backend-replay-gate`,
  wire into `just quint-ir-model-gate` after parity.
- **Solana (2nd):** `SolanaReplay.lean` renders a Mollusk invocation. Two sub-options:
  (a) render a Rust test file that calls `mollusk_svm::Mollusk` directly (mirrors EVM's
  Solidity test rendering), or (b) render a testkit scenario TOML and reuse the existing
  `testkit/harness-solana` Mollusk path. Option (b) is more reusable but couples the
  shim to the testkit scenario format; option (a) is more self-contained. The
  account-model translation (instruction discriminator from manifest + account meta +
  instruction-data bytes) is the main extra work vs NEAR. The `SolanaModulePlan`
  (Phase 2, landed) already exposes the discriminator/account schema, so the shim can
  read the plan instead of re-deriving.
- **Psy (3rd, deferred on tool):** `PsyReplay.lean` renders a `dargo execute` script.
  Blocked on `dargo` not being installed here per AGENTS.md. Design-only until the tool
  is available; the shim shape is straightforward (Psy entrypoint → dargo call).
- **Move-Sui / Aleo / Cloudflare (deferred, research spikes):** these backends have no
  real lowering (Move-Sui is a Counter MVP template; Aleo/Cloudflare are research
  spikes). A C-diff replay requires a real artifact to replay against, which requires a
  real lowering first. Deferred to Phase 6+ per the Tier B multi-backend design.

Each backend adds: one `*Replay.lean`, one `Tests/Quint/*Replay.lean`, one
`scripts/quint/*-backend-replay-gate.sh`, one `justfile` recipe. The shared
`Replay.lean` and the testkit Quint harness are unchanged.

## 10. Deferred backends — rationale

### 10.1 Psy (deferred — 3rd)

`dargo` is not installed in this environment (per AGENTS.md, `just psy-all` needs
`dargo`). The Psy backend has a real lowering and a `PsyModulePlan`, so the *design* is
feasible, but the execution environment is not available here. A `PsyReplay.lean` stub
could be written design-only, but unlike NEAR there is no in-tree executor to validate
even the stub against. Deferred until `dargo` is installable or a parity host exists.

### 10.2 Solana (deferred to 2nd, not this step)

Solana is feasible (Mollusk is in-tree as a Rust crate, `sbpf` + `solana-keygen` are
installed). It is **not** chosen as the *first* follow-up only because the
account-model translation adds meaningful complexity (instruction discriminator,
account meta list, instruction-data byte layout) that NEAR avoids (NEAR exports map
1:1 to entrypoints and inputs are a flat byte stream). The `SolanaModulePlan` already
exposes the discriminator and account schema, so a `SolanaReplay` shim can read the plan
— this is the recommended 2nd step.

### 10.3 Move-Sui (deferred — research spike)

`Move/Sui.lean` is a hardcoded Counter MVP template (~80 LOC of string interpolation).
There is no real lowering, no `Ctx`, no plan. A C-diff replay needs a real artifact to
replay against; the MVP template cannot consume arbitrary IR modules. A `SuiModulePlan`
must precede a real Move lowering (Phase 6+ per the Tier B design). Deferred.

### 10.4 Aleo (deferred — research spike)

`Aleo/IR.lean` lowers to a Leo program via `Compiler.Leo.Emit`. `leo` is installed, but
the backend is a research spike (not in `--list-targets` registry; CLI-only via
`emit --target aleo-leo`). A `LeoReplay` shim would render a `leo run` invocation, but
the Leo execution model (circuit-based) differs enough from IR semantics that the
observable comparison is not straightforward. Deferred.

### 10.5 Cloudflare (deferred — research spike)

No `ProofForge/Backend/Cloudflare` directory exists; the Cloudflare workers backend is
a research spike listed in AGENTS.md but not present as a backend module. Deferred
until a real backend module exists.

### 10.6 CosmWasm (deferred — no local env)

CosmWasm would clone the NEAR WAT pattern, but there is no local wasmtime/host executor
for CosmWasm in-tree (the testkit has no CosmWasm harness). Deferred until a local
executor exists.

## 11. RFC 0014 update summary

RFC 0014 Tier C-diff (en + zh) is updated to:

- Record the audit results: EVM is the only backend with C-diff coverage today; NEAR
  is the chosen next candidate; Solana is 2nd; Psy is 3rd (tool-blocked); Move-Sui /
  Aleo / Cloudflare are deferred (research spikes / no real lowering).
- Record the abstract replay interface (config + `renderReplayHarness` + observation),
  generalizing from `EvmReplay`, and note that the shared `Replay.lean` is the
  chain-neutral trace interpreter every shim reuses.
- Point to this document for the per-backend feasibility table and the field-level
  `NearReplay` design.
- Note the minimal additive stub (`NearReplay.lean` + smoke) and that it is not wired
  into CI.
- Keep Phase 5 Path 5a scope as a *plan + stub*, not a full implementation.

## 12. Open questions

- Should `NearReplay` v1 read back state after *every* mutating step (mirroring EVM v1)
  or only at trace end? Recommendation: after every step (matches EVM v1, catches
  mid-trace divergence).
- Should the offline-host grow a `--expect` flag so the comparison happens in-process
  (closer to EVM's in-test `assertEq`) rather than the Lean test parsing stdout?
  Recommendation: keep stdout parsing for v1 (no offline-host changes); revisit in v2.
- Should `SolanaReplay` render a Rust test (option a) or a testkit scenario TOML
  (option b)? Recommendation: option (a) for self-containment, revisit if the testkit
  scenario path proves reusable.
- Should the abstract replay interface become a Lean typeclass? Inherited open
  question from RFC 0014 Phase 7; the per-backend harness shapes differ enough that a
  typeclass is not obviously worth it yet.

## 13. Non-goals

- **Executing the NEAR artifact in Lean.** The offline-host (wasmtime) executes it; the
  shim only renders the arg list.
- **Changing `Replay.lean` or `EvmReplay.lean`.** The stub is additive and imports the
  shared replay helpers unchanged.
- **Wiring a new gate into `just check` or CI.** The stub is a standalone smoke; full
  wiring is Step B.
- **Tier C-proof.** This is differential testing (Tier C-diff), not a proof.
- **A single global `*Replay` type.** Each backend's shim is target-specific, mirroring
  RFC 0004's non-goal on plan types.

## 14. References

- [RFC 0014](rfcs/0014-unified-semantic-lowering-contract.md) — Tier C-diff definition
  (Four tiers table), Phase 5 Path 5a.
- `ProofForge/Backend/Quint/Replay.lean` — chain-neutral trace interpreter
  (`replayTrace`, `resolveActionName`, `buildArgs`, `buildInitialState`,
  `compareStates`, `itfValueToIr`).
- `ProofForge/Backend/Quint/EvmReplay.lean` — the reference C-diff shim
  (`EvmReplayConfig`, `renderFoundryTest`).
- `ProofForge/Backend/Quint/ITF.lean` — ITF trace parsing.
- `ProofForge/Backend/Quint/Lower.lean` — IR → Quint model rendering.
- `scripts/quint/evm-backend-replay-gate.sh` — the EVM C-diff gate.
- `scripts/quint/mbt-replay-gate.sh` — the Tier A IR-replay gate.
- `scripts/quint/ir-model-gate.sh` — the unified gate (emit + verify + MBT + IR replay +
  EVM backend replay).
- `testkit/harness-quint/src/lib.rs` — `run_mbt` (testkit driver, backend-agnostic).
- `testkit/harness-near/src/lib.rs` — NEAR testkit harness (offline-host invocation
  shape).
- `testkit/harness-solana/src/lib.rs` — Solana testkit harness (Mollusk invocation
  shape).
- `runtime/offline-host/src/main.rs` — the wasmtime-based NEAR WAT executor.
- `ProofForge/Backend/WasmNear/NearModulePlan.lean` — the NEAR Tier B plan (Phase 4
  Step A stub).
- `ProofForge/Backend/Solana/Plan.lean` — the Solana Tier B plan (Phase 2, landed).
- `Tests/Quint/CounterEvmReplay.lean` — the EVM C-diff test (reference shape).
- `Tests/Quint/CounterReplay.lean` — the Tier A IR-replay test (reference shape).