# 验证门禁

本页面记录了当前验证 ProofForge 的可运行门禁，并将其与计划中但尚未实现的门禁区分开来。它反映了实际的脚本和 `.github/workflows/ci.yml`；它不会添加或编辑 CI 任务。

## 当前门禁

| 门禁 | 命令 | 前提条件 | 证明了什么 | 未证明什么 |
|---|---|---|---|---|
| Lean 包构建 | `lake build` | 来自 `lean-toolchain` 的 Lean 工具链 | 库根节点通过类型检查且 `proof-forge` 链接成功 | 生成的 Yul/字节码有效性、外部工具、运行时行为 |
| Yul 生成冒烟测试 | `lake env proof-forge --root . -o build/counter.yul Examples/Evm/Contracts/Counter.lean` | 已构建 `proof-forge` | Lean 前端/LCNF 将简单合约降级为 Yul | `solc` 验收、ABI 调度、EVM 运行时行为 |
| Yul 到字节码冒烟测试 | `solc --strict-assembly build/counter.yul --bin` | `PATH` 上的 `solc` | 生成的 Yul 被 `solc` 接受 | 运行时语义或方法调度 |
| 单个 EVM 字节码编译 | `lake env proof-forge --evm-bytecode --root . --module contract --artifact-output build/evm/Counter.proof-forge-artifact.json -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean` | `solc`、`cast`、`python3` 和 `Examples/Evm/Contracts/Counter.evm-methods` | Lean → Yul → `solc` → 带有选择器生成的字节码，并写出 `proof-forge-artifact.json` metadata | 运行时行为、gas、详尽的 ABI 正确性 |
| EVM 示例编译 | `scripts/evm/build-examples.sh` | `cast`、`solc`、`python3`、`lake env proof-forge`；可选 `PROOF_FORGE_BIN`、`CONTRACTS_DIR`、`EVM_OUT_DIR` | 每个带有兄弟 `.evm-methods` 的 `.lean` 合约都编译为 `.bin`，并校验 EVM metadata 的 hash、source/module 信息、solc 信息和 SDK method specs | 运行时行为；没有 `.evm-methods` 的合约会被脚本跳过 |
| EVM 运行时冒烟测试 | `scripts/evm/foundry-smoke.sh` | `forge`、`cast`、`solc`；可选 `EVM_OUT_DIR`、`EVM_FORGE_DIR` | Foundry 执行为 Counter、ArrayExample、SimpleToken 和 VerifiedVault 生成的运行时字节码，包括 revert 检查 | 形式化证明覆盖、跨目标等效性、实际部署、详尽的边界覆盖 |
| EVM ABI ScalarProbe IR 冒烟测试 | `scripts/evm/abi-scalar-ir-smoke.sh` | `forge`、`solc`、`python3`、来自 `lean-toolchain` 的 Lean 工具链 | Portable IR `U64`、`U32` 和 `Bool` ABI 参数降级为 Yul 函数参数和 dispatcher calldata load，匹配 golden Yul，通过 `solc --strict-assembly` 生成 runtime bytecode，校验包含 selector entrypoints 与 Yul/bytecode hash 的 EVM metadata，并通过 Foundry 校验有效调用和 malformed calldata revert | 聚合 ABI 参数/返回、storage 行为 |
| EVM AssertProbe IR 冒烟测试 | `scripts/evm/assert-ir-smoke.sh` | `forge`、`solc`、`python3`、来自 `lean-toolchain` 的 Lean 工具链 | Portable IR `assert` 和 `assert_eq` 降级为 Yul revert guard，匹配 golden Yul，通过 `solc --strict-assembly` 生成 runtime bytecode，校验包含 `assertions.check` 的 EVM metadata，并通过 Foundry 校验成功路径和断言失败 revert | 丰富 revert data、表达式类型检查 |
| EVM AssignmentProbe IR 冒烟测试 | `scripts/evm/assignment-ir-smoke.sh` | `forge`、`solc`、`python3`、来自 `lean-toolchain` 的 Lean 工具链 | Portable IR 可变标量 local 和 local assignment 降级为 Yul `let` 与 `:=`，匹配 golden Yul，通过 `solc --strict-assembly` 生成 runtime bytecode，校验 selector entrypoints 与 artifact hash metadata，并通过 Foundry 校验赋值结果和 bool guard 失败 revert | 复合赋值、聚合赋值路径、storage 赋值路径 |
| EVM ConditionalProbe IR 冒烟测试 | `scripts/evm/conditional-ir-smoke.sh` | `forge`、`solc`、`python3`、来自 `lean-toolchain` 的 Lean 工具链 | Portable IR 语句级 `if/else` 降级为 Yul `switch` block，匹配 golden Yul，通过 `solc --strict-assembly` 生成 runtime bytecode，校验包含 `storage.scalar`、`control.conditional`、`assertions.check` 的 EVM metadata，并通过 Foundry 校验 then/else storage 更新结果和未知 selector revert | 分支内早退、更多控制流分析 |
| EVM 诊断冒烟测试 | `scripts/evm/diagnostic-smoke.sh` | 来自 `lean-toolchain` 的 Lean 工具链 | 不支持或格式错误的 EVM IR 形态在 Yul 生成前以显式诊断失败，包括缺少 selector、不支持的 ABI 类型、缺少返回、Hash/array/struct/bounded-loop/storage/context/event/crosscall/native-value surface、分支内 return，以及 effect 表达式/语句位置误用 | 完整 unsupported surface 覆盖、solc 行为、Foundry 运行时行为、制品 metadata |
| EVM IR 覆盖清单 | `scripts/evm/check-ir-coverage-manifest.py` | `python3` | `Tests/EvmCoverage.tsv` 为 `ProofForge/IR/Contract.lean` 中每个 portable IR constructor 记录 EVM 是否 lowered、validated、unsupported 或 structural | 行为正确性、solc 行为、Foundry 运行时行为、制品生成 |
| Psy Counter IR 冒烟测试 | `scripts/psy/counter-smoke.sh` | `PATH` 上的 `dargo`；`python3`；macOS arm64 上 `psyup install 0.1.0` 已知可用 | Counter portable IR 降级为 `.psy`，匹配 golden fixture，通过 `dargo test --file`，通过 `dargo compile` 生成非空 DPN JSON，通过 `dargo execute` 返回 `result_vm: [2]`，生成非空 ABI JSON，写出 `proof-forge-deploy.json`，并在 `proof-forge-artifact.json` 中记录和校验 metadata/deploy manifest 的 hash、能力和执行结果 | 上游压缩 genesis deploy JSON、真实 Psy node/prover 行为、更广泛 IR 覆盖 |
| Psy ContextProbe IR 冒烟测试 | `scripts/psy/context-smoke.sh` | `PATH` 上的 `dargo`；`python3`；macOS arm64 上 `psyup install 0.1.0` 已知可用 | 非 Counter Psy IR 降级参数和 context reads，匹配 golden fixture，通过 `dargo test --file`，生成非空 DPN JSON 和 ABI JSON，通过 `dargo execute` 返回 `result_vm: [15]`，写出 `proof-forge-deploy.json`，并在 `proof-forge-artifact.json` 中记录和校验 metadata/deploy manifest | maps、arrays、hashes、上游压缩 genesis deploy JSON、真实 Psy node/prover 行为 |
| Psy HashProbe IR 冒烟测试 | `scripts/psy/hash-smoke.sh` | `PATH` 上的 `dargo`；`python3`；macOS arm64 上 `psyup install 0.1.0` 已知可用 | Psy IR 将 `Hash`、typed hash let-bindings、`hash` 和 `hash_two_to_one` 降级为 `.psy`，匹配 golden fixture，通过 `dargo test --file`，生成非空 DPN JSON 和 ABI JSON，通过 `dargo execute` 返回预期四 Felt hash 输出，写出 `proof-forge-deploy.json`，并在 `proof-forge-artifact.json` 中记录和校验 metadata/deploy manifest | maps、storage maps、上游压缩 genesis deploy JSON、真实 Psy node/prover 行为 |
| CI 基线 | `.github/workflows/ci.yml` `build-test` 任务 | GitHub Actions Ubuntu、elan、Foundry stable、`solc` 0.8.30 | 清洁环境下的 `lake build`、Psy golden source 快照、Psy 诊断、Psy IR 覆盖清单、EVM 诊断、EVM IR 覆盖清单、EVM ABI ScalarProbe/AssertProbe/AssignmentProbe/ConditionalProbe IR 冒烟测试、EVM metadata 校验、EVM 编译和 Foundry 冒烟测试 | 可选 Dargo 目标冒烟测试、非 Ubuntu 行为 |

## 计划中但尚不可运行的门禁

以下门禁处于 `Planned` 状态，且不存在于 CI 或脚本中：

- `proof-forge build --target <id>` — 统一的面向目标的构建命令。
- `proof-forge test --target <id>` — 统一的面向目标的测试命令。
- 非 EVM、非 Psy 的 `proof-forge-artifact.json` 验证 — 尚未写出 metadata 的目标仍需制品元数据 schema 验证。
- 黄金 Yul/输出快照 — 通过快照差异对比进行回归检测。
- CosmWasm 冒烟测试 — `cosmwasm-check` 或 `cw-multi-test` 验证。
- Solana 冒烟测试 — Mollusk 或 `solana-test-validator` 验证。
- Move 冒烟测试 — `aptos move compile/test` 或 Sui Move 验证。
- 能力拒绝测试 — 针对不支持的能力/目标组合的编译时诊断。

## 新目标工作的预先验证规则

在目标退出 `Research` 之前，文档必须指明：

1. 所需的外部工具。
2. 目标生成的最小制品。
3. 构建或验证该制品的本地命令或脚本。
4. 预期的制品路径。
5. 一个可观察的成功标准。

如果不存在可运行的本地命令，则该目标保持 `Research` 状态。

## 可选外部工具

当前的 CI 安装了 Foundry stable 和 `solc` 0.8.30。本地机器可能没有 `solc`、`cast`、`forge`、`psyup` 或 `dargo`。缺失 EVM 工具会阻塞 EVM 工具链门禁，但不会阻塞 `lake build`。缺失 Psy 工具只会阻塞 Psy smoke 的 Dargo 部分；source generation 和 golden diff 会在脚本退出前先运行。
