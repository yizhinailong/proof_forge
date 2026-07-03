# ProofForge Testkit

`testkit/` is the experimental unified scenario runner from RFC 0007. It owns
artifact-behavior tests that should eventually replace one-script-per-target
smokes.

Current scope:

- scenario discovery from `testkit/scenarios/*.toml`
- `wasm-near` Counter execution through the existing deterministic
  `runtime/offline-host` wasmtime host
- `evm` Counter execution through an in-process `revm` harness that emits the
  portable IR Counter runtime bytecode, loads its artifact metadata selectors,
  and executes the same scenario steps as EVM transactions
- normalized observable trace parity between `wasm-near` and `evm` when both
  targets are selected for the same scenario
- `just testkit` and a CI gate

The testkit intentionally does not remove existing shell gates. Foundry and
Anvil remain the mature EVM runtime/deploy smokes; testkit is the portable
scenario layer for deterministic cross-target behavior comparison.

Run:

```sh
just testkit
```

Run only one target:

```sh
cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --target evm
cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --target wasm-near
```

List scenarios without executing them:

```sh
cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- list
```
