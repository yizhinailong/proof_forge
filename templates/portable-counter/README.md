# Portable Counter Starter Template

This is the smallest checked-in starter for a chain-neutral ProofForge
contract. The source imports `ProofForge.Contract.Source`, not an EVM, Solana,
or NEAR SDK. It expands to `ContractSpec` / portable IR; target selection
happens at the CLI layer.

## Source Validation

```sh
lake env lean templates/portable-counter/Counter.lean
```

## Target-First Emission

The current CLI migration still routes multi-target Counter emission through
the built-in `counter` fixture registry. Use these commands to validate the
same portable contract shape against concrete targets:

```sh
lake env proof-forge emit --target evm --fixture counter --format yul -o build/portable-counter/evm/Counter.yul
lake env proof-forge emit --target solana-sbpf-asm --fixture counter --format s -o build/portable-counter/solana/Counter.s
lake env proof-forge emit --target wasm-near --fixture counter --format wat -o build/portable-counter/near
```

The intended product surface is:

```text
portable Lean source -> ContractSpec / portable IR -> proof-forge --target <id>
```

Routing arbitrary `contract_source` files through every target-first `build`
path is still part of the CLI M4/source-routing hardening work. Until that
lands, keep this template as the authoring shape and use the fixture commands
above for target artifact validation.
