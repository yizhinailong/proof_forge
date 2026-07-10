# Native Counter corpus (B1.2)

Hand-written baselines for ProofForge vs native comparison.

| Target | Path | Framework |
|--------|------|-----------|
| `evm` | [`evm/Counter.sol`](evm/Counter.sol) | Solidity 0.8.30 |
| `solana-sbpf-asm` | [`solana/counter/`](solana/counter/) | Pinocchio 0.11 |
| `wasm-near` | [`near/counter-rs/`](near/counter-rs/) | near-sdk 5.x |

Scenario: `bm-counter` — `initialize` / `increment` / `get` over `u64 count`.

```sh
just benchmark-native-counter   # compile/typecheck when tools present
```
