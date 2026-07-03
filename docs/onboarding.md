# Contributor Onboarding

This page is the shortest path from a clean checkout to a useful local
ProofForge development loop. It is intentionally practical: install the shared
tools first, run the smallest gates, then add target-specific tools only when
you work on that target.

## Current Product Focus

ProofForge is under the primary-chain completion covenant (D-045). Product
implementation work is reserved for these targets, in this order:

1. `solana-sbpf-asm`
2. `evm`
3. `wasm-near`

Other target notes may receive documentation, security, or CI maintenance, but
they should not gain new registry stage, capability surface, testkit coverage,
or product scope until Gate P0 closes.

## Required Tools

Install these for normal development:

- `elan`, using the repo-pinned `lean-toolchain`.
- `just`, which is the command catalog used by local development and CI.
- `python3`, used by docs and validation scripts.
- Rust/Cargo, used by the unified testkit and several target harnesses.

Recommended editor setup:

- VS Code or Cursor with the official `leanprover.lean4` extension.
- Open the repository root, not a subdirectory, so Lake, imports, and
  `lean-toolchain` resolve consistently.
- Let the extension use the repo toolchain through `elan`; do not override the
  Lean version per workspace.

## First Local Pass

```sh
elan show
lake build
just --list
just check
scripts/i18n/check-sync.sh
git diff --check
```

`just check` is the normal fast gate. It runs the common build, diagnostics,
coverage, and smoke slices that CI expects without requiring every live-chain
tool.

## Target-Specific Tools

Install these only when working on the matching target or gate:

| Target area | Tools |
|---|---|
| EVM | Foundry (`cast`, `forge`), `solc` |
| Solana | `sbpf`, Solana CLI, `solana-keygen`, Node/npm for Web3.js smokes, Surfpool for live local tests |
| Wasm/NEAR | `wat2wasm`; NEAR sandbox only for live deployment work |
| Psy/DPN | `psyup`, `dargo` |
| Aleo | `leo` |
| Cloudflare Workers | Node/npm, `wrangler` |

The authoritative command list and prerequisites are in
[validation-gates.md](validation-gates.md). If a tool is missing, many scripts
skip that optional branch and still validate the generated source, metadata, or
diagnostics.

## Working Rules

- Before changing code, read [development-standards.md](development-standards.md)
  and the nearest source-of-truth doc for the touched boundary.
- Keep English engineering docs authoritative. Chinese `.zh.md` translations
  are synchronized from the English docs on `main`.
- Public CLI flags, target ids, capability ids, artifact fields, validation
  commands, target lifecycle stages, or example behavior changes must update
  the matching docs in the same change.
- Run the narrow gate first, then `just check`, then broader target gates only
  when the change touches that target.
