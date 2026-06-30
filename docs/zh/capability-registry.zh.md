# 能力注册表

状态：**草案规范 (Phase 1)**

用于目标 profile、制品元数据和编译时拒绝的规范能力 id。语义含义与 [RFC 0002](rfcs/0002-target-implementation-design.md) 中的矩阵保持一致。

图例：**Y** 已支持（计划中或已实现），**P** 部分支持/仅限 spike，**N** 不支持，**—** 不适用。

## 与目标 id 的关系

- 目标 id 记录在 `docs/decisions.md` 中，并由 `docs/rfcs/0002-target-implementation-design.md` 汇总。
- 此注册表拥有能力 id，而非目标生命周期阶段。
- 文档不得为相同的语义发明替代 id。


## 核心能力

| 能力 id | 可移植含义 | EVM | NEAR | CosmWasm | Solana | Aptos | Sui | Psy DPN |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `storage.scalar` | 单个持久化标量 | Y | Y | Y | Y | Y | Y | Y |
| `storage.map` | 键值对或映射存储 | Y | Y | Y | P | P | P | P |
| `caller.sender` | 交易签名者/调用者 | Y | Y | Y | Y | Y | Y | P |
| `value.native` | 调用附带的原生代币 | Y | Y | Y | Y | Y | Y | P |
| `events.emit` | 结构化日志/事件输出 | Y | Y | Y | Y | Y | Y | P |
| `crosscall.invoke` | 调用另一个合约/程序 | Y | Y | Y | Y | Y | Y | P |
| `env.block` | 区块高度/时间/链 id 读取 | Y | P | P | P | P | P | P |
| `crypto.hash` | 宿主或库哈希 | Y | Y | Y | Y | Y | Y | Y |
| `account.explicit` | 具名账户/对象/资源绑定 | N | N | N | Y | Y | Y | P |
| `storage.pda` | 程序派生地址状态 | N | N | N | Y | N | N | N |
| `crosscall.cpi` | 带有账户元数据的 Solana CPI | N | N | N | Y | N | N | N |
| `zk.circuit` | 将入口编译为目标电路定义 | N | N | N | N | N | N | Y |
| `zk.proof` | 目标证明生成或验证流 | N | N | N | N | N | N | P |

## Id 命名规则

- 格式：`<domain>.<operation>` 或 `<domain>.<variant>`（小写，点分隔）。
- 领域：`storage`, `caller`, `value`, `events`, `crosscall`, `env`, `crypto`, `account`, `zk`。
- 制品元数据列出了构建所使用的 id（参见 RFC 0002 制品 schema）。
- 诊断信息在拒绝时必须引用能力 id 和目标 id。

## 尚未注册的候选能力

这些候选项仅用于目标研究。在目标 profile 和 lowering 规则被接受前，不要将它们加入
`ProofForge.Target.Capability`。

### Kaspa Toccata

参见 [Kaspa Toccata 目标](targets/kaspa-toccata.zh.md)。

| 候选 id | 可移植含义 | 为什么需要单独表达 |
|---|---|---|
| `storage.utxo` | 状态位于 covenant 控制的 UTXO 或状态承诺中 | 不是账户/对象存储，也不是 EVM slot |
| `covenant.lineage` | 后继输出保持在被授权的 covenant family 中 | 这是交易/输出校验，不是普通存储 |
| `tx.v1` | 目标使用 Kaspa transaction v1 语义 | 交易投影和 payload 规则会影响正确性 |
| `tx.compute_budget` | 每个 input 的脚本 compute budget 是显式字段 | 预算是交易设计的一部分，不只是 gas 计量 |
| `lane.user` | app operation 可以使用 user lane | based-app 排序和 proof anchoring 需要它 |
| `zk.verify` | 脚本验证 L1 支持的证明 | 不等同于把目标本身编译成电路 |

`zk.circuit` 仍保留给主制品是电路或电路导向源包的目标。Toccata 可以使用证明，但它的
base target 是 Kaspa covenant package。

## EVM 映射 (基准)

| 能力 id | EVM 降级 |
|---|---|
| `storage.scalar` | `Storage.load` / `Storage.store` (sload/sstore) |
| `storage.map` | `Storage.mapLoad` / `Storage.mapStore` |
| `caller.sender` | `Env.sender` |
| `value.native` | `Env.value` |
| `events.emit` | `log0`–`log2` |
| `crosscall.invoke` | `call`, `staticcall`, `delegatecall`, `create`, `create2` |
| `env.block` | `Env.blockNumber`, 等 |

目前通过 `ProofForge.Evm` / `Lean.Evm` 实现 —— 参见 [targets/evm.md](targets/evm.md)。

## Phase 1 验收标准

- [ ] 此表中的每个 id 至少出现在一个目标的 `TargetProfile.capabilities` 中。
- [ ] EVM Counter 构建在制品元数据中列出 `storage.scalar`（以及其他使用的 id）。
- [ ] 在 EVM 上尝试 `storage.pda` 会失败并显示 `capability unsupported` 诊断信息。
- [ ] 当 RFC 0002 语义矩阵发生变化时，注册表保持同步。

## 更新日志

| 日期 | 变更 |
|---|---|
| 2026-06-30 | 初始注册表；取代中文技术方案中的临时 id |
| 2026-06-30 | 添加了 Psy DPN research 列和 ZK 能力 id |
