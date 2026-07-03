# ProofForge 设计决策

本文档记录了足以指导实现的架构决策。未解决的问题将保留在 RFC 和目标说明中，直到在此处解决。

另请参阅：[评审清单 (英文)](review-checklist.md)，[评审清单 (中文)](zh/review-checklist.md)。

## 决策日志| ID | 日期 | 决策 | 理由 |
|---|---|---|---|
| D-001 | 2026-06-30 | RFC 0001 和 RFC 0002 被**接受**为工程方向 | 已存在详细的目标和待办事项文档；Draft 状态具有误导性 |
| D-002 | 2026-06-30 | 第 1 阶段（目标注册表 + 可移植 IR + 制品元数据）必须在非 EVM spike 之前完成 | Spike 需要能力检查和共享的场景定义 |
| D-003 | 2026-06-30 | CosmWasm 和 Solana spike 在第 1 阶段后**并行**运行 | 两者之间没有固定顺序；两者都验证了不同的后端家族 |
| D-004 | 2026-06-30 | ~~规范的 Solana 目标 id 为 `solana-sbpf-linker`~~ **被 D-026 取代** | 标准 Zig + sbpf-linker 适配平台工具链；`solana-sbf` 仅为文件名别名。D-026 以 `solana-sbpf-asm` 作为首选的直接汇编路径取代了此项。 |
| D-005 | 2026-06-30 | 保留 **`solana-zig-fork`** 作为备选/参考轨道 | 来自 solana-sdk-mono 的成熟 SDK 参考；不是主要的产品路径 |
| D-006 | 2026-06-30 | NEAR 是 Wasm-host **参考**；CosmWasm 是仓库中第一个新的 Wasm spike | Fork 的经验教训为结构提供了参考；CosmWasm 验证了宿主适配器的通用性 |
| D-007 | 2026-06-30 | Move POC 从**仅限 Aptos** 开始；Sui 紧随其后 | Aptos 账户资源更简单；Sui 对象模型对抽象的测试更具挑战性 |
| D-008 | 2026-06-30 | Move 目标使用**源代码生成**，而非 MoveVM 上的 Lean 运行时 | 证明保留在 Lean 中；Move 仅承载可执行逻辑 |
| D-009 | 2026-06-30 | **`wasm-polkadot` / ink!** 保持为 research-only | 在安排 spike 之前不会进入目标注册表 |
| D-010 | 2026-06-30 | 云平台需等到**两个或更多目标**达到 Experimental 阶段 | 避免在本地后端实现之前构建 UI 外壳 |
| D-011 | 2026-06-30 | 将 **`psy-dpn`** 作为 ZK 电路源代码生成下的 Research 目标添加 | Psy 没有公开的类 Yul IR；首次集成应生成 `.psy` 并调用 Dargo |
| D-012 | 2026-07-01 | 将 **`kaspa-toccata`** 分类为文档优先的 Research 候选对象，而非 ZK 电路源代码生成目标 | Toccata 是通过 transaction v1、covenants、内联证明验证和 based-app 结算实现的 Kaspa L1 可编程性；代码注册表的更改需等待 UTXO/covenant 能力评审 |
| D-013 | 2026-07-01 | 将 **`wasm-stellar-soroban`** 分类为文档优先的 Wasm-host Research 候选对象 | Soroban 发射 Wasm，但具有 Stellar 特有的存储 TTL、授权、合约规范、部署和 CLI 语义；注册表的更改需等待选定第一个 spike 路径 |
| D-014 | 2026-07-01 | 将 **`wasm-icp-canister`** 分类为文档优先的 Wasm-host Research 候选对象 | Internet Computer canister 发射 Wasm，但具有 Candid、principal 身份、update/query 调用模式、cycles、稳定内存、异步 canister 间调用和生命周期语义；注册表的更改需等待选定 canister spike 路径 |
| D-015 | 2026-07-01 | 将 **`ton-tvm`** 分类为文档优先的 TVM/Tolk 源代码生成 Research 候选对象 | TON 合约以 TVM 为目标，具有 cell、TL-B 序列化、消息处理器、get 方法、操作列表、账户生命周期和 TVM gas 语义；注册表的更改需等待选定源代码生成 spike 路径 |
| D-016 | 2026-07-01 | 将 **`bch-cashscript`** 分类为文档优先的 UTXO 脚本/covenant 源代码生成 Research 候选对象 | Bitcoin Cash 合约通过 CashScript 使用 BCH Script、交易内省、CashTokens 和 SDK 交易构建器语义来锁定和花费 UTXO；注册表的更改需等待选定 CashScript spike 路径 |
| D-017 | 2026-07-01 | 将 **`algorand-avm`** 分类为文档优先的 AVM/TEAL 源代码生成 Research 候选对象 | Algorand 合约以 AVM approval/clear-state 或 LogicSig 程序为目标，具有 ARC-4 ABI、全局/本地/box 存储、资源引用、原子交易组、内部交易和 AVM 预算语义；注册表的更改需等待选定 Algorand 包 spike 路径 || D-018 | 2026-07-01 | 将 **`cardano-plutus-aiken`** 分类为文档优先的 eUTXO 验证器源代码生成 Research 候选 | Cardano 合约通过 datum、redeemer、脚本上下文、Plutus/UPLC 制品、执行单元、Plutus 蓝图以及链下交易构建语义来验证 eUTXO 支出；注册表更改需等待 Aiken 源代码生成 spike 路径选定 |
| D-019 | 2026-07-01 | 将 **`tezos-michelson-ligo`** 分类为文档优先的 Michelson/LIGO 源代码生成 Research 候选 | Tezos 合约以 Michelson 为目标，具有类型化存储、参数、入口、视图/事件、操作列表、`big_map`、tickets、Sapling、gas 和存储燃烧语义；注册表更改需等待 LIGO 源代码生成 spike 路径选定 |
| D-020 | 2026-07-01 | 将 **`starknet-cairo`** 分类为文档优先的 Cairo/Sierra/CASM 源代码生成 Research 候选 | Starknet 合约通过 Cairo 编译为 Sierra/CASM，具有 ABI、类哈希、声明/部署元数据、Starknet 存储/事件、账户抽象、系统调用以及 L1/L2 消息传递语义；注册表更改需等待 Cairo 包 spike 路径选定 |
| D-021 | 2026-07-01 | 将 **`bitcoin-script-miniscript`** 分类为文档优先的比特币基础层支出策略 Research 候选 | 比特币脚本被有意限制在带有签名、哈希锁、时间锁、描述符、Miniscript、Taproot/Tapscript、PSBT 流以及标准性/费用约束的 UTXO 锁定/解锁策略；注册表更改需等待 Miniscript/描述符 spike 路径选定 |
| D-022 | 2026-07-01 | 将 **`zcash-shielded`** 分类为文档优先的隐私 UTXO/ZK 支付 Research 候选 | Zcash 衍生自比特币，但屏蔽支持取决于 Sapling/Orchard note、nullifier、anchor、价值平衡约束、查看/披露策略以及协议定义的 ZK 证明；注册表更改需等待屏蔽 note 能力和证明/验证边界完成评审 |
| D-023 | 2026-07-01 | 将 **`aleo-leo`** 分类为文档优先的 Aleo ZK 应用源代码生成 Research 候选 | Aleo 程序结合了私有链下证明执行、公共链上最终化、加密记录、公共映射/存储、Aleo 指令、Aleo VM 字节码、ABI、证明者/验证者制品以及执行/部署交易；注册表更改需等待证明/最终化拆分完成评审 |
| D-024 | 2026-07-01 | 将 Robinhood Chain 建模为 **`robinhood-chain-testnet`**，即 `evm` 下的 EVM 兼容链 profile，而非新的编译器目标 | Robinhood Chain 执行 EVM 兼容的 Arbitrum Orbit L2 合约；ProofForge 的 EVM 后端涵盖字节码生成，而链 profile 记录链 id、RPC、浏览器、验证器、rollup 和部署元数据 |
| D-025 | 2026-07-01 | 添加 **`solana-sbpf-asm`** 作为探索中的新 Solana 路径（直接 sBPF 汇编代码生成）；保留 `solana-sbpf-linker` 作为备选 | 直接从可移植 IR 生成 sBPF 汇编避免了完整的 Lean Zig 运行时链接风险；blueshift-gg/sbpf 工具链处理汇编和链接。参见 [RFC 0005](rfcs/0005-solana-sbpf-assembly-backend.md) 和 [设计文档](targets/solana-sbpf-asm.md)。 |
| D-026 | 2026-07-01 | **采用 `solana-sbpf-asm` 作为规范的 Solana 路径；取代 `solana-sbpf-linker`** | 直接汇编路径避免了 Lean 运行时链接风险，提供了对计算单元和栈的完全控制，并镜像了 EVM/Yul 模式。`solana-sbpf-linker` 仅作为历史参考保留 —— 代码生成应以汇编路径为目标。 |
| D-027 | 2026-07-01 | **CPI 和 PDA 效应保留在 Solana 特有的层中，而非可移植 IR 中** | `cpiInvoke`、`cpiInvokeSigned` 和 `pdaDerive` 是 Solana 特有的概念（Solana 的账户传递 CPI + PDA 派生在 EVM、Wasm 或 Move 上没有类似物）。它们属于 `ProofForge.Backend.Solana.Effects` 或 Solana SDK 模块，受 `crosscall.cpi` 和 `storage.pda` 能力限制。可移植 IR (`ProofForge.IR.Contract.Effect`) 保持链中立 —— 仅当 ≥2 个目标家族共享相同的语义形状时才添加新的构造函数。 || D-028 | 2026-07-02 | **用户合约面向链中立的 Contract Intent API；选定的目标将 intent 解析为能力计划** | 默认 SDK 界面不应暴露目标链。用户编写可移植的合约 intent，然后 `--target` 选择目标适配器，该适配器将这些 intent 路由到低层级的能力实现，检查支持情况/运行时约束，并发射目标制品。能力 id 仍是目标适配器和目标扩展 SDK 使用的内部协议；它们不是主要面向用户的 API。 |
| D-029 | 2026-07-01 | 采用 Rust `near-sdk-rs` 源代码生成作为仓库内的 `wasm-near` v0 后端 | EmitZig/Zig 宿主桥接源码不在仓库中；可移植 IR → near-sdk-rs 包 → cargo wasm32 现在验证 NEAR 语义，并保留 Zig 宿主桥接路径以便以后恢复。（在 2026-07 分支合并期间，从 NEAR 分支的 D-025 重新编号。） |
| D-030 | 2026-07-01 | `wasm-near` v0 支持 `Hash` map 键、`.assertions.check` 和 `.account.explicit` | 现有 `MapProbe`（Hash 键，`assertEq`）和 `ContextProbe` (`contractId`) fixture 所需；`.crosscall.invoke` 在源代码生成 v0 中仍不受支持。（从 NEAR 分支的 D-026 重新编号。） |
| D-031 | 2026-07-01 | 采用 **`EmitWat`**（可移植 IR → Wasm AST → WAT 文本 → `wat2wasm`）作为规范的 Wasm 家族后端；将 Rust `near-sdk-rs` 源代码生成降级为**冻结的 v0 权宜方案** | `EmitWat` 镜像了仓库内的 **可移植 IR → Yul** 渲染器 `Backend/Evm/IR.lean`（由每个 `--emit-*-ir-yul` CLI 模式使用），而*不是*独立的基于 LCNF 的 `Compiler/LCNF/EmitYul.lean`。因为可移植 IR 已经抽象了 Lean 对象（仅限 `u32`/`u64`/`bool`/`hash` 标量 + 存储效应），`EmitWat` 不需要 Lean 运行时移植、对象模型装箱或 GC —— 既避免了 Rust 路线的 `near-sdk` 宏耦合（E0119 Borsh / 缺失 `&self` 的 cargo-check 失败），也避免了阻塞先前 `EmitZig` 计划的 Lean-runtime-to-Wasm 移植。共享层：`Compiler/Wasm/AST.lean` + `Printer.lean` + IR→AST 降级（平行于 `Compiler/Yul/AST.lean` + `Printer.lean`）；来自 `Backend/WasmNear/IR.lean` 和 `Backend/Evm/IR.lean` 的可重用验证。每条链：宿主导入 + ABI 序列化。关键 spike 风险：NEAR 参数（反）序列化（JSON/Borsh），EVM 后端不面临此问题（EVM 使用 calldata）。（从 NEAR 分支的 D-027 重新编号。） |
| D-032 | 2026-07-01 | 批准 **`aleo-leo`** Research 退出设计：Leo-first `zk-app-sourcegen` 边界、Road 1 的规范能力、制品清单 schema 以及 `leo build`/`leo test` 工具链 | Aleo 的证明/最终确定性分离需要其自身的源代码生成家族，区别于 `psy-dpn` 风格的电路源代码生成；代码注册表更改仍推迟到 Road 1 spike 成功并经过评审为止。（在 2026-07 分支合并期间，从 Aleo 分支的 D-025 重新编号。） |
| D-033 | 2026-07-01 | 添加 **`wasm-cloudflare-workers`** 作为 Research Wasm 宿主目标 | Cloudflare Workers 不是区块链，但它与 NEAR/CosmWasm 共享 Wasm 宿主后端模式；它通过使用重新解释的能力在链下运行相同的经过验证的业务逻辑，验证了可移植核心模型。（在 2026-07 分支合并期间，从 Cloudflare 分支的 D-025 重新编号。） || D-034 | 2026-07-02 | 采用**分层目标组合** ([target-roadmap](target-roadmap.md)) 并将 UTXO 脚本目标归类为独立的**策略家族** | 分层门控：在 `evm`/`solana-sbpf-asm`/`wasm-near` 上实现共享场景一致性将并行开启 `wasm-cosmwasm` (D-006) 和 `move-aptos` (D-007)；Soroban/Sui/源代码生成目标在这些出口开启；同一时间最多只能有一个活跃的源代码生成 spike。Bitcoin 家族目标 (`bitcoin-script-miniscript`, `bch-cashscript`, `zcash-shielded`, `kaspa-toccata`) 是支出策略生成器，而非合约执行器：它们获得一个带有新 `policy.*` 能力 id 的策略 IR（谓词树；无存储/事件/跨调用）以及一条 PSBT/regtest 验证通道，而不是被强制通过合约流水线 |
| D-035 | 2026-07-02 | **当前阶段完成标准：** 在开启 Tier-1 目标之前，共享场景（Counter，然后是 ValueVault）必须在 `evm`、`solana-sbpf-asm` 和 `wasm-near` 上通过 | 锁定当前整合阶段的完成定义 (Definition of Done)；在满足 Gate G0 之前，保持新的 Research 目标仅限文档，防止过早的能力注册表/能力变动 |
| D-036 | 2026-07-02 | 在 IR/目标层将**分配器建模统一**在单个 `AllocatorModel` (strategy/region/release) 下，保留 Solana `solana.allocator.*` 制品元数据键作为 Solana 特定的配置语法，并为 EVM 提供显式的 bump-over-scratch 绑定 | 解决工作流 24 分配器统一的悬而未决问题；RFC 0008 定义了该三元组。持久状态模型（EVM 存储、Solana 账户、NEAR 存储）保持在分配器抽象之外。在所有权稳健性 (FV-3) 证明受检 no-op 的合理性之前，`Statement.release` 在 EVM 上仍被拒绝 |
| D-037 | 2026-07-02 | 将 **`wasm-cloudflare-workers`** 保留在 `wasmHost` 目标家族下作为 Research 链下宿主 | 它与 NEAR/CosmWasm 共享 Wasm 宿主后端模式（EmitWat，可移植核心 + 宿主桥接）；其链下状态通过阶段 (Research) 和能力集来表达，而不是通过独立的家族。在更多链下目标迫使进行新分类之前，推迟建立独立的链下宿主家族 |
| D-038 | 2026-07-03 | 将 **`evm` 目标 profile** 绑定到显式的 bump-over-call-scratch 分配器模型 (`AllocatorConfig.evm`：strategy 为 `bump`，region 为 call-scratch，`release = none`) | 记录 `EmitYul`/EVM plan 已有的行为：EVM 使用按交易划分的临时暂存内存（word 寻址、编译器选择偏移量）且从不释放。`Statement.release` 在 EVM v0 上仍被拒绝。向 `release = noop` 的过渡以 FV-3 为前提：必须证明所有权检查使 release 在语义上透明（无释放后使用、无重复释放），从而保证 EVM 执行轨迹与可复用目标保持一致 |
| D-039 | 2026-07-03 | 在 testkit M4 绑定到旧版 flag 之前，将 CLI 产品形态规划为 `proof-forge build|emit|check --target <id> [--fixture <id>]` | RFC 0009 定义了 target-first 的界面、fixture 注册表以及旧版 flag 的别名/弃用计划。实现按 RFC 评审后分阶段进行；在工作流 29 M1 之前不做代码改动 |
| D-040 | 2026-07-03 | 将资源预算（EVM gas、Solana CU、NEAR gas）作为 Tier-0 一致性门控的必选项 | Tier-0 共享场景一致性（D-034）不能只比较行为；RFC 0010 定义了 testkit 场景中的可选 per-step budget 基线 + 容差带，避免宣告虚假一致性并锁定当前 Solana 直接汇编路线的低 CU 优势 |
| D-041 | 2026-07-03 | 采用可移植运行时错误模型（`assertion_id` + 可选 `user_code`）和统一的 `ContractSpec` 客户端 schema | 每个目标以原生形式编码同一错误 id（EVM revert、Solana custom error、NEAR panic payload、Psy assertion index）；testkit 可断言 `expect.error`。目标中立的 `ContractSpec` JSON 泛化现有 Solana IDL，在 testkit M3 之后为各链 TS 客户端生成提供输入 |
| D-042 | 2026-07-03 | 为可移植 IR、制品/部署 JSON schema、能力 id 以及 SDK/CLI 采用版本控制与兼容性策略 | IR 使用 `major.minor`：新构造函数为 minor，语义变化为 major；制品/部署 schema 使用整数 `schemaVersion` 并遵循宽容读取规则；能力 id 仅追加；SDK/CLI 在 1.0 前后遵循类 semver 规则。RFC 0012 定义完整策略 |
| D-043 | 2026-07-03 | 添加 `upgradePolicy` intent（`immutable | authority(keyRef) | governance(ref)`）并将签名保持在编译器之外 | 每个目标诚实地降级该策略或在编译时拒绝；EVM v0 仅支持 `immutable`；Solana 支持 `immutable` 和 `authority`；NEAR 将 `immutable`/`authority` 作为账户密钥策略。ProofForge 仅发出未签名交易/清单；密钥保管保留在钱包/KMS/CI 密钥中。RFC 0013 定义完整生命周期与签名边界 |

## 目标家族分类| 目标家族 | 目标 | 后端模式 |
|---|---|---|
| 直接编译器 | `evm` | Lean → LCNF → Yul → solc |
| EVM 兼容链 profile | `robinhood-chain-testnet` | 复用 `evm` 字节码/ABI 输出；添加 chain id、RPC、浏览器、验证器、rollup 以及部署元数据 |
| Wasm 宿主 | `wasm-near`, `wasm-cosmwasm`, `wasm-cloudflare-workers` (链下宿主, D-033), `wasm-stellar-soroban` (候选, 仅文档), `wasm-icp-canister` (候选, 仅文档) | 可移植 IR → **`EmitWat`** (Wasm AST → WAT) → `wat2wasm` + 逐链宿主导入；Rust/CDK 源代码生成仅作为冻结的 v0 临时方案使用 (D-031, [wasm-family](targets/wasm-family.md))；Cloudflare Workers 目前使用 TypeScript 源代码生成 |
| 二进制工具链 | `solana-sbpf-linker`, `solana-zig-fork` | Lean → EmitZig → bitcode → sbpf-linker (历史参考；被 D-026 取代) |
| sBPF 直接代码生成 | `solana-sbpf-asm` | Lean → IR → sBPF 汇编 (.s) → sbpf 工具链 → ELF (规范 D-026) |
| 源代码生成 | `move-aptos`, `move-sui` | 可移植 IR → Move 包源代码 |
| AVM 源代码生成 Research | `algorand-avm` (候选, 仅文档) | 可移植 IR → Algorand Python、Algorand TypeScript 或 TEAL 包 → AVM approval/clear-state 或 LogicSig 字节码 + ARC-4/app 元数据 |
| eUTXO 验证器源代码生成 Research | `cardano-plutus-aiken` (候选, 仅文档) | 可移植 IR → Aiken 包 → UPLC/Plutus 验证器制品 + Plutus 蓝图 + 交易场景元数据 |
| Michelson 源代码生成 Research | `tezos-michelson-ligo` (候选, 仅文档) | 可移植 IR → LIGO 包 → Michelson 合约 + 参数/存储 schema + 操作/视图/事件清单 |
| Cairo 源代码生成 Research | `starknet-cairo` (候选, 仅文档) | 可移植 IR → Cairo/Scarb 包 → Sierra/CASM 制品 + ABI/class-hash/部署元数据 |
| Aleo ZK 应用源代码生成 (`zk-app-sourcegen`) | `aleo-leo` (候选, 仅文档) | 可移植 IR → Leo 包 → Aleo Instructions → Aleo VM 字节码 + ABI/prover/verifier 制品 + 执行/部署元数据 |
| TVM 源代码生成 Research | `ton-tvm` (候选, 仅文档) | 可移植 IR → Tolk 或更低层级的 TON 源代码 → TVM/BOC 制品 + TL-B/消息清单 |
| 比特币脚本策略 Research | `bitcoin-script-miniscript` (候选, 仅文档) | 可移植 IR → policy/Miniscript/descriptor 包 → Script/Tapscript 输出 + PSBT/regtest 验证元数据 |
| 隐私 UTXO ZK 支付 Research | `zcash-shielded` (候选, 仅文档) | 可移植 IR → 屏蔽交易/证明清单 → 带有 Sapling/Orchard 证明包的 Zcash 交易 + zcashd/库验证元数据 |
| UTXO 脚本源代码生成 Research | `bch-cashscript` (候选, 仅文档) | 可移植 IR → CashScript `.cash` 源代码 → cashc 制品 JSON + BCH 交易构建器验证 |
| ZK 电路源代码生成 | `psy-dpn` | 可移植 IR → `.psy` 包 → Dargo → DPN 电路 JSON |
| UTXO 契约 Research | `kaspa-toccata` (候选, 仅文档) | 可移植 IR → covenant/Silverscript 包 + 交易 v1 清单 + 可选的证明结算元数据 |

## 路线图摘要

```text
Phase 0: EVM baseline (done)
Phase 1: Target registry + portable IR + artifact metadata + capability errors
Phase 2: Parallel spikes — CosmWasm (wasm-cosmwasm) + Solana (solana-sbpf-linker)
Phase 3: Move sourcegen — Aptos POC first, then Sui
Phase 3.5: Psy DPN sourcegen research spike
Research lane: Kaspa Toccata covenant/based-app target note before registry changes
Research lane: Stellar Soroban Wasm-host target note before registry changes
Research lane: Internet Computer canister target note before registry changes
Research lane: Algorand AVM/TEAL target note before registry changes
Research lane: Cardano Plutus/Aiken eUTXO target note before registry changes
Research lane: Tezos Michelson/LIGO target note before registry changes
Research lane: Starknet Cairo target note before registry changes
Research lane: Aleo Leo ZK app target note before registry changes
Research lane: TON TVM/Tolk target note before registry changes
Research lane: Bitcoin Script/Miniscript spending-policy target note before registry changes
Research lane: Zcash shielded privacy payment target note before registry changes
Research lane: Bitcoin Cash CashScript target note before registry changes
Phase 4: Cross-target shared scenario hardening
Phase 5: Cloud platform
```

详细任务：[实现待办事项](implementation-backlog.md)。

## 权威规范

| 主题 | 文档 |
|---|---|
| 可移植合约 IR | [portable-ir.md](portable-ir.md) |
| 能力 id | [capability-registry.md](capability-registry.md) |
| Counter 共享场景 | [shared-scenario.md](shared-scenario.md) |
| 目标工程形态 | [RFC 0002](rfcs/0002-target-implementation-design.md) |
| CosmWasm SDK spike 草图 | [targets/wasm-family.md](targets/wasm-family.md) |
| Wasm-NEAR 源代码生成目标 | [targets/wasm-near.md](targets/wasm-near.md) |
| Cloudflare Workers 目标 | [targets/cloudflare-workers.md](targets/cloudflare-workers.md) |
| Stellar/Soroban 候选目标 | [targets/stellar-soroban.md](targets/stellar-soroban.md) |
| Internet Computer 候选目标 | [targets/internet-computer.md](targets/internet-computer.md) |
| Algorand AVM 候选目标 | [targets/algorand-avm.md](targets/algorand-avm.md) |
| Solana 指令清单 | [targets/solana-sbf.md](targets/solana-sbf.md) |
| Cardano Plutus/Aiken 候选目标 | [targets/cardano-plutus-aiken.md](targets/cardano-plutus-aiken.md) |
| Tezos Michelson/LIGO 候选目标 | [targets/tezos-michelson-ligo.md](targets/tezos-michelson-ligo.md) |
| Starknet Cairo 候选目标 | [targets/starknet-cairo.md](targets/starknet-cairo.md) |
| Aleo Leo 候选目标 | [targets/aleo-leo.md](targets/aleo-leo.md) |
| TON TVM 候选目标 | [targets/ton-tvm.md](targets/ton-tvm.md) |
| Bitcoin Script/Miniscript 候选目标 | [targets/bitcoin-script-miniscript.md](targets/bitcoin-script-miniscript.md) |
| Zcash Shielded 候选目标 | [targets/zcash-shielded.md](targets/zcash-shielded.md) |
| Bitcoin Cash CashScript 候选目标 | [targets/bitcoin-cash-cashscript.md](targets/bitcoin-cash-cashscript.md) |
| Psy/DPN ZK 目标 | [targets/psy-dpn.md](targets/psy-dpn.md) |
| Kaspa/Toccata 候选目标 | [targets/kaspa-toccata.md](targets/kaspa-toccata.md) |

## 已废弃的立场

以下早期的文档立场不再具有权威性：

- RFC 0001 Phase 2 = 仅限 Solana，Phase 3 = 仅限 Wasm —— 已由并行的 Phase 2 spike (D-003) 取代。
- Milestone 3 = Solana 作为唯一的第二个目标 —— 已由并行的 CosmWasm + Solana (D-003) 取代。
- CLI id `solana-sbf` —— 使用 `solana-sbpf-asm` (D-026)。
- Move POC 同时生成 Sui 和 Aptos 包 —— Aptos 优先 (D-007)。
