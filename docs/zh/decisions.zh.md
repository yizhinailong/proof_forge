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
| D-013 | 2026-07-01 | 将 **`wasm-stellar-soroban`** 归类为文档优先的 Wasm-host Research 候选 | Soroban 发射 Wasm，但有 Stellar 特有的 storage TTL、authorization、contract spec、deployment 和 CLI 语义；registry 修改需等待第一版 spike 路径确定 |
| D-014 | 2026-07-01 | 将 **`wasm-icp-canister`** 归类为文档优先的 Wasm-host Research 候选 | Internet Computer canister 发射 Wasm，但有 Candid、principal identity、update/query call modes、cycles、stable memory、async inter-canister calls 和 lifecycle 语义；registry 修改需等待 canister spike 路径确定 |
| D-015 | 2026-07-01 | 将 **`ton-tvm`** 归类为文档优先的 TVM/Tolk sourcegen Research 候选 | TON 合约目标是 TVM，具有 cells、TL-B serialization、message handlers、get methods、action lists、account lifecycle 和 TVM gas 语义；registry 修改需等待 sourcegen spike 路径确定 |
| D-016 | 2026-07-01 | 将 **`bch-cashscript`** 归类为文档优先的 UTXO script/covenant sourcegen Research 候选 | Bitcoin Cash 通过 CashScript 锁定并花费 UTXO，使用 BCH Script、transaction introspection、CashTokens 和 SDK transaction-builder 语义；registry 修改需等待 CashScript spike 路径确定 |
| D-017 | 2026-07-01 | 将 **`algorand-avm`** 归类为文档优先的 AVM/TEAL sourcegen Research 候选 | Algorand 合约目标是 AVM approval/clear-state 或 LogicSig program，具有 ARC-4 ABI、global/local/box storage、resource references、atomic transaction groups、inner transactions 和 AVM budget 语义；registry 修改需等待 Algorand package spike 路径确定 |
| D-018 | 2026-07-01 | 将 **`cardano-plutus-aiken`** 归类为文档优先的 eUTXO validator sourcegen Research 候选 | Cardano 合约通过 datum、redeemer、script context、Plutus/UPLC artifacts、execution units、Plutus blueprints 和 off-chain transaction-building 语义验证 eUTXO spends；registry 修改需等待 Aiken sourcegen spike 路径确定 |
| D-019 | 2026-07-01 | 将 **`tezos-michelson-ligo`** 归类为文档优先的 Michelson/LIGO sourcegen Research 候选 | Tezos 合约目标是 Michelson，具有 typed storage、parameters、entrypoints、views/events、operation lists、`big_map`、tickets、Sapling、gas 和 storage-burn 语义；registry 修改需等待 LIGO sourcegen spike 路径确定 |
| D-020 | 2026-07-01 | 将 **`starknet-cairo`** 归类为文档优先的 Cairo/Sierra/CASM sourcegen Research 候选 | Starknet 合约通过 Cairo 编译为 Sierra/CASM，具有 ABI、class hashes、declaration/deployment metadata、Starknet storage/events、account abstraction、syscalls 和 L1/L2 messaging 语义；registry 修改需等待 Cairo package spike 路径确定 |
| D-021 | 2026-07-01 | 将 **`bitcoin-script-miniscript`** 归类为文档优先的 Bitcoin base-layer spending-policy Research 候选 | Bitcoin Script 仅适合 UTXO locking/unlocking policy，包含 signatures、hash locks、timelocks、descriptors、Miniscript、Taproot/Tapscript、PSBT flows 和 standardness/fee constraints；registry 修改需等待 Miniscript/descriptor spike 路径确定 |
| D-022 | 2026-07-01 | 将 **`zcash-shielded`** 归类为文档优先的 privacy UTXO/ZK payment Research 候选 | Zcash 源自 Bitcoin，但 shielded 支持依赖 Sapling/Orchard notes、nullifiers、anchors、value-balance constraints、viewing/disclosure policy 和协议定义的 ZK proofs；registry 修改需等待 shielded-note 能力和 proving/validation boundary 审查 |
| D-023 | 2026-07-01 | 将 **`aleo-leo`** 归类为文档优先的 Aleo ZK application sourcegen Research 候选 | Aleo programs 结合 private off-chain proof execution、public on-chain finalization、encrypted records、public mappings/storage、Aleo Instructions、Aleo VM bytecode、ABI、prover/verifier artifacts 和 execute/deploy transactions；registry 修改需等待 proof/finalization split 审查 |
| D-024 | 2026-07-01 | 将 Robinhood Chain 建模为 `evm` 下的 EVM-compatible chain profile **`robinhood-chain-testnet`**，而不是新的 compiler target | Robinhood Chain 执行 EVM-compatible Arbitrum Orbit L2 contracts；ProofForge 的 EVM backend 覆盖 bytecode generation，chain profile 记录 chain id、RPC、explorer、verifier、rollup 和 deployment metadata |

## 目标家族分类

| 家族 | 目标 | 后端模式 |
|---|---|---|
| 直接编译器 | `evm` | Lean → LCNF → Yul → solc |
| EVM-compatible chain profiles | `robinhood-chain-testnet` | 复用 `evm` bytecode/ABI 输出；补充 chain id、RPC、explorer、verifier、rollup 和 deployment metadata |
| Wasm 宿主 | `wasm-near`, `wasm-cosmwasm`, `wasm-stellar-soroban`（候选，仅文档）, `wasm-icp-canister`（候选，仅文档） | Lean → EmitZig → Wasm + 链宿主桥接，或在能更快验证语义时先走目标原生源码包 |
| 二进制工具链 | `solana-sbpf-linker`, `solana-zig-fork` | Lean → EmitZig → bitcode → sbpf-linker |
| 源代码生成 | `move-aptos`, `move-sui` | 可移植 IR → Move 包源码 |
| AVM sourcegen research | `algorand-avm`（候选，仅文档） | 可移植 IR → Algorand Python、Algorand TypeScript 或 TEAL package → AVM approval/clear-state 或 LogicSig bytecode + ARC-4/app metadata |
| eUTXO validator sourcegen research | `cardano-plutus-aiken`（候选，仅文档） | 可移植 IR → Aiken package → UPLC/Plutus validator artifacts + Plutus blueprint + transaction scenario metadata |
| Michelson sourcegen research | `tezos-michelson-ligo`（候选，仅文档） | 可移植 IR → LIGO package → Michelson contract + parameter/storage schema + operation/view/event manifests |
| Cairo sourcegen research | `starknet-cairo`（候选，仅文档） | 可移植 IR → Cairo/Scarb package → Sierra/CASM artifacts + ABI/class-hash/deployment metadata |
| Aleo ZK app sourcegen research | `aleo-leo`（候选，仅文档） | 可移植 IR → Leo package → Aleo Instructions → Aleo VM bytecode + ABI/prover/verifier artifacts + execute/deploy metadata |
| TVM sourcegen research | `ton-tvm`（候选，仅文档） | 可移植 IR → Tolk 或更底层 TON source → TVM/BOC artifact + TL-B/message manifests |
| Bitcoin script policy research | `bitcoin-script-miniscript`（候选，仅文档） | 可移植 IR → policy/Miniscript/descriptor package → Script/Tapscript output + PSBT/regtest validation metadata |
| Privacy UTXO ZK payment research | `zcash-shielded`（候选，仅文档） | 可移植 IR → shielded transaction/proving manifest → Zcash transaction with Sapling/Orchard proof bundle + zcashd/library validation metadata |
| UTXO script sourcegen research | `bch-cashscript`（候选，仅文档） | 可移植 IR → CashScript `.cash` source → cashc artifact JSON + BCH transaction-builder validation |
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
Research lane: Stellar Soroban Wasm-host target note before registry changes
Research lane: Internet Computer canister target note before registry changes
Research lane: Algorand AVM/TEAL target note before registry changes
Research lane: Cardano Plutus/Aiken eUTXO target note before registry changes
Research lane: Tezos Michelson/LIGO target note before registry changes
Research lane: Starknet Cairo target note before registry changes
Research lane: Aleo Leo ZK app target note before registry changes
Research lane: TON TVM/Tolk target note before registry changes
Research lane: Bitcoin Script/Miniscript spending-policy target note before registry changes
Research lane: Zcash shielded privacy payment target note before registry changes
Research lane: Bitcoin Cash CashScript target note before registry changes
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
| Stellar/Soroban 目标候选 | [targets/stellar-soroban.md](targets/stellar-soroban.md) |
| Internet Computer 目标候选 | [targets/internet-computer.md](targets/internet-computer.md) |
| Algorand AVM 目标候选 | [targets/algorand-avm.md](targets/algorand-avm.md) |
| Solana 指令清单 | [targets/solana-sbf.md](targets/solana-sbf.md) |
| Cardano Plutus/Aiken 目标候选 | [targets/cardano-plutus-aiken.md](targets/cardano-plutus-aiken.md) |
| Tezos Michelson/LIGO 目标候选 | [targets/tezos-michelson-ligo.md](targets/tezos-michelson-ligo.md) |
| Starknet Cairo 目标候选 | [targets/starknet-cairo.md](targets/starknet-cairo.md) |
| Aleo Leo 目标候选 | [targets/aleo-leo.md](targets/aleo-leo.md) |
| TON TVM 目标候选 | [targets/ton-tvm.md](targets/ton-tvm.md) |
| Bitcoin Script/Miniscript 目标候选 | [targets/bitcoin-script-miniscript.md](targets/bitcoin-script-miniscript.md) |
| Zcash Shielded 目标候选 | [targets/zcash-shielded.md](targets/zcash-shielded.md) |
| Bitcoin Cash CashScript 目标候选 | [targets/bitcoin-cash-cashscript.md](targets/bitcoin-cash-cashscript.md) |
| Psy/DPN ZK 目标 | [targets/psy-dpn.md](targets/psy-dpn.md) |
| Kaspa/Toccata 目标候选 | [targets/kaspa-toccata.md](targets/kaspa-toccata.md) |

## 已取代的立场

这些早期的文档立场不再具有权威性：

- RFC 0001 阶段 2 = 仅限 Solana，阶段 3 = 仅限 Wasm —— 已被并行的阶段 2 spike (D-003) 取代。
- 里程碑 3 = Solana 作为唯一的第二个目标 —— 已被并行的 CosmWasm + Solana (D-003) 取代。
- CLI id `solana-sbf` —— 使用 `solana-sbpf-linker` (D-004)。
- Move POC 同时生成 Sui 和 Aptos 包 —— Aptos 优先 (D-007)。
