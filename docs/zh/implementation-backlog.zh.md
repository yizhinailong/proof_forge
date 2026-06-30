**注意：** 公共验证命令的更改必须在同一次变更中更新 [validation-gates.md](validation-gates.md)。

# 实现 Backlog

此 Backlog 将多链设计转化为可评审的工程切片。它有意将范围限定在本地编译器、制品和冒烟测试工作。云平台应等到至少两个实质上不同的目标在本地正常工作后再开始。

相关文档：

- [设计决策](decisions.md)
- [可移植合约 IR](portable-ir.md)
- [能力注册表](capability-registry.md)
- [共享场景：Counter](shared-scenario.md)
- [RFC 0002](rfcs/0002-target-implementation-design.md)
- [目标说明](targets/README.md)
- [验证门禁](validation-gates.md)

## 工作流 1：目标注册表

目标：在添加更多后端之前使目标选择显式化。

任务：

- 添加目标 id：`evm`, `wasm-near`, `wasm-cosmwasm`,
  `solana-sbpf-linker`, `solana-zig-fork`, `move-sui`, `move-aptos`,
  `psy-dpn`。
- 定义目标家族、制品种类、所需工具和能力集
  （参见 [capability-registry.md](capability-registry.md)）。
- 为 CLI 和脚本添加目标查找函数。
- 为未知目标和不支持的能力添加诊断信息。

验收标准：

- `evm` 可以在不改变当前 EVM 行为的情况下表示为目标 profile。
- 目标 profile 可以声明外部工具需求。
- 不支持的能力错误应包含目标 id、能力 id 以及可用的源代码位置。

## 工作流 1.5：可移植 IR 和共享场景

目标：在进行非 EVM spike 之前定义合约 IR 和 Counter 场景。

任务：

- 根据 [portable-ir.md](portable-ir.md) 实现 IR 节点类型。
- 根据 [shared-scenario.md](shared-scenario.md) 表达 Counter。
- 将 Counter IR 降级到 EVM（直接降级或通过 EmitYul 适配器）。
- 将能力检查器连接到 [capability-registry.md](capability-registry.md)。

验收标准：

- Counter 模块可以在 IR 层不包含 EVM 操作码的情况下用 IR 表示。
- 从 IR 构建的 EVM 与现有的 Counter 行为一致。
- 至少有一个不支持的能力被拒绝，并带有清晰的诊断信息。
- 发射时，IR 版本出现在制品元数据中。

## 工作流 2：制品元数据

参见 [validation-gates.md](validation-gates.md) 了解当前和计划中的验证命令。

目标：每次构建都应产生机器可读的结果，以便后续提供给 CI 和云平台。

任务：

- 添加 `proof-forge-artifact.json` schema。
- 为 EVM 字节码构建发射元数据。
- 包含源模块、目标 id、制品路径、SHA-256、工具版本以及证明/检查状态。
- 从第一天起就保持 schema 的版本化。

验收标准：

- EVM 字节码构建将字节码和元数据并排写入。
- 元数据可以由 CI 脚本独立解析。
- 缺失的可选工具表示为警告，而不是格式错误的元数据。

## 工作流 3：EVM 基线加固

参见 [validation-gates.md](validation-gates.md) 了解当前和计划中的验证命令。

目标：在引入目标模型时保持 EVM 稳定。

任务：

- 保持 `proof-forge --evm-bytecode` 正常工作。
- 为简单示例添加黄金 Yul 输出。
- 在当前的 `solc --strict-assembly` 流程中添加元数据发射。
- 保留 Foundry 冒烟测试作为成熟的 EVM 冒烟测试。

验收标准：

- `lake build` 通过。
- `scripts/evm/build-examples.sh` 在装有 `solc` 的机器上成功。
- `scripts/evm/foundry-smoke.sh` 在装有 Foundry 的机器上成功。
- 生成的元数据指向字节码制品并记录 `target: evm`。

## 工作流 4：Wasm 宿主运行时拆分

目标：使 Wasm 宿主适配器由目标驱动，而不是假设每个 Wasm 合约都是 NEAR。

任务：

- 将链 extern 声明从通用的 EmitZig 运行时 extern 中移出。
- 添加由目标选择的宿主桥接列表。
- 保留 NEAR 桥接作为参考实现。
- 添加带有分配器和 region ABI 的 CosmWasm 桥接骨架。

验收标准：- Wasm 构建可以显式选择 NEAR 或 CosmWasm 桥接。
- 通用 Wasm 运行时不会强制链接 NEAR 宿主函数。
- `wasm-near` 和 `wasm-cosmwasm` 可以具有不同的必需导出。

## 工作流 5: CosmWasm spike

目标：证明 ProofForge 可以针对 NEAR 之外的其他 Wasm 宿主。

任务：

- 添加 `Lean.CosmWasm` SDK 骨架（参见 [wasm-family.md](targets/wasm-family.md)）。
- 添加 `zigc-cosmwasm` 包装器。
- 添加 `cosmwasm_contract_root.zig`。
- 导出 `interface_version_8`、`allocate`、`deallocate`、`instantiate`、`execute` 和 `query`。
- 添加使用 JSON 支持的消息的 Counter 示例。
- 添加 `cosmwasm-check` 冒烟测试。

验收标准：

- Counter Wasm 通过 `cosmwasm-check`。
- `instantiate`、`execute` 和 `query` 存在于导出中。
- 冒烟测试可以增加并查询计数器状态。

## 工作流 6: Solana sBPF-Linker spike

目标：在采用分叉编译器之前验证无分叉的 Solana 流水线。

任务：

- 围绕 `zig build-lib -target bpfel-freestanding -femit-llvm-bc` 添加 `zigc-solana-sbpf` 包装器。
- 调用 `sbpf-linker --cpu v2 --export entrypoint`。
- 添加具有一个导出 `entrypoint` 的 `solana_contract_root.zig`。
- 添加最小的 syscall/log 桥接。
- 添加显式指令清单格式（参见 [solana-sbf.md](targets/solana-sbf.md)）。
- 添加 Counter 账户示例。

验收标准：

- 由原生 Zig 生成一个最小的 `entrypoint.bc`。
- `sbpf-linker` 产生一个 `.so`。
- `.so` 在 Mollusk 或 `solana-test-validator` 中运行。
- 该 spike 记录 Lean Zig 运行时是否可以在 sBPF 约束下链接。

## 工作流 7: Solana 运行时决策

目标：决定 ProofForge 在 Solana 上是可以使用完整的 Lean 运行时，还是需要受限的运行时子集。**在工作流 6 产生 spike 数据后运行。**

问题：

- 完整的 Lean Zig 运行时是否可以在 `bpfel-freestanding` 下链接？
- 生成的 ELF 是否通过 Solana 加载器约束？
- 制品大小是否可以接受？
- 4KB 栈压力是否可控？
- 在 Solana 计算预算内，堆分配和引用计数是否可行？

决策结果：

- 在 Solana 上使用完整的 Lean Zig 运行时。
- 在 Solana 上使用受限的 Lean 运行时子集。
- 为不带完整 Lean 运行时的可移植 IR 子集生成直接的 Zig 代码。
- 回退到 `solana-zig` 分叉，同时保持 `sbpf-linker` 开放。

在 [decisions.md](decisions.md) 中记录结果。

## 工作流 8: Move 源代码生成 POC（Aptos 优先）

目标：避免将 Move 伪装成另一个 Lean 运行时目标。

任务：

- 定义可移植 IR 的 Move 兼容子集。
- 生成一个 **Aptos** Move 计数器包（Sui 将在单独的分片中跟进）。
- 运行 `aptos move compile/test`。
- 记录必须反馈到 IR 设计中的验证器限制。

验收标准：

- 生成的 Aptos Move 源代码可编译。
- 生成的包具有测试。
- 不支持的 Lean 结构在代码生成前失败。
- 后续的 Sui 对象 POC 被记录为一个单独的里程碑。

## 工作流 9: CI 扩展

有关当前和计划的验证命令，请参见 [validation-gates.md](validation-gates.md)。

目标：在第一天不需要每个外部链工具的情况下保持 CI 的实用性。

任务：

- 将 `lake build` 保留为常驻 CI。
- 仅在 `solc` 和 Foundry 可用时添加 EVM 冒烟测试。
- 为 CosmWasm、Solana 和 Move 添加带有明确工具检查的可选作业。
- 将制品元数据验证添加为独立于工具的作业。

验收标准：

- 基础 CI 不会因为缺少可选链工具而失败。
- 当特定目标的工具链存在但目标构建失败时，相应的 CI 作业会显式报错。
- 元数据架构验证在没有链工具的情况下运行。

## 工作流 10: Psy DPN ZK 目标 spike

目标：验证 ZK 电路源代码生成目标，而不将 ProofForge 与 Psy 编译器内部机制耦合。

任务：- 已完成：从一个可移植 IR fixture 生成一个 Counter `.psy` 源文件。
- 已完成：在 `scripts/psy/counter-smoke.sh` 中添加一个临时 Dargo 包生成器。
- 已完成：将 `dargo test --file` 记录为第一个本地冒烟测试运行器。
- 待办：在安装了 Psy 的 Dargo CLI 的机器上运行 `dargo compile` 并捕获 DPN 电路 JSON。
- 当 `dargo generate-abi` 可用时进行调用。
- 使用目标 id `psy-dpn` 发射 `proof-forge-artifact.json`。

验收标准：

- 生成的 `.psy` 源代码是可读的，并已检入黄金 fixture 或快照中。
- `dargo compile` 在安装了 Psy 工具链的机器上生成一个非空的 JSON 制品。
- 制品元数据记录了 Dargo/Psy 编译器版本或 commit。
- 不支持的非电路友好 IR 节点在源代码生成之前失败。

## 工作流 11: Kaspa Toccata Research 目标

目标：判断 ProofForge 是否以及如何支持 Kaspa 的 Toccata 可编程栈，同时避免把它误建模为 EVM、账户状态链或通用 ZK 电路目标。

任务：

- 已完成：为候选 id `kaspa-toccata` 添加文档优先的目标说明。
- 将目标归类为 UTXO covenant / based-app research，而不是 `zk-circuit-sourcegen`。
- 审查 UTXO state、covenant lineage、transaction v1、user lane、compute budget 和 inline proof verification 的候选能力。
- 决定第一版 spike 是生成 Silverscript，还是只围绕手写 covenant source 生成 target manifest。
- 定义一个带 successor-output validation 的极小 L1 covenant Counter-like 场景。
- 定义 covenant source、transaction v1 manifest、covenant lineage manifest 和可选 proof verifier manifest 的最小制品元数据形态。
- 在 L1 covenant 制品形态清楚前，暂缓 based-app 支持。

验收标准：

- `docs/targets/kaspa-toccata.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档区分 inline ZK verification 与 `psy-dpn` 风格的电路源代码生成。

## 建议顺序

1. 目标注册表（工作流 1）。
2. 可移植 IR + 共享 Counter 场景（工作流 1.5）。
3. EVM 制品元数据（工作流 2–3）。
4. Wasm 运行时拆分（工作流 4）。
5. **并行：** CosmWasm spike（工作流 5）和 Solana sbpf-linker spike（工作流 6）。
6. Solana 运行时决策（工作流 7 —— 在 spike 数据之后）。
7. Move Aptos POC（工作流 8）。
8. 一旦 IR fixture 存在，进行 Psy DPN 源代码生成 spike（工作流 10）。
9. 在任何 registry 变更前进行 Kaspa Toccata research target review（工作流 11）。
10. CI 目标矩阵（工作流 9）。
11. 云平台设计更新（前提条件：两个以上目标处于 Experimental 阶段；参见 [decisions.md](decisions.md)）。
