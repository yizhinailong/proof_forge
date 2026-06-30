# Development Standards

This page is the developer-facing standards index. It links existing
source-of-truth docs and states when they must be updated.

## Source of truth

| Topic | Authoritative doc |
|---|---|
| Documentation map | `docs/INDEX.md` |
| Settled architecture and roadmap decisions | `docs/decisions.md` |
| Accepted product / target direction | `docs/rfcs/0001-multichain-platform.md`, `docs/rfcs/0002-target-implementation-design.md` |
| Portable IR and runtime/capability lowering | `docs/portable-ir.md`, `docs/rfcs/0003-portable-ir-and-runtime.md` |
| Canonical capability ids and support matrix | `docs/capability-registry.md` |
| Target lifecycle and per-target notes | `docs/targets/README.md`, then the specific `docs/targets/*.md` note |
| EVM baseline details | `docs/targets/evm.md`, `Examples/Evm/README.md` |
| Shared cross-target Counter scenario | `docs/shared-scenario.md` |
| Execution backlog and acceptance criteria | `docs/implementation-backlog.md` |
| Milestone and validation log | `docs/development-log.md` |
| Validation commands and tool prerequisites | `docs/validation-gates.md` |
| Chinese narrative / strategy docs | `docs/zh/*.md`; they must align to English engineering docs and must not introduce independent engineering policy |

## RFC and decision policy

- RFCs start as `Draft`.
- RFCs become `Accepted` only when the decision is recorded in
  `docs/decisions.md` and linked docs are aligned, matching
  `docs/rfcs/README.md` lines 7-8.
- Superseded positions are recorded in `docs/decisions.md` under
  `Superseded Positions`.
- Do not change RFC status in this task unless the corresponding decision is
  already present in `docs/decisions.md`.

## Before changing code

1. Read `docs/INDEX.md`.
2. Read `docs/decisions.md` and the relevant RFC/target note.
3. If the change touches a public CLI flag, target id, capability id, artifact
   field, validation command, target lifecycle stage, or example contract
   behavior, update the nearest source-of-truth doc in the same change.
4. Run the narrow gate from `docs/validation-gates.md` that matches the touched
   boundary.

## Lean package conventions

- Lean toolchain is `leanprover/lean4:v4.31.0` from `lean-toolchain`.
- Base build gate is `lake build`.
- Current library roots are `ProofForge`, `ProofForge.Evm`, `ProofForge.Psy`,
  `ProofForge.Target`, `ProofForge.IR`, `ProofForge.Backend`,
  `ProofForge.Compiler.Yul.AST`, `ProofForge.Compiler.Yul.Printer`, and
  `ProofForge.Compiler.LCNF.EmitYul` from `lakefile.lean`.
- The executable is `proof-forge`, rooted at `ProofForge.Cli`, with
  `supportInterpreter := true` from `lakefile.lean` lines 16-19.
- New compiled Lean modules must be imported by an existing root or added to
  Lake roots before docs may claim they are part of the package.

## Current EVM conventions

- EVM contracts import `ProofForge.Evm` and `open Lean.Evm`.
- Exported contract entrypoints use `@[export l_<Contract>_<method>]` and must
  match either `--method` CLI flags or a sibling `.evm-methods` file.
- Capability names in EVM docs must reuse `docs/capability-registry.md` ids:
  `events.emit`, `crosscall.invoke`, `account.explicit`, `storage.pda`,
  `crosscall.cpi`. Do not introduce alternate ids such as `events.log`,
  `cross_call.contract`, or `account.container`.

## Planned behavior label

Any command, target, artifact field, or validation path not implemented in this
repository must be labeled `Planned` or `Research`, not written as current
behavior.
