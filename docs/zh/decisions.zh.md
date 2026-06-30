# ProofForge 设计决策

本文档记录了足以指导实现的架构决策。未决问题将保留在 RFC 和目标说明中，直到在此处得到解决。

另请参阅：[评审清单 (英文)](review-checklist.md)，[评审清单 (中文)](zh/review-checklist.md)。

## 决策日志

| ID | 日期 | 决策 | 理由 |
|---|---|---|---|
| D-001 | 2026-06-30 | RFC 0001 和 RFC 0002 被**接受**为工程方向 | 已存在详细的目标和待办事项文档；草案状态具有误导性 |
| D-002 | 2026-06-30 | 第一阶段（目标注册表 + 可移植 IR + 制品元数据）必须在非 EVM spike 之前完成 | spike 需要能力检查和共享场景定义 |
| D-003 | 2026-06-30 | CosmWasm 和 Solana spike 在第一阶段后**并行**运行 | 两者之间没有固定顺序；两者都验证不同的后端家族 |
| D-004 | 2026-06-30 | 规范的 Solana 目标 id 为 **`solana-sbpf-linker`** | 标准 Zig + sbpf-linker 符合平台工具链；`solana-sbf` 仅为文件名别名 |
| D-005 | 2026-06-30 | 保留 **`solana-zig-fork`** 作为备选/参考路径 | 来自 solana-sdk-mono 的成熟 SDK 参考；非主要产品路径 |
| D-006 | 2026-06-30 | NEAR 是 Wasm 宿主**参考**；CosmWasm 是仓库中第一个新的 Wasm spike | 分叉经验为结构提供了参考；CosmWasm 验证了宿主适配器的通用性 |
| D-007 | 2026-06-30 | Move POC 从 **仅限 Aptos** 开始；Sui 紧随其后 | Aptos 账户资源更简单；Sui 对象模型对抽象的测试更严苛 |
| D-008 | 2026-06-30 | Move 目标使用**源代码生成**，而非 MoveVM 上的 Lean 运行时 | 证明保留在 Lean 中；Move 仅承载可执行逻辑 |
| D-009 | 2026-06-30 | **`wasm-polkadot` / ink!** 保持为 Research 状态 | 在安排 spike 之前不会进入目标注册表 |
| D-010 | 2026-06-30 | 云平台需等待**两个或更多目标**达到 Experimental 阶段 | 避免在本地后端真实可用前构建 UI 外壳 |
| D-011 | 2026-06-30 | 将 **`psy-dpn`** 作为 ZK 电路源代码生成下的 Research 目标添加 | Psy 没有公开的类 Yul IR；首次集成应生成 `.psy` 并调用 Dargo |
| D-012 | 2026-07-01 | 将 **`kaspa-toccata`** 归类为文档优先的 Research 候选，而不是 ZK 电路源代码生成目标 | Toccata 是 Kaspa L1 的 transaction v1、covenant、inline proof verification 和 based-app settlement 可编程栈；代码 registry 修改需等待 UTXO/covenant 能力审查 |

## 目标家族分类

| 家族 | 目标 | 后端模式 |
|---|---|---|
| 直接编译器 | `evm` | Lean → LCNF → Yul → solc |
| Wasm 宿主 | `wasm-near`, `wasm-cosmwasm` | Lean → EmitZig → Wasm + 链宿主桥接 |
| 二进制工具链 | `solana-sbpf-linker`, `solana-zig-fork` | Lean → EmitZig → bitcode → sbpf-linker |
| 源代码生成 | `move-aptos`, `move-sui` | 可移植 IR → Move 包源码 |
| ZK 电路源代码生成 | `psy-dpn` | 可移植 IR → `.psy` 包 → Dargo → DPN 电路 JSON |
| UTXO covenant research | `kaspa-toccata`（候选，仅文档） | 可移植 IR → covenant/Silverscript 包 + transaction v1 manifest + 可选 proof settlement metadata |

## 路线图摘要

```text
Phase 0: EVM baseline (done)
Phase 1: Target registry + portable IR + artifact metadata + capability errors
Phase 2: Parallel spikes — CosmWasm (wasm-cosmwasm) + Solana (solana-sbpf-linker)
Phase 3: Move sourcegen — Aptos POC first, then Sui
Phase 3.5: Psy DPN sourcegen research spike
Research lane: Kaspa Toccata covenant/based-app target note before registry changes
Phase 4: Cross-target shared scenario hardening
Phase 5: Cloud platform
```

详细任务：[实现待办事项](implementation-backlog.md)。

## 权威规范

| 主题 | 文档 |
|---|---|
| 可移植合约 IR | [portable-ir.md](portable-ir.md) |
| 能力 id | [capability-registry.md](capability-registry.md) |
| 计数器共享场景 | [shared-scenario.md](shared-scenario.md) |
| 目标工程形态 | [RFC 0002](rfcs/0002-target-implementation-design.md) |
| CosmWasm SDK spike 草图 | [targets/wasm-family.md](targets/wasm-family.md) |
| Solana 指令清单 | [targets/solana-sbf.md](targets/solana-sbf.md) |
| Psy/DPN ZK 目标 | [targets/psy-dpn.md](targets/psy-dpn.md) |
| Kaspa/Toccata 目标候选 | [targets/kaspa-toccata.md](targets/kaspa-toccata.md) |

## 已取代的立场

这些早期的文档立场不再具有权威性：

- RFC 0001 阶段 2 = 仅限 Solana，阶段 3 = 仅限 Wasm —— 已被并行的阶段 2 spike (D-003) 取代。
- 里程碑 3 = Solana 作为唯一的第二个目标 —— 已被并行的 CosmWasm + Solana (D-003) 取代。
- CLI id `solana-sbf` —— 使用 `solana-sbpf-linker` (D-004)。
- Move POC 同时生成 Sui 和 Aptos 包 —— Aptos 优先 (D-007)。
