# 可移植合约 IR

状态：**草案规范 (阶段 1)**

可移植合约 IR 位于链中立的合约意图 API 与目标后端之间。它表达了链无关的业务逻辑，以及所选目标适配器将要降级的目标解析的能力效应。

相关：[RFC 0001](rfcs/0001-multichain-platform.md),
[RFC 0002](rfcs/0002-target-implementation-design.md),
[RFC 0003](rfcs/0003-portable-ir-and-runtime.md) (详细草案),
[能力注册表](capability-registry.md),
[共享场景](shared-scenario.md)。

## 目标

- 保留面向用户的模型，即合约源码声明可移植意图，而 `--target` 在编译时选择具体的链路由。
- 表示导出的入口、状态和转换，而不涉及 EVM/Solana/Move 的 ABI 细节。
- 将目标解析的能力调用记录为类型化效应，以便目标可以在降级之前拒绝不支持的操作。
- 携带足够的元数据用于制品发射和跨目标场景测试。

## 非目标 (v0)

- 完整的 Lean/LCNF 保留 —— 仅保留合约相关的子集。
- 为 Solana 或 Move 自动进行账户/对象推断。
- 当目标无法安全路由意图时，隐式模拟目标特定语义。
- 向目标链进行运行时证明传输 —— 证明在代码生成前已在 Lean 中完成检查。

## 分层

```text
Lean contract source
  -> Contract Intent API
  -> target intent resolution (`--target`)
  -> CapabilityPlan
  -> Portable Contract IR + target metadata
  -> Target AST / assembler / package printer
```

默认 SDK 表面是 Contract Intent API。它不应暴露 EVM 存储插槽、Solana 账户元数据、Move 资源或 Wasm 宿主 ABI。所选的目标适配器在降级之前将这些意图解析为 `CapabilityPlan`。目标扩展 SDK 可能会暴露特定于链的操作，例如 Solana PDA/CPI 或 Move 资源原语，但这些扩展仍然通过能力 id 和目标元数据进行降级，而不是向可移植 IR 添加仅限链的构造函数。

## IR 单元 (v0 草图)

### Module

- `name`：包/模块标识符
- `entrypoints`：导出的处理程序
- `state`：声明的持久状态插槽
- `types`：模块使用的可移植结构体/枚举

### 入口

- `name`：逻辑方法名称（例如 `increment`，`get`）
- `tag`：非 EVM 目标的可选分派标签
- `params`：当所选适配器需要显式元数据时，可移植值加上目标解析的账户/资源绑定
- `effects`：有序的目标解析的能力调用
- `returns`：可移植返回类型或 unit

### State

- `id`：稳定的状态变量名称
- `kind`：`scalar` | `map` | `array` | `dynamicArray`（仅形状）
- `type`：可移植类型引用

状态是**链中立的**。原生绑定（EVM 插槽、Solana 账户字节、NEAR 宿主 KV、Aptos 资源、Sui 对象）**不是** IR 的一部分：所选的 `--target` 通过 `ProofForge.Target.StorageBinding` (D-050 / D-028) 对其进行解析。作者只需编写一次 `state count: scalar U64`；每个后端都会为其所在的链具体化该形状。

参见 `ProofForge.IR.Portability` 以了解仅限家族的*构造函数*（例如 CREATE2、NEAR Promise 操作），这些构造函数不得伪装成可移植核心。

### Effect (目标解析的能力调用)

- `capability`：来自 [capability-registry.md](capability-registry.md) 的 id
- `args`：可移植操作数
- `source`：用于诊断的可选 Lean 源代码跨度

### 表达式表面

`ProofForge/IR/Contract.lean` 中当前的可执行 IR 包含一个用于目标源代码后端的紧凑表达式集：

- 字面量：`U32`、`U64`/Felt、Bool 以及固定的四肢 Hash 字面量
- 局部变量、固定数组字面量/索引、结构体字面量和字段访问
- 数值运算：`+`、`-`、`*`、`/`、`%`、`**`
- 位运算和移位：`&`、`|`、`^`、`<<`、`>>`
- 支持的标量值类型之间的转换
- 比较和布尔组合
- 从四个 Felt 肢动态构建 Hash 值
- 哈希内联函数：一对一和二对一哈希操作
- 用于存储读取、映射读取、数组读取、存储路径读取和上下文读取的 effect 表达式

语句集包括不可变和可变的局部绑定、普通赋值、一等复合赋值（`+=`、`-=`、`*=`、`/=`、`%=`、`|=`、`&=`、`^=`、`<<=`、`>>=`）、语句 effect、断言、`if/else`、有界 `for` 以及显式 `return`。语句 effect 包括用于标量存储和通用存储路径的存储写入和存储引用复合赋值 effect。

每个目标后端负责降级其接受的每个节点，或者在源代码生成之前通过显式诊断拒绝它。

## 与 LCNF 的关系

```text
Lean contract source
  -> Lean frontend / LCNF (today)
  -> Portable Contract IR (Phase 1)
  -> Target lowering
```

**阶段 1 过渡：** 在构建 IR 提取器期间，EVM 可能会暂时从 LCNF 降级，但在阶段 2 spike 被视为完成之前，Counter 共享场景必须通过 IR 编译。

## 目标 IR 子集

每个目标接受 IR 的一个子集。不支持的结构将在能力检查时失败，并带有目标 id 和能力 id。

| 限制 | Solana | Move (Aptos/Sui) | Psy DPN |
|---|---|---|---|
| 隐式合约存储 | 拒绝 — 使用显式账户 | 拒绝 — 使用资源/对象 | 仅允许通过显式 Psy 存储/sourcegen 映射 |
| 高阶函数 | 受限运行时子集待定 | 在 v0 中拒绝 | 在 v0 中拒绝 |
| 任意堆对象 | 运行时大小待定 | 拒绝 | 拒绝 |
| 闭包 | 随 sBPF spike 待定 | 拒绝 | 拒绝 |
| 无界循环 | 随 sBPF spike 待定 | 在 v0 中拒绝 | 拒绝；需要电路友好的有界形状 |

有关特定家族的限制，请参阅 [targets/solana-sbf.md](targets/solana-sbf.md)、[targets/move-family.md](targets/move-family.md) 和 [targets/psy-dpn.md](targets/psy-dpn.md)。

## Counter IR 示例 (v0)

用于 [共享场景](shared-scenario.md) 的逻辑模块：

```text
module Counter {
  state count: scalar U64

  entrypoint initialize() {
    effect storage.scalar.write("count", 0)
  }

  entrypoint increment() {
    let n = effect storage.scalar.read("count")
    effect storage.scalar.write("count", n + 1)
  }

  entrypoint get() -> U64 {
    return effect storage.scalar.read("count")
  }
}
```

EVM 降级将 `storage.scalar` 映射到 slot 存储；Solana 映射到账户数据；CosmWasm 映射到字符串键 KV；Aptos 映射到账户资源字段。

## 阶段 1 验收标准

- [ ] IR 节点类型已在 Lean 中文档化（`ProofForge/IR/` 或等效项）。
- [ ] Counter 模块可在不使用 EVM 特定操作码的情况下在 IR 中表达。
- [ ] EVM 后端可以将 Counter IR 降级为 Yul（直接降级或通过带有薄适配器的现有 EmitYul 路径）。
- [ ] 能力检查器针对每个非 EVM 目标拒绝至少一个不支持的能力，并提供清晰的诊断信息。
- [x] EVM 可移植 IR 字节码元数据记录 `irVersion: portable-ir-v0` in `proof-forge-artifact.json`。

## 待解决问题

- 复用多少 LCNF 还是构建全新的合约 IR AST？
- 账户 schema 应该存在于 IR 中还是目标 sidecar 清单中？
- 能力扩展时的 IR 版本控制策略。
