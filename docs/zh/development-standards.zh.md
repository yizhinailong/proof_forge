# 开发标准

本页面是面向开发者的标准索引。它链接了现有的真值来源文档，并说明了必须更新这些文档的时机。

## 真值来源

| 主题 | 权威文档 |
|---|---|
| 文档地图 | `docs/INDEX.md` |
| 已确定的架构和路线图决策 | `docs/decisions.md` |
| 已接受的产品 / 目标方向 | `docs/rfcs/0001-multichain-platform.md`, `docs/rfcs/0002-target-implementation-design.md` |
| 可移植 IR 与运行时/能力降级 | `docs/portable-ir.md`, `docs/rfcs/0003-portable-ir-and-runtime.md` |
| 规范的能力 id 与支持矩阵 | `docs/capability-registry.md` |
| 目标生命周期与各目标注释 | `docs/targets/README.md`, 以及具体的 `docs/targets/*.md` 注释 |
| EVM 基准详情 | `docs/targets/evm.md`, `Examples/Evm/README.md` |
| 共享的跨目标 Counter 场景 | `docs/shared-scenario.md` |
| 执行积压工作与验收标准 | `docs/implementation-backlog.md` |
| 验证命令与工具先决条件 | `docs/validation-gates.md` |
| 中文叙述 / 策略文档 | `docs/zh/*.md`；它们必须与英文工程文档保持一致，且不得引入独立的工程策略 |

## RFC 与决策策略

- RFC 以 `Draft` 开始。
- 只有当决策记录在 `docs/decisions.md` 中且链接文档已对齐（符合 `docs/rfcs/README.md` 第 7-8 行）时，RFC 才会变为 `Accepted`。
- 被取代的立场记录在 `docs/decisions.md` 的 `Superseded Positions` 下。
- 除非相应的决策已存在于 `docs/decisions.md` 中，否则不要在此任务中更改 RFC 状态。

## 更改代码之前

1. 阅读 `docs/INDEX.md`。
2. 阅读 `docs/decisions.md` 以及相关的 RFC/目标注释。
3. 如果更改涉及公共 CLI 标志、目标 id、能力 id、制品字段、验证命令、目标生命周期阶段或示例合约行为，请在同一次更改中更新最近的真值来源文档。
4. 运行 `docs/validation-gates.md` 中与所触及边界匹配的窄门。

## 命令运行器规范

- 根目录 `justfile` 是面向开发者的命令目录，用于常见本地工作流，例如
  `just build`、`just check`、`just evm-smoke abi-scalar` 和
  `just evm-all`。
- 将较长的目标 harness、生成的测试工程、validator 和特定目标的 shell
  逻辑保留在 `scripts/` 中；`justfile` recipe 应组合这些脚本，而不是内联
  它们的实现。
- 添加面向用户或 CI 覆盖的 smoke 脚本时，应在同一次更改中添加或更新匹配的
  `just` recipe/list 入口。
- 文档可以用 `just` 命令展示常见工作流，但当某个脚本是验证门禁的权威实现时，
  目标文档仍应命名底层脚本。

## Lean 包规范

- Lean 工具链是来自 `lean-toolchain` 的 `leanprover/lean4:v4.31.0`。
- 基础构建门禁是 `lake build`。
- 当前库根为 `ProofForge`、`ProofForge.Evm`、`ProofForge.Compiler.Yul.AST`、`ProofForge.Compiler.Yul.Printer` 以及来自 `lakefile.lean` 第 7-14 行的 `ProofForge.Compiler.LCNF.EmitYul`。
- 可执行文件为 `proof-forge`，根位于 `ProofForge.Cli`，包含来自 `lakefile.lean` 第 16-19 行的 `supportInterpreter := true`。
- 新编译的 Lean 模块必须由现有根导入或添加到 Lake 根中，文档才能声称它们是包的一部分。

## 当前 EVM 规范

- EVM 合约导入 `ProofForge.Evm` 和 `open Lean.Evm`。
- 导出的合约入口使用 `@[export l_<Contract>_<method>]`，且必须匹配 `--method` CLI 标志或同级的 `.evm-methods` 文件。
- EVM 文档中的能力名称必须重用 `docs/capability-registry.md` id：`events.emit`、`crosscall.invoke`、`account.explicit`、`storage.pda`、`crosscall.cpi`。不要引入替代 id，例如 `events.log`、`cross_call.contract` 或 `account.container`。

## 计划行为标签

任何未在此仓库中实现的任务命令、目标、制品字段或验证路径必须标记为 `Planned` 或 `Research`，不得写为当前行为。
