# Wasm 家族目标

Wasm 家族包括 NEAR、CosmWasm 以及随后的 Polkadot/ink! 风格的合约。它们共享一种可执行格式，但合约 ABI 不同。ProofForge 应当仅共享那些真正通用的部分。

## 通用形态

```text
Lean contract
  -> EmitZig
  -> generated Zig module
  -> target-selected Lean Zig runtime
  -> target host bridge
  -> Wasm artifact
  -> target-specific validation
```

通用工作：

- Lean 到 Zig 的代码生成。
- 为 Wasm 编译的 Lean 运行时。
- 单线程运行时 profile。
- Wasm 安全的分配器策略。
- 无 POSIX/libuv 假设。
- 制品元数据。

特定目标工作：

- 导出的函数名称和签名。
- 宿主导入。
- 存储 ABI。
- 事件/日志 ABI。
- 跨合约调用模型。
- 验证工具。
- 部署打包。

## NEAR

本地 Lean 分叉已经证明了 NEAR 的形态：

```text
Lean.Near
  -> EmitZig
  -> tools/zigc-near
  -> near_contract_root.zig
  -> host/near/lean_near.zig
  -> NEAR-compatible Wasm
```

关键经验：

- Lean SDK 可以通过 `@[extern]` 暴露链上操作。
- Zig 宿主桥接应将 Lean 对象转换为目标宿主调用。
- 方法导出可以从 sidecar 元数据生成。
- 针对目标 VM，可能需要剥离或桩化 (stubbing) WASI 导入。
- NEAR 的存储模型是隐式合约 KV 存储。

移植前的设计清理：

- 不要在通用的 EmitZig extern 列表中保留 `lean_near_*` 声明。
- 不要为每个 Wasm 目标强制链接 NEAR 宿主代码。
- 将方法元数据移入统一的目标清单。

## CosmWasm

CosmWasm 也是 Wasm，但其 ABI 是面向消息的。

预期导出：

- `interface_version_8`
- `allocate`
- `deallocate`
- `instantiate`
- `execute`
- `query`
- 稍后：`migrate`, `reply`, `sudo`, `ibc_channel_open`,
  `ibc_channel_connect`, `ibc_channel_close`, `ibc_packet_receive`,
  `ibc_packet_ack`, `ibc_packet_timeout`

预期导入包括存储、地址、加密、调试和链查询宿主函数。开始实现时，应从支持的 CosmWasm VM 版本中获取确切的导入。

首个适配器行为：

- 将消息保持为 JSON 字符串。
- 返回 JSON 响应。
- 将事件表示为属性。
- 首先使用字符串键存储。
- 稍后添加类型化 schema 生成。

## 运行时 profile

Wasm 运行时 profile 应避免：

- 线程
- POSIX 文件系统
- 进程环境
- libuv
- 原生 GMP
- 与目标无关的链宿主强制链接

运行时选项应按目标选择：

| 选项 | NEAR | CosmWasm |
|---|---|---|
| 分配器 | bump 或 Wasm 安全分配器 | CosmWasm 分配器 ABI |
| MPZ | Zig bigint 或受限算术 | Zig bigint 或受限算术 |
| 宿主桥接 | `near` | `cosmwasm` |
| 验证 | NEAR VM/MVP 检查 | `cosmwasm-check` |

## CosmWasm Counter Spike

最小 Lean 表面：

```lean
namespace CosmWasm

opaque inputJson : IO String
opaque storageRead : String -> IO (Option String)
opaque storageWrite : String -> String -> IO Unit
opaque storageRemove : String -> IO Unit
opaque returnJson : String -> IO Unit
opaque logAttribute : String -> String -> IO Unit
opaque queryChain : String -> IO String

end CosmWasm
```

预期的用户合约形态：

```lean
def instantiate : CosmWasm.Entrypoint := do
  CosmWasm.storageWrite "count" "0"
  CosmWasm.returnJson "{\"ok\":true}"

def execute : CosmWasm.Entrypoint := do
  let msg <- CosmWasm.inputJson
  if msg == "{\"increment\":{}}" then
    ...

def query : CosmWasm.Entrypoint := do
  ...
```

验收标准：

- Wasm 导出所有必需的函数。
- `cosmwasm-check` 接受该制品。
- Counter 可以实例化、增加和查询。
- 制品元数据记录了 `target: wasm-cosmwasm`。

## 待解决问题

- CosmWasm 应该通过 `wasm32-freestanding` 编译，还是通过带有导入剥离的 WASI 路径编译？
- 在制品大小成为实际问题之前，可以保留多少 Lean 运行时？
- Schema 生成应该来自 Lean 类型还是独立的清单？
- NEAR 和 CosmWasm 是否应该共享一个通用的 Wasm 内存分配器层？
