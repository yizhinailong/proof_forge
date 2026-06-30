# 验证门禁

本页面记录了当前验证 ProofForge 的可运行门禁，并将其与计划中但尚未实现的门禁区分开来。它反映了实际的脚本和 `.github/workflows/ci.yml`；它不会添加或编辑 CI 任务。

## 当前门禁

| 门禁 | 命令 | 前提条件 | 证明了什么 | 未证明什么 |
|---|---|---|---|---|
| Lean 包构建 | `lake build` | 来自 `lean-toolchain` 的 Lean 工具链 | 库根节点通过类型检查且 `proof-forge` 链接成功 | 生成的 Yul/字节码有效性、外部工具、运行时行为 |
| Yul 生成冒烟测试 | `lake env proof-forge --root . -o build/counter.yul Examples/Evm/Contracts/Counter.lean` | 已构建 `proof-forge` | Lean 前端/LCNF 将简单合约降级为 Yul | `solc` 验收、ABI 调度、EVM 运行时行为 |
| Yul 到字节码冒烟测试 | `solc --strict-assembly build/counter.yul --bin` | `PATH` 上的 `solc` | 生成的 Yul 被 `solc` 接受 | 运行时语义或方法调度 |
| 单个 EVM 字节码编译 | `lake env proof-forge --evm-bytecode --root . --module contract -o build/evm/Counter.bin Examples/Evm/Contracts/Counter.lean` | `solc`、`cast` 和 `Examples/Evm/Contracts/Counter.evm-methods` | Lean → Yul → `solc` → 带有选择器生成的字节码 | 运行时行为、gas、详尽的 ABI 正确性 |
| EVM 示例编译 | `scripts/evm/build-examples.sh` | `cast`、`solc`、`lake env proof-forge`；可选 `PROOF_FORGE_BIN`、`CONTRACTS_DIR`、`EVM_OUT_DIR` | 每个带有兄弟 `.evm-methods` 的 `.lean` 合约都编译为 `.bin` | 运行时行为；没有 `.evm-methods` 的合约会被脚本跳过 |
| EVM 运行时冒烟测试 | `scripts/evm/foundry-smoke.sh` | `forge`、`cast`、`solc`；可选 `EVM_OUT_DIR`、`EVM_FORGE_DIR` | Foundry 执行为 Counter、ArrayExample、SimpleToken 和 VerifiedVault 生成的运行时字节码，包括 revert 检查 | 形式化证明覆盖、跨目标等效性、实际部署、详尽的边界覆盖 |
| CI 基线 | `.github/workflows/ci.yml` `build-test` 任务 | GitHub Actions Ubuntu、elan、Foundry stable、`solc` 0.8.30 | 清洁环境下的 `lake build`、EVM 编译和 Foundry 冒烟测试 | 可选的未来目标、制品元数据验证、黄金快照、非 Ubuntu 行为 |

## 计划中但尚不可运行的门禁

以下门禁处于 `Planned` 状态，且不存在于 CI 或脚本中：

- `proof-forge build --target <id>` — 统一的面向目标的构建命令。
- `proof-forge test --target <id>` — 统一的面向目标的测试命令。
- `proof-forge-artifact.json` 验证 — 制品元数据 schema 验证。
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

当前的 CI 安装了 Foundry stable 和 `solc` 0.8.30。本地机器可能没有 `solc`、`cast` 或 `forge`。缺失 EVM 工具会阻塞 EVM 工具链门禁，但不会阻塞 `lake build`。
