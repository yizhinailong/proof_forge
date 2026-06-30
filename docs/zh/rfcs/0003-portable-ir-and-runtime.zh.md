# RFC 0003：可移植合约 IR、能力降级与运行时 profile

状态：草案

日期：2026-06-30

## 摘要

RFC 0001 将可移植合约 IR 指定为 Lean 源代码与目标后端之间的层。RFC 0002 列出了后端，但未对 IR、能力机制以及运行时选择问题进行说明。本 RFC 填补了这一空白。它定义了平台其余部分所依赖的三个要素：

1. 一种可移植合约 IR，其带有副作用的调用是类型化的能力，而非目标操作码。
2. 一个能力命名空间和每个目标的能力降级表，后端通过查表将每个能力降级为具体的宿主原语。
3. 每个目标的运行时 profile，说明 Lean 语言运行时如何与链宿主运行时协调，且编译器在降级前进行静态检查。

本 RFC 明确的核心主张是：目标选择是一个构建时、表驱动且静态检查的决策。不存在跨链的运行时调度。合约要么在其能力和运行时约束下干净地降级到目标，要么在生成任何制品之前被拒绝并提供精确的诊断。

本 RFC 不定义完整的 IR 表面。IR 单元结构（Module、入口、State、Effect）在 [`portable-ir.md`](../portable-ir.md) 中定义；规范的能力 id 和每个目标的对应支持矩阵在 [`capability-registry.md`](../capability-registry.md) 中定义。本 RFC 仅定义这些规范未涵盖的核心部分：能力降级规则格式、运行时 profile 以及静态检查。除 Effect/能力表示之外的 IR 类型和语句细节将推迟到 `portable-ir.md`，并在了解 Solana 约束后在实现中确定。

## 动机

当前的 EVM 后端证明了 Lean 可以降级到链。但这并不能证明该设计具有通用性。目前有三件事阻碍了通用化：

- EVM 路径绕过了任何可移植层：`Lean → LCNF → EmitYul → Yul`。宿主调用 (`lean_evm_*`) 在 EmitYul 内部通过名称识别并融合到 Yul 操作码中。不存在以抽象方式表示能力调用的 IR，因此第二个后端无法共享任何内容。
- 能力在 RFC 0001 和 RFC 0002 中作为一个概念被提及，但没有机制让编译器知道合约使用了哪些能力，或者拒绝无法满足这些能力的目标。
- Lean 语言运行时 (`lean_rt`) 与每个链的宿主运行时之间的关系从未阐明。在实践中，EVM 后端将 Lean 运行时退化为无操作 (no-ops)，并将 EVM 操作码视为运行时。Lean 分支中的 NEAR 参考保留了完整的 Lean 运行时并添加了宿主桥接。Move 后端则完全无法承载 Lean 运行时。如果没有明确的模型，每个新后端都会临时重新推导这些决策 ad hoc。

本 RFC 修正了共享层，使得后端仅在能力降级表和运行时 profile 上有所不同，而不在思维模型上有所不同。

## 非目标

- 本 RFC 不指定 IR 单元结构（Module/入口/State/Effect）——那是 [`portable-ir.md`](../portable-ir.md)。它仅指定后端和能力检查器所依赖的能力降级规则格式和运行时 profile。
- 它不定义规范的能力 id 集——那是 [`capability-registry.md`](../capability-registry.md)。它使用这些 id。
- 它不选择 Solana 运行时策略。它定义了三种策略，以及 Solana spike 结果反馈到 IR 子集的约束。
- 它不定义云平台或制品注册表架构，超出能力和运行时字段要求的范围（RFC 0002 已经勾勒了制品元数据）。
- 它不要求立即通过 IR 迁移现有的 EVM 路径。EVM 可能会以双路径（直接 LCNF 和通过 IR）运行，直到黄金快照证明其等效性。

## 与其他规范的关系ProofForge 现在将共享层设计拆分到多个文档中。本 RFC 是运行时与降级权威；其他文档拥有各自的层面。

| 层面 | 权威 | 本 RFC 的角色 |
|---|---|---|
| IR 单元结构 | [`portable-ir.md`](../portable-ir.md) | 消费它；在 `Effect` 之上添加能力降级规则 |
| 能力 id + 支持矩阵 | [`capability-registry.md`](../capability-registry.md) | 消费 id；定义降级规则格式以及后端如何使用它们 |
| 跨目标场景 | [`shared-scenario.md`](../shared-scenario.md) | 提供静态检查必须通过/拒绝的测试用例 |
| 已定决策 | [`decisions.md`](../decisions.md) | 继承 D-001..D-010；见下文 |

继承自 [`decisions.md`](../decisions.md) 且影响本 RFC 的决策：

- **D-001**：RFC 0001/0002 已被接受为工程方向。本 RFC 是它们所依赖的缺失环节。
- **D-002**：第一阶段（目标注册表 + 可移植 IR + 制品元数据）必须在非 EVM spike 之前完成。此处定义的能力检查器和运行时 profile 是第一阶段的交付物。
- **D-003**：CosmWasm 和 Solana spike 在第二阶段**并行**运行。这取代了早期的顺序路线图（仅限 Solana 的第二阶段，或 CosmWasm 先于 Solana）。两者验证不同的后端家族；互不限制。Solana 运行时决策（B vs B'）仍必须在 Solana 退出 spike 之前确定，但它不再阻塞 CosmWasm。
- **D-004/D-005**：规范的 Solana id 是 `solana-sbpf-linker`；Zig 分叉保留作为回退/参考。下方的运行时 profile 使用规范 id。
- **D-007/D-008**：Move POC 是 Aptos 优先的源代码生成（策略 C）。本 RFC 的策略 C 和 Move 运行时 profile 遵循该方案。


## 两个运行时，三种协调策略

ProofForge 必须协调两个不同的运行时层：

- Lean 语言运行时 (`lean_rt`)：Lean 的对象模型 —— 装箱标量 `(n << 1) | 1`、构造函数头、引用计数、闭包、thunk、大数。语言级机制，与链无关。
- 链宿主运行时：链自身的执行 ABI —— EVM 操作码、Solana 系统调用、Wasm 宿主导入、Move VM。

它们不能作为两个平等的运行时共存于一个目标上。每个目标选择三种协调策略之一。该策略是每个目标最重要的决策，因为它决定了 IR 允许包含的内容。

### 策略 A：退化运行时（宿主即运行时）

Lean 语言运行时被简化为无操作。引用计数变为 `lean_inc/dec/del → no-op`；`isShared` 始终返回 1；堆是每次调用的暂存内存。宿主调用不通过桥接二进制文件路由 —— 它们在降级时被内联到发射的代码中。

使用者：EVM。

对 IR 的影响：IR 可以使用任何在没有堆的情况下进行降级的纯 Lean 结构（算术、作为内存区域的结构体、降级为生成的 `switch` 的闭包）。它不能依赖无界分配、GC 或跨调用的持久堆对象。

### 策略 B：完整 Lean 运行时加宿主桥接

完整的 Lean 语言运行时被编译到目标上，并与恰好一个宿主桥接模块链接，该模块将 Lean 对象转换为链的宿主 ABI 调用。

使用者：NEAR、CosmWasm 以及（如果可以链接）Solana。

对 IR 的影响：IR 可以使用 `lean_rt` 支持的完整 Lean 子集，包括闭包和堆对象，但受限于目标的尺寸和预算限制。

### 策略 C：无 Lean 运行时（源代码生成）

不交付 Lean 运行时。后端生成目标语言的源代码，目标自身的 VM 即为运行时。Lean 仅用于类型和证明，它们在代码生成前被检查并擦除。

使用者：Sui Move、Aptos Move。

对 IR 的影响：IR 必须是一个受限的、一阶的、Move 兼容的子集。没有闭包，没有 Lean 堆对象，没有任意递归。Resource、object 和 ability 语义必须在 IR 中显式表示。### 变体 B'：受限 Lean 运行时

当完整的 Lean 运行时不适配某个目标（Solana sBPF 是预期情况）时，使用 B 的子策略。编译 `lean_rt` 的一个子集 —— 包含装箱标量和显式构造函数，但可能会舍弃闭包、大数和 IR 解释器。宿主桥接保持不变。

对 IR 的影响：如果一个目标使用 B'，则 IR 不得使用被舍弃的特性，且静态检查器必须在降级前拒绝它们。Solana spike（工作流 7）决定 Solana 是使用 B、B'，还是回退到类似 A 的路径。

## 能力模型

### 作为类型化效应的能力调用

可移植 IR 不包含目标操作码。它包含能力调用：对带有能力标识符注解的 opaque 函数的调用。IR 在调用旁记录能力标签，以便后端可以对其进行降级，而无需从被调用者名称中重新推断。

概念表示（Lean 草图；具体的 IR 数据结构是实现细节，但它必须携带此信息）：

```lean
/-- A capability identifier in a hierarchical namespace, e.g. `storage.scalar`. -/
structure CapId where
  parts : List String

/-- A capability call recorded in the IR. The callee is an opaque symbol
    declared in the contract's capability SDK; the `capability` field lets the
    backend lower it from the table rather than by name matching. -/
structure CapabilityCall where
  capability : CapId
  callee     : Name        -- e.g. ``Storage.load``, `Lean.Solana.readData`
  args       : Array IRExpr
```

合约通过在特定目标的 SDK 中调用一个声明为 `opaque` 且带有 `@[capability "..."]` 属性的函数来使用一种能力：

```lean
@[capability "storage.scalar.read"]
opaque load (slot : Nat) : IO Nat
```

Lean 前端将此注解保留到 LCNF 中，且 IR 构建器在每个调用点记录它。后端不再对 `lean_evm_*` 名称进行模式匹配；它们读取能力标签。

### 能力命名空间

能力 id 的规范集合及其逐目标支持矩阵位于 [`capability-registry.md`](../capability-registry.md) 中，这是 id 的唯一事实来源。RFC 0003 不会重新定义它们；它消费它们。

作为参考，注册表的第一个版本包括：`storage.scalar`、`storage.map`、`storage.pda`、`caller.sender`、`value.native`、`events.emit`、`crosscall.invoke`、`crosscall.cpi`、`env.block`、`crypto.hash` 和 `account.explicit`。每个 id 都是一个语义能力 (`<domain>.<operation>`)，而不是目标操作码。新的 id 通过规范修订添加到注册表中，而不是按后端添加；后端提议 id，注册表拥有它们。

本 RFC 仅在注册表之上添加了两项内容：

1. **降级规则格式**（下一小节）—— 后端如何为已注册的 id 发射宿主原语。注册表说明目标支持 *哪些* id；本 RFC 说明受支持的 id *如何* 降级为宿主代码。
2. **运行时 profile**（稍后章节）—— 约束在目标下可能出现 *哪些 IR 特性*，与能力 id 无关。

### 能力降级表

每个目标提供一个表，将它支持的每个能力 id 映射到一个降级规则。该规则说明后端如何为该能力发射宿主原语，以及降级是否需要额外的目标元数据（例如 Solana 账户清单、Move ability 注解）。

```lean
/-- How a target lowers one capability. -/
structure CapabilityLowering where
  capability : CapId
  -- A tag telling the backend which emitter to use for this capability.
  lowering   : LoweringKind
  -- Whether the lowering needs per-call target metadata from a manifest.
  needsMetadata : Bool

inductive LoweringKind where
  | evmOpcode   (op : String)              -- e.g. sload, sstore, caller
  | hostImport  (bridgeFn : Name)          -- e.g. `Lean.Near.storage_read`
  | syscall     (bridgeFn : Name)          -- e.g. `Lean.Solana.read_data`
  | generated   (targetApi : Name)         -- e.g. Move `sui::event::emit`
```

| 目标 | 能力 | 降级 |
|---|---|---|
| evm | `storage.scalar` | `evmOpcode "sload"` / `"sstore"` |
| evm | `caller.sender` | `evmOpcode "caller"` |
| wasm-near | `storage.scalar` | `hostImport ``Lean.Near.storage_read`` |
| wasm-cosmwasm | `storage.scalar` | `hostImport ``Lean.CosmWasm.storage_read`` |
| solana-sbpf-linker | `storage.scalar` | `syscall ``Lean.Solana.read_data`` (需要账户清单) |
| solana-sbpf-linker | `storage.pda` | `syscall PDA 派生 (需要账户清单) |
| solana-sbpf-linker | `crosscall.cpi` | `带有账户元数据的 syscall CPI |
| move-sui | `events.emit` | `generated ``sui::event::emit`` |
| move-aptos | `storage.scalar` | `generated resource access (needs abilities + acquires)`` |

一个目标支持的能力集合正是其表格中的行集合。对于某个目标，没有对应行的能力对该目标是不支持的。

### 静态能力检查

在降级之前，编译器计算合约使用的能力 id 集合（IR 中所有能力调用的并集），并根据目标的支持集合对其进行检查。这是一个集合操作；它要么成功，要么产生精确的诊断信息。

```
usedCapabilities(contract) ⊆ supportedCapabilities(target)
```

失败时，编译器会为每个不支持的能力发射一条诊断信息：

```
error: target `solana-sbpf-linker` does not support capability `value.native`
  hint: Solana has no EVM-style msg.value; model native assets as explicit
        lamport/Coin accounts via the `account.explicit` capability
  used at: Examples/Counter.lean:42
```

此项检查使得“拒绝不支持的目标，而不是默默地改变语义”成为一种真实的编译器行为，而不仅仅是文档承诺。它取代了目前 EmitYul 内部的名称匹配。

### 特性使用跟踪，而不仅仅是能力跟踪

同一个静态 pass 还会根据运行时 profile（见下文）跟踪 IR 特性使用情况：闭包计数、递归深度、堆对象分配、bignum 使用。针对 B' 运行时的使用闭包的合约会以同样的方式被拒绝：

```
error: target `solana-sbpf-linker` runtime profile `restrictedLean` does not support closures
  used at: Examples/Counter.lean:55 (`fun x => ...`)
  hint: rewrite as a first-order function or inline the body
```

## 运行时 profile

每个目标声明一个运行时 profile。该 profile 规定了 Lean 运行时在该目标上的对账策略和特性预算。编译器会静态地对照此预算检查合约的特性使用情况。

```lean
inductive RuntimeMode where
  | degenerate       -- Strategy A: Lean runtime is no-ops; host is the runtime
  | fullLean         -- Strategy B: full lean_rt + host bridge
  | restrictedLean   -- Strategy B': subset of lean_rt
  | none             -- Strategy C: source generation; no lean_rt

inductive HostBridgeKind where
  | inlineOpcodes    -- EVM: no bridge binary; opcodes emitted inline
  | module (id : String)   -- "near" | "cosmwasm" | "solana"
  | none             -- source generation targets

inductive AllocatorStrategy where
  | evmFreeMemPtr    -- Solidity free-memory-pointer at 0x40
  | bump
  | wasmSafe
  | cosmwasmAbi
  | none             -- source generation

structure RuntimeProfile where
  mode              : RuntimeMode
  hostBridge        : HostBridgeKind
  allocator         : AllocatorStrategy
  supportsClosures  : Bool
  supportsBignum    : Bool
  supportsHeapObjects : Bool
  maxStackBytes     : Nat          -- EVM effectively unbounded; Solana 4096
  maxArtifactBytes  : Nat          -- target upload limit, if any
```

初始 profile：

| 目标 | 模式 | 宿主桥接 | 支持闭包 | 支持大数 | 支持堆对象 |
|---|---|---|---|---|---|
| evm | 退化 | 内联操作码 | 否（降级为 switch） | 否（U256 封顶） | 否（单次调用暂存） |
| wasm-near | 全量 Lean | 模块 "near" | 是 | 是 | 是 |
| wasm-cosmwasm | 全量 Lean | 模块 "cosmwasm" | 是 | 是 | 是 |
| solana-sbpf-linker | 受限 Lean（暂定） | 模块 "solana" | 由 spike 待定 | 待定 | 待定 |
| move-sui | 无 | 无 | 否 | 否（固定宽度） | 否（资源） |
| move-aptos | 无 | 无 | 否 | 否（固定宽度） | 否（资源） |

Solana 行刻意保持暂定。其 `restrictedLean` 模式及其特性布尔值并非假设 —— 它们是工作流 7 的产出。在该 spike 落地之前，Solana profile 记录的是待解决的问题，而非答案。

## 构建流程

面向目标的构建，端到端流程：

1. 解析 `--target <id>`；解析目标 profile 及其运行时 profile。
2. 将 Lean 源码编译为 LCNF，保留 `@[capability]` 注解并记录特性使用情况（闭包、递归、分配）。
3. 构建可移植 IR：入口、类型、状态转换，以及带有其 `CapId` 标记的能力调用。证明在第 2 步中进行检查并被擦除；IR 携带证明状态元数据，而非证明项。
4. **静态检查（集合运算，构建时，不可协商）：**
   - `usedCapabilities ⊆ supportedCapabilities(target)`，否则拒绝。
   - `usedFeatures ⊆ runtimeProfile.features`，否则拒绝。
5. 降级：针对每个能力调用，查找目标的降级规则并发射宿主原语（操作码 / 桥接调用 / 系统调用 / 生成的 API）。
6. 根据 `mode` 构建运行时：
   - 退化运行时 → 仅发射无操作（no-op）的 RC 存根和内联的宿主操作码。
   - 全量 Lean / 受限 Lean → 编译相应的 `lean_rt` 子集并链接恰好一个 `host/<bridge>` 模块。
   - 无 → 跳过运行时构建；发射目标源代码。
7. 根据目标的制品种类进行打包，并运行其冒烟测试门禁。

第 4 步和第 6 步是决定“编译后的代码知道调用哪个运行时”的地方。这是在构建时通过查表和链接选择决定的，绝非在运行时。

## 宿主桥接选择是在链接时进行的且具有排他性

对于策略 B 和 B' 目标，会链接恰好一个宿主桥接模块。不存在运行时选择，也没有符号冲突：每个桥接实现一组不同的 extern (`lean_near_*`, `lean_cosmwasm_*`, `lean_solana_*`)。构建过程从运行时 profile 的 `hostBridge` 字段中选择桥接。

与现状相比，这需要的清理工作：Lean 分支在 EmitZig 的通用运行时 extern 列表中硬编码了 `lean_near_*`，因此每个 Wasm 构建都会强制链接 NEAR 桥接。工作流 4 使桥接选择变为目标驱动：EmitZig 为运行时 profile 命名的桥接发射 extern，而通用的 Wasm 运行时不强制链接任何特定于链的内容。这是将“NEAR 可用”转变为“Wasm 家族可用”的工程变革。

## Solana 约束反馈到 IR 中

Solana sBPF spike (工作流 6/7) 并非 IR 的下游；它约束了 IR。该 spike 回答了在 4KB 栈和加载器段约束下，全量 `lean_rt` 是否能在 `bpfel-freestanding` 下链接。结果以及每种结果对 IR 的强制要求：

- **全量运行时链接（策略 B 成立）：** IR 可以为 Solana 保留闭包和堆对象。Solana profile 布尔值翻转为 true。
- **仅子集链接（策略 B'）：** IR 必须支持一个一阶、无闭包、有界递归的子集，该子集可在 Solana 下降级。静态检查器会拒绝超过该范围的 Solana 构建。这个子集可能与 Move 兼容子集重叠，这在战略上很有用。
- **无可行运行时子集（回退到 A）：** IR 必须在 Solana 上直接降级为 Zig 而不使用 `lean_rt`，就像 EmitYul 在 EVM 上直接降级为 Yul 而不使用 `lean_rt` 一样。Solana 成为一个退化运行时目标，其“宿主即运行时”通过系统调用实现。由于结果未知，IR 设计必须从一开始就保持 B' 兼容子集的整洁：一阶函数、显式入口、装箱标量、显式构造函数。仅在策略 B 下才能存续的特性（无界闭包、任意递归、完整大数）必须按目标 opt-in，而不是默认假设。

## 与现有 EVM 后端的关系

EVM 后端将作为工作基准保留。它不会在第一天就通过 IR 重写。迁移是分阶段进行的：

1. 为 `evm` 添加目标 profile、运行时 profile 和能力降级表，该表派生自 EmitYul 现有的功能。
2. 添加能力和特性静态检查作为在 EmitYul 之前运行的 pass。最初它仅根据 EVM profile 验证 EVM 合约。
3. 引入可移植 IR 作为降级到相同 Yul 的替代路径。保留直接的 LCNF→EmitYul 路径，直到黄金 Yul 快照证明这两条路径为每个示例发射的输出完全一致。
4. 一旦等效性成立，即可移除直接路径。

现有的 `@[extern "lean_evm_*"]` 名称成为 `evmOpcode` 行的降级规则目标；EmitYul 的内部名称匹配被查表取代。除非快照差异另有说明，否则 EVM 行为不会改变。

## 验收标准

本 RFC 在以下条件满足时视为已实现：

- 存在一个用于 `evm` 的目标 profile，描述了目标家族、制品种类、能力集和运行时 profile，且不改变当前的 EVM 输出。
- 如果合约使用了目标表中缺失的能力，则会被拒绝，并提供指出目标 id、能力 id 和源位置的诊断信息。
- 如果合约使用了目标的运行时 profile 不允许的特性，则会被拒绝，并提供指出该特性和源位置的诊断信息。
- 在添加能力和特性检查前后，EVM 构建产生完全相同的 Yul/字节码（黄金快照等效性）。
- 即使后端尚未实现，注册表中也至少记录了一个非 EVM 目标的运行时 profile，从而使注册表成为能力和运行时约束的唯一事实来源。

## 待解决问题

- 能力 id 是否应该携带描述其触及状态*种类*的负载（例如 `storage.scalar` vs `storage.map` vs `account.explicit`），还是 `capability-registry.md` 中当前的扁平命名空间已足以进行精确诊断？
- 能力 id 如何在源代码级别绑定到 SDK 函数——是通过 Lean 属性、派生声明还是单独的清单？这里假设使用属性形式（`@[capability "..."]`），但尚未最终确定。
- 静态特性检查应该是保守的（拒绝任何可能使用闭包的内容）还是精确的（仅拒绝确认的闭包）？对于初版来说，保守做法更安全。
- 对于 Move 源代码生成，资源 ability 和 `acquires` 子句存在于何处——是在 IR 中、目标清单中，还是派生自能力使用情况？RFC 0002 的 Move 笔记倾向于 IR；本 RFC 暂缓讨论。
- Wasm 家族是在 NEAR 和 CosmWasm 之间共享通用的分配器层，还是每个桥接拥有自己的分配器？运行时 profile 列出了每个目标的分配器，暗示是后者；这需要确认。
- 可移植 IR 应该是被 Lean 实现的后端消耗的 Lean 数据结构，还是可以被外部（Zig/Rust）后端消耗的序列化格式？答案将影响后端是否可以按照 RFC 0001 的待解决问题采用非 Lean 实现。

## Research 参考文献- EVM 基线与退化运行时方法：`ProofForge.Evm`，`ProofForge.Compiler.LCNF.EmitYul`。EmitYul 中的 `lean_evm_*` 识别是能力降级表的前身。
- NEAR 全运行时加桥接参考：本地 Lean 分叉 `Lean.Near`，`tools/zigc-near`，`src/runtime/zig/host/near`。
- Solana 运行时决策（策略 B vs B' vs 回退到 A）：`docs/implementation-backlog.md`，`docs/targets/solana-sbf.md` 中的工作流 6/7。
- Move 源代码生成限制（策略 C IR 子集）：`docs/targets/move-family.md`。
- 能力矩阵与目标 profile：RFC 0002。
- IR 单元结构（Module/Entrypoint/State/Effect）：`docs/portable-ir.md`。
- 规范能力 id 与支持矩阵：`docs/capability-registry.md`。
- 已定决策（D-001..D-010，包括并行阶段 2 spike）：`docs/decisions.md`。
- 跨目标 Counter 场景：`docs/shared-scenario.md`。
