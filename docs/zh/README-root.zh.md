# ProofForge

Lean 优先的多链智能合约平台。

ProofForge 的长期目标是实现一套经过验证的 Lean 合约代码库，能够跨多个区块链目标家族进行编译、测试和部署。当前仓库包含 EVM 后端基线，以及向 Solana/sBPF、Wasm 家族链、Move 家族链和未来云部署平台扩展的首批设计文档。

参阅 [RFC 0001](docs/rfcs/0001-multichain-platform.md) 了解多链架构和路线图。
参阅 [RFC 0002](docs/rfcs/0002-target-implementation-design.md) 了解目标 profile、后端实现细节以及提议的构建流水线。
参阅 [docs/INDEX.md](docs/INDEX.md) 获取完整的文档地图。

中文分析文档：

- [ProofForge 多链愿景可行性分析](docs/zh/feasibility-analysis.md)
- [ProofForge 多链技术实现方案](docs/zh/technical-implementation-plan.md)
- [ProofForge 多链方案 Review 清单](docs/zh/review-checklist.md)

## 当前实现

本软件包将当前的 EVM/Yul 后端保持在 Lean 4 源码树之外。它增加了：

- `ProofForge.Evm`：一个使用 `@[extern "lean_evm_*"]` 原语的小型 EVM 合约 SDK。
- `ProofForge.Compiler.Yul`：一个 Yul AST 和打印器。
- `ProofForge.Compiler.LCNF.EmitYul`：一个 LCNF 到 Yul 的发射器。
- `proof-forge`：一个无需对 `lean` 打补丁即可将 Lean 文件编译为 Yul 或 EVM 运行时字节码的 CLI。

目前已实现的目标是 EVM。Solana/sBPF、Wasm 家族和 Move 家族目标是设计目标，而非当前的编译器输出。

构建：

```sh
lake build
```

编译示例：

```sh
lake env proof-forge --evm-bytecode --root . --module contract \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean
```

对于仅 Yul 的输出：

```sh
lake env proof-forge --root . -o build/counter.yul Examples/Evm/Contracts/Counter.lean
```

如果 `solc` 已安装，验证生成的 Yul：

```sh
solc --strict-assembly build/counter.yul --bin
```

构建从 Lean fork 迁移的 EVM 合约示例：

```sh
scripts/evm/build-examples.sh
```

此路径需要 `PATH` 上的 Foundry (`cast`/`forge`) 和 `solc`。

将一个 EVM 合约直接编译为运行时字节码：

```sh
lake env proof-forge --evm-bytecode --root . --module contract \
  -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean
```

运行 Foundry 冒烟测试：

```sh
scripts/evm/foundry-smoke.sh
```

冒烟测试运行器使用 Forge 的本地 EVM 测试运行器和 `vm.etch` 来执行生成的运行时字节码。

## 开发文档

- [开发标准](docs/development-standards.md)
- [验证门控](docs/validation-gates.md)
- [EVM 目标笔记](docs/targets/evm.md)
- [能力注册表](docs/capability-registry.md)

## 模块命名

- **Lake 模块：** `ProofForge.Evm`（在合约文件中导入）。
- **Lean 命名空间：** `Lean.Evm`（在示例中通过 `open Lean.Evm` 使用）。

这种拆分源于 Lean fork 迁移；在新代码安排重命名之前，应保留这两个名称。

## 平台方向

ProofForge 使用可移植核心加能力模型：

- 可移植核心：业务逻辑、状态机转换、数学和证明。
- 能力：显式的面向链的操作，例如存储、调用者、价值转移、事件、跨合约调用、账户/对象/资源访问以及链环境读取。
- 目标适配器：每个目标家族的 ABI、打包、测试运行器和部署逻辑。

计划中的目标家族：

- EVM：当前通过 Yul、`solc` 和 Foundry 实现的基准。
- Solana/sBPF：计划用于 Solana 账户和指令模型的后端。
- Wasm 家族：计划用于 NEAR、CosmWasm 和 Polkadot/ink 风格合约的适配器。
- Move 家族：针对 Sui 和 Aptos 的 Research 轨道。
- 比特币生态系统：目前仅限 Research；不是早期的直接 L1 后端。

未来的 CLI 方向：

```sh
proof-forge build --target evm
proof-forge build --target wasm-near        # planned reference target
proof-forge build --target wasm-cosmwasm    # planned first new Wasm spike
proof-forge build --target solana-sbpf-linker
proof-forge build --target move-aptos       # planned first Move POC
proof-forge build --target move-sui         # planned follow-up Move target
```

`proof-forge build --target ...` 正在计划中；已实现的命令仍为 `proof-forge --evm-bytecode`。

规范的目标 id：[docs/decisions.md](docs/decisions.md)。文件名 `docs/targets/solana-sbf.md` 是 Solana 目标笔记的历史别名。
