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

### Stellar Soroban

参见 [Stellar Soroban 目标](targets/stellar-soroban.zh.md)。

大部分 Soroban 行为可以先从现有 Wasm-host 能力集开始，但若干目标语义还没有被当前 registry 覆盖。

| 候选 id | 可移植含义 | 为什么需要单独表达 |
|---|---|---|
| `auth.require` | 合约要求地址级 authorization payload | 比读取 caller/sender 更强、更结构化 |
| `auth.account_contract` | contract account 通过目标原生账户逻辑验证 authorization | Soroban account-contract flow 需要它 |
| `storage.ttl` | 状态条目有 TTL extension、archival 和 restoration 行为 | 标量/映射存储本身无法表达 |
| `artifact.contract_spec` | 构建输出包含 tooling 和 bindings 使用的 contract interface/spec metadata | 这是制品级要求，不是运行时存储 |
| `asset.stellar` | 合约使用 Stellar Asset Contract 或 token-interface 集成 | 原生资产表面不同于通用 `value.native` |

### Internet Computer

参见 [Internet Computer 目标](targets/internet-computer.zh.md)。

ICP canister 与 Wasm-host 家族有重叠，但在添加 target profile 前，需要显式表达若干 canister 语义。

| 候选 id | 可移植含义 | 为什么需要单独表达 |
|---|---|---|
| `abi.candid` | 构建输出并验证 Candid service interface | 公开 ABI 不只是导出的 Wasm symbol |
| `canister.method_mode` | entrypoint 区分 update、query 和 composite query method | call mode 影响 persistence、consensus 和 call restrictions |
| `storage.stable_memory` | 状态使用 stable memory 或 stable structures 跨 upgrade 保留 | 标量/映射存储本身无法表达 |
| `storage.orthogonal_persistence` | 状态遵循 Motoko-style orthogonal persistence 语义 | 不同于显式 key-value store |
| `principal.id` | caller/canister/user identity 是 Principal | 不是 EVM address 或通用 account id |
| `cycles.manage` | 目标可以 inspect、accept、send 或 account for cycles | cycles 是资源计量，不是普通 `value.native` |
| `crosscall.async` | cross-canister call 是异步消息流 | 不同于同步 contract call |
| `canister.lifecycle` | 目标支持 install、upgrade、stop/start 和 lifecycle hooks | lifecycle 是 deployment 与 state safety 的一部分 |
| `certified.data` | 目标暴露 certified variables 或 certified data responses | IC certification pattern 需要它 |
| `management.canister` | 目标可以调用 virtual management canister | system lifecycle API 是目标原生能力 |

### Algorand AVM

参见 [Algorand AVM 目标](targets/algorand-avm.zh.md)。

Algorand 与通用合约能力有部分重叠，但 AVM programs、storage classes、transaction groups 和 explicit resource references 在添加 target profile 前需要显式表达。

| 候选 id | 可移植含义 | 为什么需要单独表达 |
|---|---|---|
| `avm.application` | target 发射 stateful application approval 和 clear-state programs | application artifact 有两个 AVM programs 和 app lifecycle semantics |
| `avm.logicsig` | target 发射 stateless LogicSig program | LogicSig 是独立的 stateless authorization artifact，不是 app call |
| `abi.arc4` | 构建输出或验证 ARC-4 ABI / app spec metadata | public method shape 是 tooling-visible metadata，不只是导出的代码 |
| `storage.global` | contract 使用 application global state | limits 和 access rules 不同于 local 或 box state |
| `storage.local` | contract 使用 account-local application state | state 按 account 和 app 索引，不是 global contract map |
| `storage.box` | contract 使用 box storage，并带显式 box references | box access 需要 resource references 和 budget planning |
| `tx.group` | contract 依赖 atomic transaction group ordering 或 inspection | group semantics 是目标原生 transaction context |
| `tx.resource_refs` | app call 需要显式 accounts、assets、apps 或 boxes references | resource availability 会影响 AVM execution 能否访问数据 |
| `itxn.submit` | application 提交 inner transactions | inner effects 是 transaction-level，不是同步 method call |
| `asset.asa` | contract 处理 Algorand Standard Assets | native asset model 不同于通用 `value.native` |
| `gas.avm_budget` | lowering 跟踪 AVM opcode budget、costs 和 program limits | AVM budget constraints 不是 EVM gas 或 Wasm host fuel |
| `artifact.algokit` | 构建输出 AlgoKit / Puya app artifacts 和 validation metadata | 目标工具链需要 app spec 和 bytecode package metadata |

### TON TVM

参见 [TON TVM 目标](targets/ton-tvm.zh.md)。

TON 与通用合约能力有部分重叠，但 TVM cells、messages 和 actions 在添加 target profile 前需要显式表达。

| 候选 id | 可移植含义 | 为什么需要单独表达 |
|---|---|---|
| `storage.cell` | contract state 编码为 TVM cells、slices 和 builders | 不是 EVM slot storage 或 host KV |
| `abi.tlb` | 构建输出或验证 TL-B/cell layout metadata | 公开数据形态是 cell-oriented |
| `message.recv` | contract 处理 internal 或 external inbound messages | entrypoint 形态由 message 驱动 |
| `message.send` | contract 通过 action semantics 发出 outbound messages | 不是同步 cross-contract calls |
| `method.get` | contract 暴露 off-chain get methods | 不同于会改变状态的 message handlers |
| `action.list` | target effects 累积在 TVM action lists 中 | send/deploy/reserve effects 需要它 |
| `state.init` | deploy 需要 code/data `StateInit` handling | deployment artifact 是目标原生制品 |
| `account.status` | account lifecycle/status 影响行为 | uninit/active/frozen/deleted handling 需要它 |
| `gas.tvm` | TVM gas 和 fee model 显式存在 | 不是通用 EVM gas 或 host fee metering |
| `asset.jetton` | contract 集成 TON jetton/token standards | 原生 token standard 不同于 `value.native` |

### Bitcoin Cash CashScript

参见 [Bitcoin Cash CashScript 目标](targets/bitcoin-cash-cashscript.zh.md)。

BCH/CashScript 与 UTXO covenant 目标有重叠，但 CashVM、transaction introspection、CashTokens 和 transaction-builder 语义在添加 target profile 前需要显式表达。

| 候选 id | 可移植含义 | 为什么需要单独表达 |
|---|---|---|
| `storage.utxo` | state 和 value 位于 spendable UTXOs | 不是账户/对象存储或 global contract state |
| `script.p2sh` | contract deployment/addressing 使用 P2SH locking scripts | deployment/address surface 是目标原生能力 |
| `script.unlocker` | contract calls 是 selected UTXOs 的 unlocking scripts | 不是普通 method dispatch |
| `tx.introspection` | contract 读取当前交易 inputs/outputs 和 active input data | BCH CashVM 的核心 covenant mechanism |
| `covenant.introspection` | contract 通过 introspection 约束 successor outputs | covenant-style state transition 需要它 |
| `storage.local_state` | local state 通过 script data 或 CashTokens commitments 模拟 | 不是 persistent global storage |
| `asset.cashtoken` | contract 处理 CashTokens category、capability、NFT commitment 和 token amount | native asset model 不同于通用 `value.native` |
| `timelock.locktime` | contract 依赖 locktime、sequence 或 age checks | 不同于普通 block reads |
| `signature.checksig` | contract 将 signature verification 作为 spend condition | UTXO spend authorization 是 script-level |
| `artifact.cashscript` | 构建输出 CashScript artifact JSON 和 bytecode metadata | 目标工具链要求 |
| `tx.builder` | validation 包含构造并评估 spend transaction | 实际目标语义需要 transaction construction |

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
