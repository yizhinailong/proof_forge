# Gate 完成记录

状态：**Live (2026-07-03)**

本页是分层目标组合的逐 Gate 完成台账（[target-roadmap](../target-roadmap.md)，
D-034）。每个 Gate 都有一条记录，列出验收标准、逐项状态、证据和签署日期。
只有当所有标准都 **met** 时，Gate 才能 **closed**；任何一个未满足的标准都会
阻塞下一层级。Gate P0 记录主三链完成规约（D-045），它比 G0 的行为/预算切片
更严格。

不同于记录工程里程碑流水的 [development-log](../development-log.md)，本页记录
的是*阶段边界*决策：当前阶段的 Definition of Done 是否已经满足，并且证据可审计。

## 使用方式

- 当某个 Gate 的第一条标准开始推进时，新增一个 `## Gate GN` 小节。
- 随工作落地更新状态为 ✅ / ❌ / 🟡（met / unmet / in-progress）。
- 证据使用可复现的命令和 commit 范围，而不是只写描述性文字。
- Gate 关闭时添加 `**Closed: YYYY-MM-DD**`；在此之前都保持 **Open**。

## Gate G0 — Tier-0 退出（当前阶段目标）

**Definition of Done：** 共享场景（Counter，然后是 ValueVault）在
[testkit](../../testkit/)（RFC 0007）中通过 `evm`、`solana-sbpf-asm` 和
`wasm-near`，同时满足行为一致性和资源预算（D-040 / RFC 0010）。

**状态：Closed**

**Closed: 2026-07-03**

### 验收标准

| # | 标准 | 状态 | 证据 |
|---|---|---|---|
| G0-1 | Counter 在 3 个 target 上行为一致 | ✅ met | `just testkit` → `counter trace parity: ok (3 target(s))` |
| G0-2 | ValueVault 在 3 个 target 上行为一致 | ✅ met | 远端 CI `28655651561`（`12a007b`）的 `build-test` → `Run unified testkit` 在安装 Foundry/cast 后成功 |
| G0-3 | Counter 资源预算：`solana_cu`、`evm_gas`、`near_gas` | ✅ met | `testkit/scenarios/counter.toml` 已锁定三种预算；`CAST="$PWD/build/tools/cast-shim" cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --scenario counter --trace` |
| G0-4 | ValueVault 在 3 个 target 上的资源预算 | ✅ met | `testkit/scenarios/value-vault.toml` 已为全部 11 次调用锁定 `solana_cu`、`evm_gas` 和 `near_gas`；`CAST="$PWD/build/tools/cast-shim" cargo run --manifest-path testkit/Cargo.toml -p proof-forge-testkit -- run --scenario value-vault --trace` |
| G0-5 | Unsupported-capability 诊断一致性 | ✅ met | `just testkit` → `unsupported-crosscall ... diagnostic crosscall.invoke unsupported: ok` |
| G0-6 | `just check` 绿灯（build + lint + gates） | ✅ met | `CAST="$PWD/build/tools/cast-shim" just check` 已在本地通过；远端 CI `28658576786`（`0c52fb8`）也已全部成功，包括 `Run unified testkit`、`Check Solana light gates`、Foundry smoke 和 Anvil deploy smoke |

### Gate G0 关闭后的 carry-over 工作

Gate G0 关闭的是共享行为/资源预算切片。它**不等于**关闭 Gate P0。剩余的主三链
生产级硬化继续保持 active：

1. EVM semantic-plan migration（Workstream 3：ExprPlan/StmtPlan/
   EntrypointPlan/EventPlan/CrosscallPlan/MetadataPlan）。
2. Solana Pinocchio live dual-deploy equivalence 的 CI/toolchain 稳定化以及
   更广 reference 覆盖（Workstream 7）。
3. NEAR/Wasm target-first 本地执行/部署元数据签署。

### Sign-off

Gate G0 已在 2026-07-03 于 commit `0c52fb8` 关闭；GitHub CI run
`28658576786` 已全部成功。该 closing run 验证了当前 `just check` CI 面，包括
unified testkit、Solana light gates、EVM Foundry/Anvil gates，以及冻结的非主链
spike smoke jobs。

---

## Gate P0 — 主三链完成规约（当前产品前置条件）

**Definition of Done：** ProofForge 必须按实现顺序完成三个优先链：
`solana-sbpf-asm`、`evm`（Ethereum）和 `wasm-near`（NEAR/Wasm）。在此之前，
任何额外链都不能推进到 docs-only research 或冻结 spike 维护之外（D-045）。

**状态：Open**

### 验收标准

| # | 标准 | 状态 | 证据 |
|---|---|---|---|
| P0-1 | Solana 直接 sBPF 后端达到生产级 | 🟡 in progress | Gate G0 行为/预算一致性已关闭；Pinocchio reference-equivalence 已纳入 `just solana-light`；2026-07-03 的本地 live dual-deploy triage 发现真实的 Agave/Solana CLI ELF 兼容阻塞（`solana program deploy` 在调用前拒绝生成的 ProofForge ELF），因此工作流 7 必须先补出 Solana loader-compatible 的 ELF packaging 路径，之后才能把 live CI 设为强制门禁 |
| P0-2 | Ethereum/EVM 后端达到生产级 | 🟡 in progress | Foundry 和 Anvil CI 已绿；剩余硬化包括工作流 3 的 EVM semantic-plan migration |
| P0-3 | NEAR/Wasm 后端达到生产级 | 🟡 in progress | EmitWat/NEAR 诊断、IR 覆盖、offline host smoke 和预算基线已绿；剩余硬化是完整 target-first 本地执行/部署元数据签署 |
| P0-4 | 额外链推进保持冻结 | ✅ met | D-044/D-045 冻结 Aptos/CosmWasm 超过 M1/M2 的推进，并在 P0 关闭前保持其他目标 docs-first |

### Sign-off

尚未关闭。关闭 P0 需要逐目标证据，证明 Solana、Ethereum/EVM 和 NEAR/Wasm
满足 D-045 的生产级 DoD。Gate G0 证据是必要条件，但不是充分条件。

---

## Gate G1a — CosmWasm M4（冻结，D-044）

**状态：Frozen。** 根据 D-044/D-045，`wasm-cosmwasm` spike 在 Gate P0 关闭前
保持在当前 M1/M2 状态。不得推进 registry stage，不得推进 M3/M4。

## Gate G1b — Aptos M4（冻结，D-044）

**状态：Frozen。** 根据 D-044/D-045，`move-aptos` spike 在 Gate P0 关闭前保持在
当前 M1/M2 状态（Counter printer + golden + test gate，B1 state-id fidelity）。
不得推进 M3（testkit CLI-wrapped executor）、M4（registry stage → Experimental），
也不得启动 `move-sui`。

## Gate G2 — 两个 Tier-1 退出（未开始）

**状态：Not started。** 只有在 G1a 和 G1b 都关闭后才开启；而它们本身都要求
Gate P0 先关闭（D-045）。
