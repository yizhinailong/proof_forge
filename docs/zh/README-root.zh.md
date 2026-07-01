# ProofForge

Lean 优先的多链智能合约平台。

ProofForge 的长期目标是建立一个经过验证的 Lean 合约代码库，该代码库可以在多个区块链目标家族中进行编译、测试和部署。当前仓库包含 EVM 后端基线，以及扩展至 Solana/sBPF、Wasm 家族链、Move 家族链和未来云部署平台的首批设计文档。

有关多链架构和路线图，请参阅 [RFC 0001](docs/rfcs/0001-multichain-platform.md)。
有关目标 profile、后端实现细节和提议的构建流水线，请参阅 [RFC 0002](docs/rfcs/0002-target-implementation-design.md)。
有关完整文档地图，请参阅 [docs/INDEX.md](docs/INDEX.md)。

中文分析文档：

- [ProofForge 多链愿景可行性分析](docs/zh/feasibility-analysis.md)
- [ProofForge 多链技术实现方案](docs/zh/technical-implementation-plan.md)
- [ProofForge 多链方案 Review 清单](docs/zh/review-checklist.md)

## 当前实现

此包将当前的 EVM/Yul 后端保留在 Lean 4 源码树之外。它增加了：

- `ProofForge.Evm`：一个使用 `@[extern "lean_evm_*"]` 原语的小型 EVM 合约 SDK。
- `ProofForge.Compiler.Yul`：一个 Yul AST 和打印器。
- `ProofForge.Compiler.LCNF.EmitYul`：一个 LCNF 到 Yul 的发射器。
- `proof-forge`：一个在不补丁 `lean` 的情况下，将 Lean 文件编译为 Yul 或 EVM 运行时字节码的 CLI。

目前已实现的目标是 EVM。Solana/sBPF、Wasm 家族和 Move 家族目标是设计目标，而非当前的编译器输出。

推荐的本地命令运行器：

```sh
just --list
just build
just check
just evm-smoke abi-scalar
just evm-all
```

根目录 `justfile` 是面向开发者的命令目录。底层验证逻辑仍然保留在
`scripts/` 中，因此直接调用脚本仍然适用于 CI、调试和特定目标文档。
如果本机尚未安装 `just`，可以从
[casey/just](https://github.com/casey/just) 安装。

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

验证生成的 Yul（如果 `solc` 已安装）：

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

生成并验证当前的 Psy/DPN Counter IR spike：

```sh
lake env proof-forge --emit-counter-ir-psy -o build/psy/Counter.psy
scripts/psy/counter-smoke.sh
```

验证 Psy/DPN 表达式谓词 fixture，它涵盖了相等、不等、排序比较以及布尔组合：

```sh
lake env proof-forge --emit-expression-predicate-ir-psy -o build/psy/ExpressionPredicateProbe.psy
scripts/psy/expression-predicate-smoke.sh
```

验证 Psy/DPN 算术 fixture，该 fixture 练习了减法、乘法和嵌套算术优先级：

```sh
lake env proof-forge --emit-arithmetic-ir-psy -o build/psy/ArithmeticProbe.psy
scripts/psy/arithmetic-smoke.sh
```

验证 Psy/DPN `u32` 算术 fixture，它镜像了上游 `u32_test.psy` 的核心形态：

```sh
lake env proof-forge --emit-u32-arithmetic-ir-psy -o build/psy/U32ArithmeticProbe.psy
scripts/psy/u32-arithmetic-smoke.sh
```

验证 Psy/DPN bitwise fixture，该 fixture 演练了 Felt 以及 `u32` `&`、`|`、`^`、`<<` 和 `>>` 的降级：

```sh
lake env proof-forge --emit-bitwise-ir-psy -o build/psy/BitwiseProbe.psy
scripts/psy/bitwise-smoke.sh
```

验证 Psy/DPN U32 哈希打包 fixture，该 fixture 运用了 `[u32; 8]` limb 数组、U32 ABI 参数、转换为 Felt 以及动态 `Hash` 构建：

```sh
lake env proof-forge --emit-u32-hash-packing-ir-psy -o build/psy/U32HashPackingProbe.psy
scripts/psy/u32-hash-packing-smoke.sh
```

验证 Psy/DPN 条件 fixture，该 fixture 演练了语句级的 `if/else` 降级：

```sh
lake env proof-forge --emit-conditional-ir-psy -o build/psy/ConditionalProbe.psy
scripts/psy/conditional-smoke.sh
```

验证 Psy/DPN 上下文 fixture，该 fixture 演练了参数降级和 Psy 上下文读取：

```sh
lake env proof-forge --emit-context-ir-psy -o build/psy/ContextProbe.psy
scripts/psy/context-smoke.sh
```

验证 Psy/DPN hash fixture，该 fixture 通过 Psy `hash` 和 `hash_two_to_one` 运行 `crypto.hash`：

```sh
lake env proof-forge --emit-hash-ir-psy -o build/psy/HashProbe.psy
scripts/psy/hash-smoke.sh
```

验证 Psy/DPN map fixture，该 fixture 通过 Psy `contains`、`get`、`insert` 和 `set` 运用了固定容量的 `Map<Hash, Hash, N>` 存储：

```sh
lake env proof-forge --emit-map-ir-psy -o build/psy/MapProbe.psy
scripts/psy/map-smoke.sh
```

验证 Psy/DPN 断言 fixture，该 fixture 演练了 IR 级别的 `assert` 和 `assert_eq` 降级：

```sh
lake env proof-forge --emit-assert-ir-psy -o build/psy/AssertProbe.psy
scripts/psy/assert-smoke.sh
```

验证 Psy/DPN 有界循环 fixture，该 fixture 测试了静态 `for` 降级：

```sh
lake env proof-forge --emit-loop-ir-psy -o build/psy/LoopProbe.psy
scripts/psy/loop-smoke.sh
```

验证 Psy/DPN 固定数组测试固件，该固件运用了数组字面量、索引和固定数组存储：

```sh
lake env proof-forge --emit-array-ir-psy -o build/psy/ArrayProbe.psy
scripts/psy/array-smoke.sh
```

验证 Psy/DPN struct fixture，它测试了结构体字面量、字段访问和标量存储结构体：

```sh
lake env proof-forge --emit-struct-ir-psy -o build/psy/StructProbe.psy
scripts/psy/struct-smoke.sh
```

验证 Psy/DPN struct-array fixture，该 fixture 测试了结构体数组和固定存储结构体数组：

```sh
lake env proof-forge --emit-struct-array-ir-psy -o build/psy/StructArrayProbe.psy
scripts/psy/struct-array-smoke.sh
```

验证 Psy/DPN ABI aggregate fixture，该 fixture 运用了面向 ABI 的结构体参数、固定数组参数以及结构体返回值：

```sh
lake env proof-forge --emit-abi-aggregate-ir-psy -o build/psy/AbiAggregateProbe.psy
scripts/psy/abi-aggregate-smoke.sh
```

验证 Psy/DPN 嵌套聚合 fixture，该 fixture 运用了可变局部结构体数组、嵌套固定数组以及字段路径赋值：

```sh
lake env proof-forge --emit-nested-aggregate-ir-psy -o build/psy/NestedAggregateProbe.psy
scripts/psy/nested-aggregate-smoke.sh
```

验证 Psy/DPN 存储嵌套聚合 fixture，该 fixture 演练了跨越 `#[ref]` 结构体字段和存储数组的嵌套存储路径：

```sh
lake env proof-forge --emit-storage-nested-aggregate-ir-psy -o build/psy/StorageNestedAggregateProbe.psy
scripts/psy/storage-nested-aggregate-smoke.sh
```

验证 Psy/DPN unsupported-shape 诊断：

```sh
scripts/psy/diagnostic-smoke.sh
```

每个由 Dargo 支持的 Psy 冒烟测试都会在 Dargo 输出旁边写入并验证 `target/proof-forge-deploy.json` 和 `target/proof-forge-artifact.json`。部署清单记录了编译后的 DPN 方法 id、ABI、部署者、状态树高度、源代码/电路/ABI 哈希以及当前上游 `gen_deploy_json` 差距。

Psy 冒烟测试预期 `PATH` 上的 `dargo`。首选安装程序为 `psyup`：

```sh
curl -fsSL https://raw.githubusercontent.com/QEDProtocol/psyup/main/install.sh | bash
```

在 macOS arm64 上，`psyup` 最新版本目前可能未发布匹配的工具链 tarball。已知 `psyup install 0.1.0` 提供 `psy-toolchain-v0.1.0-aarch64-apple-darwin.tar.gz`。

## 开发文档

- [开发标准](docs/development-standards.md)
- [验证门禁](docs/validation-gates.md)
- [EVM 目标说明](docs/targets/evm.md)
- [能力注册表](docs/capability-registry.md)

## 模块命名

- **Lake 模块：**`ProofForge.Evm`（在合约文件中导入）。
- **Lean 命名空间：**`Lean.Evm`（在示例中通过 `open Lean.Evm` 使用）。

这种拆分源于 Lean fork 迁移；在新代码安排重命名之前，应同时保留这两个名称。

## 平台方向

ProofForge 使用可移植核心加能力模型：

- 可移植核心：业务逻辑、状态机转换、数学和证明。
- 能力：显式的面向链的操作，例如存储、调用者、价值转移、事件、跨合约调用、账户/对象/资源访问以及链环境读取。
- 目标适配器：针对每个目标家族的 ABI、打包、测试运行器和部署逻辑。

计划中的目标家族：

- EVM：目前通过 Yul、`solc` 和 Foundry 实现的基线。
- Solana/sBPF：针对 Solana 账户和指令模型的计划后端。
- Wasm 家族：针对 NEAR、CosmWasm 和 Polkadot/ink 风格合约的计划适配器。
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

`proof-forge build --target ...` 已在计划中；已实现的命令仍为 `proof-forge --evm-bytecode`。

规范的目标 id：[docs/decisions.md](docs/decisions.md)。文件名 `docs/targets/solana-sbf.md` 是 Solana 目标笔记的历史别名。
