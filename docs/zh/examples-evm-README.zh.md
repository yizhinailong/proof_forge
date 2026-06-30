# ProofForge EVM 示例

本目录是一个自包含的示例仓库，用于在 Lean 中编写 EVM 智能合约并通过 EmitYul 进行编译。

它演示了 [`ProofForge/Evm.lean`](../../ProofForge/Evm.lean) 中的 `ProofForge.Evm` SDK。以 `ProofForge.Evm` 导入模块并使用 `Lean.Evm` 命名空间 (`open Lean.Evm`)。

有关 CLI 模式、`.evm-methods` sidecar 格式、能力映射和已知限制的权威来源，请参阅 [docs/targets/evm.md](../../docs/targets/evm.md)。

- `Counter.lean` 使用 `Storage.load`/`store` 实现了一个带有 `get`/`set`/`increment`/`decrement` 方法的简单计数器。
- `SimpleToken.lean` 是一个具有所有者访问控制、用于余额的 `Storage.mapLoad`/`mapStore` 以及条件转账功能的 ERC-20 风格代币。
- `ArrayExample.lean` 演示了内存中的 `Array Nat` 字面量、元素访问 (`xs[i]!`)、大小查询以及对数组元素的算术运算。

## 构建所有示例

从仓库根目录执行：

```bash
scripts/evm/build-examples.sh
```

这会通过 `proof-forge --evm-bytecode` 将每个 `.lean` 合约编译为 EVM 字节码 (Lean -> EmitYul -> Yul -> `solc --strict-assembly` -> 字节码)。
它需要 `PATH` 上的 Foundry (`cast`/`forge`) 和 `solc`。

## 运行 Foundry 冒烟测试

```bash
scripts/evm/foundry-smoke.sh
```

这会编译示例，并使用 Foundry 的 `vm.etch` cheatcode 针对生成的运行时字节码运行 Forge 测试。

## 当前 EVM 支持

目前的支持程度足以通过 `proof-forge --evm-bytecode` 编写和部署小型 Lean EVM 合约：

- 合约方法：通过 4 字节函数选择器进行选择器分发（`.evm-methods` 文件）。
- 存储：`Storage.load`/`store` (sload/sstore)，`Storage.mapLoad`/`mapStore`（通过 keccak256 实现的映射）。
- 环境：`Env.sender` (caller)，`Env.value` (msg.value)，`Env.blockNumber`，`Env.balance`。
- 算术：Nat 加/减/乘/除/取模、比较、位运算（全部受限于 U256）。
- 控制流：if-then-else、match、布尔逻辑。
- 数组：字面量构建 (`#[...]`)、元素访问 (`xs[i]!`)、大小。
- Externals：`call`、`staticcall`、`delegatecall`、`create`、`create2`、`selfdestruct`。
- 事件：`log0`/`log1`/`log2`。
- Revert：基础 `revert` 和 `revertWithReason` (Solidity `Error(string)` ABI)。

目前仍有一些重要限制：

- `Nat` 受限于 U256（溢出时 revert）；EVM 上没有大数 (bignum)/GMP。
- `String` 字面量已分配，但字符串操作 API（拼接、比较）尚未在 Yul 运行时中完全实现。
- 独立的 `proof-forge` CLI 使用 `runFrontend` 路径；它不会对上游 `lean` 二进制文件进行补丁。
