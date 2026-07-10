# Benchmark Counter matrix (generated)

Generated: `2026-07-10T11:20:14Z`

Source rows: `build/benchmarks/bm-counter_*_{proofforge,native}.json`

Rules:

- No cross-chain score (gas ≠ CU ≠ fuel).
- Behavior parity is gated separately (`just benchmark-behavior-gate`).
- Empty costs mean the runner deferred that dimension (honest `—`).

## `bm-counter`

| Target | PF ok | Native ok | PF artifact | Native artifact | PF/native size | PF costs | Native costs |
|--------|------:|----------:|------------:|----------------:|---------------:|----------|--------------|
| `evm` | yes | yes | 180 | 359 | 0.50× | — | gas[initialize=25626, increment=43581, get=23357] |
| `solana-sbpf-asm` | yes | yes | 1384 | 0 | — | — | — |
| `wasm-near` | yes | yes | 403 | 54785 | 0.01× | fuelΔ[initialize=17, increment=44, get=33] | — |

<details><summary>Row notes</summary>

- **evm/proofforge**: runtime bytecode built; evm_gas requires Foundry/revm (B1.4+)
- **evm/native**: Anvil/cast lifecycle; native Solidity Counter.sol
- **solana-sbpf-asm/proofforge**: ELF built via sbpf; solana_cu requires Mollusk/Surfpool (B1.4+)
- **solana-sbpf-asm/native**: cargo check ok; cargo-build-sbf failed (see build log); CU deferred
- **wasm-near/proofforge**: offline-host; wasmtime fuel delta (not NEAR gas)
- **wasm-near/native**: near-sdk host tests + release wasm; fuel not comparable to PF offline-host ABI

</details>

