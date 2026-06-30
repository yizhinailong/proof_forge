# 目标笔记

此目录包含位于 RFC 之下、实现任务之上的目标家族笔记。随着 Research 转化为代码，这些笔记将不断被编辑。

相关：[文档索引](../INDEX.md),
[RFC 0002](../rfcs/0002-target-implementation-design.md),
[实现待办事项](../implementation-backlog.md),
[设计决策](../decisions.md)。

## 目标生命周期

| 阶段 | 含义 |
|---|---|
| Research | 我们了解链模型和工具链形态，但尚不存在本地后端。 |
| Spike | 正在生成最小制品，通常针对一个 Counter 示例。 |
| Experimental | 目标拥有 SDK、构建和冒烟测试，但能力覆盖范围较窄。 |
| Supported | 目标拥有稳定的 CLI、制品元数据、CI、文档和共享场景测试。 |

## 阶段退出标准

- `Research` 仅在目标 profile 草案、所需工具列表和最小 spike 验收标准被记录后退出。
- `Spike` 仅在存在可重复的本地命令或脚本且目标笔记记录了结果时退出。
- `Experimental` 仅在针对窄能力集存在 SDK/构建/冒烟测试覆盖，且文档指明制品元数据、CI 或可选 CI、能力支持和示例时退出。
- `Supported` 要求稳定的 CLI、制品元数据、CI、文档以及至少一个共享场景测试。

**Experimental** 并不意味着“损坏”——EVM 拥有 CI 和 Foundry 冒烟测试，但缺乏目标注册表和可移植 IR 集成。

## 当前目标状态

| 目标 | 阶段 | 笔记 |
|---|---|---|
| [EVM](evm.md) | Experimental | 通过 Yul 实现基线，`solc`，Foundry 冒烟测试。 |
| NEAR | Research | 本地 Lean 分叉中的参考；尚未移植到此仓库。 |
| CosmWasm | Research | 强力的 Wasm spike 候选者；复用 NEAR 的经验。 |
| Solana sBPF-linker | Research | 首选 Solana 路径（`solana-sbpf-linker` id）。 |
| Solana Zig fork | Research | 来自 `solana-sdk-mono` 的备选参考。 |
| Sui Move | Research | 源代码生成；遵循 Aptos POC。 |
| Aptos Move | Research | 第一个 Move POC 目标。 |
| Psy DPN | Research | 通过生成的 `.psy` 和 Dargo 实现的 ZK 电路源代码生成目标。 |

## 文档

- [EVM](evm.md)
- [Wasm 家族](wasm-family.md)
- [Solana sBPF](solana-sbf.md) — 目标 id `solana-sbpf-linker` 的笔记
- [Move 家族](move-family.md)
- [Psy DPN ZK 目标](psy-dpn.md)
