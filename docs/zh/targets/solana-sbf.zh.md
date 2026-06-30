# Solana sBPF 目标

规范目标 id：**`solana-sbpf-linker`**。此文件名 (`solana-sbf.md`) 仅作为导航的简短别名。

Solana 是最重要的非 EVM 目标，用于证明 ProofForge 的可移植核心并非暗中基于 EVM 构建。其状态模型是显式账户，而非隐式合约存储。

## 合约模型

Solana 程序公开一个入口：

```zig
export fn entrypoint(input: [*]u8) callconv(.c) u64
```

运行时输入包含：

- 账户数量
- 序列化账户
- 指令数据
- 程序 id

程序必须解析账户和指令数据，验证签名者和可写标志，修改账户数据，并可选地执行 CPI。

## 首选流水线：sbpf-linker

`zignocchio` 项目演示了一条无分叉路径：

```text
generated Zig
  -> zig build-lib -target bpfel-freestanding -femit-llvm-bc=entrypoint.bc
  -> sbpf-linker --cpu v2 --export entrypoint -o program.so entrypoint.bc
  -> Solana loader-compatible ELF
```

为什么这应该是第一个 ProofForge 路线：

- 它使用原生的 Zig 而不是特定于 Solana 的 Zig fork。
- 它更适合平台产品，因为依赖项是显式的工具。
- 它类似于 EVM/Solang 模式，即生成中间制品并调用目标打包器。

风险：

- Lean Zig 运行时可能无法在 `bpfel-freestanding` 下链接。
- 4KB 堆栈压力可能使正常的 Lean 运行时路径开销过大。
- `.rodata`、`.bss`、`.data`、panic、allocator 和 libc 的假设可能会破坏 Solana 加载器。
- 制品大小和计算单元可能会迫使使用受限的运行时子集。

## 参考流水线：solana-zig Fork

`solana-sdk-mono` 仓库展示了另一条路径：

```text
generated Zig
  -> solana-zig .sbf/.solana target
  -> dynamic `.so`
  -> Mollusk tests
```

此路线提供了更丰富的 SDK 参考，涵盖：

- 账户解析
- 类型化账户
- CPI
- PDA 辅助工具
- 事件
- Mollusk 测试

在 `sbpf-linker` 验证期间，它应保持作为参考和备选方案。

## Instruction Manifest

Solana 需要显式的账户 schema。一个 sidecar 清单应描述指令分发和账户。

示例：

```toml
[[instruction]]
name = "initialize"
tag = 0
handler = "l_Counter_initialize"
accounts = [
  { name = "authority", index = 0, signer = true, writable = true },
  { name = "counter", index = 1, signer = false, writable = true, owner = "program" },
  { name = "system_program", index = 2, signer = false, writable = false }
]

[[instruction]]
name = "increment"
tag = 1
handler = "l_Counter_increment"
accounts = [
  { name = "authority", index = 0, signer = true, writable = false },
  { name = "counter", index = 1, signer = false, writable = true, owner = "program" }
]
```

此清单应为目标元数据，而不是嵌入到通用的 Lean 源代码中。

## Lean SDK 草图

第一个版本：

```lean
namespace Solana

structure Pubkey where
  bytes : ByteArray

structure AccountRef where
  index : UInt8

opaque instructionData : IO ByteArray
opaque programId : IO Pubkey
opaque accountKey : AccountRef -> IO Pubkey
opaque accountOwner : AccountRef -> IO Pubkey
opaque isSigner : AccountRef -> IO Bool
opaque isWritable : AccountRef -> IO Bool
opaque dataLen : AccountRef -> IO UInt64
opaque readData : AccountRef -> IO ByteArray
opaque writeData : AccountRef -> ByteArray -> IO Unit
opaque lamports : AccountRef -> IO UInt64
opaque log : String -> IO Unit
opaque setReturnData : ByteArray -> IO Unit

end Solana
```

稍后：

- PDA 派生。
- CPI 包装器。
- SPL Token 辅助函数。
- 类型化账户编解码器。
- 事件编码。

## 生成的根适配器

根适配器拥有 Solana ABI 机制：

```zig
export fn entrypoint(input: [*]u8) callconv(.c) u64 {
    var ctx = solana.deserialize(input);
    lean_rt.lean_initialize_runtime_module();
    return dispatch(&ctx);
}
```

分发选项：

- 指令首字节作为 tag
- 生成的 `switch`
- 在调用 Lean 处理程序之前进行生成的账户验证
- Lean 处理程序接收账户引用或隐式上下文

初步建议：在 Zig 中进行生成的验证，Lean 处理程序接收账户引用和指令字节。这保持了 Solana 账户模型的可见性。

## 运行时验证计划

Spike 1：原始 Zig 入口

- 生成的 `entrypoint` 记录日志并返回成功。
- 使用原生 Zig + `sbpf-linker` 构建。
- 在 `solana-test-validator` 或 Mollusk 中运行。

Spike 2：Lean 运行时链接

- 将最小生成的 Lean Zig 与运行时链接。
- 无账户，仅返回成功或记录日志。
- 记录链接器错误和不支持的 section。

Spike 3：账户状态

- 带有显式账户清单的计数器账户。
- `initialize`, `increment`, `get`。
- 无 CPI。

Spike 4：CPI

- 系统程序转账或账户创建。
- PDA 签名。

Spike 5：SPL Token

- 代币转账 CPI。
- 这应等到 syscall 和账户抽象稳定后再进行。

## 测试策略

使用两种风格：

- 使用 Mollusk 进行确定性的快速程序测试。
- 使用 `solana-test-validator --bpf-program` 进行部署形态的冒烟测试。

CI 应在安装工具链之前将 Solana 测试设为可选。

## 开放性问题

- 完整的 Lean 运行时还是受限的 Solana 运行时子集？
- 生成的 Lean Zig 能否避免大的栈帧？
- 账户清单应该是 `.toml`、`.json` 还是 Lean 声明？
- 第一个 Solana POC 应该直接使用 zignocchio SDK 代码，还是仅复制最小的 syscall/账户片段？
- 能否围绕 Mollusk 为开发者构建类似 Foundry 的冒烟测试人体工程学体验？
