# Formal Verification Roadmap

Status: **Draft (post-consolidation, 2026-07)**

ProofForge is Lean-first, but most of today's assurance comes from tests and
golden files rather than theorems. This page records where formal verification
can be added, what already exists after the 2026-07 branch consolidation, and
which proofs pay for themselves first. Tasks are tracked in
[implementation-backlog.md](implementation-backlog.md) (Workstream 25).

## What already exists

The NEAR work contributed the first three formal anchors, now on `main`:

| Anchor | Module | What it gives us |
|---|---|---|
| Executable IR semantics (scalar subset) | `ProofForge/IR/Semantics.lean` | A small-step/trace interpreter for the scalar IR subset that proofs can reference; used by the NEAR trace obligations |
| Ownership rules | `ProofForge/IR/Ownership.lean`, `Tests/IROwnership.lean` | Checker for `release`/owned-local discipline (no use-after-release, branch consistency), currently validated by tests |
| Backend trace obligations | `ProofForge/Backend/WasmNear/Refinement.lean`, `ProofForge/Backend/Evm/Refinement.lean`, `Tests/NearWasmFormal.lean` | `TraceObligation` with `decide`-checked theorems: the Counter IR trace matches expected observable values, EmitWat exports cover the trace entrypoints, and the EVM Yul surface contains selector-dispatched functions for the same trace |

These are the right shape: small executable definitions plus decidable
theorems, checked in CI without external tools.

## Verification targets, in priority order

### FV-1: Capability routing soundness (small, high value)

`ProofForge.Target.requireCapabilities` and `resolveSpec` are the platform's
core promise: *a contract that routes to a target only uses capabilities that
target supports*. Today this is a runtime check exercised by tests.

Prove, for the checked boundary:

- **Soundness:** if `resolveSpec profile spec = .ok plan`, then every
  capability in `plan.calls` is in `profile.capabilities`.
- **Completeness of rejection:** if the spec references a capability outside
  the profile, `resolveSpec` returns `.error`.
- **Target-extension isolation:** if any call carries `solana.*` metadata and
  the profile family is not `.solana`, resolution fails (D-027 enforced by
  theorem, not convention).

These are structural inductions over arrays; no semantics needed. They turn
the "reject rather than silently change semantics" principle (RFC 0001) into
a machine-checked invariant.

### FV-2: IR semantics coverage and metatheory

Extend `IR/Semantics.lean` from the scalar subset toward the checked IR
surface (maps, fixed arrays, structs, `ifElse`, `boundedFor`, events as
observable trace items), then state:

- **Determinism:** evaluation of a well-formed entrypoint body is
  deterministic (one trace per input/state).
- **Progress/preservation for the typed subset:** statements that pass the
  existing shape/type validation do not get stuck and preserve binding types.
- **Bounded termination:** `boundedFor` with static bounds always terminates
  (structurally true today; state it so future IR changes cannot break it).

This is the foundation everything else refines against. Keep it executable
(`decide`-friendly) so CI checks stay cheap.

### FV-3: Ownership/release soundness (connect FV-2 to `IR/Ownership.lean`)

The ownership checker currently passes 6 behavioral test cases. Once FV-2
gives release-aware semantics, prove: programs accepted by the ownership
checker never evaluate a released local and never release twice. This is the
formal justification for lowering `release` to allocator frees in EmitWat
while EVM/Psy reject it and TS ignores it — three different lowerings of one
IR construct are only safe if the IR-level discipline is proven.

### FV-4: Backend refinement obligations, one scenario at a time

Replicate the `TraceObligation` pattern per backend against the shared
scenario (Counter first, ValueVault second):

| Backend | Obligation shape | Feasibility |
|---|---|---|
| `wasm-near` / EmitWat | Exists (exports + IR trace); extend to Wasm-level evaluation of the emitted WAT through the offline host | High — offline host already executes the artifact deterministically |
| `evm` (IR → Yul plan) | Initial surface obligation exists (IR trace + selector-dispatched Yul functions); next, interpret the emitted Yul plan for the scenario (storage reads/writes, return words) and compare against the IR trace | Medium — needs a small Yul-subset interpreter in Lean; keeps `solc` out of the trusted path but not out of the build |
| `psy-dpn` | Compare `dargo execute` result vectors against IR trace outputs (differential gate, not a theorem) | Already close: smoke scripts assert `result_vm` values today |
| `solana-sbpf-asm` | Differential testing via Mollusk/Surfpool first; assembly-level semantics is a research track, not a near-term proof | Low for proofs, high for differential gates |
| `wasm-cloudflare-workers` | Differential HTTP-level gate only (off-chain host, D-033) | Not a proof target |

Rule of thumb: a backend earns "Experimental → Supported" only with (a) the
scenario differential gate and (b) at least the export/trace obligation
theorem, mirroring what `wasm-near` already has.

### FV-5: Checked arithmetic semantics per target

The SDK's checked operators (`+!`, `-!`, `*!`, `/!`) must mean the same thing
on a 256-bit EVM word, a 64-bit Wasm integer, and a field element in Psy.
State the intended semantics once in FV-2's value domain (trap on overflow /
division-by-zero as trace outcomes), then make each backend's lowering
obligation include the overflow branch. The EVM and Psy diagnostic suites
already test rejection paths; the theorems pin down accepted-path behavior.

### FV-6: Lowering equivalence for the two authoring surfaces

`contract_source` (Lean SDK) and the legacy `.learn` parser both lower to
`ContractSpec`. Today equivalence is enforced by paired fixtures. For the
covered subset, prove that parsing a `.learn` fixture and elaborating the
matching `contract_source` block produce equal `ContractSpec` values
(decidable equality already derives). This keeps the "Learn is frozen
compatibility, not a second language" policy honest, and makes drift a build
failure instead of a review judgment.

### FV-7: Token SDK plan invariants

`TokenSpec.planForTarget` invariants worth stating as theorems:

- Feature routing is total: every accepted feature set yields a plan or a
  planner diagnostic (no silent drops).
- Documented incompatibilities (e.g. `transfer_fee` + `non_transferable`)
  always produce the diagnostic.
- Solana plans reference only program ids and accounts declared in the plan
  itself (well-formedness of the emitted instruction sequence).

### FV-8: User-level contract invariants (product direction)

The long-term differentiator: let contract authors state invariants next to
`contract_source` (e.g. `balance = deposits - releases + fees` for
ValueVault) and prove them against the FV-2 semantics before codegen. This
needs no backend work — it is pure Lean over the IR semantics — and is the
first proof surface users see. Start with ValueVault as the worked example.

## Non-goals

- No proofs about `solc`, `wat2wasm`, `sbpf`, `leo`, or chain runtimes; those
  stay in the differential-testing trust boundary and are recorded per gate
  in [validation-gates.md](validation-gates.md).
- No proof-transport to chains (no on-chain verification of Lean proofs);
  proofs gate codegen, per RFC 0001.
- No attempt to verify the Lean elaborator or Lake; the trusted computing
  base is stated, not eliminated.

## Suggested sequencing

1. FV-1 capability soundness (structural, unblocks nothing, high trust value).
2. FV-2 semantics extension + determinism (foundation).
3. FV-3 ownership soundness (justifies the merged `release` lowerings).
4. FV-4 EVM Yul-subset trace obligation for Counter: extend the current EVM
   surface obligation with a small Yul-subset interpreter, proving the pattern
   generalizes beyond NEAR.
5. FV-6 authoring-surface equivalence for the fixture subset.
6. FV-5 / FV-7 as the respective surfaces stabilize; FV-8 once FV-2 lands.
