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
| [EVM](evm.md) | Experimental | 通过 Yul 实现基准线，`solc`，Foundry 冒烟测试。 |
| NEAR | Research | 本地 Lean 分支中的参考实现；尚未移植到此仓库。 |
| CosmWasm | Research | 强力的 Wasm Spike 候选；复用 NEAR 的经验。 |
| [Stellar Soroban](targets/stellar-soroban.zh.md) | Research | 文档优先的 Wasm-host 候选，使用 Soroban/Stellar CLI 工具链；尚未进入代码 registry。 |
| [Internet Computer](targets/internet-computer.zh.md) | Research | 文档优先的 Wasm canister 候选，包含 Candid、cycles、stable memory 和 canister lifecycle；尚未进入代码 registry。 |
| [Algorand AVM](targets/algorand-avm.zh.md) | Research | 文档优先的 AVM/TEAL source/package-generation 候选，包含 app programs、LogicSig、ARC-4 ABI、storage、resource references 和 transaction-group 语义；尚未进入代码 registry。 |
| Solana sBPF-linker | Research | 首选的 Solana 路径（`solana-sbpf-linker` id）。 |
| Solana Zig fork | Research | 来自 `solana-sdk-mono` 的备选参考。 |
| Sui Move | Research | 源代码生成；遵循 Aptos POC。 |
| Aptos Move | Research | 首个 Move POC 目标。 |
| [TON TVM](targets/ton-tvm.zh.md) | Research | 文档优先的 TVM/Tolk sourcegen 候选，包含 cells、messages、get methods、actions 和 TVM gas。 |
| [Bitcoin Cash CashScript](targets/bitcoin-cash-cashscript.zh.md) | Research | 文档优先的 UTXO script/covenant sourcegen 候选，通过 CashScript 与 BCH transaction-builder 验证。 |
| Psy DPN | Experimental | 通过生成的 `.psy`、Dargo 冒烟测试和制品元数据校验实现的窄范围 ZK 电路源代码生成目标。 |
| [Kaspa Toccata](targets/kaspa-toccata.zh.md) | Research | 文档优先的 UTXO covenant / based-app 目标候选；尚未进入代码 registry。 |

## 文档

- [EVM](evm.md)
- [Wasm 家族](wasm-family.md)
- [Stellar Soroban 目标](targets/stellar-soroban.zh.md)
- [Internet Computer 目标](targets/internet-computer.zh.md)
- [Algorand AVM 目标](targets/algorand-avm.zh.md)
- [Solana sBPF](solana-sbf.md) —— 目标 id `solana-sbpf-linker` 的说明
- [Move 家族](move-family.md)
- [TON TVM 目标](targets/ton-tvm.zh.md)
- [Bitcoin Cash CashScript 目标](targets/bitcoin-cash-cashscript.zh.md)
- [Psy DPN ZK 目标](psy-dpn.md)
- [Kaspa Toccata 目标](targets/kaspa-toccata.zh.md)
