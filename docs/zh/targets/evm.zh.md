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
scripts/evm/conditional-ir-smoke.sh
scripts/evm/context-ir-smoke.sh
scripts/evm/event-ir-smoke.sh
scripts/evm/hash-ir-smoke.sh
scripts/evm/map-ir-smoke.sh
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
proof-forge --emit-conditional-ir-yul [-o output.yul]
proof-forge --emit-conditional-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-context-ir-yul [-o output.yul]
proof-forge --emit-context-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-event-ir-yul [-o output.yul]
proof-forge --emit-evm-event-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-hash-ir-yul [-o output.yul]
proof-forge --emit-evm-hash-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
proof-forge --emit-evm-map-ir-yul [-o output.yul]
proof-forge --emit-evm-map-ir-bytecode [--solc solc] [--yul-output output.yul] [--artifact-output file] [-o output.bin]
```

`--bytecode` 是 `--evm-bytecode` 的别名。

`--solc <path>` 和 `--cast <path>` 用于覆盖外部工具路径。`--artifact-output <path>` 用于覆盖默认 EVM metadata 路径；如果不指定，bytecode 模式会在 bytecode 输出旁写入 `proof-forge-artifact.json`。

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
| `storage.scalar` | `Storage.load`, `Storage.store` |
| `storage.map` | `Storage.mapLoad`, `Storage.mapStore`；portable IR `Map<U64, U64, N>` get/set/insert 和单段 map storage path |
| `caller.sender` | `Env.sender` |
| `value.native` | `Env.value` |
| `env.block` | `Env.blockNumber`, `Env.balance` |
| `crosscall.invoke` | `call`, `staticcall`, `delegatecall`, `create`, `create2` |
| `events.emit` | `log0`, `log1`, `log2`；portable IR `eventEmit` 降为 `log1`，topic0 由事件名派生 |
| `assertions.check` | Portable IR `assert` / `assert_eq` 降为 Yul revert guard |
| `control.conditional` | Portable IR `if/else` 降为 Yul `switch` block |
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
- 生产 EVM SDK 路径仍然通过 LCNF/EmitYul 降级；portable IR EVM 后端目前覆盖标量 storage/ABI、断言、局部赋值、条件分支、context read、event、`Hash` word 值与 hashing，以及 `Map<U64, U64, N>` storage fixture，其他更宽的 portable IR 节点仍以显式诊断拒绝。
- Portable IR EVM 目前仍缺少聚合 ABI 值、非 `U64` map 形态、storage array、struct、indexed/Solidity-signature event schema、跨合约调用和目标专属 deploy manifest。
- `storage.map.contains` 仍被显式拒绝，因为 EVM mapping 在没有辅助 bitmap 的情况下不跟踪 key presence。

## Portable IR 门禁

Portable IR EVM 后端与较早的 `ProofForge.Evm` SDK 路径分开跟踪：

```sh
scripts/evm/diagnostic-smoke.sh
scripts/evm/check-ir-coverage-manifest.py
scripts/evm/abi-scalar-ir-smoke.sh
scripts/evm/assert-ir-smoke.sh
scripts/evm/assignment-ir-smoke.sh
scripts/evm/conditional-ir-smoke.sh
scripts/evm/context-ir-smoke.sh
scripts/evm/event-ir-smoke.sh
scripts/evm/hash-ir-smoke.sh
scripts/evm/map-ir-smoke.sh
scripts/evm/ir-counter-smoke.sh
```

`Tests/EvmCoverage.tsv` 记录每个 portable IR constructor 在 EVM 上是 `lowered`、`validated`、`unsupported` 还是 `structural`。新增 portable IR 节点必须更新该清单，否则 CI 不应通过。

`Tests/EvmDiagnostics.lean` 固定当前 unsupported surface 的行为，确保不支持的 EVM IR 形态在 Yul 生成前失败，而不是静默遗漏行为。

`AssignmentProbe` 验证 portable IR 可变标量局部绑定和 local assignment 会降为 Yul `let` 声明与 `:=` 赋值。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、Foundry 成功执行，以及赋值后的 bool guard 为 false 时的 revert 路径。

`ConditionalProbe` 验证 portable IR 语句级 `if/else` 会降为 Yul `switch condition case 0 { else } default { then }` block。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、Foundry 执行 then/else storage 更新，以及未知 selector revert。分支内部的 `return` 仍被显式拒绝，直到 EVM IR 后端通过 Yul `leave` 支持早退 lowering。

`ContextProbe` 验证 portable IR context read 到 EVM opcode 的 lowering：`userId` 降为 `caller()`，`contractId` 降为 `address()`，`checkpointId` 降为 `number()`。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`caller.sender`、`account.explicit`、`env.block`）、通过 `vm.prank`/`vm.roll` 得到的 Foundry 运行时 context 值，以及未知 selector revert。

`EvmHashProbe` 验证 portable IR `Hash` 值在 EVM 上使用单 word ABI/storage 表示。四 limb `hash4` literal 和动态 `hashValue` 表达式会打包为一个 256-bit word；`hash` 与 `hash_two_to_one` 会降为调用 `keccak256` 的 Yul helper，分别对一个或两个 32-byte memory word 取哈希。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`crypto.hash`、`storage.scalar`）、ABI `bytes32` 参数/返回、通过 `sload`/`sstore` 的 Hash 标量 storage、Foundry `vm.load` 原始 slot，以及未知 selector revert。

`EventProbe` 验证 portable IR event emission 通过 Yul `log1` 降级。EVM IR v0 使用刻意较小的事件策略：`topic0 = keccak256(UTF-8 event name)`，log data 是按 32-byte word 连续编码的字段值。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力 `events.emit`、Foundry recorded logs（`emitter`、topic 和 decoded data）、ABI selector dispatch，以及未知 selector revert。indexed fields 和 Solidity event-signature topics 需要等 portable IR 里有显式 event declaration 后再实现。

`EvmMapProbe` 验证 portable IR `Map<U64, U64, N>` storage 使用与 SDK 一致的 Solidity-style slot layout：先把 `key` 和 `slot` 作为两个 32-byte word 写入内存，再计算 `keccak256(key || slot)`。对应 smoke 会检查 golden Yul 可复现、`solc --strict-assembly` 字节码生成、metadata 能力（`storage.scalar`、`storage.map`、`assertions.check`）、ABI get/set/insert 行为、单段 `mapKey` storage path、Foundry `vm.load` 原始 storage slot，以及未知 selector revert。

## 元数据

EVM bytecode 模式会发射 ProofForge 制品元数据 JSON。默认路径是 bytecode 输出旁边的 `proof-forge-artifact.json`；smoke 脚本会显式传入 fixture 专属 `--artifact-output`，避免并行运行时互相覆盖。

当前 EVM metadata schema 记录：

- `schemaVersion: 1`
- `target: evm`、`targetFamily: evm` 和 `artifactKind: evm-bytecode`
- source kind（`lean-sdk` 或 `portable-ir`）、source module，以及 portable IR fixture 的 `irVersion: portable-ir-v0`
- 可获得的 portable IR capability ids
- selector-facing ABI entrypoints 或 SDK method specs
- `solc` path/version
- Yul 和 bytecode 的 artifact path、byte size 和 SHA-256
- `solc --strict-assembly` 与 bytecode generation 的 validation flag

`scripts/evm/validate-artifact-metadata.py` 会在 EVM IR smoke 脚本和 `scripts/evm/build-examples.sh` 中校验这些 metadata 文件。

在统一的目标清单发布（RFC 0002）之前，方法分派仍使用 `.evm-methods` sidecar 文件。
