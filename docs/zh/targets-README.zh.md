# 目标说明

本目录包含目标家族说明，其层级介于 RFC 与实现任务之间。随着研究转化为代码，这些说明将不断更新。

相关文档：[文档索引](../INDEX.md)、
[RFC 0002](../rfcs/0002-target-implementation-design.md)、
[实现积压](../implementation-backlog.md)、
[设计决策](../decisions.md)。

## 目标生命周期

| 阶段 | 含义 |
|---|---|
| Research | 我们了解链模型和工具链形态，但尚不存在本地后端。 |
| Spike | 正在生成最小制品，通常针对一个 Counter 示例。 |
| Experimental | 目标已具备 SDK、构建和冒烟测试，但能力覆盖范围较窄。 |
| Supported | 目标具备稳定的 CLI、制品元数据、CI、文档和共享场景测试。 |

## 阶段退出标准

- `Research` 仅在目标 profile 草案、所需工具列表以及最小 Spike 验收标准已记录时退出。
- `Spike` 仅在存在可重复的本地命令或脚本，且目标说明记录了结果时退出。
- `Experimental` 仅在针对窄能力集具备 SDK/构建/冒烟覆盖，且文档指明了制品元数据、CI 或可选 CI、能力支持及示例时退出。
- `Supported` 要求具备稳定的 CLI、制品元数据、CI、文档以及至少一个共享场景测试。

**Experimental** 并不意味着“损坏”——EVM 已具备 CI 和 Foundry 冒烟测试，但缺乏目标注册表和可移植 IR 集成。

## 当前目标状态

| 目标 | 阶段 | 说明 |
|---|---|---|
| [EVM](evm.md) | Experimental | 通过 Yul、`solc`、Foundry smoke 建立基线；包含 EVM-compatible chain profile `robinhood-chain-testnet`。 |
| [NEAR](targets/wasm-near.zh.md) | Spike | Rust `near-sdk-rs` sourcegen 后端；CLI emit modes、IR lowering、package generation。 |
| CosmWasm | Research | 强力的 Wasm Spike 候选；复用 NEAR 的经验。 |
| [Stellar Soroban](targets/stellar-soroban.zh.md) | Research | 文档优先的 Wasm-host 候选，使用 Soroban/Stellar CLI 工具链；尚未进入代码 registry。 |
| [Internet Computer](targets/internet-computer.zh.md) | Research | 文档优先的 Wasm canister 候选，包含 Candid、cycles、stable memory 和 canister lifecycle；尚未进入代码 registry。 |
| [Algorand AVM](targets/algorand-avm.zh.md) | Research | 文档优先的 AVM/TEAL source/package-generation 候选，包含 app programs、LogicSig、ARC-4 ABI、storage、resource references 和 transaction-group 语义；尚未进入代码 registry。 |
| Solana sBPF-linker | Research（已取代） | Solana 历史参考路径（`solana-sbpf-linker` id）；已被 `solana-sbpf-asm` (D-026) 取代。 |
| Solana sBPF Asm | Research | direct-assembly 路线（`solana-sbpf-asm` id），Lean → IR → sbpf asm → sbpf toolchain → ELF。见 [设计文档](solana-sbpf-asm.md)、[RFC 0005](../rfcs/0005-solana-sbpf-assembly-backend.md)。 |
| Solana Zig fork | Research | 来自 `solana-sdk-mono` 的备选参考。 |
| Sui Move | Research | 源代码生成；遵循 Aptos POC。 |
| Aptos Move | Research | 首个 Move POC 目标。 |
| [Cardano Plutus/Aiken](targets/cardano-plutus-aiken.zh.md) | Research | 文档优先的 eUTXO validator sourcegen 候选，通过 Aiken、UPLC、Plutus blueprints、datum/redeemer/script-context schemas 和 transaction-building validation。 |
| [Tezos Michelson/LIGO](targets/tezos-michelson-ligo.zh.md) | Research | 文档优先的 Michelson sourcegen 候选，通过 LIGO、typed storage、entrypoints、views/events、operation lists 和 sandbox/test validation。 |
| [Starknet Cairo](targets/starknet-cairo.zh.md) | Research | 文档优先的 Cairo/Sierra/CASM sourcegen 候选，包含 Scarb、ABI/class hash metadata、Starknet storage/events 和 Starknet Foundry/devnet validation。 |
| [Aleo Leo](targets/aleo-leo.zh.md) | Research | 文档优先的 ZK application sourcegen 候选，包含 Leo、Aleo Instructions、Aleo VM bytecode、private records、public finalization、prover/verifier artifacts 和 Leo CLI/devnet validation。 |
| [TON TVM](targets/ton-tvm.zh.md) | Research | 文档优先的 TVM/Tolk sourcegen 候选，包含 cells、messages、get methods、actions 和 TVM gas。 |
| [Bitcoin Script/Miniscript](targets/bitcoin-script-miniscript.zh.md) | Research | 文档优先的 Bitcoin base-layer spending-policy 候选，通过 Script、Miniscript、descriptors、PSBT、Taproot/Tapscript 和 Bitcoin Core regtest validation。 |
| [Zcash Shielded](targets/zcash-shielded.zh.md) | Research | 文档优先的 privacy UTXO/ZK payment 候选，包含 transparent Zcash flows、Sapling/Orchard shielded notes、nullifiers、anchors、value-balance constraints 和 zcashd/library validation。 |
| [Bitcoin Cash CashScript](targets/bitcoin-cash-cashscript.zh.md) | Research | 文档优先的 UTXO script/covenant sourcegen 候选，通过 CashScript 与 BCH transaction-builder 验证。 |
| Psy DPN | Experimental | 通过生成的 `.psy`、Dargo 冒烟测试和制品元数据校验实现的窄范围 ZK 电路源代码生成目标。 |
| [Kaspa Toccata](targets/kaspa-toccata.zh.md) | Research | 文档优先的 UTXO covenant / based-app 目标候选；尚未进入代码 registry。 |

## 文档

- [EVM](evm.md)
- [Wasm 家族](wasm-family.md)
- [Wasm-NEAR](targets/wasm-near.zh.md)
- [Stellar Soroban 目标](targets/stellar-soroban.zh.md)
- [Internet Computer 目标](targets/internet-computer.zh.md)
- [Algorand AVM 目标](targets/algorand-avm.zh.md)
- [Solana sBPF Asm](solana-sbpf-asm.md) —— 规范 direct-assembly 路线（`solana-sbpf-asm` 目标 id，D-026）
- [Solana sBPF](solana-sbf.md) —— 已被取代的 Zig/sbpf-linker 路线（`solana-sbpf-linker` 目标 id）
- [Move 家族](move-family.md)
- [Cardano Plutus/Aiken 目标](targets/cardano-plutus-aiken.zh.md)
- [Tezos Michelson/LIGO 目标](targets/tezos-michelson-ligo.zh.md)
- [Starknet Cairo 目标](targets/starknet-cairo.zh.md)
- [Aleo Leo 目标](targets/aleo-leo.zh.md)
- [TON TVM 目标](targets/ton-tvm.zh.md)
- [Bitcoin Script/Miniscript 目标](targets/bitcoin-script-miniscript.zh.md)
- [Zcash Shielded 目标](targets/zcash-shielded.zh.md)
- [Bitcoin Cash CashScript 目标](targets/bitcoin-cash-cashscript.zh.md)
- [Psy DPN ZK 目标](psy-dpn.md)
- [Kaspa Toccata 目标](targets/kaspa-toccata.zh.md)
