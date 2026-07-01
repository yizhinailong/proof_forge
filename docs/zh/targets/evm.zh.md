# EVM 目标

目标 id：**`evm`**

阶段：**Experimental** —— CI 冒烟测试、目标注册表、portable IR 诊断/覆盖门禁以及 EVM 制品元数据校验已接入。

相关内容：[能力注册表](../capability-registry.md)，[共享场景](../shared-scenario.md)，[RFC 0002](../rfcs/0002-target-implementation-design.md)。

## 流水线

```text
Lean contract (ProofForge.Evm / Lean.Evm)
  -> Lean frontend / LCNF
  -> EmitYul
  -> Yul AST + Printer
  -> solc --strict-assembly
  -> EVM runtime bytecode
  -> Foundry smoke (vm.etch)
```

## EVM 兼容链 profile

如果 EVM 兼容的 L1、L2 或 app chain 执行标准 EVM 字节码，它们不需要单独的
compiler target。ProofForge 会把它们作为 `evm` target 下面的 chain profile：

```text
ProofForge target: evm
  -> EVM runtime bytecode + ABI
  -> EVM-compatible chain profile
  -> RPC deployment / explorer verification / chain metadata
```

target profile 负责编译语义和能力集合。chain profile 负责部署元数据，例如 chain
id、RPC endpoints、native gas symbol、explorer、rollup family 和 verifier settings。
链特定的 L2 contracts、bridges、precompiles、account abstraction services 或 gas
accounting 差异，应作为 profile metadata 或可选 deployment capabilities 建模，而不是第二套
EVM compiler backend。

已实现的 chain profiles：

| Chain profile id | Compiler target | Chain id | Native gas | Rollup family | Public RPC | Explorer / verifier |
|---|---|---:|---|---|---|---|
| `robinhood-chain-testnet` | `evm` | `46630` | `ETH` | Arbitrum Orbit L2, Ethereum blobs DA | `https://rpc.testnet.chain.robinhood.com` | `https://explorer.testnet.chain.robinhood.com`, Blockscout API `https://explorer.testnet.chain.robinhood.com/api/` |

因此，Robinhood Chain 的普通合约编译已由 EVM backend 覆盖。完整产品支持仍需要部署命令或
manifest 能够选择 `robinhood-chain-testnet`，把该 profile 的 RPC metadata 传给
wallet/broadcast tooling，并在 deployment artifacts 中记录 chain profile data。

## 构建命令

```sh
lake build

lake env proof-forge --evm-bytecode --root . --module contract \
  --artifact-output build/evm/Counter.proof-forge-artifact.json \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean

scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/assert-ir-smoke.sh
scripts/evm/assignment-ir-smoke.sh
scripts/evm/assign-op-ir-smoke.sh
scripts/evm/conditional-ir-smoke.sh
scripts/evm/loop-ir-smoke.sh
scripts/evm/context-ir-smoke.sh
scripts/evm/event-ir-smoke.sh
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/hash-ir-smoke.sh
scripts/evm/map-ir-smoke.sh
scripts/evm/storage-array-ir-smoke.sh
scripts/evm/storage-struct-ir-smoke.sh
scripts/evm/typed-storage-ir-smoke.sh
scripts/evm/array-value-ir-smoke.sh
scripts/evm/struct-value-ir-smoke.sh
scripts/evm/abi-aggregate-ir-smoke.sh
```

## CLI 模式

默认 Yul 模式：

```sh
proof-forge [--root DIR] [--module Mod.Name] [-o output.yul] [--method selector:fn:argc:view|update] input.lean
```

EVM 字节码模式：

```sh
proof-forge --evm-bytecode [--root DIR] [--module Mod.Name] [--methods-file file] [--yul-output file] [--artifact-output file] [-o output.bin] input.lean
```

Portable IR EVM fixture 模式：

```sh
proof-forge --emit-counter-ir-yul [-o output.yul]
proof-forge --emit-counter-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-abi-scalar-ir-yul [-o output.yul]
proof-forge --emit-abi-scalar-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-assert-ir-yul [-o output.yul]
proof-forge --emit-assert-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-assignment-ir-yul [-o output.yul]
proof-forge --emit-assignment-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-assign-op-ir-yul [-o output.yul]
proof-forge --emit-evm-assign-op-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-conditional-ir-yul [-o output.yul]
proof-forge --emit-conditional-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-loop-ir-yul [-o output.yul]
proof-forge --emit-evm-loop-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-context-ir-yul [-o output.yul]
proof-forge --emit-context-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-event-ir-yul [-o output.yul]
proof-forge --emit-evm-event-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-crosscall-ir-yul [-o output.yul]
proof-forge --emit-evm-crosscall-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-expression-ir-yul [-o output.yul]
proof-forge --emit-evm-expression-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-hash-ir-yul [-o output.yul]
proof-forge --emit-evm-hash-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-map-ir-yul [-o output.yul]
proof-forge --emit-evm-map-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-storage-array-ir-yul [-o output.yul]
proof-forge --emit-evm-storage-array-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-storage-struct-ir-yul [-o output.yul]
proof-forge --emit-evm-storage-struct-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-typed-storage-ir-yul [-o output.yul]
proof-forge --emit-evm-typed-storage-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-array-value-ir-yul [-o output.yul]
proof-forge --emit-evm-array-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-struct-array-value-ir-yul [-o output.yul]
proof-forge --emit-evm-struct-array-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-struct-value-ir-yul [-o output.yul]
proof-forge --emit-evm-struct-value-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-abi-aggregate-ir-yul [-o output.yul]
proof-forge --emit-evm-abi-aggregate-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
```

`--bytecode` 是 `--evm-bytecode` 的别名。

`--solc <path>` 和 `--cast <path>` 用于覆盖外部工具路径。`--artifact-output <path>` 用于覆盖默认 EVM metadata 路径；如果不指定，bytecode 模式会在 bytecode 输出旁写入 `proof-forge-artifact.json`，并在 metadata 文件旁写入 `proof-forge-deploy.json`。当 smoke 脚本传入类似 `Counter.proof-forge-artifact.json` 的 fixture 专属 metadata 路径时，deploy manifest 会写成 `Counter.proof-forge-deploy.json`。

## .evm-methods sidecar 格式

每一行都遵循以下语法：

```text
<solidity-signature>=<lean-export-symbol>[view|update]
```

示例：

```text
get()=l_Counter_get[view]
set(uint256)=l_Counter_set[update]
transfer(uint256,uint256)=l_SimpleToken_transfer[update]
```

解析器规则（来自 `ProofForge/Cli.lean`）：

- 空行和 `#` 注释会被忽略。
- 选择器使用 `cast sig <solidity-signature>` 计算。
- `l_Counter_get` 通过剥离前导 `l_` 并添加前缀 `f_` 映射到 Yul 函数 `f_Counter_get`；这必须与 `EmitYul.yulFnName` 保持一致。
- `view`、`pure`、`return`、`returns` 和 `true` 表示分派返回一个值；`update`、`void` 和 `false` 表示除非 Lean 入口以显式的 EVM return 终止，否则它返回零字节。
- EVM 字节码模式要求至少有一个方法。

## 添加或更改 EVM 示例

1. 在 `Examples/Evm/Contracts/` 下添加或更新 Lean 合约。
2. 添加或更新同级的 `.evm-methods` 文件。
3. 如果该示例是基线的一部分，请在 `scripts/evm/foundry-smoke.sh` 中添加或更新一个用例。
4. 运行 `scripts/evm/build-examples.sh`；当 Foundry 和 `solc` 可用时，运行 `scripts/evm/foundry-smoke.sh`。

## 已实现的能力

映射到 [capability-registry](../capability-registry.md) id：

| 能力 id | SDK / IR 表面 |
|---|---|
| `storage.scalar` | `Storage.load`, `Storage.store`；portable IR `Bool`/`U32`/`U64`/`Hash` 标量 storage read/write、numeric word 的标量 storage 复合赋值、扁平 scalar storage struct 字段 read/write，以及扁平 scalar storage struct 的 whole read/write |
| `storage.map` | `Storage.mapLoad`, `Storage.mapStore`；portable IR `Map<K, V, N>` get/set/insert/contains 和单段 map storage path，其中 `K` 和 `V` 是 word 类型（`Bool`、`U32`、`U64` 或 `Hash`）；`contains` 使用 ProofForge 管理的 presence slot，因此 value 为零的 key 也可以保持 present |
| `storage.array` | 部分支持：portable IR `Bool`/`U32`/`U64`/`Hash` 固定 storage array 和扁平 struct 固定 storage array 降为连续 EVM storage slot，并带运行时 index bounds check；word 和扁平 struct storage array 可以通过 storage read 进入 fixed-array ABI return |
| `data.fixed_array` | 部分支持：用于 portable IR 固定 storage array、word array 的单段 index storage path、struct array 上的 index+field storage path、不可变和可变 local fixed-array value、fixed-array literal、静态和动态 local/literal index read、静态和动态 local 元素赋值/复合赋值、带 RHS 快照的 whole local fixed-array assignment、带静态/动态字段 read/write 以及带 RHS 快照 whole local assignment 的扁平 struct local fixed array、扁平静态 fixed-array ABI 参数/返回、嵌套标量 fixed-array ABI 参数/返回、元素为扁平 struct 的 fixed-array ABI 参数/返回、来自 word array 与扁平 struct array 的 storage-backed fixed-array ABI return、leaf 为 scalar word 或扁平 struct 的嵌套 fixed-array typed crosscall 参数/返回、scalar fixed-array 非 indexed event data field，以及元素为扁平 struct 的 fixed-array event data field；零长度 ABI array、嵌套 local array、leaf 为非扁平 struct 或其他不支持形态的嵌套 crosscall fixed array 仍会显式拒绝 |
| `data.struct` | 部分支持：portable IR 扁平不可变和可变 local struct value、local fixed array 内的扁平 struct element、struct literal、field access、静态 local 字段赋值/复合赋值、带 RHS 快照的 whole local struct assignment、扁平 ABI-facing struct 参数/返回、ABI-facing 参数/返回中的扁平 struct fixed array、storage-backed fixed-array-of-flat-struct ABI return、扁平非 indexed event data field、支持 whole read/write 的扁平 scalar storage struct，以及扁平 struct 固定 storage array 会把支持字段展开为 EVM word；嵌套字段和不支持的字段形态仍会显式拒绝 |
| `caller.sender` | `Env.sender` |
| `value.native` | `Env.value` |
| `env.block` | `Env.blockNumber`, `Env.balance` |
| `crosscall.invoke` | SDK `call`, `staticcall`, `delegatecall`, `create`, `create2`；portable IR `crosscallInvoke` 降为同步 EVM `call`，method 使用低 32 位 selector，参数是 32-byte word，调用失败和返回不足一个 word 都会 revert；typed crosscall 支持 Bool/U32/U64/Hash scalar-word 参数，也支持把扁平 struct、scalar fixed-array、元素为扁平 struct 的 fixed-array，以及 leaf 为 scalar word 或扁平 struct 的嵌套 fixed-array 参数展开为 ABI word；typed normal/value/static/delegate call 返回 Bool/U32/U64/Hash scalar word 并对 Bool/U32 返回做范围 guard，同时支持 entrypoint 直接返回扁平 struct、scalar fixed-array、元素为扁平 struct 的 fixed-array，以及 leaf 为 scalar word 或扁平 struct 的嵌套 fixed-array return data；`crosscallInvokeValueTyped` 会把显式 U64 call value 转发到 EVM `call` 的 value slot；`crosscallInvokeStaticTyped` 保留 static context 下状态写入失败的行为；`crosscallInvokeDelegateTyped` 保留 caller storage context；`crosscallCreate` 和 `crosscallCreate2` 通过 Yul `create`/`create2` 部署固定 init-code hex，零地址失败会 revert，并返回部署地址 word |
| `events.emit` | `log0` 到 `log4`；portable IR `eventEmit` 降为 `log1`，`eventEmitIndexed` 最多降为 `log4`，topic0 由 Solidity-style event signature 派生，非 indexed data field 可以是 scalar word、扁平 struct、scalar fixed array 或元素为扁平 struct 的 fixed array |
| `assertions.check` | Portable IR `assert` / `assert_eq` 降为 Yul revert guard |
| `control.conditional` | Portable IR `if/else` 降为 Yul `switch` block |
| `control.bounded_loop` | Portable IR `boundedFor` 降为带静态边界的 Yul `for` loop |
| `crypto.hash` | Portable IR `Hash` 值降为单 word EVM `bytes32`；`hash` / `hash_two_to_one` 降为 Yul `keccak256` helper |
| `account.explicit` | 部分支持：Portable IR `contractId` context read 降为 Yul `address()` |

EVM 不支持（设计上针对其他目标）：

- `storage.pda`, `crosscall.cpi`

## 模块布局

- `ProofForge/Evm.lean` — EVM SDK（`@[extern "lean_evm_*"]` 原语）。
- `ProofForge/Compiler/LCNF/EmitYul.lean` — LCNF 到 Yul 的降级。
- `ProofForge/Compiler/Yul/` — Yul AST 和打印器。
- `ProofForge/Cli.lean` — `proof-forge` CLI。

合约导入 `ProofForge.Evm` 和 `open Lean.Evm`。

## 示例

参见 [Examples/Evm/README.md](../../Examples/Evm/README.md)：

- `Counter.lean` — 标量存储
- `SimpleToken.lean` — 带有映射的 ERC-20 风格代币
- `ArrayExample.lean` — 内存数组
- `VerifiedVault.lean` — 合约模块中的证明
- `stdlib/` — ERC20, Ownable, Pausable

## 已知限制

- `Nat` 限制在 U256；EVM 上没有大数。
- Yul 运行时中的字符串操作 API 不完整。
- 生产 EVM SDK 路径仍然通过 LCNF/EmitYul 降级；portable IR EVM 后端目前覆盖标量 storage/ABI、断言、局部赋值、局部复合赋值、标量 storage 复合赋值、条件分支、静态 bounded loop、通过 Yul `leave` 实现的分支/loop 内早退、context read、scalar 和扁平 aggregate event data、`Hash` word 值与 hashing、带托管 key presence 的 word key/value `Map<K, V, N>` storage、`Bool`/`U32`/`U64`/`Hash` 固定 storage array、扁平 scalar storage struct、扁平 struct 固定 storage array、带静态和动态 index 的不可变和可变 local fixed-array value、标量/hash 字段上的扁平不可变和可变 local struct value、带静态/动态字段访问的扁平 struct local fixed array、扁平静态聚合 ABI 参数/返回、嵌套标量 fixed-array ABI 参数/返回、word array 和扁平 struct array 的 storage-backed fixed-array ABI return、同步返回一个 word 的 `crosscallInvoke`、支持 scalar word、扁平 struct、scalar fixed-array、元素为扁平 struct 的 fixed-array，以及 leaf 为 scalar word 或扁平 struct 的嵌套 fixed-array 参数/返回的 typed crosscall、normal/value/static/delegate typed call 的扁平 struct、scalar fixed-array、元素为扁平 struct 的 fixed-array，以及 leaf 为 scalar word 或扁平 struct 的嵌套 fixed-array entrypoint 直接返回、带 value 的 typed `crosscallInvokeValueTyped`、typed `crosscallInvokeStaticTyped`、typed `crosscallInvokeDelegateTyped`，以及固定 init-code 的 `crosscallCreate` 和 `crosscallCreate2`，其他更宽的 portable IR 节点仍以显式诊断拒绝。
- Portable IR EVM 目前仍缺少动态 ABI 值、嵌套 local array、leaf 为非扁平 struct 或其他不支持形态的嵌套 crosscall fixed array、非 word 或 aggregate map 形态、超出扁平 struct array 的 nested local struct、更完整的 event declaration、动态 constructor 参数、artifact-linked init code、variable-length 跨调用返回数据，以及真实 creation transaction 或 broadcast manifest。

## Portable IR 门禁

Portable IR EVM 后端与较早的 `ProofForge.Evm` SDK 路径分开跟踪：

```sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/assert-ir-smoke.sh
scripts/evm/assignment-ir-smoke.sh
scripts/evm/assign-op-ir-smoke.sh
scripts/evm/conditional-ir-smoke.sh
scripts/evm/loop-ir-smoke.sh
scripts/evm/context-ir-smoke.sh
scripts/evm/event-ir-smoke.sh
scripts/evm/crosscall-ir-smoke.sh
scripts/evm/expression-ir-smoke.sh
scripts/evm/hash-ir-smoke.sh
scripts/evm/map-ir-smoke.sh
scripts/evm/typed-map-ir-smoke.sh
scripts/evm/storage-array-ir-smoke.sh
scripts/evm/storage-struct-ir-smoke.sh
scripts/evm/typed-storage-ir-smoke.sh
scripts/evm/array-value-ir-smoke.sh
scripts/evm/struct-value-ir-smoke.sh
scripts/evm/abi-aggregate-ir-smoke.sh
scripts/evm/ir-counter-smoke.sh
```

`Tests/EvmCoverage.tsv` 记录每个 portable IR constructor 在 EVM 上是 `lowered`、`validated`、`unsupported` 还是 `structural`。新增 portable IR 节点必须更新该清单，否则 CI 不应通过。

`Tests/EvmDiagnostics.lean` 固定当前 unsupported surface 的行为，确保不支持的 EVM IR 形态在 Yul 生成前失败，而不是静默遗漏行为。

`AssignmentProbe` 验证 portable IR 可变标量局部绑定和 local assignment 会降为 Yul `let` 声明与 `:=` 赋值。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、Foundry 成功执行，以及赋值后的 bool guard 为 false 时的 revert 路径。

`EvmAbiAggregateProbe` 验证 portable IR 静态聚合 ABI lowering。struct 参数、fixed-array 参数、类似 `Array<Array<U64,2>,2>` 的嵌套标量 fixed array，以及元素为扁平 struct 的 fixed array 都会展开为连续 calldata word。`U32` 和 `Bool` 聚合 word 会保留 dispatcher range guard，扁平 struct/fixed-array 返回、嵌套标量 fixed-array 返回，以及扁平 struct fixed array 返回会编码为多 word ABI return data。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly`、artifact metadata 能力 `data.struct` 和 `data.fixed_array`、Foundry 对 struct、array、nested-array、tuple-array 参数与返回的调用、malformed calldata revert，以及未知 selector revert。

`EvmAssignOpProbe` 验证 portable IR 对可变 `U32`/`U64` local 和 `U64` 标量 storage 的复合赋值。local 复合赋值降为 Yul `name := op(name, value)`；标量 storage 复合赋值降为 `sstore(slot, op(sload(slot), value))`。shift operator 保持 EVM 的参数顺序，即 `shl(shift, value)` 和 `shr(shift, value)`。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力 `storage.scalar`、Foundry 返回值、原始 storage slot 更新，以及未知 selector revert。聚合 target 仍保持显式诊断。

`ConditionalProbe` 验证 portable IR 语句级 `if/else` 会降为 Yul `switch condition case 0 { else } default { then }` block。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、Foundry 执行 then/else storage 更新，以及未知 selector revert。EVM 专用的分支内早退由 `EvmLoopProbe` 覆盖。

`EvmLoopProbe` 验证 portable IR `boundedFor` 会降为 Yul `for` loop：prelude 声明 loop index，condition 与静态 exclusive stop bound 比较，post block 每轮加一。它也验证分支内和 loop 内早退：嵌套 `return` 会先写入返回值，再用 Yul `leave` 离开当前函数。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`storage.scalar`、`control.conditional`、`control.bounded_loop`）、Foundry 运行时 storage 更新、早退返回值与 storage effect，以及未知 selector revert。无效 loop 范围仍会以显式诊断失败。

`ContextProbe` 验证 portable IR context read 到 EVM opcode 的 lowering：`userId` 降为 `caller()`，`contractId` 降为 `address()`，`checkpointId` 降为 `number()`。它也通过 `native_value()` selector 验证 `nativeValue` 降为 `callvalue()`。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`caller.sender`、`account.explicit`、`env.block`、`value.native`）、通过 `vm.prank`/`vm.roll` 得到的 Foundry 运行时 context 值、通过 `probe.call{value: ...}` 得到的原生 value，以及未知 selector revert。

`EvmHashProbe` 验证 portable IR `Hash` 值在 EVM 上使用单 word ABI/storage 表示。四 limb `hash4` literal 和动态 `hashValue` 表达式会打包为一个 256-bit word；`hash` 与 `hash_two_to_one` 会降为调用 `keccak256` 的 Yul helper，分别对一个或两个 32-byte memory word 取哈希。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`crypto.hash`、`storage.scalar`）、ABI `bytes32` 参数/返回、通过 `sload`/`sstore` 的 Hash 标量 storage、Foundry `vm.load` 原始 slot，以及未知 selector revert。

`EventProbe` 验证 portable IR event emission 到 Yul log 的降级。EVM IR v0 会根据 event name 和 field type 生成 Solidity-style event signature，例如 `ValueEvent(uint64)`、`PairEvent((uint64,uint64))`、`ArrayEvent(uint64[2])` 或 `PairArrayEvent((uint64,uint64)[2])`，再用它派生 topic0。普通 `eventEmit` 降为 `log1`；`eventEmitIndexed` 会把最多三个 scalar indexed field 快照进 topic，并把剩余非 indexed field 写成 ABI-style 32-byte data word。非 indexed data field 可以是 scalar word、扁平 struct、scalar fixed array 或元素为扁平 struct 的 fixed array，aggregate value 会在调用 Yul log 前按 ABI 顺序展开。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力 `events.emit`、Foundry recorded logs（`emitter`、signature topic、indexed topic、扁平 struct data、scalar fixed-array data、fixed-array-of-struct data 和 decoded scalar data）、ABI selector dispatch，以及未知 selector revert。Aggregate indexed field 和更完整的 event declaration 仍是 portable IR 的显式 unsupported surface。

`EvmCrosscallProbe` 验证 portable IR `crosscallInvoke`、`crosscallInvokeTyped`、`crosscallInvokeValueTyped`、`crosscallInvokeStaticTyped`、`crosscallInvokeDelegateTyped`、`crosscallCreate` 和 `crosscallCreate2`。Call-like 表达式会降为按 arity、返回类型、value 模式、static 模式和 delegate 模式区分的 Yul helper。EVM IR v0 把 target 表达式解释为地址 word，把 method 表达式解释为低 32 位 selector，把 scalar 参数解释为 32-byte ABI word，把扁平 struct、scalar fixed-array、元素为扁平 struct 的 fixed-array，以及 leaf 为 scalar word 或扁平 struct 的嵌套 fixed-array 参数按 ABI 顺序展开为连续 word，并把带 value 调用的 call value 解释为 U64 word。helper 会打包 calldata，执行 `call(gas(), target, 0, ...)`、`call(gas(), target, call_value, ...)`、`staticcall(gas(), target, ...)` 或 `delegatecall(gas(), target, ...)`，在调用失败或返回数据短于预期大小时 revert，并解码一个或多个 32-byte 返回 word。Typed helper 在 normal、value、static 和 delegate 模式下覆盖 `Bool`、`U32`、`U64`、`Hash`、entrypoint 直接返回的扁平 struct、scalar fixed array、元素为扁平 struct 的 fixed array，以及 leaf 为 scalar word 或扁平 struct 的嵌套 fixed array；Bool 和 U32 helper 会在返回给 dispatcher 前拒绝越界 return word。Creation helper 会把固定 init-code hex 写入 memory，执行 `create` 或 `create2`，并在返回零地址时 revert。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力 `crosscall.invoke`、metadata entrypoint、Foundry U64 零/一/二参数调用、typed Bool/U32/Hash 调用、normal/value/static/delegate 模式下的扁平 struct、scalar fixed-array、元素为扁平 struct 的 fixed-array 和 leaf 为 scalar word 或扁平 struct 的嵌套 fixed-array aggregate typed return、扁平 struct、scalar fixed-array、元素为扁平 struct 的 fixed-array 和 leaf 为 scalar word 或扁平 struct 的嵌套 fixed-array typed-call 参数、normal/value/static/delegate 模式下的 aggregate Bool/U32 malformed return guard、native value 转发到 payable callee、带 value 的扁平/嵌套 scalar-or-flat-struct aggregate 参数、U64 read-only staticcall 返回、Bool/U32/Hash static typed return、static 扁平/嵌套 scalar-or-flat-struct aggregate 参数、非法 static Bool/U32 return guard、static context 状态写入失败、caller-storage delegatecall 读写、Bool/U32/Hash delegate typed return、delegate 扁平/嵌套 scalar-or-flat-struct aggregate 参数、非法 delegate Bool/U32 return guard、固定 init-code `create` 部署、确定性 `create2` 地址校验、对 deployed runtime 的调用、callee revert、短返回 revert、非法 typed return revert，以及未知 selector revert。

`EvmExpressionProbe` 直接验证 scalar expression lowering，而不是借由 storage 或 assignment side effect 间接覆盖。它覆盖 `U64` 和 `U32` arithmetic（`add`、`sub`、`mul`、`div`、`mod`）、通过 Yul `exp` 实现的 `U64` exponentiation、`U64`/`U32` bitwise operator 和符合 EVM 参数顺序的 shift、predicate expression（`eq`、`ne`、`lt`、`le`、`gt`、`ge`）、boolean `and`/`or`/`not`、scalar literal、不可变 local read、支持的 `U32`/`U64`/`Bool` cast、单 word scalar return、`U32`/`Bool` calldata dispatcher guard，以及 assertion guard。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力 `assertions.check`、Foundry 运行时结果、malformed calldata revert，以及未知 selector revert。

`EvmMapProbe` 验证 portable IR `Map<U64, U64, N>` storage 使用与 SDK 一致的 Solidity-style value slot layout：先把 `key` 和 `slot` 作为两个 32-byte word 写入内存，再计算 `keccak256(key || slot)`。`storage.map.contains` 使用 ProofForge 管理的 presence mapping，其根为 `keccak256(slot || PROOF_FORGE_MAP_PRESENCE)`，因此 insert 或 set 过的 key 即使 value 是零也仍然 present。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`storage.scalar`、`storage.map`、`assertions.check`）、ABI get/set/insert/contains 行为、单段 `mapKey` storage path 的 read、write 和复合赋值、Foundry `vm.load` 原始 value 和 presence storage slot，以及未知 selector revert。EVM IR v0 仍把 map path 限制为单段 `mapKey`；嵌套 map/aggregate storage path 保持显式诊断。

`EvmTypedMapProbe` 将同一套 mapping slot layout 扩展到 word key/value map。它验证 `U32`、`Bool` 和 `Hash` map key/value，仍然使用 `keccak256(key || slot)` helper，并且每个 map state 只占一个声明 slot，同时为 `contains` 使用 domain-separated presence mapping。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`storage.scalar`、`storage.map`、`assertions.check`）、`U32` 和 `Bool` map 参数的 ABI dispatcher guard、statement 和 expression 位置的 map write、previous-value return、`Hash`/`bytes32` map value、单段 `mapKey` path read/write、numeric `U32` map-path 复合赋值、typed `contains`、Foundry `vm.load` 原始 value 和 presence storage slot，以及未知 selector revert。嵌套 map path、aggregate 或非 word key/value 形态仍保持显式诊断。

`EvmStorageArrayProbe` 验证 portable IR `U64` 固定 storage array 会降为连续的 EVM storage slot。Array state 会占用 `length` 个 slot，因此定义在 array 后面的 state 会从整个 array span 之后开始。直接 `storageArrayRead`/`storageArrayWrite` effect 和单段 `index` storage path 都会通过 `__proof_forge_array_slot(base, length, index)`，在 `sload` 或 `sstore` 前对越界 index revert。它还验证 `return_values()`：先写入 storage element，再读回这些 element，并编码为 fixed-array ABI return。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`storage.scalar`、`storage.array`、`data.fixed_array`）、ABI read/write/return selector、generic path read/write 和复合赋值、Foundry 原始 slot layout、越界 revert，以及未知 selector revert。

`EvmTypedStorageProbe` 把 storage-array 门禁从最早的 `U64` 案例扩展到 word scalar 类型。它验证 `Bool` scalar storage，以及 `U32`/`Bool`/`Hash` 固定 storage array，全部使用相同的连续 word-slot layout 和 `__proof_forge_array_slot(base, length, index)` helper。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`storage.scalar`、`storage.array`、`data.fixed_array`、`assertions.check`）、word array 的 Foundry 原始 slot layout、ABI `Bool`/`Hash` 返回、写入时的 `U32` calldata range guard、typed array 的 storage-path read/write、numeric `U32` storage-path 复合赋值、越界 revert，以及未知 selector revert。

`EvmStorageStructProbe` 验证 portable IR 扁平 storage struct。Scalar storage struct 会按字段声明顺序为每个支持字段保留一个 EVM storage slot；struct 的固定 storage array 会保留 `length * field_count` 个 slot。直接 `storageStructFieldRead`/`storageStructFieldWrite`、`storageArrayStructFieldRead`/`storageArrayStructFieldWrite`、scalar `field` storage path、`index`+`field` storage path，以及 whole scalar storage struct read/write 都会降为确定性的 `sload`/`sstore`。Whole write 会先快照 RHS 字段再写入目标 slot，因此自引用 storage struct 更新会读取原始 RHS 值。Struct array 会使用 `__proof_forge_struct_array_slot(base, length, field_count, field_offset, index)`，先对越界 index revert，再计算 `base + index * field_count + field_offset`。它还验证 `return_points()`：从扁平 struct 固定 storage array 读取字段，并编码为 fixed-array-of-struct ABI return。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`storage.scalar`、`storage.array`、`data.fixed_array`、`data.struct`）、scalar 和 array struct 字段 read/write、field path 复合赋值、whole scalar storage struct read/write、storage-backed ABI struct return、storage-backed fixed-array-of-struct return、`Bool`/`U32`/`Hash` 字段、Foundry 原始 slot layout、越界 revert，以及未知 selector revert。嵌套 struct 字段和非扁平 struct storage 仍保持显式诊断。

`EvmArrayValueProbe` 验证 portable IR local fixed-array value。不可变和可变 local fixed-array binding 都会展开为每个元素一个内部 Yul local；对 local array 或 array literal 的 `arrayGet` 支持静态 `U32`/`U64` literal index 和动态 word index。动态读取会降为按长度生成的 Yul helper，动态可变 local 元素赋值和数字复合赋值会降为覆盖展开 local 的 `switch`。whole local fixed-array assignment 从另一个 local fixed-array 或 fixed-array literal 赋值时，会先把 RHS word 快照到临时 local，再写回目标元素。对应 smoke 覆盖 `U64`、`U32`、`Bool` 和 `Hash` 元素 array、静态/动态可变元素写入、whole-local assignment、golden Yul 可复现、`solc --strict-assembly`、artifact metadata、Foundry 运行时调用、动态越界 revert，以及未知 selector revert。嵌套 array 仍保持显式诊断。

`EvmStructArrayValueProbe` 验证 portable IR 的扁平 struct local fixed array。不可变和可变 local binding 会展开为每个 element field 一个 Yul local，例如 `people[1].score` 会变成确定性的内部 local。`field(arrayGet(localArray, index), name)` 支持静态 literal index 和动态 word index；动态读取复用标量 array 的按长度生成 helper，动态可变字段赋值和复合赋值会降为带 default revert 的 `switch` block。对应 smoke 覆盖 `U64`、`U32`、`Bool` 和 `Hash` 字段、静态/动态字段读取、静态/动态可变字段写入、数字字段复合赋值、golden Yul 可复现、`solc --strict-assembly`、artifact metadata 能力（`data.fixed_array`、`data.struct`、`assertions.check`）、Foundry 运行时调用、动态越界 revert，以及未知 selector revert。从另一个 local struct array 或自引用 struct-array literal 做 whole local assignment 时，会先快照 RHS 字段再写回目标字段。嵌套 array/struct element 仍保持显式诊断。

`EvmStructValueProbe` 验证 portable IR 扁平 local struct value。不可变和可变 struct local binding 都会展开为每个支持字段一个内部 Yul local；对 local struct 或直接 struct literal 的 `field` access 会降为对应的标量/hash word 表达式。静态 local 字段赋值和数字字段复合赋值会降为对这些展开 local 的赋值。whole local struct assignment 从另一个 local struct 或 struct literal 赋值时，会先把 RHS field word 快照到临时 local，再写回目标字段。对应 smoke 覆盖 `U64`、`U32`、`Bool` 和 `Hash` 字段、可变字段写入、whole-local assignment、golden Yul 可复现、`solc --strict-assembly`、artifact metadata 能力 `data.struct`、Foundry 运行时调用，以及未知 selector revert。嵌套 struct field 仍保持显式诊断。

## 元数据

EVM bytecode 模式会发射 ProofForge 制品元数据 JSON 和 ProofForge EVM deploy manifest。默认 metadata 路径是 bytecode 输出旁边的 `proof-forge-artifact.json`；smoke 脚本会显式传入 fixture 专属 `--artifact-output`，避免并行运行时互相覆盖。deploy manifest 路径由 metadata 路径派生，例如 `Counter.proof-forge-deploy.json`。

当前 EVM metadata schema 记录：

- `schemaVersion: 1`
- `target: evm`、`targetFamily: evm` 和 `artifactKind: evm-bytecode`
- source kind（`lean-sdk` 或 `portable-ir`）、source module，以及 portable IR fixture 的 `irVersion: portable-ir-v0`
- 可获得的 portable IR capability ids
- selector-facing ABI entrypoints 或 SDK method specs
- `solc` path/version
- Yul、bytecode、可选 source 和 deploy manifest 的 artifact path、byte size 和 SHA-256
- `solc --strict-assembly`、bytecode generation 与 deploy manifest generation 的 validation flag

EVM deploy manifest 会记录：

- `kind: proof-forge-evm-deploy-manifest`
- source kind/module、`irVersion`、capabilities 和 ABI entrypoints/methods
- Yul/source 输入以及 runtime bytecode 的 hash/size
- `creation.mode: runtime-bytecode`，目前 constructor args 为空且没有 init code
- `deployment.broadcast: not-generated`，因为当前 Foundry smoke 通过 `vm.etch` 安装 runtime bytecode，而不是广播链上交易

`scripts/evm/validate-artifact-metadata.py` 会在 EVM IR smoke 脚本和 `scripts/evm/build-examples.sh` 中校验这些 metadata 文件及其引用的 deploy manifest。`scripts/evm/validate-deploy-manifest.py` 可以单独校验 deploy manifest。

在统一的目标清单发布（RFC 0002）之前，方法分派仍使用 `.evm-methods` sidecar 文件。
