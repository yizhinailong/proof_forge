# proof-forge

Standalone EVM backend experiment for Lean 4.

This package keeps the EVM/Yul backend outside the Lean 4 source tree. It adds:

- `ProofForge.Evm`: a small EVM contract SDK using `@[extern "lean_evm_*"]` primitives.
- `ProofForge.Compiler.Yul`: a Yul AST and printer.
- `ProofForge.Compiler.LCNF.EmitYul`: an LCNF-to-Yul emitter.
- `proof-forge`: a CLI that compiles a Lean file to Yul without patching `lean`.

Build:

```sh
lake build
```

Compile the example:

```sh
lake env proof-forge --root . -o build/counter.yul Examples/Counter.lean
```

Validate the generated Yul if `solc` is installed:

```sh
solc --strict-assembly build/counter.yul --bin
```

Build the EVM contract examples migrated from the Lean fork:

```sh
scripts/evm/build-examples.sh
```

Run Foundry smoke tests:

```sh
scripts/evm/foundry-smoke.sh
```

The smoke runner uses Forge's local EVM test runner and `vm.etch` to execute
the generated runtime bytecode.

Current scope:

- The CLI emits a default no-argument `main` entry point.
- ABI selector dispatch is wired through `tools/evmc` and `.evm-methods` files.

Planned backend targets:

- NIR
- Stranded SBF
