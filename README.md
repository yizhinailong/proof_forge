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

Current scope:

- The CLI emits a default no-argument `main` entry point.
- ABI selector dispatch exists in the emitter model, but is not wired into the CLI yet.
- The external frontend path currently has a notation loading gap for overloaded syntax such as `n + 1`; use explicit definitions such as `Nat.add n 1` in contract entry code for now.

Planned backend targets:

- NIR
- Stranded SBF
