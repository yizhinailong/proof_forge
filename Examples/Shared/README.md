# Shared portable examples

These modules are the canonical **multi-target** authoring demos: one
`contract_source` module, three primary-chain builds via `--target`.

## Counter

Source: [Counter.lean](Counter.lean) (`contract_source`, self-contained for
`ContractLoader`).

The compiler test fixture with equivalent semantics lives in
`ProofForge/Contract/Examples/Counter.lean`.

| Target | Command | Primary artifact |
|---|---|---|
| `evm` | `proof-forge build --target evm --root . -o build/portable-counter/Counter.bin Examples/Shared/Counter.lean` | Yul + runtime bytecode |
| `solana-sbpf-asm` | `proof-forge build --target solana-sbpf-asm --root . -o build/portable-counter/Counter.s Examples/Shared/Counter.lean` | sBPF assembly + manifest |
| `wasm-near` | `proof-forge build --target wasm-near --root . -o build/portable-counter/near Examples/Shared/Counter.lean` | WAT (+ optional Wasm) |

Run the checked demo:

```bash
scripts/portable/counter-multi-target.sh
```

Or from the repo root:

```bash
just portable-counter-multi-target
```

The business logic lives in `ProofForge/Contract/Examples/Counter.lean`
(`contract_source`). Application repos should follow the same pattern: portable
Lean SDK syntax in one module, chain choice at build time.
