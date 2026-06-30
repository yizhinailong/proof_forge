# ProofForge 多链技术实现方案

日期：2026-06-30

## 总结

根据最近对 EVM、NEAR、CosmWasm、Solana、Sui 和 Aptos 的调研，ProofForge
不应该把所有链都当成同一种 backend。更合理的工程划分是：

```text
Lean 业务代码 + 证明
  -> 可移植合约 IR
  -> target profile / capability 检查
  -> 不同目标族的 backend
  -> 链原生工具构建和 smoke test
```

目标族分四类：

- 直接编译目标：EVM/Yul 是当前 baseline。
- Wasm host 目标：NEAR、CosmWasm，共享 Wasm 产物思路，但 host ABI 不同。
- 二进制工具链目标：Solana sBPF，先生成 bitcode/ELF，再用链工具加工。
- 源码生成目标：Sui Move、Aptos Move，生成 Move package，而不是搬 Lean runtime。

这份文档是给后续 review 用的工程细节版。

## 总体架构

建议逐步形成下面的目录结构：

```text
ProofForge/
  Target.lean
  Target/Capability.lean
  Target/Artifact.lean
  Target/Registry.lean
  IR/Contract.lean
  IR/Effect.lean
  Backend/Evm.lean
  Backend/Wasm/Near.lean
  Backend/Wasm/CosmWasm.lean
  Backend/Solana/SbfLinker.lean
  Backend/Move/Sui.lean
  Backend/Move/Aptos.lean
runtime/zig/host/near/
runtime/zig/host/cosmwasm/
runtime/zig/host/solana/
tools/zigc-near
tools/zigc-cosmwasm
tools/zigc-solana-sbpf
scripts/{evm,near,cosmwasm,solana,move}/
Examples/{Evm,Near,CosmWasm,Solana,Move}/
```

不是一次性大重构，而是后续每个 target 落地时往这个方向收敛。

## Target Profile

每条链都应该有一个 target profile，描述：

- target id，例如 `evm`、`wasm-cosmwasm`、`solana-sbpf-linker`。
- artifact 类型，例如 EVM bytecode、Wasm、Solana ELF、Move package。
- 支持哪些 capability。
- 需要哪些外部工具。
- build pipeline。
- smoke test 方式。

目标 id 建议：

| Target | 产物 | 路线 |
|---|---|---|
| `evm` | runtime bytecode | 当前已实现 |
| `wasm-near` | NEAR Wasm | 借鉴 Lean fork |
| `wasm-cosmwasm` | CosmWasm Wasm | 新增 Wasm adapter |
| `solana-sbpf-linker` | Solana `.so` | stock Zig + sbpf-linker |
| `solana-zig-fork` | Solana `.so` | solana-zig fork 备选 |
| `move-sui` | Sui Move package | 生成 Move source |
| `move-aptos` | Aptos Move package | 生成 Move source |

## Capability 检查

ProofForge 不能承诺所有代码都能去所有链。正确做法是先检查 capability。

例子：

- 合约使用 `msg.value` 类能力，EVM 可以直接支持。
- Solana 没有 EVM 式 `msg.value`，必须变成显式 lamport/token account。
- Sui 的状态不是 slot，也不是 KV，而是 object。
- Aptos 的状态通常是 account resource。

所以编译器应该明确报错：

```text
target move-sui does not support capability evm.raw_call
target solana-sbpf-linker requires explicit account schema for storage.counter
```

这比“偷偷转换语义”安全得多。

## Artifact Metadata

每次 build 都应该生成一个统一 metadata 文件：

```json
{
  "schemaVersion": 1,
  "target": "solana-sbpf-linker",
  "entryFile": "Examples/Solana/Counter.lean",
  "module": "Counter",
  "proofs": {
    "checked": true,
    "warnings": []
  },
  "capabilities": [
    "storage.account",
    "caller.signer",
    "events.log"
  ],
  "artifacts": [
    {
      "kind": "solana-elf",
      "path": "build/solana/counter.so",
      "sha256": "..."
    }
  ],
  "toolchain": {
    "lean": "4.x",
    "zig": "0.15.x",
    "sbpf-linker": "..."
  }
}
```

以后云平台的 artifact registry、部署记录、proof report、test report 都可以围绕这个文件扩展。

## EVM 实现路线

当前已经跑通：

```text
Lean
  -> LCNF
  -> EmitYul
  -> Yul
  -> solc --strict-assembly
  -> runtime bytecode
  -> Foundry smoke
```

下一步 EVM 应该做的是“产品化 baseline”：

- 保留现有 `proof-forge --evm-bytecode`。
- 增加 artifact metadata。
- 给 Counter、VerifiedVault、SimpleToken 增加稳定 golden 输出。
- 把 `.evm-methods` 后续统一到 target manifest。

EVM 是对照组。所有新 target 都应该拿同样的 counter/vault 场景对比。

## NEAR 实现路线

NEAR 在 Lean fork 里已经有雏形：

```text
Lean contract
  -> EmitZig
  -> tools/zigc-near
  -> Lean Zig runtime + NEAR host bridge
  -> Wasm
  -> strip/stub WASI imports
  -> NEAR-compatible Wasm
```

NEAR 的关键经验：

- `Lean.Near` 定义高层 SDK。
- `@[extern "lean_near_*"]` 让 Lean 调 host bridge。
- Zig 侧 `lean_near_*` 把 Lean String/IO/Object 转成 NEAR host API。
- `zigc-near` 生成方法导出 wrapper。

需要改进：

- 不要让 `EmitZig` 核心硬编码 `lean_near_*`。
- Wasm runtime 不能默认 force-link NEAR host。
- NEAR method export metadata 要纳入统一 manifest。

## CosmWasm 实现路线

CosmWasm 和 NEAR 一样都是 Wasm，但 ABI 完全不同。

第一版 pipeline：

```text
Lean
  -> EmitZig
  -> CosmWasm root adapter
  -> wasm32-freestanding 或 wasm32-unknown 风格 Wasm
  -> cosmwasm-check
  -> cw-multi-test 或 wasmd smoke
```

CosmWasm 需要导出：

- `interface_version_8`
- `allocate`
- `deallocate`
- `instantiate`
- `execute`
- `query`
- 后续再做 `migrate`、`reply`、`sudo`、IBC。

Lean SDK 第一版可以很朴素：

```lean
namespace CosmWasm

structure Env where
  blockHeight : UInt64
  blockTimeNanos : UInt64
  contractAddress : String

structure MessageInfo where
  sender : String
  fundsJson : String

opaque storageRead : String -> IO (Option String)
opaque storageWrite : String -> String -> IO Unit
opaque storageRemove : String -> IO Unit
opaque returnJson : String -> IO Unit
opaque logAttribute : String -> String -> IO Unit

end CosmWasm
```

第一版不要急着做 schema compiler。消息可以先走 JSON string：

```lean
def execute : CosmWasm.Execute := do
  let msg <- CosmWasm.inputJson
  if msg == "{\"increment\":{}}" then
    ...
```

后续再从 Lean 类型生成 JSON schema。

第一版 smoke：

1. 生成 `counter.wasm`。
2. 跑 `cosmwasm-check counter.wasm`。
3. 用 `cw-multi-test` 或本地 wasmd 执行：
   - instantiate
   - execute increment
   - query count

## Solana 实现路线

Solana 现在有两条路线。

### 路线 A：zignocchio / sbpf-linker

这是更符合平台化的路线：

```text
Zig source
  -> zig build-lib -target bpfel-freestanding -femit-llvm-bc=entrypoint.bc
  -> sbpf-linker --cpu v2 --export entrypoint -o program.so entrypoint.bc
```

优点：

- 不依赖 solana-zig fork。
- 更像 EVM/Solang 的“标准中间产物 + 链工具加工”。
- 可以把 `sbpf-linker` 作为外部 toolchain dependency。

风险：

- Lean Zig runtime 能不能在 `bpfel-freestanding` 下编过还需要验证。
- sBPF stack 很小，4KB 限制会影响 Lean runtime 和复杂函数。
- rodata、section、allocator、panic、libc 都要做特殊处理。

ProofForge 第一版 Solana pipeline：

```text
Lean
  -> EmitZig
  -> solana_contract_root.zig
  -> bpfel-freestanding LLVM bitcode
  -> sbpf-linker
  -> program.so
  -> Mollusk 或 solana-test-validator smoke
```

Solana root adapter 只导出一个入口：

```zig
export fn entrypoint(input: [*]u8) callconv(.c) u64 {
    var ctx = solana.deserialize(input);
    lean_rt.lean_initialize_runtime_module();
    return dispatchLeanInstruction(&ctx);
}
```

Solana 不能用 NEAR 那种多方法导出。它必须在一个入口里按 instruction data dispatch。

方法 manifest 应该描述账户：

```toml
[[instruction]]
name = "increment"
tag = 1
handler = "l_Counter_increment"
accounts = [
  { name = "authority", signer = true, writable = false },
  { name = "counter", signer = false, writable = true, owner = "program" }
]
```

第一版 Lean SDK：

```lean
namespace Solana

structure Pubkey where bytes : ByteArray
structure AccountRef where index : UInt8

opaque accountKey : AccountRef -> IO Pubkey
opaque isSigner : AccountRef -> IO Bool
opaque isWritable : AccountRef -> IO Bool
opaque readData : AccountRef -> IO ByteArray
opaque writeData : AccountRef -> ByteArray -> IO Unit
opaque log : String -> IO Unit
opaque setReturnData : ByteArray -> IO Unit

end Solana
```

先不做自动账户推断。Solana 的账户模型必须显式。

第一版 smoke：

- Counter PDA/account。
- instruction tag = `initialize/increment/get`。
- Mollusk 做快速 deterministic program test。
- `solana-test-validator --bpf-program` 做部署式 smoke。

### 路线 B：solana-zig fork

`solana-sdk-mono` 走的是 solana-zig fork 的 `.sbf/.solana` target。

优点：

- SDK 更成熟。
- 账户、CPI、typed account、program-test 示例更完整。
- Mollusk 测试链路清楚。

缺点：

- 依赖 fork 编译器。
- 对平台用户的安装成本更高。

建议：

- 先以 `solana-sbpf-linker` 为主线。
- 保留 `solana-zig-fork` 作为 fallback 和参考实现。
- 如果 Lean runtime 在 sbpf-linker 下失败，再用 fork 路线判断是否是 linker 问题还是 runtime 问题。

## Move / Sui 实现路线

Sui 不是 Lean runtime 目标，而是 Move source generation 目标。

Sui 状态模型是 object：

```move
public struct Counter has key {
    id: UID,
    value: u64,
}
```

ProofForge 应该生成：

```text
Move.toml
sources/counter.move
tests/counter_tests.move
```

Lean portable contract：

```lean
structure CounterState where
  value : UInt64

def increment (s : CounterState) : CounterState :=
  { s with value := s.value + 1 }
```

生成 Sui Move 大概是：

```move
module proof_forge_counter::counter {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    public struct Counter has key {
        id: UID,
        value: u64,
    }

    public entry fun init(ctx: &mut TxContext) {
        let counter = Counter {
            id: object::new(ctx),
            value: 0,
        };
        transfer::share_object(counter);
    }

    public entry fun increment(counter: &mut Counter) {
        counter.value = counter.value + 1;
    }
}
```

难点：

- Sui 的 object ownership 和共享对象需要在 IR 里表达。
- `Coin<T>`、transfer、dynamic fields 不能硬套 EVM storage 模型。
- 生成 Move 需要 verifier-friendly，不能只是字符串拼接。

## Move / Aptos 实现路线

Aptos 更接近账户资源模型，第一版可能比 Sui 更容易：

```move
module proof_forge_counter::counter {
    struct Counter has key {
        value: u64,
    }

    public entry fun init(account: &signer) {
        move_to(account, Counter { value: 0 });
    }

    public entry fun increment(account: &signer) acquires Counter {
        let addr = signer::address_of(account);
        let counter = borrow_global_mut<Counter>(addr);
        counter.value = counter.value + 1;
    }
}
```

Aptos 的优势：

- 账户资源模型更像“contract state under address”。
- `aptos move compile/test` 工具链清晰。

Aptos 的难点：

- Move abilities：`copy/drop/store/key` 必须正确生成。
- 全局资源访问需要 `acquires`。
- signer 权限和资源 ownership 不能模糊处理。

## Portable IR 要约束什么

为了能生成 Solana 和 Move，IR 不能太像 EVM。

第一版 IR 应该只支持：

- `UInt8/UInt32/UInt64/Bool/String/ByteArray`
- struct
- enum/tagged instruction
- pure state transition
- bounded arrays/maps 的抽象
- 显式 capability call
- 显式 entrypoint metadata

暂时不要支持：

- 任意 higher-order function runtime。
- 任意 Lean closure。
- 无限制递归。
- 动态反射。
- 原始 chain syscall。

证明可以留在 Lean 编译阶段，不需要搬到目标链 runtime。

## 近期里程碑

### M1：目标注册和 metadata

验收：

- 有 `TargetProfile` 概念。
- EVM build 生成 `proof-forge-artifact.json`。
- 文档列出每个 target 的 capability。

### M2：CosmWasm spike

验收：

- 能生成一个最小 `counter.wasm`。
- 有 `allocate/deallocate/interface_version_8`。
- `cosmwasm-check` 通过。
- 能 instantiate/execute/query。

### M3：Solana sbpf-linker spike

验收：

- stock Zig 能生成 `entrypoint.bc`。
- `sbpf-linker` 能生成 `.so`。
- 最小 entrypoint 能在 Mollusk 或 validator 跑。
- 明确 Lean runtime 哪些部分不能进 sBPF。

### M4：Move sourcegen spike

验收：

- 生成 Sui 或 Aptos counter package。
- `sui move build/test` 或 `aptos move compile/test` 通过。
- 记录 IR 到 Move 的限制。

## 当前判断

优先做：

1. EVM metadata 和 target profile。
2. CosmWasm，因为它能复用 NEAR/Wasm 经验。
3. Solana sbpf-linker，因为它不依赖 fork Zig，更适合平台产品。
4. Aptos/Sui Move sourcegen POC。

不要急着做：

- 完整云平台。
- 直接 Move bytecode。
- 自动 Solana account 推断。
- 所有 Wasm 链一次支持。

最关键的工程原则：

> target 差异必须显式进入 type/capability/manifest，而不是藏在 backend 里。

## 参考资料

- 当前 EVM baseline：本仓库 `ProofForge.Evm`、`ProofForge.Compiler.LCNF.EmitYul`、`scripts/evm/foundry-smoke.sh`。
- NEAR 参考实现：本地 `/Users/davirian/dev/active/lean4-zig-compiler` 里的 `Lean.Near`、`tools/zigc-near`、`src/runtime/zig/host/near`。
- Solana solana-zig fork 路线：`https://github.com/DaviRain-Su/solana-sdk-mono.git`。
- Solana stock Zig + sbpf-linker 路线：`https://github.com/vitorpy/zignocchio`。
- sbpf-linker：`https://github.com/blueshift-gg/sbpf-linker`。
- CosmWasm：`https://cosmwasm.cosmos.network/`。
- Sui Move：`https://docs.sui.io/concepts/sui-move-concepts`。
- Aptos Move：`https://aptos.dev/network/blockchain/move`。
