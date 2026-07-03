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

## 目标组合排期边界

下面这些分组是 target note 的库存清单，不是排期授权。当前产品实现 backlog 受主三链完成规约
(D-045) 约束：先按顺序把 `solana-sbpf-asm`、`evm` 和 `wasm-near`
做到生产级完善，然后任何额外链才能推进到 docs-only research 或冻结 spike 维护之外。

用本页回答“仓库里已经有哪些目标说明？”；用
[target-roadmap.md](../target-roadmap.md) 和
[gate-status.md](../gate-status.md) 回答“下一步哪些目标可以获得产品实现投入？”

## 活跃产品目标（Gate P0）

在 Gate P0 关闭前，只有这三个 target 可以获得产品硬化工作。下面顺序就是 D-045
规定的实现优先级。

| 目标 | 阶段 | 排期状态 |
|---|---|---|
| [Solana sBPF Asm](../targets/solana-sbpf-asm.md) | Experimental | 第一优先级；direct assembly 路线（`solana-sbpf-asm`），live deploy / Pinocchio equivalence 硬化作为 P0-1 追踪。 |
| [EVM](targets/evm.zh.md) | Experimental | 第二优先级；Yul/`solc`/Foundry 基线，EVM-compatible chain profiles 仍作为 `evm` 下的部署元数据；semantic-plan 硬化作为 P0-2 追踪。 |
| [Wasm-NEAR](targets/wasm-near.zh.md) | Experimental | 第三优先级；EmitWat 路线已具备诊断、IR coverage、formal trace anchors 和 offline host smoke；本地执行/部署元数据签署作为 P0-3 追踪。 |

## 维护冻结的已落地库存

这些 backend 已经有有用的代码或 smoke 覆盖，但 D-045 在 Gate P0 关闭前冻结新的
registry stage、capability surface、testkit coverage、CI 扩展和产品范围。允许的工作仅限
CI 稳定性、安全修复和文档维护。

| 目标 | 阶段 | 冻结范围 |
|---|---|---|
| [Psy DPN](../targets/psy-dpn.md) | Experimental subset | 生成 `.psy`/Dargo 的路径保持维护；P0 前不推进 capability-completion。 |
| [Aleo Leo](targets/aleo-leo.zh.md) | Research spike | Counter/PureMath sourcegen 和 smoke 保持维护；P0 前不开新的 ZK-app 实现路线。 |
| [Cloudflare Workers](../targets/cloudflare-workers.md) | Research off-chain host | TypeScript Worker demo 作为 off-chain host 参考保留；P0 前不做产品扩展。 |

## 冻结的 Tier-1 Spike

这些是 Gate P0 之后最先恢复的目标，但主三链规约打开期间不得继续推进。

| 目标 | 阶段 | 恢复条件 |
|---|---|---|
| CosmWasm | Frozen M1/M2 spike | 仅在 Gate P0 关闭后恢复 M3/M4；复用 Wasm-family 的 EmitWat host-adapter 路线。 |
| Aptos Move | Frozen M1/M2 spike | 仅在 Gate P0 关闭后恢复 M3/M4；仍然是 Sui 之前第一个 Move sourcegen proof。 |

## Docs-Only Parked Research

这些说明保留研究结果，但不是当前执行队列。只有对应 roadmap enabler 打开并排入具体
spike 后，才会从 docs-only 状态恢复。

| 目标 | 家族 | 当前边界 |
|---|---|---|
| [Stellar Soroban](targets/stellar-soroban.zh.md) | Wasm host | CosmWasm 证明 host-adapter split 后才打开。 |
| [Internet Computer](targets/internet-computer.zh.md) | Wasm host | 需要 Wasm-host split，再加 async/inter-canister design note。 |
| Sui Move | Move/object sourcegen | 在 Aptos 证明 Move printer 和 sourcegen lane 后跟进。 |
| [Algorand AVM](targets/algorand-avm.zh.md) | Source package generation | 停在后续 sourcegen-lane exit 之后。 |
| [Cardano Plutus/Aiken](targets/cardano-plutus-aiken.zh.md) | eUTXO validator sourcegen | 停在后续 sourcegen-lane exit 之后。 |
| [Tezos Michelson/LIGO](targets/tezos-michelson-ligo.zh.md) | Source package generation | 停在后续 sourcegen-lane exit 之后。 |
| [Starknet Cairo](targets/starknet-cairo.zh.md) | Cairo/Sierra/CASM sourcegen | Aptos 之后的首个非 Move sourcegen 候选，但仍受 P0 阻塞。 |
| [TON TVM](targets/ton-tvm.zh.md) | TVM sourcegen | 停在后续 sourcegen-lane exit 之后。 |
| [Bitcoin Script/Miniscript](targets/bitcoin-script-miniscript.zh.md) | Policy family | 只有单独的 `policy.*` 路线排期后才打开。 |
| [Zcash Shielded](targets/zcash-shielded.zh.md) | Privacy UTXO / ZK payment | 跟随可工作的 Bitcoin policy lane。 |
| [Bitcoin Cash CashScript](targets/bitcoin-cash-cashscript.zh.md) | UTXO script/covenant sourcegen | 跟随 Bitcoin policy lane。 |
| [Kaspa Toccata](targets/kaspa-toccata.zh.md) | UTXO covenant / based app | 停在 policy/ZK lane 决策之后。 |

## 已取代或参考路线

| 路线 | 状态 | 说明 |
|---|---|---|
| Solana sBPF-linker | 已取代 | 历史 `solana-sbpf-linker` 路线；已被 `solana-sbpf-asm` (D-026) 取代。 |
| Solana Zig fork | 仅参考 | 来自 `solana-sdk-mono` 的外部参考；不是产品路线。 |

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
