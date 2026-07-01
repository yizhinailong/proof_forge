# Target Notes

This directory contains target-family notes that sit below the RFCs and above
implementation tasks. They are meant to be edited as research turns into code.

Related: [Documentation index](../INDEX.md),
[RFC 0002](../rfcs/0002-target-implementation-design.md),
[Implementation backlog](../implementation-backlog.md),
[Design decisions](../decisions.md).

## Target Lifecycle

| Stage | Meaning |
|---|---|
| Research | We understand the chain model and toolchain shape, but no local backend exists. |
| Spike | A minimal artifact is being produced, usually for one Counter example. |
| Experimental | A target has SDK, build, and smoke tests, but capability coverage is narrow. |
| Supported | A target has stable CLI, artifact metadata, CI, docs, and shared scenario tests. |

## Stage Exit Criteria

- `Research` exits only when a target profile draft, required-tool list, and
  minimal spike acceptance criteria are documented.
- `Spike` exits only when a reproducible local command or script exists and
  the target note records the result.
- `Experimental` exits only when SDK/build/smoke coverage exists for a narrow
  capability set and docs name artifact metadata, CI or optional CI,
  capability support, and examples.
- `Supported` requires stable CLI, artifact metadata, CI, docs, and at least
  one shared scenario test.

**Experimental** does not mean "broken" — EVM has CI and Foundry smoke but lacks
target registry and portable IR integration.

## Current Target Status

| Target | Stage | Notes |
|---|---|---|
| [EVM](evm.md) | Experimental | Baseline through Yul, `solc`, Foundry smoke; includes EVM-compatible chain profile `robinhood-chain-testnet`. |
| NEAR | Research | Reference in local Lean fork; not yet ported into this repo. |
| CosmWasm | Research | Strong Wasm spike candidate; reuses NEAR lessons. |
| [Stellar Soroban](stellar-soroban.md) | Research | Docs-first Wasm-host candidate through Soroban/Stellar CLI tooling; not yet in the code registry. |
| [Internet Computer](internet-computer.md) | Research | Docs-first Wasm canister candidate with Candid, cycles, stable memory, and canister lifecycle; not yet in the code registry. |
| [Algorand AVM](algorand-avm.md) | Research | Docs-first AVM/TEAL source/package-generation candidate with app programs, LogicSig, ARC-4 ABI, storage, resource references, and transaction-group semantics; not yet in the code registry. |
| Solana sBPF-linker | Research (superseded) | Historical reference Solana path (`solana-sbpf-linker` id); superseded by `solana-sbpf-asm` (D-026). |
| Solana sBPF Asm | Research | Direct-assembly route (`solana-sbpf-asm` id), Lean → IR → sbpf asm → sbpf toolchain → ELF. See [design doc](solana-sbpf-asm.md), [RFC 0004](../rfcs/0004-solana-sbpf-assembly-backend.md). |
| Solana Zig fork | Research | Fallback reference from `solana-sdk-mono`. |
| Sui Move | Research | Source-generation; follows Aptos POC. |
| Aptos Move | Research | First Move POC target. |
| [Cardano Plutus/Aiken](cardano-plutus-aiken.md) | Research | Docs-first eUTXO validator sourcegen candidate through Aiken, UPLC, Plutus blueprints, datum/redeemer/script-context schemas, and transaction-building validation. |
| [Tezos Michelson/LIGO](tezos-michelson-ligo.md) | Research | Docs-first Michelson sourcegen candidate through LIGO with typed storage, entrypoints, views/events, operation lists, and sandbox/test validation. |
| [Starknet Cairo](starknet-cairo.md) | Research | Docs-first Cairo/Sierra/CASM sourcegen candidate with Scarb, ABI/class hash metadata, Starknet storage/events, and Starknet Foundry/devnet validation. |
| [Aleo Leo](aleo-leo.md) | Research | Docs-first ZK application sourcegen candidate through Leo, Aleo Instructions, Aleo VM bytecode, private records, public finalization, prover/verifier artifacts, and Leo CLI/devnet validation. |
| [TON TVM](ton-tvm.md) | Research | Docs-first TVM/Tolk sourcegen candidate with cells, messages, get methods, actions, and TVM gas. |
| [Bitcoin Script/Miniscript](bitcoin-script-miniscript.md) | Research | Docs-first Bitcoin base-layer spending-policy candidate through Script, Miniscript, descriptors, PSBT, Taproot/Tapscript, and Bitcoin Core regtest validation. |
| [Zcash Shielded](zcash-shielded.md) | Research | Docs-first privacy UTXO/ZK payment candidate through transparent Zcash flows, Sapling/Orchard shielded notes, nullifiers, anchors, value-balance constraints, and zcashd/library validation. |
| [Bitcoin Cash CashScript](bitcoin-cash-cashscript.md) | Research | Docs-first UTXO script/covenant sourcegen candidate through CashScript and BCH transaction-builder validation. |
| Psy DPN | Experimental | Narrow ZK circuit sourcegen target through generated `.psy`, Dargo smokes, and artifact metadata validation. |
| [Kaspa Toccata](kaspa-toccata.md) | Research | Docs-first UTXO covenant/based-app target candidate; not yet in the code registry. |

## Documents

- [EVM](evm.md)
- [Wasm family](wasm-family.md)
- [Stellar Soroban target](stellar-soroban.md)
- [Internet Computer target](internet-computer.md)
- [Algorand AVM target](algorand-avm.md)
- [Solana sBPF Asm](solana-sbpf-asm.md) — canonical direct-assembly route (`solana-sbpf-asm` target id, D-026)
- [Solana sBPF](solana-sbf.md) — superseded Zig/sbpf-linker route (`solana-sbpf-linker` target id)
- [Move family](move-family.md)
- [Cardano Plutus/Aiken target](cardano-plutus-aiken.md)
- [Tezos Michelson/LIGO target](tezos-michelson-ligo.md)
- [Starknet Cairo target](starknet-cairo.md)
- [Aleo Leo target](aleo-leo.md)
- [TON TVM target](ton-tvm.md)
- [Bitcoin Script/Miniscript target](bitcoin-script-miniscript.md)
- [Zcash Shielded target](zcash-shielded.md)
- [Bitcoin Cash CashScript target](bitcoin-cash-cashscript.md)
- [Psy DPN ZK target](psy-dpn.md)
- [Kaspa Toccata target](kaspa-toccata.md)
