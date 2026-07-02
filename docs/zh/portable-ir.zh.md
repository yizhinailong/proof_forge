# 可移植合约 IR

状态：**草案规范 (Phase 1)**

可移植合约 IR 位于链中立的 Contract Intent API 与目标后端之间。它表达与链无关的业务逻辑，以及所选目标适配器将要降级的 target-resolved capability effect。

相关：[RFC 0001](rfcs/0001-multichain-platform.md),
[RFC 0002](rfcs/0002-target-implementation-design.md),
[RFC 0003](rfcs/0003-portable-ir-and-runtime.md) (详细草案),
[能力注册表](capability-registry.md),
[共享场景](shared-scenario.md)。

## 目标

- 保留面向用户的模型：合约源码声明 portable intent，`--target` 在编译期选择具体链路线。
- 表示导出的入口、状态和转换，且不包含 EVM/Solana/Move ABI 细节。
- 将 target-resolved capability call 记录为类型化效应，以便目标在降级前拒绝不支持的操作。
- 携带足够的元数据用于制品发射和跨目标场景测试。

## 非目标 (v0)

- 完整保留 Lean/LCNF —— 仅保留与合约相关的子集。
- 为 Solana 或 Move 自动推断账户/对象。
- 在 target 无法安全路由某个 intent 时隐式模拟目标特定语义。
- 将运行时证明传输到目标链 —— 证明在代码生成前已在 Lean 中检查。

## 分层

```text
Lean contract source
  -> Contract Intent API
  -> target intent resolution (`--target`)
  -> CapabilityPlan
  -> Portable Contract IR + target metadata
  -> Target AST / assembler / package printer
```

默认 SDK 表面是 Contract Intent API。它不应暴露 EVM storage slot、Solana account meta、Move resource 或 Wasm host ABI。所选 target adapter 会在降级前把这些 intent 解析为 `CapabilityPlan`。Target Extension SDK 可以暴露 Solana PDA/CPI 或 Move resource primitive 等链特定操作，但这些 extension 仍通过 capability id 和 target metadata 降级，而不是向 portable IR 添加链专属 constructor。

## IR 单元 (v0 草图)

### 模块

- `name`：包/模块标识符
- `entrypoints`：导出的处理器
- `state`：声明的持久化状态槽
- `types`：模块使用的可移植结构体/枚举

### 入口

- `name`：逻辑方法名（例如 `increment`, `get`）
- `tag`：非 EVM 目标的可选分发标签
- `params`：可移植值，以及所选适配器需要显式元数据时的 target-resolved account/resource binding
- `effects`：有序的 target-resolved capability call
- `returns`：可移植返回类型或 unit

### 状态

- `id`：稳定的状态变量名
- `kind`：`scalar` | `map` | `account_owned` | `object`（目标降级提示）
- `type`：可移植类型引用

### 效应（target-resolved capability call）

- `capability`：来自 [capability-registry.md](capability-registry.md) 的 id
- `args`：可移植操作数
- `source`：用于诊断的可选 Lean 源码范围

### 表达式表面

当前 `ProofForge/IR/Contract.lean` 中的可执行 IR 为目标源码后端包含一组紧凑的表达式：

- 字面量：`U32`、`U64`/Felt、Bool，以及固定四 limb 的 Hash 字面量
- 局部变量、固定数组字面量/索引、结构体字面量和字段访问
- 数值操作：`+`、`-`、`*`、`/`、`%`、`**`
- 位运算和移位：`&`、`|`、`^`、`<<`、`>>`
- 支持的标量值类型之间的 cast
- 比较和布尔组合
- 由四个 Felt limb 动态构造 Hash 值
- 哈希 intrinsic：one-to-one 和 two-to-one 哈希操作
- 用于存储读取、映射读取、数组读取、存储路径读取和上下文读取的 effect 表达式

语句集合包括不可变和可变局部绑定、普通赋值、一等复合赋值（`+=`、`-=`、`*=`、`/=`、`%=`、`|=`、`&=`、`^=`、`<<=`、`>>=`）、语句 effect、断言、`if/else`、有界 `for` 和显式 `return`。语句 effect 包括存储写入，以及用于标量存储和通用存储路径的存储引用复合赋值 effect。

每个目标后端都必须降低它接受的每个节点，或者在源码生成前用明确诊断拒绝它。

## 与 LCNF 的关系

```text
Lean contract source
  -> Lean frontend / LCNF (today)
  -> Portable Contract IR (Phase 1)
  -> Target lowering
```

**阶段 1 转换：** 在构建 IR 提取器期间，EVM 可能会暂时从 LCNF 降级，但在阶段 2 spike 被视为完成之前，Counter 共享场景必须通过 IR 编译。

## 目标 IR 子集

每个目标接受 IR 的一个子集。不支持的结构将在能力检查时失败，并带有目标 id 和能力 id。

| 限制 | Solana | Move (Aptos/Sui) | Psy DPN |
|---|---|---|---|
| 隐式合约存储 | 拒绝 — 使用显式账户 | 拒绝 — 使用资源/对象 | 仅允许通过显式 Psy 存储/sourcegen 映射 |
| 高阶函数 | 受限运行时子集待定 | 在 v0 中拒绝 | 在 v0 中拒绝 |
| 任意堆对象 | 运行时大小待定 | 拒绝 | 拒绝 |
| 闭包 | 随 sBPF spike 待定 | 拒绝 | 拒绝 |
| 无界循环 | 随 sBPF spike 待定 | 在 v0 中拒绝 | 拒绝；需要电路友好的有界形状 |

请参阅 [targets/solana-sbf.md](targets/solana-sbf.md)、[targets/move-family.md](targets/move-family.md) 和 [targets/psy-dpn.md](targets/psy-dpn.md) 以了解特定家族的限制。

## Counter IR 示例 (v0)

[共享场景](shared-scenario.md)的逻辑模块：

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

EVM 降级将 `storage.scalar` 映射到插槽存储；Solana 映射到账户数据；CosmWasm 映射到字符串键值对 KV；Aptos 映射到账户资源字段。

## 第一阶段验收标准

- [ ] 在 Lean 中记录 IR 节点类型（`ProofForge/IR/` 或同等内容）。
- [ ] Counter 模块可在不使用 EVM 特有操作码的情况下在 IR 中表达。
- [ ] EVM 后端可以将 Counter IR 降级为 Yul（直接降级或通过现有的带有薄适配器的 EmitYul 路径）。
- [ ] 能力检查器针对每个非 EVM 目标拒绝至少一个不支持的能力，并提供清晰的诊断信息。
- [x] EVM portable IR bytecode metadata 已在 `proof-forge-artifact.json` 中记录 `irVersion: portable-ir-v0`。

## 待解决问题

- 复用多少 LCNF 与构建全新的合约 IR AST 之间的权衡？
- 账户架构（account schemas）应该存在于 IR 中还是目标 sidecar 清单中？
- 能力扩展时的 IR 版本控制策略。
