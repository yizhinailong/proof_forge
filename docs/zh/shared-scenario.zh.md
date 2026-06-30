# 共享合约场景：Counter

状态：**草案规范 (Phase 1–2)**

Counter 场景是第一个跨目标验收标准测试。它在 Lean 业务核心中练习可移植标量状态，而不涉及特定于链的账户模型。

相关：[可移植 IR](portable-ir.md),
[能力注册表](capability-registry.md),
[Decisions](decisions.md)。

## 场景定义

一个合约维护单个无符号 64 位计数器。

| 操作 | 行为 |
|---|---|
| `initialize` | 将计数器设置为 `0` |
| `increment` | 将 `1` 加到计数器 |
| `get` | 返回当前计数器值 |

v0 不需要原生代币转账、跨合约调用或事件（v1 中可选 `events.emit`）。

## 所需能力

| 能力 id | 使用者 |
|---|---|
| `storage.scalar` | 所有操作 |
| `caller.sender` | v1 中的可选访问控制 |

## 目标特定适配

每个目标适配器将相同的逻辑场景映射到原生机制：

| 目标 | 状态表示 | 冒烟测试 |
|---|---|---|
| `evm` | 合约存储槽 | Foundry + `vm.etch` |
| `wasm-cosmwasm` | 宿主 KV 中的字符串键 `"count"` | `cosmwasm-check` + instantiate/execute/query |
| `solana-sbpf-linker` | 账户数据字段 | Mollusk 或 `solana-test-validator` |
| `move-aptos` | 签名者账户下的 `Counter` 资源 | `aptos move test` |
| `psy-dpn` | Psy 存储字段，在 v0 中可能是 `Felt`/`U32` | `dargo compile` + 内存冒烟测试 |

目标特定的账户 schema 和 manifest 是适配器关注点——不会隐藏在可移植 Lean 逻辑内部。有关指令 manifest 格式，请参阅 [solana-sbf.md](targets/solana-sbf.md)。

## Phase 2 验收标准

当**两个**并行 spike 独立通过时，Phase 2 即告完成：

### CosmWasm (`wasm-cosmwasm`)

- [ ] Counter Wasm 导出所需的 CosmWasm 入口。
- [ ] `cosmwasm-check` 通过。
- [ ] instantiate → increment → query 返回预期计数。
- [ ] 制品元数据记录 `target: wasm-cosmwasm` 和所使用的能力。

### Solana (`solana-sbpf-linker`)

- [ ] 来自标准 Zig 的最小 `entrypoint.bc`。
- [ ] `sbpf-linker` 生成可加载的 `.so`。
- [ ] 在 Mollusk 或验证节点中执行 initialize → increment → read counter。
- [ ] 指令 manifest 记录账户布局。

### 联合（在两个 spike 之后）

- [ ] 同一个可移植 IR 模块降级到 EVM + 至少一个非 EVM 目标。
- [ ] 文档列出了此场景下每个目标支持的能力。

## ZK 目标 Research 标准

`psy-dpn` 不属于 Phase 2 退出标准，但一旦源代码生成 spike 开始，它应该复用 Counter 场景。

- [ ] Counter IR 可以用 Psy 兼容的标量类型表示。
- [ ] 生成的 `.psy` 包可以使用 `dargo compile` 编译。
- [ ] 发射 DPN 电路 JSON 并记录在制品元数据中。
- [ ] 冒烟路径被记录为 `dargo execute`、`dargo test`、`psy-wasm` 或本地 Psy 节点/证明器工具。

## 示例位置

| 目标 | 路径 | 状态 |
|---|---|---|
| EVM | `Examples/Evm/Contracts/Counter.lean` | **代码库中** |
| CosmWasm | `Examples/CosmWasm/Counter.lean` | 已规划，不在代码库中 |
| Solana | `Examples/Solana/Counter.lean` | 已规划，不在代码库中 |
| Aptos | `Examples/Move/Aptos/Counter/` | 已规划，不在代码库中 |
| Psy DPN | `Examples/Psy/Counter/` | 已规划，不在代码库中 |

## v0 范围之外

- PDA 派生
- CPI / 子消息
- 访问控制 / 所有权
- 超过 U64 的溢出（目标可能会限制得更低）
