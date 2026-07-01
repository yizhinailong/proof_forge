# Aleo Leo Target

Status: **Spike (local smoke exists — `scripts/aleo/counter-smoke.sh`)**

Candidate target id: **`aleo-leo`**

This note records the first ProofForge classification for Aleo and the
implemented Road 1 spike. It does not add a Lean target profile yet; the spike
validates the Leo source-generation boundary before any code registry changes.

Primary deliverables:

- `ProofForge.Backend.Aleo.IR` lowers the portable IR `Counter` fixture to Leo.
- `proof-forge --emit-counter-ir-leo` emits `Counter.leo`.
- `Examples/Aleo/Counter.golden.leo` is the tracked golden fixture.
- `scripts/aleo/counter-smoke.sh` generates a Leo package, runs `leo build` and
  `leo test`, writes `proof-forge-artifact.json`, and validates the metadata.


Primary sources:

- [Aleo getting started](https://docs.aleo.org/build/getting-started)
- [Leo installation](https://docs.aleo.org/build/leo/documentation/getting_started/installation)
- [Aleo Instructions overview](https://docs.aleo.org/build/aleo-instructions/overview)
- [Public & Private State](https://docs.aleo.org/learn/core-concepts/public-and-private-state)
- [Programs](https://docs.aleo.org/learn/core-concepts/programs)
- [Transactions](https://docs.aleo.org/learn/core-concepts/transactions)
- [Leo finalization model](https://docs.aleo.org/build/leo/documentation/guides/finalization)
- [Leo CLI overview](https://docs.aleo.org/build/leo/documentation/cli/cli_overview)
- [leo build](https://docs.aleo.org/build/leo/documentation/cli/cli_build)
- [leo execute](https://docs.aleo.org/build/leo/documentation/cli/cli_execute)
- [leo test](https://docs.aleo.org/build/leo/documentation/cli/cli_test)

## Local Smoke

The Road 1 spike is validated end-to-end by:

```bash
./scripts/aleo/counter-smoke.sh
```

Prerequisites:

- Lean toolchain from `lean-toolchain` and a built `proof-forge` binary.
- `python3` for package/manifest helpers.
- `leo` CLI on `PATH` (tested with Leo 4.0.2); if `leo` is missing, the script
  reports the generated `Counter.leo` and exits with code `127`.

What it proves:

- Portable IR `ProofForge.IR.Examples.Counter` lowers to a Leo 4.0 program with
  a public `mapping`, `@noupgrade constructor`, and `fn ... -> Final` entry
  points whose `final` blocks read/write the mapping.
- Generated Leo source matches the tracked golden fixture
  `Examples/Aleo/Counter.golden.leo`.
- `leo build` produces Aleo Instructions (`build/main.aleo`) and ABI JSON
  (`build/abi.json`).
- `leo test` passes.
- `proof-forge-artifact.json` is produced and schema-validated.

What it does not prove:

- Private records, transitions, or proof generation.
- Direct Aleo Instructions generation.
- Devnet deployment or execute transactions.
- Cross-target equivalence with EVM/Psy Counter semantics.
- A standalone `.avm` bytecode file; the current `leo build` output embeds VM
  artifacts in the compiled package rather than emitting a separate file.

## Classification

Aleo is a ZK-native smart-contract L1. It is not the same kind of target as
Zcash, Psy/DPN, or Starknet.

The better first classification is:

```text
Aleo ZK application sourcegen target
  with Leo as the first source-generation boundary
  with Aleo Instructions as the lower-level compiler target
  with Aleo VM bytecode, prover/verifier artifacts, ABI, and transaction proofs
```

Aleo is "ZK" because program execution is split between:

- proof context: private, off-chain execution that can consume/create records
  and generate ZK proofs;
- finalization context: public, on-chain execution that reads/writes mappings,
  storage variables, and storage vectors.

That means Aleo is closer to a privacy-aware contract chain than to a plain ZK
circuit output target. ProofForge should model Aleo programs as deployable
program packages, not just as circuits.

## Why This Is Not The Same As Existing ZK Targets

Existing ProofForge ZK-related notes cover different shapes:

- `psy-dpn`: target source compiles to DPN circuit JSON artifacts.
- `zcash-shielded`: ZK proves protocol-defined shielded payment statements.
- `kaspa-toccata`: an L1 covenant may verify a proof inline or settle based-app
  state.
- `starknet-cairo`: Cairo contracts compile through Sierra/CASM; Starknet is
  not modeled as a generic circuit target.

Aleo needs its own family because:

- Leo programs are smart contracts with program ids, imports, entry functions,
  records, mappings, finalization logic, and deploy/execute transactions;
- private state uses records, which are encrypted and UTXO-like;
- public state uses mappings/storage updated by validators in `final` logic;
- execute transactions contain transitions and ZK proofs;
- build outputs include `.aleo` instructions, ABI, prover/verifier files, and
  Aleo VM bytecode;
- local validation can use `leo build`, `leo test`, `leo execute`, and devnet
  deployment flows.

## Candidate Target Family

Do not add this to `ProofForge.Target.Registry` until the target model can
express Aleo's proof/finalization split and record/mapping state split.

Candidate family:

```text
zk-app-sourcegen
```

Candidate backend pattern:

```text
ProofForge portable IR subset
  -> generated Leo package
  -> leo build
  -> Aleo Instructions (.aleo)
  -> Aleo VM bytecode + ABI + prover/verifier artifacts
  -> leo test / leo execute / leo devnet validation metadata
```

Direct Aleo Instructions generation is a later road. It is attractive for a
compiler backend, but Leo is the safer first artifact because it is the
recommended developer language and exposes program structure more clearly.

Candidate artifact shape:

```text
aleo-leo-package
  - generated Leo source
  - program id and imports
  - record / mapping / storage schema
  - proof-context entry functions
  - finalization manifest
  - compiled Aleo Instructions
  - AVM bytecode
  - ABI JSON
  - prover and verifier artifacts
  - execute/deploy transaction metadata
  - test/devnet validation result
```

## Candidate Capabilities

These are research candidates, not canonical capability ids yet.

| Candidate capability | Meaning |
|---|---|
| `lang.leo` | Target emits Leo source packages. |
| `ir.aleo_instructions` | Build emits or consumes Aleo Instructions. |
| `vm.aleo_avm` | Target runs on the Aleo VM, not Algorand AVM. |
| `artifact.avm` | Build emits Aleo VM bytecode. |
| `artifact.aleo_abi` | Build emits Aleo ABI metadata. |
| `proof.prover_key` | Build or execute flow produces prover artifacts. |
| `proof.verifier_key` | Build or deploy flow records verifier artifacts. |
| `execution.transition` | Entry execution produces a transition and proof. |
| `execution.finalize` | Program has public on-chain finalization logic. |
| `state.record` | Private state is held in encrypted records. |
| `state.mapping` | Public state is held in mappings. |
| `state.storage` | Public state may use storage variables or storage vectors. |
| `input.private` | Function input is private proof-context data. |
| `input.public` | Function input is public data. |
| `output.private` | Function output is private by default. |
| `output.public` | Function output is public. |
| `program.import` | Program imports and calls another Aleo program. |
| `program.upgrade` | Deployment may support explicit program upgrades. |
| `transaction.execute` | Validation can produce an execute transaction. |
| `transaction.deploy` | Validation can produce or inspect a deploy transaction. |
| `fee.credits` | Fees are paid in Aleo Credits, publicly or privately. |
| `test.leo` | Validation uses Leo tests. |
| `test.aleo_devnet` | Validation uses Leo devnet or devnode-backed flows. |

`zk.circuit` alone is not sufficient for Aleo. It may describe the proof aspect,
but Aleo also needs program, state, transaction, and finalization capabilities.

## Implementation Roads

### Road 1: Leo Sourcegen Package

Use this road first.

First spike:

- choose a tiny Counter-like program;
- generate Leo source with one entry `fn` and one `final { }` block;
- use a public `mapping` for the counter;
- run `leo build` and record `.aleo`, ABI, bytecode, and toolchain metadata;
- run `leo test`, with `--prove` as an optional heavier gate.

This validates the compiler boundary without taking responsibility for Aleo VM
internals.

### Road 2: Private Record Flow

Use this road to validate Aleo's ZK-specific value proposition.

First spike:

- define a simple private record type;
- consume one record and create one successor record in a proof-context entry
  function;
- keep record contents private while exposing only required public outputs or
  finalize effects;
- run `leo execute --print` or SDK-backed execution to inspect transaction and
  proof metadata.

This is the path that proves Aleo support is more than an account-chain source
generator.

### Road 3: Direct Aleo Instructions

Use this road only after Leo sourcegen proves the semantics.

First spike:

- lower a tiny typed IR fixture directly to `.aleo` instructions;
- preserve public/private input annotations;
- generate or validate prover/verifier artifacts through the official toolchain;
- compare output against Leo-generated Aleo Instructions for the same behavior.

This road is useful for compiler precision, but it has a larger semantic
surface than Leo sourcegen.

## Non-Goals For The First Pass

- Do not add `aleo-leo` to the code registry before candidate capabilities are
  reviewed.
- Do not classify Aleo as only a generic ZK circuit target.
- Do not confuse Aleo VM with Algorand AVM.
- Do not model records as EVM storage or as Zcash shielded notes.
- Do not model `final` blocks as private execution; finalization is public and
  on-chain.
- Do not claim full Aleo support until there is a reproducible local build/test
  command.
- Do not start with direct Aleo Instructions if Leo sourcegen is enough to
  validate the first spike.

## Research Exit Criteria

Aleo can leave Research only when we have:

- a reviewed target profile proposal;
- a committed capability proposal for Leo, Aleo Instructions, Aleo VM bytecode,
  transitions, finalization, records, mappings, proofs, ABI, fees, and devnet
  validation;
- a minimal artifact manifest schema for Leo source, compiled outputs,
  prover/verifier artifacts, ABI, and transaction/deploy metadata;
- a toolchain decision for local validation using Leo CLI, SDK, devnet, or
  devnode;
- one reproducible local command or script that validates a tiny Leo program
  package, even if proving-heavy gates are optional in CI.

**Status:** The Road 1 spike satisfies the reproducible local command and
artifact manifest schema criteria. The remaining criteria (target profile,
full capability proposal, devnet validation) stay open until private records
and transitions are reviewed.

## Research Exit Plan

A detailed design spec covering Research exit + Road 1 spike is in
[docs/superpowers/specs/2026-07-01-aleo-leo-design.md](../../superpowers/specs/2026-07-01-aleo-leo-design.md).

The spec finalizes:

- Target family: `zk-app-sourcegen`.
- Canonical capabilities for the first spike:
  `lang.leo`, `vm.aleo_avm`, `artifact.avm`, `artifact.aleo_abi`,
  `execution.finalize`, `state.mapping`, `input.public`, `output.public`,
  `test.leo`.
- Research-only capabilities for future spikes:
  `ir.aleo_instructions`, `proof.prover_key`, `proof.verifier_key`,
  `execution.transition`, `state.record`, `state.storage`, `input.private`,
  `output.private`, `program.import`, `program.upgrade`, `transaction.execute`,
  `transaction.deploy`, `fee.credits`, `test.aleo_devnet`.
- Artifact manifest schema for `aleo-leo-package`.
- Toolchain decision: `leo build` + `leo test` primary; prove/execute optional.
- Spike scope: Road 1 only, public mapping Counter from
  `ProofForge.IR.Examples.Counter`.

The Road 1 spike is implemented; code registry changes
(`ProofForge.Target.Capability` / `ProofForge.Target.Registry`) remain deferred
until the proof/finalization split and private-record roadmap are reviewed.
