# ProofForge Testkit

`testkit/` is the experimental unified scenario runner from RFC 0007. It owns
artifact-behavior tests that should eventually replace one-script-per-target
smokes.

Current scope:

- scenario discovery from `testkit/scenarios/*.toml`
- `wasm-near` Counter execution through the existing deterministic
  `runtime/offline-host` wasmtime host
- `just testkit` and a CI gate

The first slice intentionally does not remove existing shell gates. M2 will add
the EVM/revm harness and the first cross-target trace comparison.

Run:

```sh
just testkit
```

List scenarios without executing them:

```sh
cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- list
```
