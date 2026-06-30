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
| Psy Counter IR smoke | `scripts/psy/counter-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Counter portable IR lowers to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON with `dargo compile`, returns `result_vm: [2]` through `dargo execute`, emits non-empty ABI JSON, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Deploy JSON, live Psy node/prover behavior, broader IR coverage |
| Psy ContextProbe IR smoke | `scripts/psy/context-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Non-Counter Psy IR lowers parameters and context reads to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [15]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Maps, arrays, hashes, deploy JSON, live Psy node/prover behavior |
| Psy HashProbe IR smoke | `scripts/psy/hash-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers `Hash`, typed hash let-bindings, `hash`, and `hash_two_to_one` to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns the expected four-Felt hash outputs through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Maps, storage maps, deploy JSON, live Psy node/prover behavior |
| Psy MapProbe IR smoke | `scripts/psy/map-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers fixed-capacity `Map<Hash, Hash, N>` storage and `contains`/`get`/`insert`/`set` effects to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [55, 66, 77, 88]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Bounded loops, arrays, structs, assertions, deploy JSON, live Psy node/prover behavior |
| Psy AssertProbe IR smoke | `scripts/psy/assert-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers statement-level `assert` and `assert_eq` into generated method bodies, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [12]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Bounded loops, arrays, structs, deploy JSON, live Psy node/prover behavior |
| Psy LoopProbe IR smoke | `scripts/psy/loop-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers static bounded `for` loops into generated method bodies, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [3]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Arrays, structs, deploy JSON, live Psy node/prover behavior |
| Psy ArrayProbe IR smoke | `scripts/psy/array-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers fixed-array value types, array literals, index reads, and fixed storage array index read/write effects to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [60]` and `result_vm: [31]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Struct arrays, nested arrays, deploy JSON, live Psy node/prover behavior |
| Psy StructProbe IR smoke | `scripts/psy/struct-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers struct declarations, struct literals, field access, scalar storage struct assignment, and scalar storage struct field read/write effects to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [30]` and `result_vm: [26]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Struct arrays, nested structs, deploy JSON, live Psy node/prover behavior |
| Psy StructArrayProbe IR smoke | `scripts/psy/struct-array-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers fixed arrays of structs, storage arrays of structs, whole struct element writes, and indexed struct field read/write effects to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [100]` and `result_vm: [102]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Deeply nested mixed aggregate updates, deploy JSON, live Psy node/prover behavior |
| Psy AbiAggregateProbe IR smoke | `scripts/psy/abi-aggregate-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers ABI-facing struct parameters, fixed-array parameters, and struct returns to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [15]`, `result_vm: [6]`, and `result_vm: [9, 4]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Deeply nested mixed aggregate updates, deploy JSON, live Psy node/prover behavior |
| Psy NestedAggregateProbe IR smoke | `scripts/psy/nested-aggregate-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers mutable local aggregate bindings and nested assignment paths such as `families[1].children[0].age = 31`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [51]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Storage-backed nested aggregate updates, deploy JSON, live Psy node/prover behavior |
| Psy StorageNestedAggregateProbe IR smoke | `scripts/psy/storage-nested-aggregate-smoke.sh` | `dargo` on `PATH`; `python3`; `psyup install 0.1.0` is known-good on macOS arm64 | Psy IR lowers generic storage paths across scalar storage structs, nested `#[ref]` fields, and storage arrays to `.psy`, matches the golden fixture, passes `dargo test --file`, produces non-empty DPN JSON and ABI JSON, returns `result_vm: [220]` through `dargo execute`, writes `proof-forge-artifact.json`, and validates metadata hashes/capabilities/results | Map storage paths, deploy JSON, live Psy node/prover behavior |
| Psy diagnostic smoke | `scripts/psy/diagnostic-smoke.sh` | Lean toolchain from `lean-toolchain` | Unsupported or malformed Psy IR shapes fail before source generation with explicit diagnostics for Unit parameters, zero-length ABI arrays, unknown ABI structs, unsupported map shapes, non-storage structs, empty structs, invalid bounded loops, effect expression/statement misuse, invalid assignment targets, and invalid storage paths | Exhaustive unsupported-surface coverage, Dargo behavior, deploy JSON |
| CI baseline | `.github/workflows/ci.yml` `build-test` job | GitHub Actions Ubuntu, elan, Foundry stable, `solc` 0.8.30 | Clean-environment `lake build`, Psy golden source snapshots for Counter/ContextProbe/HashProbe/MapProbe/AssertProbe/LoopProbe/ArrayProbe/StructProbe/StructArrayProbe/AbiAggregateProbe/NestedAggregateProbe/StorageNestedAggregateProbe, Psy diagnostic smoke, EVM compile, and Foundry smoke | Optional Dargo target smokes, metadata validation, non-Ubuntu behavior |

## Planned gates that are not runnable yet

The following gates are `Planned` and do not exist in CI or as scripts:

- `proof-forge build --target <id>` — unified target-oriented build command.
- `proof-forge test --target <id>` — unified target-oriented test command.
- Non-Psy `proof-forge-artifact.json` validation — artifact metadata schema
  validation for targets that do not yet write metadata.
- Golden Yul/output snapshots — regression detection via snapshot diffing.
- CosmWasm smoke — `cosmwasm-check` or `cw-multi-test` validation.
- Solana smoke — Mollusk or `solana-test-validator` validation.
- Move smoke — `aptos move compile/test` or Sui Move validation.
- Cross-target capability rejection matrix — compile-time diagnostics for
  unsupported capability/target combinations beyond the Psy diagnostic smoke.

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
have `solc`, `cast`, `forge`, `psyup`, or `dargo`. Missing EVM tools block EVM
toolchain gates but not `lake build`. Missing Psy tools block only the Psy
smoke Dargo portions; source generation and golden diff still run before each
script exits.
