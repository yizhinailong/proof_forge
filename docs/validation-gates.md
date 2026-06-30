# Validation Gates

This page documents the runnable gates that validate ProofForge today and
separates them from gates that are planned but not yet implemented. It mirrors
actual scripts and `.github/workflows/ci.yml`; it does not add or edit CI jobs.

## Current gates

| Gate | Command | Prerequisites | What it proves | What it does not prove |
|---|---|---|---|---|
| Lean package build | `lake build` | Lean toolchain from `lean-toolchain` | Library roots typecheck and `proof-forge` links | Generated Yul/bytecode validity, external tools, runtime behavior |
| Yul generation smoke | `lake env proof-forge --root . -o build/counter.yul Examples/Evm/Contracts/Counter.lean` | Built `proof-forge` | Lean frontend/LCNF lowers a simple contract to Yul | `solc` acceptance, ABI dispatch, EVM runtime behavior |
| Yul-to-bytecode smoke | `solc --strict-assembly build/counter.yul --bin` | `solc` on `PATH` | Generated Yul is accepted by `solc` | Runtime semantics or method dispatch |
| Single EVM bytecode compile | `lake env proof-forge --evm-bytecode --root . --module contract -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean` | `solc`, `cast`, and `Examples/Evm/Contracts/Counter.evm-methods` | Lean → Yul → `solc` → bytecode with selector generation | Runtime behavior, gas, exhaustive ABI correctness |
| EVM examples compile | `scripts/evm/build-examples.sh` | `cast`, `solc`, `lake env proof-forge`; optional `PROOF_FORGE_BIN`, `CONTRACTS_DIR`, `EVM_OUT_DIR` | Every `.lean` contract with a sibling `.evm-methods` compiles to `.bin` | Runtime behavior; contracts without `.evm-methods` are skipped by the script |
| EVM runtime smoke | `scripts/evm/foundry-smoke.sh` | `forge`, `cast`, `solc`; optional `EVM_OUT_DIR`, `EVM_FORGE_DIR` | Foundry executes generated runtime bytecode for Counter, ArrayExample, SimpleToken, and VerifiedVault, including revert checks | Formal proof coverage, cross-target equivalence, real deployment, exhaustive edge coverage |
| CI baseline | `.github/workflows/ci.yml` `build-test` job | GitHub Actions Ubuntu, elan, Foundry stable, `solc` 0.8.30 | Clean-environment `lake build`, EVM compile, and Foundry smoke | Optional future targets, metadata validation, golden snapshots, non-Ubuntu behavior |

## Planned gates that are not runnable yet

The following gates are `Planned` and do not exist in CI or as scripts:

- `proof-forge build --target <id>` — unified target-oriented build command.
- `proof-forge test --target <id>` — unified target-oriented test command.
- `proof-forge-artifact.json` validation — artifact metadata schema validation.
- Golden Yul/output snapshots — regression detection via snapshot diffing.
- CosmWasm smoke — `cosmwasm-check` or `cw-multi-test` validation.
- Solana smoke — Mollusk or `solana-test-validator` validation.
- Move smoke — `aptos move compile/test` or Sui Move validation.
- Psy DPN smoke — generated `.psy` package plus `dargo compile` validation.
- Capability rejection tests — compile-time diagnostics for unsupported
  capability/target combinations.

## Upfront validation rule for new target work

Before a target exits `Research`, docs must name:

1. The external tools required.
2. The minimal artifact the target produces.
3. A local command or script that builds or validates the artifact.
4. The expected artifact path.
5. One observable success criterion.

If no runnable local command exists, the target remains `Research`.

## Optional external tools

Current CI installs Foundry stable and `solc` 0.8.30. Local machines may not
have `solc`, `cast`, `forge`, or `dargo`. Missing EVM tools block EVM toolchain
gates but not `lake build`. Missing `dargo` will block future `psy-dpn`
toolchain gates only.
