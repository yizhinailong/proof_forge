# EVM 目标

目标 id: **`evm`**

阶段: **Experimental** — CI 冒烟测试通过，但目标注册表、可移植 IR 和制品元数据尚未接入。

相关: [能力注册表](../capability-registry.md),
[共享场景](../shared-scenario.md),
[RFC 0002](../rfcs/0002-target-implementation-design.md)。

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
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean

scripts/evm/build-examples.sh
scripts/evm/foundry-smoke.sh
```

## CLI 模式

默认 Yul 模式：

```sh
proof-forge [--root DIR] [--module Mod.Name] [-o output.yul] [--method selector:fn:argc:view|update] input.lean
```

EVM bytecode 模式：

```sh
proof-forge --evm-bytecode [--root DIR] [--module Mod.Name] [--methods-file file] [--yul-output file] [-o output.bin] input.lean
```

`--bytecode` 是 `--evm-bytecode` 的别名。

`--solc <path>` 和 `--cast <path>` 覆盖外部工具路径。

## .evm-methods sidecar 格式

每行遵循以下语法：

```text
<solidity-signature>=<lean-export-symbol>[view|update]
```

示例：

```text
get()=l_Counter_get[view]
set(uint256)=l_Counter_set[update]
transfer(uint256,uint256)=l_SimpleToken_transfer[update]
```

解析器规则 (来自 `ProofForge/Cli.lean`):

- 空行和 `#` 注释将被忽略。
- 选择器使用 `cast sig <solidity-signature>` 计算。
- `l_Counter_get` 通过去除前导 `l_` 并添加前缀 `f_` 映射到 Yul 函数 `f_Counter_get`；这必须与 `EmitYul.yulFnName` 保持一致。
- `view`、`pure`、`return`、`returns` 和 `true` 表示分派返回一个值；`update`、`void` 和 `false` 表示除非 Lean 入口通过显式的 EVM return 自行终止，否则它返回零字节。
- EVM 字节码模式需要至少一个方法。

## 添加或更改 EVM 示例

1. 在 `Examples/Evm/Contracts/` 下添加或更新 Lean 合约。
2. 添加或更新同级的 `.evm-methods` 文件。
3. 如果该示例是基线的一部分，请在 `scripts/evm/foundry-smoke.sh` 中添加或更新用例。
4. 运行 `scripts/evm/build-examples.sh`；当 Foundry 和 `solc` 可用时运行 `scripts/evm/foundry-smoke.sh`。

## 已实现的能力

映射到 [capability-registry](../capability-registry.md) id：

| 能力 id | SDK 接口 |
|---|---|
| `storage.scalar` | `Storage.load`, `Storage.store` |
| `storage.map` | `Storage.mapLoad`, `Storage.mapStore` |
| `caller.sender` | `Env.sender` |
| `value.native` | `Env.value` |
| `env.block` | `Env.blockNumber`, `Env.balance` |
| `crosscall.invoke` | `call`, `staticcall`, `delegatecall`, `create`, `create2` |
| `events.emit` | `log0`, `log1`, `log2` |

EVM 不支持（针对其他目标的设计）：

- `account.explicit`, `storage.pda`, `crosscall.cpi`

## 模块布局

- `ProofForge/Evm.lean` — EVM SDK (`@[extern "lean_evm_*"]` 原语)。
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

- `Nat` 限制为 U256；EVM 上没有大数 (bignum)。
- Yul 运行时中的字符串操作 API 不完整。
- 尚无统一的 `proof-forge-artifact.json`（计划于工作流 2）。
- 目前的降级绕过了可移植 IR；Counter 必须在阶段 1 中通过 IR 路由。

## 元数据

方法分派使用 `.evm-methods` sidecar 文件，直到统一的目标清单落地 (RFC 0002)。
