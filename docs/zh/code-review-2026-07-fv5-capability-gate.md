# ProofForge 全量代码 + 架构评审（2026-07，FV-5 能力门分支）

- **评审对象**：`cursor/fv5-overflow-capability-gate` 分支（HEAD `bbf1582a`），
  覆盖可移植 IR、Target 能力路由、各链后端、以及当前正在实现的形式化验证
  （FV-1 / FV-4 / FV-5）部分。
- **定位**：原生中文分析文档，**不是工程权威源**。与
  [architecture-review-2026-07](architecture-review-2026-07.md)、
  [feasibility-analysis](feasibility-analysis.md) 同类。可落地为工程策略的
  结论应回写英文文档（`docs/decisions.md`、相关 RFC、
  [implementation-backlog](../implementation-backlog.md) Workstream 25）。
- **上一篇的分工**：`architecture-review-2026-07.md` 评审的是"分支模式 vs
  主干化"这条组织线；本文评审的是**实现正确性与 FV 可靠性**这条代码线，
  二者互补、不重叠。

---

## 总体结论

这是一个**架构清晰、工程纪律罕见地扎实**的项目。核心命题——"一份 Lean 合约
→ 可移植 IR → 按能力路由到各链后端，不支持的能力在编译期拒绝而非静默改变
语义"——立得住，代码也忠实实现了这个分层。约 75K 行 Lean，43K 在后端层，
成熟度分级诚实（EVM / Solana / NEAR 生产形态，Aleo / Move / CosmWasm 明确标注
为 spike），无跨后端耦合、无 god-module、无 TODO/FIXME 烂账。

**形式化验证部分的诚实度是最大亮点**：`docs/formal-verification.md` 用
Tier A / C-diff / C-proof 三层表格明确划分"证明了什么 / 没证明什么"，主动防止
对外过度宣称。这在同类项目里极少见，应当保持。

**但当前分支的 FV-5 overflow gate 存在一个实质性问题：这个 gate 对所有真实
合约是失效的**，而它本要防住的跨链溢出分歧，恰恰在每一个真实合约上都在发生。
详见第三节 P0。

---

## 一、架构层面：设计合理的地方

1. **分层边界干净**。`Authoring（Intent API / .learn / Token SDK）→ ContractSpec
   → Portable IR → Capability 路由 → Backends → Artifacts+Gates` 与代码一一对应。
   `ProofForge/Target/` 只有 ~1150 行却承担了整个路由契约，职责收敛得很好。

2. **D-027（目标扩展隔离）是正确的边界**。链专属语义（Solana CPI/PDA）通过
   capability id + metadata 走，而不是往可移植 IR 里塞链专属构造子。而且这条被
   机器验证了：`requireTargetExtensionMetadata_ok_iff`
   （`ProofForge/Target/Formal.lean:13`）是**全称量化**的结构归纳，不是
   `native_decide`——这是"对的证明形态"。

3. **FV-1 路由可靠性是真证明**。`requireCapabilityPlan_sound`
   （`ProofForge/Target/Formal.lean:26`）对所有 profile / plan 成立，把"拒绝而非
   静默改变语义"变成了 kernel 检查的不变量。

4. **`ChainSemantics`（`ProofForge/Target/ChainSemantics.lean`）把跨链语义分歧
   显式建模**（native amount 的单位与位宽、事件索引模型、crosscall 模型），
   而不是假装它们一样。这个建模方向是对的。

5. **后端成熟度分级健康、无跨后端耦合**。EVM（30 文件，参考实现）、
   WasmNear（34 文件，最模块化）、Solana（扩展层重）、Psy（精简）各自独立可测；
   Aleo / Move / CosmWasm 明确是 spike/stub。最大的文件（`Evm/IR/Expr.lean`
   ~1442 行）是领域集中而非 god-module。

---

## 二、架构层面：需要改进的结构性问题

### ① 能力派生的"二选一"是一个潜在可靠性漏洞（根因）

`capabilityCallsForSpec`（`ProofForge/Target/Adapter.lean:37`）逻辑是：

```
if intentCalls 非空 then intentCalls else moduleCalls
```

**有 intent 时，模块体真正用到的能力被整体丢弃**。而
`CapabilityPlan.capabilities`（`ProofForge/Target/Plan.lean:33`）完全从 `calls`
派生。后果：**`resolveSpec` 可能对一个"模块体用了目标不支持的能力"的 spec
返回 `.ok`**，只要 intent 声明不完整。

FV-1 的 soundness 定理虽然对 plan 成立，但它保证的**不是**用户真正关心的性质
（"模块只用受支持的能力"）——因为 plan 不忠实反映模块。`overflowChecked` 只是
第一个暴露出来的实例；任何"模块体产生但 intent 未声明"的能力
（`.cryptoHash`、`.controlBoundedLoop` 等）都可能同样漏过。

**建议**：把 `capabilityCallsForSpec` 改成 `intentCalls ∪ moduleDerivedCalls`
（去重），或补一条引理 `moduleCapabilities ⊆ planCapabilities`。这样
checkedArithmetic 自然流过 `requireCapabilities`，FV-5 的专用 gate 可以删掉。

### ② `native_decide` 用了 130 处（Tests 另有 23 处），扩大了 TCB

对一个卖点是形式化验证的项目，用"编译到原生代码再运行"来"证明"定理，等于把
Lean 编译器和 FFI 拉进可信基（不同于 `decide` 是 kernel 检查的）。文档说清了它是
pointwise，但没提这层 TCB 扩张。这些多是小 fixture，很多可以降级成 `decide`。

**建议**：审计哪些 `native_decide` 能降级到 `decide`；在 TCB / non-goals 里显式
写明"信任 Lean 编译器"这一条。

### ③ `partial def` 576 处，是通往真正（C-proof）验证的最大障碍

核心 IR 解释器 `evalExpr` / `runEntrypoint`（`ProofForge/IR/Semantics.lean`，
第 420、561… 行）与 ownership checker（`ProofForge/IR/Ownership.lean`）都是
`partial def`——**放弃了归纳原理**。这就是为什么 FV-2 / FV-3 都卡住、整个 FV
故事上限只能停在"对 fixture 做 `native_decide`"：那个"万物据以 refine 的可执行
语义"自己没法被归纳。文档 FV-3 已诚实承认这点。

**建议**：把定理需要的那部分核心解释器 / 检查器改写成良基 `def`
（`termination_by` 或 fuel）。这是大投入，但是解锁 C-proof 的必经之路。

### ④ RFC 0014 的 ModulePlan 收敛只做了一半

各后端 `PlanError` / `LowerError` 命名与类型各异；`ProofForge/Backend/Diagnostic.lean`
定义了 `LoweringError` typeclass，但**没有任何后端实现实例**（Phase 3 机制在、
实例为零）。这类半迁移要么补完，要么在 backlog 里显式 park，否则会误导后来者
以为已统一。

---

## 三、当前实现（FV-5 分支）的具体问题

### 🔴 P0 —— FV-5 overflow gate 对真实合约完全失效，底层分歧未处理

逐段追踪链路，代码与项目自己的文档互相印证：

| 环节 | 事实 | 证据 |
|---|---|---|
| SDK 的"检查"操作符 | `+!` / `-!` / `*!` / `/!` → `addValue`/… → 普通 IR `.add`，**不设 `overflowChecked`** | `Contract/Source.lean:81-94` |
| gate 触发条件 | 仅当 `spec.module.overflowChecked = true` 才拒绝 | `Target/Adapter.lean:143` |
| 谁设过该 flag | **全代码库只有一处**——FV-5 测试 fixture 自己 | `Target/FV5Overflow.lean:36` |
| EVM 实际 lowering | `.add` → `__pf_checked_add`（溢出 revert），**无视 flag，恒为 checked** | `Backend/Evm/ToYul/Helpers.lean:19,48` |
| Solana 实际 lowering | `.add` → `.add64`（静默回绕），恒为 wrapping | `Backend/Solana/SbpfAsm/Expr.lean:81` |
| NEAR 实际 lowering | `.add` → `i64.add`（静默回绕），恒为 wrapping | `Backend/WasmNear/LoweringEnv.lean:40` |

**推论**：Counter、ValueVault、ERC20、ERC1155、NearFungibleToken 等真实合约通篇
用 `+!`，但 `overflowChecked` 全是默认 `false`。于是：

- 任何一个合约**同时**编译到 EVM 和 Solana/NEAR，**产物的溢出语义就已经不一致**
  （EVM revert，Solana/NEAR 静默回绕）——这正是平台承诺要消除的"静默改变语义"。
- FV-5 gate **一次都不会触发**，因为没有真实合约会把 flag 设成 true。
- `docs/capability-registry.md:81-105` 自己也承认这是"平台里最实质的跨链语义
  分歧"，且 gate "exposes but does not yet enforce per-node"。

更微妙的一点：默认值 `false` 的**宣称含义是"到处都 wrapping（可移植）"**，但
**EVM 根本不兑现**这个含义（它恒为 checked）。所以默认态既不是"到处 wrapping"，
也没有 gate 兜底——三不靠。这条 commit 把自己框定为"完成了 arith.checked
story"，实际风险是给人**已经防住了分歧**的错觉，而真实防护面只覆盖一个 SDK
永远不会产生的模块状态。

**修复方向（择一或组合）**：

- （治标）让 `contract_source` 的 `+!` 或 EVM elaboration 在检测到显式 checked
  操作符时置 `overflowChecked := true`，至少让"SDK 里读作 checked 的东西"和 flag
  对齐。
- （治本，推荐）**把溢出模式下沉到 IR 节点级**：`.add` 携带 `checked | wrapping`
  标签。这样 EVM 的 checked、Solana/NEAR 的 wrapping 就成了**每个节点可判定、
  可 gate、可证明**的属性，而不是一个模块级、没人设、EVM 还不遵守的开关。同时
  把默认从"false=wrapping 但 EVM 不认"改成"未标注即为需拒绝的 mismatch"，与
  平台的 reject-by-default 承诺对齐。
- （最低限度）在此之前，至少让 EVM 在 `overflowChecked=false` 时也 emit wrapping
  （`addmod 2^256` 式），以兑现默认值的宣称语义；否则默认态本身就是静默分歧。

### 🟠 P1 —— Solana refinement 的 obligation 过弱，"定理"名不副实

`TraceObligation.hasEntrypointDispatch`（`Backend/Solana/Refinement.lean:119-123`）：

```lean
asm.contains s!"entry_{entrypointName}" || asm.contains entrypointName
```

第二个析取项 `asm.contains entrypointName` 是**裸子串匹配**：只要入口名作为子串
出现在汇编文本任意位置（注释里、更长标识符里、字符串里）就算通过。入口名 `get`
会被 `budget` / `target` / `getter` 或任何含 "get" 的注释命中。于是
`counter_sbpf_artifact_surface_ok`（`Backend/Solana/Refinement.lean:171`）这个
`native_decide` "定理"证明的东西，远弱于它的名字和 docstring 声称的"每个入口都有
dispatch label"。

**建议**：删掉裸子串那一支，只匹配真实 label 形态（`entry_<name>:` 或真实
dispatch 助记符）。obligation 的强度只等于它最弱的那一支。

### 🟡 P2 —— 命名 / 表述问题（非 bug，但会误导）

- **pointwise `native_decide` fixture 检查却叫 `theorem`**（遍布三个 Refinement
  层）。文档层用 Tier 表缓解了，但代码不自证。建议加命名约定
  （`_fixture_ok` / `example_`）或 tag 注释，区分"逐点检查"与"全称定理"。
- **`EvmBytecodeSemantics` 的 stub**（`step_noop : step s = s := rfl`，
  `Backend/Evm/EvmBytecodeSemantics.lean:95`）是诚实标注的 seam，被 Phase 6b
  工具链版本冲突（Lean v4.22 vs v4.31）正当地 block 住。没问题——但别让
  "sorry-free stub theorem"被当成 anchor 计入进度。
- `Lean.Evm` namespace 遮蔽 Lean 编译器自身的 `Lean`——已在 Workstream 24 记录，
  无需重复处理。

---

## 四、优先级建议清单

| 优先级 | 动作 | 理由 |
|---|---|---|
| **P0** | 把溢出模式下沉到 IR 节点级（`.add` 带 checked/wrapping 标签），或至少让 `+!` / elaboration 设置 `overflowChecked` | 当前 gate 对真实合约失效，最实质的跨链分歧仍在静默发生 |
| **P0** | `capabilityCallsForSpec` 改为 `intent ∪ module` 去重（或加 `moduleCaps ⊆ planCaps` 引理） | 根因；修好后 FV-5 专用 gate 可删，FV-1 定理才真正覆盖用户关心的性质 |
| **P1** | 收紧 `hasEntrypointDispatch`，删掉裸子串匹配 | 让 Solana artifact-surface obligation 名副其实 |
| **P2** | 审计 `native_decide` → `decide` 的可降级项；TCB 文档补"信任编译器"条目 | 收敛验证产品的可信基 |
| **中期** | 把核心 IR 解释器 + ownership checker 从 `partial def` 改成良基 `def` | 解锁 FV-2 / FV-3 / C-proof 的唯一路径 |
| **收尾** | 补完或显式 park RFC 0014 的 `LoweringError` 实例迁移 | 消除半迁移状态 |

---

## 五、附录：证据链索引（可复现）

| 主题 | 文件:行 |
|---|---|
| `+!`/`-!`/`*!`/`/!` 操作符定义 | `ProofForge/Contract/Source.lean:91-94` |
| `addValue`/`subValue`/… 定义（→ `.add` 等，不设 flag） | `ProofForge/Contract/Source.lean:81-88` |
| FV-5 gate 条件 | `ProofForge/Target/Adapter.lean:143` |
| 能力派生"二选一" | `ProofForge/Target/Adapter.lean:37` |
| `CapabilityPlan.capabilities` 从 calls 派生 | `ProofForge/Target/Plan.lean:33` |
| 唯一设 `overflowChecked := true` 处 | `ProofForge/Target/FV5Overflow.lean:36` |
| `Module.capabilities` 在 flag 为真时加 `.checkedArithmetic` | `ProofForge/IR/Contract.lean:509` |
| `overflowChecked` 默认 `false` | `ProofForge/IR/Contract.lean:320` |
| EVM `.add` → checked helper | `ProofForge/Backend/Evm/ToYul/Helpers.lean:19,48` |
| Solana `.add` → `.add64`（wrapping） | `ProofForge/Backend/Solana/SbpfAsm/Expr.lean:81` |
| NEAR `.add` → `i64.add`（wrapping） | `ProofForge/Backend/WasmNear/LoweringEnv.lean:40` |
| Solana obligation 裸子串匹配 | `ProofForge/Backend/Solana/Refinement.lean:119-123,171` |
| FV-1 全称结构定理（正面样例） | `ProofForge/Target/Formal.lean:13,26` |
| IR 解释器 `partial def` | `ProofForge/IR/Semantics.lean:420,561` |
| EVM bytecode 语义 stub | `ProofForge/Backend/Evm/EvmBytecodeSemantics.lean:95` |
| 跨链溢出分歧的官方说明 | `docs/capability-registry.md:81-105` |

**统计口径**（`grep --include="*.lean"`，HEAD `bbf1582a`）：
`native_decide` 130（ProofForge）+ 23（Tests）；`partial def` 576；真实 `sorry` 0
（另有 2 处仅出现在注释文本）；`unsafe` 18（全部在 CLI 的环境加载路径，属正当
元编程）；`@[extern]` 29。
