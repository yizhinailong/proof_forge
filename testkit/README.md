# ProofForge Testkit

`testkit/` is the experimental unified scenario runner from RFC 0007. It owns
artifact-behavior tests that should eventually replace one-script-per-target
smokes.

Current scope:

- scenario discovery from `testkit/scenarios/*.toml`
- scenario manifest validation that rejects empty or duplicate target ids and
  artifact checks for targets not declared by the scenario
- typed scalar scenario args (`u64`, `u32`, `bool`) that each harness encodes
  into its native ABI (`Borsh`/little-endian input for `wasm-near`, ABI words
  for `evm`, and `[tag] + little-endian args` for `solana-sbpf-asm`)
- scenario-declared artifact checks through `[[artifact]]` entries, including
  golden-file equality (`matches_file`), text contains checks (`contains`),
  and structured JSON/TOML path assertions through nested `[[artifact.json]]`
  and `[[artifact.toml]]` checks for target metadata and manifests
- scenario-declared negative diagnostics through `[[diagnostic]]` entries;
  the first diagnostic-only scenario verifies that Solana rejects the portable
  `crosscall.invoke` capability with the expected target/capability message
- `wasm-near` Counter and ValueVault execution through the existing
  deterministic `runtime/offline-host` wasmtime host
- `evm` Counter execution through an in-process `revm` harness that emits the
  portable IR Counter runtime bytecode, loads its artifact metadata selectors,
  and executes the same scenario steps as EVM transactions; ValueVault is
  wired through the same harness when Foundry `cast` is available for selector
  hydration
- `solana-sbpf-asm` Counter and ValueVault execution through `mollusk-svm`
  when `sbpf` and `solana-keygen` are available
- normalized observable trace parity across every selected target that ran
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
cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --scenario value-vault
```

List scenarios without executing them:

```sh
cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- list
```
