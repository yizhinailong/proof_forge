# Move 家族目标

Sui 和 Aptos 不属于 Wasm 或 EVM 风格的运行时目标。ProofForge 不应尝试将完整的 Lean 运行时编译到 Move 中。实际的首选路径是从受限的可移植合约 IR 进行源代码生成。

## 通用 Move 策略

```text
Lean portable contract
  -> Lean checks and proofs
  -> Move-compatible portable IR subset
  -> generated Move package
  -> target CLI build/test
```

生成的包应当具有可读性且对验证器友好。源代码生成也比直接生成字节码更易于审查。

## 共享限制

在第一个 Move 兼容 IR 中允许：

- 布尔值
- 无符号整数
- 地址
- 字节向量
- 具有具体字段的结构体
- 降级为标签的简单枚举
- 一阶函数
- 显式入口
- 显式中止代码
- 用于事件、资源和对象的目标能力

最初不允许：

- 高阶运行时函数
- 任意 Lean 闭包
- 任意递归
- Lean 堆对象
- 原始 IO
- 动态反射
- 未表示为能力的目标系统调用

证明保留在 Lean 中。生成的 Move 代码仅包含可执行的运行时逻辑。

## Sui

Sui 使用以对象为中心的模型。持久化状态映射到带有 `UID` 的对象。

生成的对象示例：

```move
public struct Counter has key {
    id: UID,
    value: u64,
}
```

映射：

| 可移植概念 | Sui 映射 |
|---|---|
| 合约状态 | 带有 `UID` 的对象 |
| 入口方法 | `public entry fun` |
| 调用者 | 调用者 `TxContext.sender(ctx)` |
| 原生资产 | `Coin<T>` |
| 事件 | 事件 `sui::event::emit` |
| 映射 | table 或动态字段 |
| 部署 | Move 包发布 |

首个包布局：

```text
build/sui/counter/
  Move.toml
  sources/counter.move
  tests/counter_tests.move
```

首个 POC：

- `Counter` 对象。
- `init(ctx: &mut TxContext)`。
- `increment(counter: &mut Counter)`。
- `value(counter: &Counter): u64`。
- Move 单元测试。

主要设计风险：Sui 对象所有权并非存储实现细节。
它会改变方法签名和调用流，因此必须在可移植 IR 或目标清单中体现。

## Aptos

Aptos 更接近于账户作用域的资源。

示例生成的资源：

```move
struct Counter has key {
    value: u64,
}
```

映射：

| 可移植概念 | Aptos 映射 |
|---|---|
| 合约状态 | 带有 `key` 的账户资源 |
| 入口方法 | `public entry fun` |
| 调用者 | `&signer` |
| 原生资产 | Aptos Coin 或同质化资产 API |
| 事件 | 框架事件 API |
| 映射 | table 资源 |
| 部署 | Move 包发布 |

首个包布局：

```text
build/aptos/counter/
  Move.toml
  sources/counter.move
  tests/counter_tests.move
```

首个 POC：

- `init(account: &signer)`.
- `increment(account: &signer) acquires Counter`.
- `value(addr: address): u64 acquires Counter`.
- Move 单元测试。

主要设计风险：Aptos 需要正确的 abilities 和 `acquires` 子句。
代码生成必须理解资源访问，而不是在事后修补字符串。

## Move 的可移植 IR 需求

IR 必须编码：

- 哪些结构体是持久化资源或对象
- 所有权模式
- 入口可变性
- 中止代码
- 访问路径
- 事件定义
- ability 需求
- 目标特定的包地址/模块名称

Move 后端应在 IR 请求不支持的行为时尽早失败。

示例：

```text
error: move-sui cannot lower implicit contract storage `balances`
hint: declare a Sui object or dynamic field mapping

error: move-aptos resource `Counter` is mutated but entrypoint has no signer
hint: add signer/account capability to the entrypoint
```

## Sui 对比 Aptos 优先

Aptos 对于首个生成的包来说可能更容易，因为其账户资源更接近传统的存储单元。从战略角度看，Sui 对于测试抽象更为重要，因为其对象模型与 EVM 的差异更大。

建议的顺序：

1. Aptos Counter 资源 POC。
2. Sui Counter 对象 POC。
3. 比较 IR 差异。
4. 将更简洁的路径提升为首个 Experimental Move 目标。

## 开放性问题

- Move 包生成应该使用 Lean、Zig 还是小型独立生成器来实现？
- 生成的 Move 应该暴露 public view 函数、entry 函数，还是两者兼有？
- 通用资产在 Sui 和 Aptos 上应如何映射到 `Coin<T>`？
- Move 的 ability 系统中有多少内容应该在可移植 IR 中建模？
- 源代码生成是否应该保留回溯到 Lean 定义的注释？
