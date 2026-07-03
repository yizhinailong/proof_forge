# Gate 完成记录

状态：**Live (2026-07-03)**

本页是分层目标组合的逐 Gate 完成台账（[target-roadmap](../target-roadmap.md)，
D-034）。每个 Gate 都有一条记录，列出验收标准、逐项状态、证据和签署日期。
只有当所有标准都 **met** 时，Gate 才能 **closed**；任何一个未满足的标准都会
阻塞下一层级（D-044 completion-first rule）。

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

**状态：Open**（行为大体满足；预算和当前验证基线仍不完整）

### 验收标准

| # | 标准 | 状态 | 证据 |
|---|---|---|---|
| G0-1 | Counter 在 3 个 target 上行为一致 | ✅ met | `just testkit` → `counter trace parity: ok (3 target(s))` |
| G0-2 | ValueVault 在 3 个 target 上行为一致 | 🟡 partial | 先前 `just testkit` 证据覆盖了三个 target；当前本地证据在缺少 Foundry `cast` 时可能跳过 EVM 分支，因此仍需记录一次工具齐全的 clean run |
| G0-3 | Counter 资源预算：`solana_cu`、`evm_gas`、`near_gas` | 🟡 partial | `testkit/scenarios/counter.toml` 已有 `solana_cu` + `evm_gas` baseline；**任何场景都尚未实现 `near_gas`** |
| G0-4 | ValueVault 在 3 个 target 上的资源预算 | ❌ unmet | `testkit/scenarios/value-vault.toml` **没有 `[step.expect.budget]` block** |
| G0-5 | Unsupported-capability 诊断一致性 | ✅ met | `just testkit` → `unsupported-crosscall ... diagnostic crosscall.invoke unsupported: ok` |
| G0-6 | `just check` 绿灯（build + lint + gates） | ❌ unmet | 最新远端 `main` CI（`28654051741`，`cd0b049`）在 `just build` 失败；本地 docs sync 也需要修复后才可以宣称 green |

### 关闭 Gate G0 的剩余工作

1. **恢复验证基线**：提交缺失的 `ProofForge/Target/HostBridge.lean`，避免根目录
   `target/` ignore 规则误伤 `ProofForge/Target/*`，修复 Rust toolchain action，
   并且只有在实际跑绿后才重新记录 `just check` / CI 证据。
2. **NEAR gas budget 实现**（RFC 0010）：把 `near_gas`（burnt gas / gas used）
   接入 `harness-near` outcome，并给每个 Counter 和 ValueVault step 添加
   `near_gas` baseline + tolerance。最高优先级，因为这是唯一完全缺失的预算维度。
3. **ValueVault budget baselines**：为三个 target 上的所有 ValueVault step
   测量并锁定 `solana_cu`、`evm_gas`，以及在实现后锁定 `near_gas`。
4. （Gate 的非阻塞 carry-over，但属于 Tier-0 hardening track）EVM semantic-plan
   migration（Workstream 3：ExprPlan/StmtPlan/EntrypointPlan/EventPlan/
   CrosscallPlan/MetadataPlan）和 Solana Pinocchio CI equivalence（Workstream 7）。

### Sign-off

尚未关闭。关闭需要 G0-1 到 G0-6 全部为 ✅，并在此记录 closing commit 以及
`just testkit` + `just check` 证据。

---

## Gate G1a — CosmWasm M4（冻结，D-044）

**状态：Frozen。** 根据 D-044，`wasm-cosmwasm` spike 在 Gate G0 关闭前保持在
当前 M1/M2 状态。不得推进 registry stage，不得推进 M3/M4。

## Gate G1b — Aptos M4（冻结，D-044）

**状态：Frozen。** 根据 D-044，`move-aptos` spike 在 Gate G0 关闭前保持在
当前 M1/M2 状态（Counter printer + golden + test gate，B1 state-id fidelity）。
不得推进 M3（testkit CLI-wrapped executor）、M4（registry stage → Experimental），
也不得启动 `move-sui`。

## Gate G2 — 两个 Tier-1 退出（未开始）

**状态：Not started。** 只有在 G1a 和 G1b 都关闭后才开启；而它们本身都要求
Gate G0 先关闭（D-044）。
