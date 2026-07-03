> **注意：** 公共验证命令的更改必须在同一变更中更新
> [validation-gates.md](validation-gates.md)。

# 实现待办列表

此待办列表将多链设计转化为可评审的工程切片。
它被有意地限定在本地编译器、制品和冒烟测试工作范围内。
云平台应等到至少两个实质上不同的目标在本地正常工作后再开始。

相关文档：

- [设计决策](decisions.md)
- [可移植合约 IR](portable-ir.md)
- [能力注册表](capability-registry.md)
- [共享场景：Counter](shared-scenario.md)
- [RFC 0002](rfcs/0002-target-implementation-design.md)
- [目标说明](targets/README.md)
- [验证门禁](validation-gates.md)

## 工作流 1：目标注册表

目标：在添加更多后端之前使目标选择显式化。

任务：

- 添加目标 id：`evm`, `wasm-near`, `wasm-cosmwasm`,
  `solana-sbpf-asm`, `solana-sbpf-linker` (已取代), `solana-zig-fork`,
  `move-sui`, `move-aptos`, `psy-dpn`。
- 定义目标家族、制品种类、所需工具和能力集
  （参见 [capability-registry.md](capability-registry.md)）。
- 为 CLI 和脚本添加目标查找函数。
- 已完成：为部署元数据添加 EVM 兼容链的 profile 层，
  从 `evm` 编译器目标下的 `robinhood-chain-testnet` 开始。
- 为未知目标和不支持的能力添加诊断信息。

验收标准：

- `evm` 可以表示为一个目标 profile，而无需更改当前的 EVM 行为。
- EVM 兼容链 profile 可以复用 `evm` 编译器目标，而不会被目标 id 查找返回。
- 目标 profile 可以声明外部工具需求。
- 不支持的能力错误应包含目标 id、能力 id 以及可用的源位置。

## 工作流 1.5：可移植 IR 和共享场景

目标：在进行非 EVM spike 之前定义合约 IR 和 Counter 场景。

任务：

- 根据 [portable-ir.md](portable-ir.md) 实现 IR 节点类型。
- 根据 [shared-scenario.md](shared-scenario.md) 表达 Counter。
- 将 Counter IR 降级到 EVM（直接降级或通过 EmitYul 适配器）。
- 将能力检查器连接到 [capability-registry.md](capability-registry.md)。

验收标准：

- Counter 模块可以在 IR 中表示，且 IR 层不包含 EVM 操作码。
- 从 IR 构建的 EVM 版本与现有的 Counter 行为一致。
- 至少有一个不支持的能力被拒绝，并带有清晰的诊断信息。
- 发射时，IR 版本出现在制品元数据中。

## 工作流 2：制品元数据

参见 [validation-gates.md](validation-gates.md) 以了解当前和计划中的验证命令。

目标：每次构建都应产生机器可读的结果，以便后续提供给 CI 和云平台。

任务：- 已完成 EVM 部分：为 EVM 字节码构建添加 `proof-forge-artifact.json` schema。
- 已完成 EVM 部分：为 `--evm-bytecode` 和可移植 IR EVM 字节码 fixture 构建发射元数据。
- 已完成 EVM 部分：包含源模块、目标 id、制品路径、SHA-256、字节大小、solc 路径/版本、选择器/签名元数据以及验证状态。
- 已完成 EVM 部分：在 `abi.methods[].signature` 中为 `proof-forge-artifact.json` 和 `proof-forge-deploy.json` 保留 SDK `.evm-methods` Solidity 签名；验证器检查选择器形状、重复的方法选择器/函数/签名、生成的 Yul 函数名以及签名/参数数量一致性，且 SDK 示例门控要求提供签名。
- 已完成 EVM 部分：为每个 EVM 字节码构建发射并验证 ProofForge 部署清单，记录运行时字节码输入、ABI 选择器、可部署的 initcode 以及当前的 `not-generated` 交易广播状态。
- 已完成 EVM 部分：为每个 EVM 字节码构建生成一个链接到制品的 `.init.bin` 创建字节码文件，将其记录在 `proof-forge-artifact.json` 和 `proof-forge-deploy.json` 中，并验证 initcode 头部是否复制并返回了引用的运行时字节码。
- 已完成 EVM 部分：添加 `--evm-chain-profile <id>`，使字节码构建可以在 `proof-forge-deploy.json` 中记录已知的 EVM 链 profile（如 `robinhood-chain-testnet` 或 `anvil-local`）；验证器在不广播的情况下检查 profile id、链 id、RPC URL、浏览器、验证器以及部署区块的一致性。
- 已完成 EVM 部分：添加 `--evm-constructor-args-hex <hex>`，使字节码构建可以将显式的 ABI 编码构造函数参数追加到生成的 `.init.bin` 中，在 `proof-forge-deploy.json` 中记录归一化的十六进制/字节大小/SHA-256 构造函数元数据，并验证 initcode 尾部是否与清单匹配。
- 已完成 EVM 部分：添加 `--evm-constructor-param <name:type>`，使字节码构建可以在制品元数据和部署清单中记录静态字构造函数 ABI schema，验证支持的 schema 类型，并验证显式的 ABI 编码构造函数参数 blob 是否具有预期的 32 字节字长。
- 已完成 EVM 部分：添加 `--evm-constructor-arg <name=value>`，使字节码构建可以为 `uint256`、`uint64`、`uint32`、`bool`、`bytes32` 和 `address` 对有类型的构造函数值进行 ABI 编码，记录构造函数参数是来自有类型的值还是原始十六进制，拒绝缺失/重复/超出范围的值，并根据元数据和部署清单验证生成的 initcode 尾部。
- 已完成 EVM 部分：在 `abi.entrypoints` 中记录结构化的面向可移植 IR 选择器的入口 ABI 元数据，包括 Solidity 风格的选择器签名、IR 类型名称、ABI 参数/返回类型、展平的 calldata 字类型/计数以及展平的返回字类型/计数；验证器检查与 `cast sig` 的选择器/签名一致性，且 `EvmAbiAggregateProbe` 通过 `--expect-entrypoint-abi` 锁定聚合字布局。
- 已完成 EVM 部分：在 `abi.events` 中记录可移植 IR 事件 ABI 元数据，包括 Solidity 风格的事件签名、`topic0`、索引/数据字段、展平的 ABI 字类型以及 topic/数据编码；EventProbe 使用 `--expect-event` 和 `cast keccak` 验证每个发射的事件。
- 已完成 EVM 部分：扩展 `scripts/evm/diagnostic-smoke.sh` 以锁定针对不支持的动态构造函数 ABI 类型、缺失或重复的有类型值、混合的有类型/原始构造函数参数源、溢出以及格式错误的静态字值（如短地址）的构造函数 CLI 诊断。
- 已完成 EVM 部分：添加一个 Anvil 部署冒烟测试，该测试使用 `cast send --create` 发送生成的 Counter `.init.bin`，记录构造函数 ABI schema 和有类型的构造函数参数以及一个 `proof-forge-deploy-run.json` 制品，记录 `eth_getTransactionByHash` 创建交易 JSON，验证 `anvil-local` 链 profile、收据/部署地址/运行时代码匹配以及交易输入 initcode，并通过 JSON-RPC 演练 Counter 生命周期。
- 从第一天起保持 schema 的版本化。

验收标准：- EVM 字节码构建将运行时字节码、可部署的 initcode、元数据和部署清单并排写入。
- 元数据和部署清单可以由 CI 脚本独立解析。
- 可移植 IR 字节码元数据和部署清单可以描述面向 ABI 的入口，包括选择器签名、扁平化的 calldata 字布局以及扁平化的 return-data 字布局。
- 可移植 IR 字节码元数据和部署清单可以描述面向 ABI 的事件，包括索引 topic 编码和非索引数据字编码。
- 部署清单可以携带来自目标注册表的可选 EVM 链 profile 元数据，同时保持交易广播制品显式为 `not-generated`。
- 本地 Anvil 部署可以消耗生成的部署清单和 initcode，生成经过验证的部署运行制品，并证明部署的运行时代码与生成的字节码匹配，即使在 initcode 包含带有记录的静态构造函数 ABI 模式的类型化或原始 ABI 编码的构造函数参数尾部时也是如此；部署运行制品还链接了观察到的创建交易 JSON，并验证其输入等于生成的 initcode，且部署 profile 的链 id 与实际本地链匹配。
- EVM 元数据可以将缺失的可选版本数据表示为 `null`，而不是格式错误的元数据。

## 工作流 3：EVM 基线加固

有关当前和计划中的验证命令，请参阅 [validation-gates.md](validation-gates.md)。

目标：在引入目标模型时保持 EVM 稳定。

任务：- 保持 `proof-forge --evm-bytecode` 正常工作。
- EVM 语义计划迁移 TODO：
  - 已完成：使 `ModulePlan` 变为目标驱动，以便在 Yul 生成之前从 `Target.resolveModule/resolveSpec Target.evm` 派生辅助程序规划。
  - 将 `ProofForge.Backend.Evm.IR` 拆分为 `Validate`、`Lower`、`ToYul` 和 `Metadata` 模块，同时保留 `IR.lean` 作为兼容性外观，直到调用方完成迁移。
  - 已完成：将标量和映射存储槽的 Yul 构建移至 `StorageSlotPlan -> ToYul`，从存储路径使用的映射值/存在槽开始。
  - 将 `StorageSlotPlan -> ToYul` 扩展到数组槽和结构体数组字段槽，然后从 `IR.lean` 中移除旧的直接槽表达式构建器。
  - 添加 `ExprPlan` 和 `StmtPlan`，使表达式和语句验证、辅助程序发现以及目标特定降级在 Yul AST 组装之前发生。
  - 为选择器分发、calldata 保护、ABI 字平铺、返回数据编码和元数据选择器布局添加 `EntrypointPlan`。
  - 为事件签名主题、索引主题哈希、非索引数据平铺和元数据事件布局添加 `EventPlan`。
  - 为类型化的 `call`、带值的 `call`、`staticcall`、`delegatecall`、`create` 和 `create2` 辅助程序添加 `CrosscallPlan`。
  - 添加 `MetadataPlan` 和部署制品规划，以便从同一个语义计划中生成字节码元数据、initcode、部署清单和链 profile 引用。
  - 仅在每个迁移的能力都涵盖了计划级诊断、黄金 Yul、solc 字节码生成、Foundry 冒烟测试、制品元数据验证和 EVM IR 覆盖清单后，才删除旧的自定义语义 `IR.lean -> Yul` 降级。
  - 保留 `ProofForge.Compiler.Yul.AST` 和 `ProofForge.Compiler.Yul.Printer`；此次迁移替换的是后端语义降级，而非目标 AST/打印机边界。
- 已完成：添加 EVM IR 诊断冒烟测试，使不支持的可移植 IR 形状在 Yul 生成之前失败并显示稳定的消息。
- 已完成：添加 EVM IR 覆盖清单门控，使每个可移植 IR 构造函数必须针对 EVM 后端分类为已降级、已验证、不支持或结构化。
- 已完成：为 `U64`、`U32` 和 `Bool` 上的可移植 IR EVM 标量 ABI 参数解码添加 `AbiScalarProbe`，并包含黄金 Yul、solc 字节码和 Foundry 畸形 calldata 验证。
- 已完成：将 EVM IR `assert` 和 `assert_eq` 降级为 Yul revert 保护，并包含 `AssertProbe` 黄金 Yul、solc 字节码以及 Foundry 成功/revert 验证。
- 已完成：添加 EVM IR 可变标量局部绑定和局部赋值降级，并包含 `AssignmentProbe` 黄金 Yul、solc 字节码以及 Foundry 成功/revert 验证。
- 已完成：为所有可移植 `AssignOp` 变体添加 EVM IR 局部和标量存储复合赋值降级，并包含 `EvmAssignOpProbe` 黄金 Yul、solc 字节码、Foundry 运行时/原始槽验证、元数据能力验证，以及针对畸形目标/类型的显式诊断。
- 已完成：将 EVM IR 语句级 `if/else` 降级为 Yul `switch` 代码块，并包含 `ConditionalProbe` 黄金 Yul、solc 字节码、Foundry 运行时验证，以及通过 `EvmLoopProbe` 进行的 EVM 特定分支局部提前返回验证。
- 已完成：将 EVM IR `boundedFor` 降级为具有静态边界的 Yul `for` 循环，并包含 `EvmLoopProbe` 黄金 Yul、solc 字节码、Foundry 运行时/原始存储验证、元数据能力验证、通过 Yul `leave` 进行的分支局部和循环局部提前返回降级，以及显式的无效范围诊断。
- 已完成：将 `userId`、`contractId` 和 `checkpointId` 的 EVM IR 上下文读取降级为 Yul `caller()`、`address()` 和 `number()`，并包含 `ContextProbe` 黄金 Yul、solc 字节码、Foundry 运行时验证和元数据能力验证。
- 已完成：将 EVM IR `nativeValue` 降级为 Yul `callvalue()`，并包含 `ContextProbe` 黄金 Yul、solc 字节码、Foundry 带值调用验证以及 `value.native` 元数据能力验证。- 已完成：添加 EVM IR `eventEmit` 降级至 Yul `log1`，支持 `keccak256(Solidity-style event signature)` topic0 和 32 字节字数据字段，包含 `EventProbe` 黄金 Yul、solc 字节码、Foundry recorded-log 验证、元数据能力验证以及显式格式错误事件诊断。
- 已完成：添加 EVM IR `eventEmitIndexed` 降级至 Yul `log2`/`log3`/`log4`，支持最多三个标量索引字段，包含签名 topic0、索引 topic、非索引 32 字节字数据、`EventProbe` 黄金 Yul、solc 字节码、Foundry recorded-log 验证、元数据能力验证以及显式索引事件诊断。
- 已完成：填补多 topic 标量索引事件的 EventProbe 验证空白。`IndexedTwoValues(uint64,uint64,uint64)` 和 `IndexedThreeValues(uint64,uint64,uint64,uint64)` 现在证明生成的 Yul 发射 `log3` 和 `log4`，保留有序标量索引 topic，验证元数据选择器，使用 `solc` 编译，并通过 Foundry recorded-log 断言。
- 已完成：填补有类型标量事件字段的 EventProbe 验证空白。`TypedScalarEvent(bool,uint32,bytes32)` 和 `IndexedTypedScalar(bool,uint32,bytes32,uint64)` 现在证明 Bool、U32 和 Hash 事件数据字及索引 topic 正确降级，包含 Bool/U32 调度器守卫、黄金 Yul、元数据选择器检查、`solc` 以及 Foundry recorded-log 断言。
- 已完成：将 EVM IR 事件数据降级扩展至标量字之外，使非索引扁平结构体字段、标量固定长度数组字段以及扁平结构体的固定长度数组发射 ABI 风格的扁平化数据字，包含规范的 Solidity 风格事件签名（如 `PairEvent((uint64,uint64))`、`ArrayEvent(uint64[2])` 和 `PairArrayEvent((uint64,uint64)[2])`）、`EventProbe` 黄金 Yul、solc 字节码、Foundry recorded-log 验证、元数据选择器验证以及针对不支持的聚合索引字段的显式诊断。
- 已完成：扩展 EVM IR `eventEmitIndexed` 降级，使扁平结构体索引字段以及元素为扁平结构体的固定长度数组索引字段将其 ABI 风格的扁平化字哈希为索引 topic。`EventProbe` 现在涵盖 `IndexedPair((uint64,uint64),uint64)` 和 `IndexedPairArray((uint64,uint64)[2],uint64)`，包含黄金 Yul、solc 字节码、元数据选择器验证、Foundry recorded-log topic 哈希检查，以及针对嵌套/不支持的聚合索引形状的诊断。
- 已完成：通过添加 `IndexedArray(uint64[2],uint64)` 黄金 Yul、元数据选择器验证、solc 字节码生成和 Foundry recorded-log topic 哈希检查，填补标量固定长度数组索引 topic 的 EventProbe 验证空白。
- 已完成：扩展 EventProbe 嵌套固定长度数组事件聚合覆盖范围。`MatrixEvent(uint64[2][2])` 和 `PairMatrixEvent((uint64,uint64)[2][2])` 证明了标量和扁平结构体叶子节点的递归非索引数据扁平化，而 `IndexedMatrix(uint64[2][2],uint64)` 和 `IndexedPairMatrix((uint64,uint64)[2][2],uint64)` 证明了对递归扁平化的 ABI 风格字进行索引聚合 topic 哈希。冒烟测试现在锁定新的选择器、事件 ABI 元数据、黄金 Yul、`solc` 字节码以及 Foundry recorded-log 断言；带有不支持或非扁平叶子节点的嵌套数组仍保持显式诊断。
- 已完成：添加存储后端的扁平结构体事件数据和索引聚合 topic 的 EventProbe 覆盖。`StoragePairEvent((uint64,uint64))` 和 `IndexedStoragePair((uint64,uint64),uint64)` 现在证明整个标量存储结构体写入可以通过 `storageScalarRead` 读回，扁平化为事件数据字，哈希为索引 topic，在黄金 Yul 中验证，在元数据选择器中检查，由 `solc` 编译，并由 Foundry recorded-log 解码。
- 已完成：添加存储后端的固定长度数组事件聚合的 EventProbe 覆盖。`StorageArrayEvent(uint64[2])`、`StoragePairArrayEvent((uint64,uint64)[2])`、`IndexedStorageArray(uint64[2],uint64)` 和 `IndexedStoragePairArray((uint64,uint64)[2],uint64)` 现在证明存储数组读取和存储数组结构体字段读取可以供给非索引事件数据扁平化和索引聚合 topic 哈希，包含黄金 Yul、元数据选择器检查、`solc` 以及 Foundry recorded-log 验证。
- 已完成：添加 EVM IR `crosscallInvoke` 降级至同步 EVM `call` 辅助函数，支持选择器打包、字参数、单字返回、失败调用以及短返回 revert，包含 `EvmCrosscallProbe` 黄金 Yul、solc 字节码、
  Foundry 运行时验证、元数据能力验证，以及显式的
  畸形跨调用类型诊断。
- 已完成：为 `Bool`、`U32`、`U64` 和 `Hash` 上的类型化标量字
  跨调用添加 EVM IR `crosscallInvokeTyped` 降级，包含特定于返回类型的
  Yul 辅助函数、Bool/U32 返回数据保护、`EvmCrosscallProbe` 黄金 Yul、
  solc 字节码、Foundry 有效/无效类型化返回验证、元数据
  入口验证、针对该阶段未涵盖的聚合参数/返回形状的诊断，
  以及显式的 Psy 不支持诊断。
- 已完成：将 EVM IR 普通 `crosscallInvokeTyped` 返回降级扩展到
  标量字之外，用于扁平结构体和标量固定数组的直接入口返回，
  包含特定于 ABI 字形状的 Yul 辅助函数、多字返回数据
  大小检查、跨聚合返回字的 Bool/U32 范围保护、
  `EvmCrosscallProbe` 黄金 Yul、solc 字节码、Foundry 聚合
  结构体/数组返回验证、元数据选择器验证，以及针对该阶段
  未涵盖的聚合返回形状的显式诊断。
- 已完成：将 EVM IR 类型化跨调用参数降级扩展到标量字之外，
  使普通、带值的、静态和委托类型化调用可以将扁平结构体和
  标量固定数组参数扁平化为 ABI 字。`EvmCrosscallProbe`
  现在通过黄金 Yul、solc 字节码、Foundry 运行时检查、
  元数据选择器验证以及针对该阶段未涵盖的聚合参数形状的
  显式诊断，涵盖了普通结构体和固定数组参数，以及带值/静态/委托
  结构体参数。
- 已完成：为带值的类型化跨调用添加 EVM IR `crosscallInvokeValueTyped` 降级，
  通过特定于值的 Yul 辅助函数转发显式的 U64 调用值表达式，
  用于标量返回以及扁平结构体和标量固定数组入口聚合返回，
  包含 `EvmCrosscallProbe` 黄金 Yul、solc 字节码、Foundry `msg.value`/被调用者余额验证、
  聚合 Bool/U32 畸形返回保护、元数据入口验证、EVM
  畸形值/返回诊断，以及显式的 Psy 不支持诊断。
- 已完成：为类型化静态调用添加 EVM IR `crosscallInvokeStaticTyped` 降级，
  使用不带值的 Yul `staticcall` 辅助函数，包含选择器/标量/扁平聚合
  参数打包、标量返回、扁平结构体和标量固定数组入口聚合返回，
  以及 Bool/U32 返回保护，包含 `EvmCrosscallProbe` 黄金 Yul、
  solc 字节码、Foundry U64 只读返回、Bool/U32/Hash 静态类型化返回、
  聚合返回验证、无效类型化返回、静态上下文状态写入失败验证、
  元数据入口验证、EVM 畸形嵌套聚合诊断，以及显式的 Psy 不支持诊断。
- 已完成：为类型化委托调用添加 EVM IR `crosscallInvokeDelegateTyped` 降级，
  使用不带值的 Yul `delegatecall` 辅助函数，包含选择器/标量/扁平聚合
  参数打包、标量返回、扁平结构体和标量固定数组入口聚合返回，
  以及 Bool/U32 返回保护，包含 `EvmCrosscallProbe` 黄金 Yul、
  solc 字节码、Foundry 调用者存储读/写验证、Bool/U32/Hash 委托类型化返回验证、
  聚合返回验证、无效类型化返回验证、元数据入口验证、
  EVM 畸形嵌套聚合诊断，以及显式的 Psy 不支持诊断。
- 已完成：将 EVM IR 类型化跨调用聚合覆盖范围扩展到普通、带值的、
  静态和委托类型化调用参数以及直接入口返回中的扁平结构体固定数组。
  `EvmCrosscallProbe` 现在验证所有四种调用模式下的 `RemotePair[2]` ABI 字扁平化、
  Bool/U32 字段返回保护、黄金 Yul、solc 字节码、Foundry 运行时行为
  以及元数据选择器。
- 已完成：将 EVM IR 类型化跨调用聚合覆盖范围扩展到普通、带值的、
  静态和委托类型化调用中的嵌套标量固定数组参数和直接入口返回。`EvmCrosscallProbe` 现在验证 `uint64[2][2]` ABI 字展平、黄金 Yul、solc 字节码、元数据选择器、Foundry 运行时行为、值转发、staticcall 行为以及所有四种调用模式下的 delegatecall 行为。在该里程碑阶段，诊断程序仍会拒绝结构体和其他非标量嵌套固定数组叶节点；扁平结构体叶节点现在由下方的后续项涵盖。
- 已完成：将 EVM IR 类型化跨调用聚合覆盖范围扩展到叶节点为扁平结构体的嵌套固定数组。`EvmCrosscallProbe` 现在验证普通、带值、静态和委托类型化调用中的 `RemotePair[2][2]` 参数和直接入口返回，包括 ABI 字展平、Bool/U32 字段保护、黄金 Yul、solc 字节码、元数据选择器、Foundry 运行时行为、值转发、staticcall 行为和 delegatecall 行为。诊断程序仍会拒绝结构体为非扁平或以其他方式不受支持的嵌套固定数组叶节点。
- 已完成：为固定 init-code 十六进制添加 EVM IR `crosscallCreate` 和 `crosscallCreate2` 降级。创建助手将 init code 写入内存，调用 Yul `create`/`create2`，在零地址失败时回滚，返回部署的地址字，并验证黄金 Yul、solc 字节码、元数据选择器、Foundry 部署的运行时调用、确定性 CREATE2 地址推导、EVM 畸形创建诊断以及 Psy 不受支持诊断。
- 已完成：为以下项添加 EVM IR 直接标量表达式验证：`U64`/`U32` 算术、`U64` 幂运算、`U64`/`U32` 位操作和移位、谓词、布尔运算符、字面量、不可变局部变量、受支持的转换、单字返回、调度器保护和断言保护，配合 `EvmExpressionProbe` 黄金 Yul、solc 字节码、Foundry 运行时/畸形 calldata 验证、元数据能力验证和 CI 覆盖。
- 已完成：添加 EVM IR `Hash` 字降级、`hash4`/`hashValue` 打包，以及通过 Yul `keccak256` 助手进行的 `hash`/`hash_two_to_one` 降级，配合 `EvmHashProbe` 黄金 Yul、solc 字节码、Foundry ABI/存储验证、元数据能力验证以及显式的 Hash/U64 不匹配诊断。
- 已完成：通过 Solidity 风格的 `keccak256(key, slot)` 映射槽位添加 EVM IR `Map<U64, U64, N>` 存储降级，配合 `EvmMapProbe` 黄金 Yul、solc 字节码、Foundry 运行时/原始槽位验证、元数据能力验证，以及针对不受支持的映射形状和语句位置误用的显式诊断。
- 已完成：在 `Map<U64, U64, N>` 之上添加 EVM IR 单段 `mapKey` 存储路径复合赋值，配合 `EvmMapProbe` 黄金 Yul、solc 字节码、Foundry 运行时/原始槽位验证、元数据能力验证，以及针对表达式位置和嵌套路径误用的显式诊断。
- 已完成：将 `U32`、`U64`、`Bool` 和 `Hash` 上的 EVM IR 存储映射泛化为字键/值形状，复用 Solidity 风格的 `keccak256(key, slot)` 映射槽位，配合 `EvmTypedMapProbe` 黄金 Yul、solc 字节码、Foundry 运行时/原始槽位验证、`U32`/`Bool` calldata 保护、元数据能力验证、CI 覆盖以及针对非字映射形状的显式诊断。
- 已完成：通过以 `keccak256(slot || PROOF_FORGE_MAP_PRESENCE)` 为根的 ProofForge 托管存在槽位添加 EVM IR `storage.map.contains` 降级，配合 `EvmMapProbe` 和 `EvmTypedMapProbe` 黄金 Yul、solc 字节码、针对 U64/U32/Bool/Hash 映射的 Foundry 值/存在槽位验证、零值存在键覆盖、元数据验证以及针对语句位置误用的显式诊断。
- 已完成：在连续的 `mapKey` 段上添加 EVM IR 嵌套映射存储路径，折叠用于值存储的 Solidity 风格映射槽位和用于最终键的 ProofForge 托管存在槽位，配合 `EvmMapProbe` 和 `EvmTypedMapProbe` 黄金 Yul、solc 字节码、Foundry 原始槽位验证，- U32 调度器守卫覆盖、元数据验证，以及针对混合 map/聚合存储路径的显式诊断。
- 已完成：添加 EVM IR `U64` 固定存储数组降级为带有运行时边界检查的连续存储插槽，包含 `EvmStorageArrayProbe` 黄金 Yul、solc 字节码、Foundry 运行时/原始插槽验证、元数据能力验证，以及针对不支持的数组元素类型的显式诊断。
- 已完成：在 `U64` 固定存储数组上添加 EVM IR 单分段 `index` 存储路径读/写/复合赋值，复用有界数组插槽辅助程序并扩展 `EvmStorageArrayProbe` 验证。
- 已完成：将 EVM IR 字 (word) 存储泛化为 `Bool` 标量存储和 `U32`/`Bool`/`Hash` 固定存储数组，复用有界数组插槽辅助程序，包含 `EvmTypedStorageProbe` 黄金 Yul、solc 字节码、Foundry 运行时/原始插槽验证、`U32` calldata 范围守卫、元数据能力验证、CI 覆盖，以及针对不支持的非字存储元素类型的显式诊断。
- 已完成：为带有静态字面量索引的 `U64`、`U32`、`Bool` 和 `Hash` 元素添加 EVM IR 不可变本地固定数组值降级，支持直接固定数组字面量索引，包含 `EvmArrayValueProbe` 黄金 Yul、solc 字节码、Foundry 运行时验证、元数据能力验证，以及针对静态越界索引的显式诊断。
- 已完成：将 EVM IR 本地固定数组降级扩展到可变聚合本地变量，包括静态元素赋值、数值元素复合赋值以及 `U32`/`Bool`/`Hash` 元素写入，包含 `EvmArrayValueProbe` 黄金 Yul、solc 字节码、Foundry 运行时验证、元数据入口验证、CI 覆盖，以及针对不可变元素赋值的显式诊断。
- 已完成：通过在表达式中传递降级环境，将 EVM IR 本地固定数组降级扩展到动态本地/字面量索引，为动态读取生成特定长度的 Yul getter 辅助程序，将动态本地元素赋值和数值复合赋值降级为 `switch` 代码块，并通过 `EvmArrayValueProbe` 黄金 Yul、元数据入口、solc 字节码和 Foundry 运行时检查验证动态范围内/越界行为。
- 已完成：添加来自本地值和字面量的 EVM IR 整体本地固定数组赋值，在写入目标元素之前将 RHS 元素快照到临时 Yul 本地变量中，并通过 `EvmArrayValueProbe` 黄金 Yul、元数据入口、solc 字节码和 Foundry 运行时检查验证本地源和自引用字面量 RHS 行为。
- 已完成：将 EVM IR 本地固定数组降级扩展到静态嵌套标量数组，包括不可变读取、可变叶节点赋值、数值叶节点复合赋值、嵌套整体本地赋值和 RHS 快照，包含 `EvmArrayValueProbe` 黄金 Yul、元数据入口、solc 字节码和 Foundry 运行时检查。扁平结构体嵌套叶节点由 `EvmStructArrayValueProbe` 覆盖；其他不支持的聚合叶节点保留为显式诊断。
- 已完成：将 EVM IR 本地固定数组降级扩展到动态嵌套标量数组索引，包括用于读取的嵌套 getter 辅助程序、用于可变叶节点赋值和复合赋值的嵌套 `switch` 降级、混合静态/动态路径覆盖、运行时越界 revert、`EvmArrayValueProbe` 黄金 Yul、元数据入口、solc 字节码和 Foundry 运行时检查。
- 已完成：为 `U64`、`U32`、`Bool` 和 `Hash` 字段添加 EVM IR 扁平不可变本地结构体值降级，支持直接结构体字面量字段访问，包含 `EvmStructValueProbe` 黄金 Yul、solc 字节码、Foundry 运行时验证、元数据能力验证，以及针对整体结构体存储误用和嵌套字段的显式诊断。
- 已完成：将 EVM IR 扁平本地结构体降级扩展到可变聚合本地变量，包括静态字段赋值、数值字段复合赋值，以及`U32`/`Bool`/`Hash` 字段写入，包含 `EvmStructValueProbe` 黄金 Yul、solc 字节码、Foundry 运行时验证、制品元数据入口验证、CI 覆盖率，以及针对不可变字段赋值的显式诊断。
- 已完成：添加 EVM IR 从局部变量和字面量进行整体局部结构体赋值的功能，在写入目标字段前将 RHS 字段快照到临时 Yul 局部变量中，并通过 `EvmStructValueProbe` 黄金 Yul、制品元数据入口、solc 字节码和 Foundry 运行时检查验证局部源和自引用字面量 RHS 行为。
- 已完成：添加 EVM IR 扁平结构体的局部固定数组，将每个元素字段展开为确定性的 Yul 局部变量，支持静态和动态 `field(arrayGet(localArray, index), name)` 读取、可变字段赋值、数值字段复合赋值、从局部数组和自引用数组字面量进行整体局部赋值（带 RHS 快照）、`U64`/`U32`/`Bool`/`Hash` 字段覆盖、动态越界回滚、`EvmStructArrayValueProbe` 黄金 Yul、制品元数据入口/能力验证、solc 字节码生成、Foundry 运行时检查以及 CI 覆盖。
- 已完成：将 EVM IR 嵌套局部固定数组扩展到扁平结构体叶节点，将每个嵌套元素字段展开为确定性的 Yul 局部变量，支持静态和动态嵌套字段读取、嵌套可变字段赋值、数值嵌套字段复合赋值、从局部数组和自引用嵌套数组字面量进行整体嵌套局部赋值（带 RHS 快照）、动态越界回滚、更新的 `EvmStructArrayValueProbe` 黄金 Yul、制品元数据入口验证、solc 字节码生成、Foundry 运行时检查以及覆盖率清单更新。
- 已完成：为标量存储结构体和扁平结构体的固定存储数组添加 EVM IR 扁平存储结构体降级，包括直接结构体字段副作用、标量 `field` 存储路径、数组 `index`+`field` 存储路径、数值字段复合赋值、带 RHS 快照的整体标量存储结构体读/写、存储后端支持的 ABI 结构体返回、`Bool`/`U32`/`Hash` 字段覆盖、`EvmStorageStructProbe` 黄金 Yul、solc 字节码、Foundry 运行时/原始插槽验证、制品元数据能力验证、CI 覆盖率，以及针对缺失字段和非扁平存储结构体的显式诊断。
- 已完成：通过在存储数组元素读取上使用 `return_values()` 扩展 `EvmStorageArrayProbe`，以及在固定存储结构体数组字段读取上使用 `return_points()` 扩展 `EvmStorageStructProbe`，来验证 EVM IR 的存储后端聚合 ABI 返回，包括黄金 Yul、solc 字节码、制品元数据选择器验证、Foundry ABI 解码和原始插槽检查。
- 已完成：为固定数组和结构体参数/返回添加 EVM IR 静态聚合 ABI 降级，包括嵌套标量固定数组和扁平结构体的固定数组，具有 calldata 字扁平化、`U32`/`Bool` 聚合字保护、多字返回数据编码、`EvmAbiAggregateProbe` 黄金 Yul、solc 字节码、Foundry 运行时/畸形 calldata 验证、制品元数据能力验证、结构化 `abi.entrypoints` 选择器/calldata/返回字布局验证、CI 覆盖率，以及针对 Unit、零长度数组、非扁平结构体字段和仅限 crosscall 的不支持嵌套固定数组叶形状的显式诊断。
- 已完成：填补 `Hash` 叶节点的 EVM 聚合 ABI 验证空白。`HashPair(bytes32,bytes32)`、`pick_hash(bytes32[2])` 和 `make_hash_array(bytes32,bytes32)` 现在证明 `Hash`/`bytes32` 字段和固定数组通过 calldata 和返回数据编码进行扁平化，包含黄金 Yul、制品元数据选择器检查、`solc`、Foundry ABI 解码和短 `bytes32[2]` calldata 拒绝。
- 已完成：为 SDK EVM 示例（`Counter`、`ArrayExample`、`SimpleToken`、`ERC20`、`Ownable`、`Pausable` 和 `VerifiedVault`）添加黄金 Yul 输出，并使 `scripts/evm/build-examples.sh` 在验证制品元数据之前将生成的 Yul 与这些固定装置进行 diff 比较。- 已完成：围绕当前的 `solc --strict-assembly` 流程，为 SDK 和可移植 IR EVM 字节码构建添加制品元数据发射与验证。
- 保留 Foundry 冒烟测试作为成熟的 EVM 冒烟测试。

验收标准：

- `lake build` 通过。
- `scripts/evm/diagnostic-smoke.sh` 通过。
- `scripts/evm/check-ir-coverage-manifest.py` 通过。
- `scripts/evm/build-examples.sh` 在装有 `solc` 的机器上成功运行。
- `scripts/evm/foundry-smoke.sh` 在装有 Foundry 的机器上成功运行。
- 生成的制品元数据指向字节码制品并记录 `target: evm`。

## 工作流 4：Wasm 宿主运行时拆分

目标：使 Wasm 宿主适配器由目标驱动，而不是假设每个 Wasm 合约都是 NEAR。

任务：

- 将链 extern 声明移出通用的 EmitZig 运行时 extern。
- 添加一个由目标选择的宿主桥接列表。
- 保留 NEAR 桥接作为参考实现。
- 添加一个带有分配器和 region ABI 的 CosmWasm 桥接骨架。

验收标准：

- Wasm 构建可以显式选择 NEAR 或 CosmWasm 桥接。
- 通用 Wasm 运行时不会强制链接 NEAR 宿主函数。
- `wasm-near` 和 `wasm-cosmwasm` 可以拥有不同的必需导出。

## 工作流 5：CosmWasm Spike

目标：证明 ProofForge 可以针对 NEAR 之外的其他 Wasm 宿主。

任务：

- 添加 `Lean.CosmWasm` SDK 骨架（参见 [wasm-family.md](targets/wasm-family.md)）。
- 添加 `zigc-cosmwasm` 包装器。
- 添加 `cosmwasm_contract_root.zig`。
- 导出 `interface_version_8`、`allocate`、`deallocate`、`instantiate`、`execute` 和 `query`。
- 添加使用 JSON 支持的消息的 Counter 示例。
- 添加 `cosmwasm-check` 冒烟测试。

验收标准：

- Counter Wasm 通过 `cosmwasm-check`。
- 导出中存在 `instantiate`、`execute` 和 `query`。
- 冒烟测试可以增加并查询计数器状态。

## 工作流 6：Solana sBPF 汇编工具链集成（阶段 0）

目标：端到端验证直接汇编路线 —— 预制的 `.s` 文件通过 blueshift-gg/sbpf 工具链往返转换为可加载的 ELF。取代旧的 sbpf-linker spike (D-026)。

任务：

- 通过 `cargo install --git https://github.com/blueshift-gg/sbpf.git` 安装 `sbpf`。
- 在 `proof-forge` 中添加 `--emit-sbpf-asm` CLI 模式，用于写入预制的 `entrypoint.s`（返回成功，无账户解析）。
- 在预制的 `.s` 上运行 `sbpf build`；验证是否生成了有效的 eBPF ELF。
- 验证 `sbpf disassemble` 对 ELF 进行往返转换。
- 在制品元数据中记录工具链版本。

验收标准：

- [x] `sbpf build` 生成被识别为 `ELF 64-bit LSB ... eBPF` 的 `.so`。
- [x] `sbpf disassemble` 生成与输入匹配的汇编。
- [x] `--emit-sbpf-asm` 写入有效的 `.s` 且无汇编错误。
- [x] `proof-forge-artifact.json` 记录 `target: "solana-sbpf-asm"`。
- [x] `sbpf` 通过 `cargo install` 安装到 PATH。

参考：[solana-sbpf-asm 设计文档](targets/solana-sbpf-asm.md)，[RFC 0005](rfcs/0005-solana-sbpf-assembly-backend.md)。

## 工作流 7：Solana sBPF 汇编 Counter 源代码生成（阶段 1）

目标：将可移植 IR Counter 模块降级为 sBPF 汇编并通过 `sbpf test`。这是汇编路线的第一个真实源代码生成后端。

任务：

- 实现 `ProofForge.Backend.Solana.StateLayout` —— 从指令清单计算每个账户的字段偏移量；发射 `.equ` 常量。
- 实现 `ProofForge.Backend.Solana.SbpfAsm` —— 将 `IR.Module` 降级为 `.s`：
  - 入口适配器：解析序列化的账户，根据指令判别式进行分发。
  - 账户验证：根据清单进行签名者、可写性、所有者检查。
  - 表达式降级：字面量、局部变量、加/减、比较、类型转换。
  - 语句降级：letBind、赋值、赋值操作、ifElse、返回、断言。
  - Effect 降级：在账户数据偏移处进行 storageScalar 读/写。
- 添加 `--solana-elf` CLI 模式：发射 `.s` 然后调用 `sbpf build`。
- 在生成 `.s` 的同时生成指令清单 (`manifest.toml`)。
- 创建 `Examples/Solana/Counter.lean` + 清单。
- 运行 `sbpf test` (Mollusk) 以及 Surfpool/Web3.js 实时部署冒烟测试。

验收标准：- Counter 场景（initialize、increment、get）通过 `sbpf test`。
- Surfpool/Web3.js 实时冒烟测试通过（可选，取决于工具可用性）。
- 能力检查器拒绝使用不支持能力的 IR 模块，并提供引用目标 id 和能力 id 的清晰诊断信息。
- 相同的可移植 IR Counter 模块可降级至 EVM 和 Solana。
- 制品元数据记录 `target: "solana-sbpf-asm"`、`irVersion`、入口以及所使用的能力。

范围外（阶段 2+）：maps、struct 类型、事件、有界循环、Borsh 序列化、完整的 SPL Token 数据布局、完整的实时 CPI 矩阵覆盖，以及 Rust/Pinocchio 等效性。CPI 和 PDA 保持 Solana 特定（D-027）：SDK 通过目标能力调用和 sBPF 辅助操作路由它们，而不是将它们添加到可移植 IR 中。

参考：[solana-sbpf-asm 设计文档](targets/solana-sbpf-asm.md) § 分阶段实施计划。

### 阶段 1 进展（增量子项）

工作流 7 阶段 1 后端（`ProofForge.Backend.Solana.SbpfAsm`）增量落地。每个子项都带有自己的可运行验证门禁，以便在完整验收标准关闭前看到阶段性进展：- [x] IR → sBPF AST → 文本流水线；入口适配器根据第一个指令数据字节进行分发 (V-GATE-SOLANA-01/02; Phase 0 基线)。
- [x] Counter 源代码生成 (字面量, 局部变量, `add`, 标量存储 读/写/`assignOp`, `letBind`/`letMutBind`, `assign`, `return`)；Mollusk 冒烟测试覆盖 initialize / increment 0→1 / increment 5→6 / get→return_data (V-GATE-SOLANA-03)。
- [x] 控制流 + 断言覆盖：比较表达式 (`.eq`/`.ne`/`.lt`/`.le`/`.gt`/`.ge`)，布尔表达式 (`.boolAnd`/`.boolOr`/`.boolNot`)，语句级 `.ifElse` then/else 降级（使用新命名的标签），`.assert` 和 `.assertEq` 降级到共享的 `assert_fail` (exit 2) / `assert_eq_fail` (exit 3) 标签。Fixture：`ProofForge.IR.Examples.ControlFlowAssertProbe` (三个入口：`lifecycle`, `guarded_increment`, `equality_guard`)；CLI 模式 `--emit-control-ir-sbpf`；确定性发射门控 `scripts/solana/emit-control-smoke.sh` (不需要 `sbpf`)；Mollusk 运行时门控 `scripts/solana/control-smoke.sh` (六项检查：生命周期 x2, guarded_increment 成功 + assert revert, equality_guard 成功 + assertEq revert) (V-GATE-SOLANA-08)。
- [x] 指令清单 (`manifest.toml`) 与 `.s` 一同生成。`ProofForge.Backend.Solana.SbpfAsm.renderManifest` 发射一个包含目标、程序占位符 id 以及每个入口指令表的 TOML，使用 Phase 1 默认账户约定 (writable, signer=false, owner=program)。`--emit-counter-ir-sbpf` 和 `--emit-control-ir-sbpf` 在 `.s` 旁边写入 `manifest.toml` 并将其作为制品包含在内。
- [x] `--solana-elf` CLI 模式：发射 `.s`，写入 `manifest.toml`，脚手架化一个 `sbpf` 项目，调用 `sbpf build`，将生成的 `.so` 复制到请求的输出，并在制品元数据中记录 `sbpfBuild: passed`。
- [x] 账户验证：根据清单进行 signer / writable / owner 检查。每个入口发射一个序言，在账户头部偏移量 10 处检查 `is_writable`，并验证账户所有者等于序列化的程序 id。失败退出码为 4 (`error_not_writable`), 5 (`error_signer`), 和 6 (`error_owner`)。Phase 1 Mollusk 运行时门控禁用了直接账户映射 ABI，因此演练了旧有的嵌入式账户数据布局。
- [x] `Examples/Solana/Counter.lean` + 清单作为一个自包含示例。包括一个被追踪的 `Counter.golden.s` 和 `Counter.manifest.toml`，以及一个可在 CI 运行的 `scripts/solana/build-examples.sh`，用于发射和对比差异。
- [x] 能力检查器拒绝不支持的能力/目标组合，并提供引用目标 id 和能力 id 的清晰诊断。作为 V-GATE-SOLANA-05 的基础；由 `Tests/SolanaDiagnostics.lean` 和 `scripts/solana/diagnostic-smoke.sh` 演练。
- [x] Solana SDK 目标扩展通过能力计划元数据路由 `ProofForge.Solana` PDA/CPI API，发射 `manifest.toml` 扩展定义以及入口操作部分，并在 IR 主体之前注入处理程序级辅助调用 (`sol_pda_derive_<name>`, `sol_cpi_<name>`)，同时在 `r1` 中保留 Solana 输入指针。由 `Tests/SolanaSdk.lean`, `Tests/SolanaSdkManifest.lean` 以及 `scripts/solana/sdk-smoke.sh`（在 `sbpf build` 可用时）覆盖。
- [x] Surfpool/Web3.js 现场部署冒烟测试 (V-GATE-SOLANA-04)。可选的 `scripts/solana/surfpool-web3-smoke.sh` 门控构建 Counter ELF，启动 Surfpool，使用 Solana CLI 进行部署，通过 `@solana/web3.js` 创建一个程序所有的 counter 账户，调用 initialize/increment/get，检查账户数据 0→1→2，并验证 `get` 返回数据。该脚本传递 `--solana-sbpf-arch v0` 以直接生成与 Solana CLI 部署兼容的 ELF，并为 Surfpool 使用 `--use-rpc`。
- [x] `--solana-elf` 暴露了 `--solana-sbpf-arch v0|v3` 并在 `proof-forge-artifact.json` 中记录所选架构。默认保持为 `v3`；Surfpool 现场部署使用 `v0`，直到部署的 CLI/运行时栈在没有 `--skip-feature-verify` 的情况下接受更新的 sbpf 特性集。- [x] PDA 辅助运行时打包现在在调用 `sol_create_program_address` 之前，发射静态 ASCII 种子字节缓冲区、Solana `Slice { ptr, len }` 种子表、动态 program-id 指针计算以及一个 32 字节 PDA 结果缓冲区。由 `Tests/SolanaSdkManifest.lean` 和 `scripts/solana/sdk-smoke.sh` 覆盖。
- [x] PDA 类型化种子降级现在保留兼容性 `seeds` 字段，同时为字面量/UTF-8 字节、账户公钥、bump 种子和标量指令数据种子添加面向目标的类型化描述符。Solana 目标扩展处理这些描述符，将 `bump?` 追加到有效系统调用种子列表，在 manifest/制品元数据中发射 `typed_seeds`/`typedSeeds`，并在存在 `account?` 时根据声明的账户验证派生的 PDA 公钥。由 `Tests/SolanaSdk.lean`、`Tests/SolanaSdkManifest.lean`、`Tests/SolanaPdaSeeds.lean`、`scripts/solana/sdk-smoke.sh` 和 `scripts/solana/pda-web3-smoke.sh` 覆盖。
- [x] 标准 Solana 协议 SDK 辅助程序现在涵盖系统程序 (System Program) 转账/创建账户以及 SPL Token transfer_checked/mint_to/burn/approve/revoke/set_authority。它们通过带有 `solana.cpi.protocol`、规范 `data_layout`、账户元数据、签名者种子和指令数据源名称的目标能力元数据进行路由，并包含在生成的 manifest 以及制品 JSON 中。由 `Tests/SolanaSdk.lean`、`Tests/SolanaSdkManifest.lean` 和 `scripts/solana/sdk-smoke.sh` 覆盖。
- [x] 运行时分配器目标扩展现在建模了 Solana 默认的向下 bump 分配器 (`heap_start = "0x300000000"`, `heap_bytes = 32768`)，以及一个与 Pinocchio 风格无堆入口一致的 `noAllocator`/deny-dynamic 选项。选定的分配器通过 `runtime.allocator` 能力元数据进行路由，并出现在 `manifest.toml`、`proof-forge-artifact.json` 和汇编元数据中。由 `Tests/SolanaAllocator.lean`、`Tests/SolanaSdk.lean`、`Tests/SolanaSdkManifest.lean` 和 `scripts/solana/sdk-smoke.sh` 覆盖。
- [x] 运行时内存目标扩展现在通过 `runtime.memory` 能力元数据路由仅限 Solana 的 SDK 操作，并将入口操作降级为基于生成的状态账户偏移量的 `sol_memcpy_`、`sol_memcmp_` 和 `sol_memset_` 辅助程序。生成的 manifest 和制品 JSON 记录了 `[[solana.entrypoint_memory]]` / `memoryActions`；Web3.js 在程序拥有的账户上验证复制的字节、比较结果和填充模式。由 `Tests/SolanaMemory.lean` 和 `scripts/solana/memory-web3-smoke.sh` 覆盖。
- [x] 返回数据和计算预算目标扩展现在通过 `runtime.return_data` 和 `runtime.compute_units` 能力元数据路由仅限 Solana 的 SDK 操作。返回数据操作将状态支持的字节切片降级为 `sol_set_return_data`，并可以通过 `sol_get_return_data` 读取最近的 CPI 返回数据缓冲区/程序 id；计算预算操作降级特性门控的 `sol_remaining_compute_units` 系统调用，并将观察到的剩余 CU 值写入状态，分析操作则降级 `sol_log_compute_units_`。生成的 manifest 记录了 `[[solana.entrypoint_return_data]]` 和 `[[solana.entrypoint_compute_units]]`。由 `Tests/SolanaReturnDataCompute.lean` 覆盖。
- [x] 生成的 Solana SDK 指令 schema 现在使用模块范围的多账户账户列表，而不是旧的单账户 manifest。该 schema 包含状态账户、PDA 账户、CPI 账户和可执行 CPI 程序账户，并且 sBPF 后端从该同一 schema 计算 `INSTRUCTION_DATA` 偏移量。生成的 prologue 根据 schema 验证签名者/可写约束和程序拥有的账户。账户列表在 `manifest.toml` 和 `proof-forge-artifact.json` 中均有发射。由 `Tests/SolanaSdkManifest.lean`、`Tests/SolanaCpiPacking.lean` 和 `scripts/solana/sdk-smoke.sh` 覆盖。
- [x] 系统程序 (System Program) 转账/创建账户和 SPL Token CPI 指令数据打包将标准指令字节发射到 C `SolInstruction` 负载中。系统转账/创建账户使用 bincode 风格的 `u32` 鉴别器以及 `u64` lamports/空间和所有者公钥字段；SPLToken `transfer_checked`、`mint_to`、`burn`、`approve` 和 `revoke` 使用标准代币指令标签和金额/精度布局，而 `set_authority` 封装了指令标签 `6`、权限类型 `MintTokens` 以及从只读输入账户获取的新权限公钥。值源可以绑定到生成的标量状态偏移量、数值字面量或解码后的标量入口参数。CPI 辅助程序还封装了程序 id 字节、绑定到生成的多账户输入布局的 C `SolAccountMeta[]`、`SolAccountInfo[]` 条目、签名者种子表以及系统调用寄存器设置。由 `Tests/SolanaCpiPacking.lean`、`Tests/SolanaSdkManifest.lean` 和 `scripts/solana/sdk-smoke.sh` 覆盖。
- [x] System Program transfer CPI 现在具有活跃的 Surfpool/Web3.js 行为门控。`ProofForge.Solana.Examples.SystemCpi` 构建了一个生成的 `--solana-system-cpi-elf` fixture，其入口读取标量 `lamports` 指令参数，执行 System Program transfer CPI，并将转账金额记录在程序拥有的状态账户中。`scripts/solana/system-cpi-web3-smoke.sh` 验证制品模式，使用 Solana CLI 在 Surfpool 上部署 ELF，通过 `@solana/web3.js` 调用它，并检查接收者的 lamport 增量和状态数据。sBPF 降级在直接账户映射下从序列化的账户布局计算指令数据指针，并将其保留在 `r9` 中，以便内部辅助程序调用不会在被调用者堆栈帧之间丢失它。覆盖范围：`just solana-system-cpi-web3` / V-GATE-SOLANA-10。
- [x] System Program `create_account` CPI 现在具有活跃的 Surfpool/Web3.js 行为门控。`ProofForge.Solana.Examples.SystemCreateAccountCpi` 构建了一个生成的 `--solana-system-create-account-cpi-elf` fixture，其入口读取标量 `lamports` 和 `space` 指令参数，使用付款人和新账户签名者执行 System Program `create_account` CPI，创建一个程序拥有的账户，并将这两个值记录在现有的程序拥有状态账户中。Web3.js 测试框架检查新账户所有者、数据长度、lamports 和记录的状态值。覆盖范围：`just solana-system-create-account-cpi-web3` / V-GATE-SOLANA-11。
- [x] SPL Token `transfer_checked` CPI 现在具有活跃的 Surfpool/Web3.js 行为门控。`ProofForge.Solana.Examples.SplTokenTransferCheckedCpi` 构建了一个生成的 `--solana-spl-token-transfer-cpi-elf` fixture，其入口读取标量 `amount` 指令参数，使用源权限签名者执行 SPL Token `transfer_checked` CPI，并将金额记录在程序拥有的状态中。Web3.js 测试框架通过 `@solana/spl-token` 创建一个代币铸造（mint）以及源/目标代币账户，检查代币余额增量，并检查状态记录。sBPF 降级现在在每个入口/辅助程序堆栈帧中构建一个运行时账户指针表，以便可变大小的 SPL Token 账户数据不会在内部辅助程序调用之间使账户偏移量失效。覆盖范围：`just solana-spl-token-transfer-cpi-web3` / V-GATE-SOLANA-12。
- [x] 入口指令数据解码现在将第 0 字节视为入口标签，并将来自 `instruction_data+1` 的封装标量参数解码到堆栈局部变量中。初始标量 ABI 支持 `U64`、`U32` 和 `Bool`，在 `manifest.toml`/`proof-forge-artifact.json` 中发射每个入口的参数模式和最小指令数据长度，使用 `error_instruction_data` 拒绝过短的有效载荷，并向 CPI 值绑定公开相同的固定输入偏移量，因此诸如 SPL Token `transfer_checked` 之类的 SDK 调用可以从用户指令参数而不是占位符中获取 `amount`。由 `Tests/SolanaCpiPacking.lean`、`Tests/SolanaSdkManifest.lean` 和 `scripts/solana/sdk-smoke.sh` 覆盖。

### Solana SDK 完成路线图

驱动此路线图的参考文档：- Solana CPI 和 PDA 文档：
  <https://solana.com/docs/core/cpi> 和
  <https://solana.com/docs/core/pda>。
- Anchor CPI/账户约束文档：
  <https://www.anchor-lang.com/docs/basics/cpi> 和
  <https://www.anchor-lang.com/docs/references/account-constraints>。
- Pinocchio 无依赖 / no-std 程序模型：
  <https://docs.rs/pinocchio> 和
  <https://github.com/anza-xyz/pinocchio>。

基准：截至 2026-07-02，Solana 路径具有直接的 sBPF 汇编发射、通过 Surfpool/Web3.js 进行的 Counter 部署、SDK 能力元数据、生成的 manifest/制品输出、模块范围的多账户 schema、标准 System/SPL Token CPI 数据打包、bump-allocator 元数据、标量入口参数解码、类型化 PDA seed 降级、实时 System Program transfer 加上 create-account CPI 验证、实时 SPL Token `transfer_checked` CPI 验证、实时 SPL Token `mint_to`/`burn`/`approve`/`revoke` CPI 验证、以及实时 SPL Token `set_authority` CPI 验证，加上通过 `sol_log_64_` 进行的实时标量 `events.emit` 日志验证、通过 `sol_log_pubkey` 进行的实时账户公钥日志验证、通过 `sol_log_data` 进行的实时状态支持的数据日志验证、以及针对 `contextRead checkpointId` 的实时 `Clock.slot` sysvar 验证，加上通过 `sol_memcpy_`、`sol_memmove_`、`sol_memcmp_` 和 `sol_memset_` 进行的实时 `runtime.memory` 验证，加上通过 `sol_sha256`、`sol_keccak256` 和特性门控的 `sol_blake3` 进行的实时仅限 Solana 的 `crypto.hash` 验证，加上通过 `sol_get_rent_sysvar` 进行的实时 `Rent.lamports_per_byte_year` sysvar 验证。
它还涵盖了通过 `sol_get_epoch_schedule_sysvar` 对所有当前 RPC 暴露的 `EpochSchedule` 字段进行的实时验证：`slots_per_epoch`、`leader_schedule_slot_offset`、`warmup`、`first_normal_epoch` 和 `first_normal_slot`，加上通过 `sol_get_epoch_rewards_sysvar` 对 `distribution_starting_block_height`、`num_partitions`、`parent_blockhash_word0..3`、`total_points_low/high`、`total_rewards`、`distributed_rewards` 和 `active` 进行的实时 `EpochRewards` 验证，加上通过具有 `SysvarLastRestartS1ot1111111111111111111111` sysvar id 的 `sol_get_sysvar` 进行的特性门控实时 `LastRestartSlot.last_restart_slot` 验证。实时 SDK 覆盖范围现在包括将 `runtime.return_data` 降级为 `sol_set_return_data` 和 `sol_get_return_data`，带有空读取、设置返回模拟以及同指令设置/获取往返检查，加上将 `runtime.compute_units` 降级为特性门控的 `sol_remaining_compute_units` 状态写入，以及通过 `sol_log_compute_units_` 进行的分析日志。
以下估算假设有一名工程师在该分支上工作，当前的直接汇编架构保持稳定，且本地 `sbpf`/Surfpool/Solana CLI 工具链保持可用。

| 级别 | 预计工作量 | 完成标准 |
|---|---:|---|
| SDK alpha：可用的 Solana 程序 | 3-5 个专注工程日 | 简单程序可以使用状态、PDA seed、标量指令参数、System Program CPI、SPL Token CPI、日志/返回数据，以及 Web3.js 行为测试，而无需手写汇编补丁。 |
| SDK beta：可参考对比的 Solana 后端 | 2-3 个专注周 | ProofForge 输出与相同账户 schema 的 Rust/Pinocchio 固定装置进行对比，涵盖关键系统调用，验证实时 CPI 行为，并支持每个入口的账户 schema。 |
| Anchor/Pinocchio 级别的开发者界面 | beta 之后 4-6 个专注周 | SDK 提供账户约束、类型化账户/数据辅助工具、IDL/客户端生成、更丰富的 SPL/Token-2022 覆盖范围，以及与框架级工作流相当的稳定诊断。 |

已完成的 alpha 切片：- 指令 ABI 加固：参数有效负载长度边界检查、`manifest.toml` 和 `proof-forge-artifact.json` 中每个入口的参数 schema，以及稳定的标量参数元数据现已就绪。
- PDA 类型化种子降级：`literalSeed`/`utf8Seed`、`accountSeed`、`bumpSeed` 和 `paramSeed` 描述符现在降级为 Solana 种子切片，`bump?` 参与有效种子列表，并且可以根据派生的公钥检查声明的 PDA 账户。
- PDA/Web3.js 派生 fixture：`scripts/solana/pda-web3-smoke.sh` 读取生成的 SDK Vault `typedSeeds` 制品数据，并根据 `PublicKey.findProgramAddressSync` 和 `PublicKey.createProgramAddressSync` 验证字面量/账户/bump 描述符语义；该测试框架还涵盖了 UTF-8 和指令参数解析器行为。
- 实时 System Program 转账 CPI fixture：`scripts/solana/system-cpi-web3-smoke.sh` 在 Surfpool 上构建并部署生成的转账 CPI 程序，通过 Web3.js 调用它，并证明 lamport 转移和状态写入。
- 实时 System Program 创建账户 CPI fixture：`scripts/solana/system-create-account-cpi-web3-smoke.sh` 在 Surfpool 上构建并部署生成的创建账户 CPI 程序，通过 Web3.js 调用它，并证明新账户的所有者/空间/lamport 以及状态写入。
- 实时 SPL Token transfer-checked CPI fixture：`scripts/solana/spl-token-transfer-cpi-web3-smoke.sh` 在 Surfpool 上构建并部署生成的 transfer_checked CPI 程序，使用 `@solana/spl-token` 创建 SPL Token 测试账户，通过 Web3.js 调用它，并证明源/目标代币余额增量以及状态写入。
- 实时 SPL Token 操作 CPI fixture：`scripts/solana/spl-token-ops-cpi-web3-smoke.sh` 在 Surfpool 上构建并部署生成的 `mint_to`/`burn`/`approve`/`revoke` CPI 程序，验证生成的四个入口制品 schema，使用 `@solana/spl-token` 创建 SPL Token 测试账户，通过 Web3.js 调用所有四个生成的入口，并证明供应量/余额/代理更改以及状态写入。
- 实时 SPL Token 权限 CPI fixture：`scripts/solana/spl-token-authority-cpi-web3-smoke.sh` 在 Surfpool 上构建并部署生成的 `set_authority` CPI 程序，验证生成的单入口制品 schema，通过 `@solana/spl-token` 创建 SPL Token mint，通过 Web3.js 调用生成的入口，并证明 mint 权限已转移到请求的新权限以及标记状态写入。
- 实时标量事件、公钥日志和数据日志 fixture：`scripts/solana/log-event-web3-smoke.sh` 在 Surfpool 上构建并部署生成的 `events.emit` 程序，通过 Web3.js 调用它，验证生成的 `sol_log_64_` 交易日志包含稳定的 `AmountEvent` 标签和标量 `amount` 字段，并证明程序拥有的状态账户记录了相同的值。同一 fixture 现在还验证仅限 Solana 的 `logAccountPubkey` 元数据，调用生成的 `log_state_pubkey` 入口，并证明 `sol_log_pubkey` 记录了状态账户的 base58 公钥。它还验证仅限 Solana 的 `logStateData` 元数据，调用 `log_state_data`，并证明 `sol_log_data` 为状态支持的 `amount` 字节发射 base64 `Program data:` 有效负载。
- 实时 Clock sysvar fixture：`scripts/solana/clock-sysvar-web3-smoke.sh` 在 Surfpool 上构建并部署生成的 `contextRead checkpointId` 程序，将其降级为 `sol_get_clock_sysvar`，通过 Web3.js 调用它，并证明记录的 `Clock.slot` 与观察到的交易槽匹配。
- 实时内存 syscall fixture：`scripts/solana/memory-web3-smoke.sh` 在 Surfpool 上构建并部署生成的 `runtime.memory` 程序，通过 Web3.js 调用它，并通过从程序拥有的状态中读取复制的值、移动的值、比较结果和填充字节来证明 `sol_memcpy_`、`sol_memmove_`、`sol_memcmp_` 和 `sol_memset_` 的效果。
- 返回数据/计算单元 SDK fixture：`Tests/SolanaReturnDataCompute.lean` 证明 `runtime.return_data` 和 `runtime.compute_units` 通过仅限 Solana 的能力元数据路由，在 EVM 上拒绝，并为 `sol_set_return_data`、`sol_get_return_data`、受特性门控的 `sol_remaining_compute_units` 和 `sol_log_compute_units_` 渲染 manifest 章节以及 sBPF 辅助调用。`scripts/solana/return-data-compute-web3-smoke.sh` 构建并部署生成的 `--solana-return-data-compute-elf` fixture 在 Surfpool 上，验证制品 action 元数据，验证无数据的 `sol_get_return_data` 读取，通过 Web3.js 模拟 returnData 确认 `sol_set_return_data`，检查包含 program id 字的同指令 set/get 往返过程，记录一个非零的 remaining-compute-units 值，并确认 compute-unit 日志记录。
- 实时 SHA-256/Keccak-256/Blake3 syscall fixture：`scripts/solana/crypto-hash-web3-smoke.sh` 在 Surfpool 上构建并部署一个生成的仅限 Solana 的 `crypto.hash` 程序，通过 Web3.js 调用 `set_preimage`、`hash_preimage`、`keccak_preimage` 和 `blake3_preimage`，并证明账户存储的 32 字节摘要与相同小端序原像的 Node SHA-256 和 `@noble/hashes` Keccak-256/Blake3 参考值匹配。Blake3 action 在 manifest 和制品元数据中被记录为 feature-gated。
- 实时 Rent sysvar fixture：`scripts/solana/rent-sysvar-web3-smoke.sh` 在 Surfpool 上构建并部署一个生成的仅限 Solana 的 `sysvar` 目标扩展程序，通过 Web3.js 调用 `record_rent`，并证明记录的 `Rent.lamports_per_byte_year` 与 Rent sysvar 账户数据匹配。
- 实时 EpochSchedule sysvar fixture：`scripts/solana/epoch-schedule-sysvar-web3-smoke.sh` 在 Surfpool 上构建并部署一个生成的仅限 Solana 的 `sysvar` 目标扩展程序，通过 Web3.js 调用 `record_epoch_schedule`，并证明记录的 `EpochSchedule.slots_per_epoch`、`EpochSchedule.leader_schedule_slot_offset`、`EpochSchedule.warmup`、`EpochSchedule.first_normal_epoch` 和 `EpochSchedule.first_normal_slot` 与 RPC `getEpochSchedule()` 字段匹配。
- 实时 EpochRewards sysvar fixture：`scripts/solana/epoch-rewards-sysvar-web3-smoke.sh` 在 Surfpool 上构建并部署一个生成的仅限 Solana 的 `sysvar` 目标扩展程序，通过 Web3.js 调用 `record_epoch_rewards`，并证明 `sol_get_epoch_rewards_sysvar` 将 `EpochRewards` 字段记录到状态中。在可移植标量层拥有第一类宽值输出状态之前，`parent_blockhash` 被暴露为四个小端序 `u64` 字视图，`total_points` 被暴露为低/高 `u64` 字视图。
- 实时 LastRestartSlot sysvar fixture：`scripts/solana/last-restart-slot-sysvar-web3-smoke.sh` 在 Surfpool 上构建并部署一个生成的仅限 Solana 的 `sysvar` 目标扩展程序，通过 Web3.js 调用 `record_last_restart_slot`，并证明受 feature-gated 限制的 `LastRestartSlot.last_restart_slot` 读取通过 `sol_get_sysvar` 降级，并与 LastRestartSlot sysvar 账户数据匹配。该 action 在 manifest 和制品元数据中被标记为 `feature_gated`。

已完成的 beta scaffolding 分片：- Pinocchio System transfer 参考合约：
  `references/solana/pinocchio/system-transfer` 包含一个已检入的无分配器 Pinocchio 参考，用于与 `ProofForge.Solana.Examples.SystemCpi` 相同的 System transfer 账户 schema。gate `scripts/solana/pinocchio-system-transfer-equivalence.sh` 发射 ProofForge System CPI 制品，并将其指令标签、参数 ABI、账户顺序、签名者/可写约束、CPI 协议/数据布局以及状态写入合约与参考清单/源代码进行比较。
- Pinocchio System transfer 实时等效性测试框架：
  `scripts/solana/pinocchio-system-transfer-live-equivalence.sh` 被配置为构建 ProofForge ELF 和已检入的 Pinocchio 参考 ELF，将这两个程序部署到一个 Surfpool 实例，为每个程序调用相同的 Web3.js transfer 场景，并比较接收者的 lamport 增量以及状态写入。当 `cargo-build-sbf` 找不到 Solana rustc/platform-tools 时，该测试框架目前会跳过。
- Pinocchio System create-account 参考合约：
  `references/solana/pinocchio/system-create-account` 包含一个已检入的无分配器 Pinocchio 参考，用于与 `ProofForge.Solana.Examples.SystemCreateAccountCpi` 相同的 System Program `create_account` 账户 schema。gate `scripts/solana/pinocchio-system-create-account-equivalence.sh` 发射 ProofForge create-account CPI 制品，并将其指令标签、双参数 ABI、账户顺序、签名者/可写约束、CPI 协议/数据布局、lamports/space/owner 合约以及双字段状态写入合约与参考清单/源代码进行比较。通过 `PROOF_FORGE_PINOCCHIO_CARGO_CHECK=1`，同一个 gate 会根据 `pinocchio-system` 对参考进行类型检查。
- Pinocchio System create-account 实时等效性测试框架：
  `scripts/solana/pinocchio-system-create-account-live-equivalence.sh` 被配置为构建 ProofForge ELF 和已检入的 Pinocchio 参考 ELF，将这两个程序部署到一个 Surfpool 实例，为每个程序调用相同的 Web3.js create-account 场景，并比较 lamports/space 输入以及两者的状态写入。当 `cargo-build-sbf` 找不到 Solana rustc/platform-tools 时，该测试框架目前会跳过。
- Pinocchio SPL Token transfer 参考合约：
  `references/solana/pinocchio/spl-token-transfer` 包含一个已检入的无分配器 Pinocchio 参考，用于与 `ProofForge.Solana.Examples.SplTokenTransferCheckedCpi` 相同的 SPL Token `transfer_checked` 账户 schema。gate `scripts/solana/pinocchio-spl-token-transfer-equivalence.sh` 发射 ProofForge SPL Token CPI 制品，并将其指令标签、参数 ABI、账户顺序、签名者/可写约束、CPI 协议/数据布局、decimals/amount 合约以及状态写入合约与参考清单/源代码进行比较。通过 `PROOF_FORGE_PINOCCHIO_CARGO_CHECK=1`，同一个 gate 会根据 `pinocchio-token` 对参考进行类型检查。
- Pinocchio SPL Token transfer 实时等效性测试框架：
  `scripts/solana/pinocchio-spl-token-transfer-live-equivalence.sh` 被配置为构建 ProofForge ELF 和已检入的 Pinocchio Token 参考 ELF，将这两个程序部署到一个 Surfpool 实例，为每个程序调用相同的 Web3.js + `@solana/spl-token` transfer_checked 场景，并比较源/目标代币余额增量以及 amount 状态写入。当 `cargo-build-sbf` 找不到 Solana rustc/platform-tools 时，该测试框架目前会跳过。
- Pinocchio SPL Token ops 参考合约：
  `references/solana/pinocchio/spl-token-ops` 包含一个已检入的无分配器 Pinocchio 参考，用于与 `ProofForge.Solana.Examples.SplTokenOpsCpi` 相同的 SPL Token `mint_to`/`burn`/`approve`/`revoke` 账户 schema。gate `scripts/solana/pinocchio-spl-token-ops-equivalence.sh` 发射 ProofForge SPL Token ops CPI 制品，并将其四个指令标签、参数 ABI、账户顺序、签名者/可写约束、CPI 协议/数据布局、SPL Token 指令合约以及状态写入合约与参考清单/源代码进行比较。通过 `PROOF_FORGE_PINOCCHIO_CARGO_CHECK=1`，同一个 gate 会根据 `pinocchio-token` 对参考进行类型检查。
- Pinocchio SPL Token ops 实时等效性测试框架：
  `scripts/solana/pinocchio-spl-token-ops-live-equivalence.sh` 被配置为构建 ProofForge ELF 和已检入的 Pinocchio Token ops 参考 ELF，将这两个程序部署到一个 Surfpool 实例，为每个程序调用相同的 Web3.js + `@solana/spl-token` mint/burn/approve/revoke 场景，并比较代币影响以及所有四个 amount/marker 状态写入。当 `cargo-build-sbf` 找不到 Solana rustc/platform-tools 时，该测试框架目前会跳过。- Pinocchio SPL Token 权限引用合约：
  `references/solana/pinocchio/spl-token-authority` 包含一个已签入的 no-allocator Pinocchio 引用，其针对与 `ProofForge.Solana.Examples.SplTokenAuthorityCpi` 相同的 SPL Token `set_authority` 账户 schema。gate `scripts/solana/pinocchio-spl-token-authority-equivalence.sh` 发射 ProofForge SPL Token 权限 CPI 制品，并将其指令 ABI、账户顺序、签名者/可写约束、CPI 协议/数据布局、`SetAuthority` 指令合约以及标记状态写入合约与引用清单/源码进行对比。通过 `PROOF_FORGE_PINOCCHIO_CARGO_CHECK=1`，同一个 gate 会针对 `pinocchio-token` 对该引用进行类型检查。
- Pinocchio SPL Token 权限实时等效性 harness：
  `scripts/solana/pinocchio-spl-token-authority-live-equivalence.sh` 被配置为构建 ProofForge ELF 和已签入的 Pinocchio Token 权限引用 ELF，将这两个程序部署到一个 Surfpool 实例，为每个程序调用相同的 Web3.js + `@solana/spl-token` 铸币权限转移场景，并比较铸币权限以及标记状态的写入。当 `cargo-build-sbf` 找不到 Solana rustc/platform-tools 时，该 harness 目前会跳过。

已完成的开发者层面切片：- 可移植 ValueVault 表面源代码：
  `ProofForge.Contract.Surface` 现在允许示例仅声明一次状态槽位、参数、方法和事件字段，然后通过类型化引用（`read`、`write`、`bind`、`emit`、`ret`）编写入口主体，而不是原始的 `ContractSpec` 字符串管道。`ProofForge.Contract.Examples.ValueVault` 使用此层，并有意在源代码中保留 `selector? = none`。
- 声明派生的 IR 名称：
  `state_decl`、`binding_decl`、`method_decl`、`method_return_decl` 和 `event_decl` 宏现在从 Lean 声明中派生 IR 名称，因此可移植 Counter 和 ValueVault 源代码不再为状态槽位、输入、局部变量、方法名称或事件名称重复原始字符串。测试在跨 EVM 和 Solana 路由相同源代码之前，断言派生的蛇形命名（snake-case）状态/参数/方法名称和帕斯卡命名（PascalCase）事件名称。
- 面向源代码的声明外观：
  `contract_decl Name do ...` 从 Lean 标识符派生模块名称，并将 `ContractSpec` 保留为编译器拥有的中间产物，而不是用户可见的编写模型。`ProofForge.Contract.Examples.Counter` 和 `ProofForge.Contract.Examples.ValueVault` 现在使用此外观；较旧的 `*_ref` 宏仍作为旧下游源代码的兼容性垫片（shims）。
- 合约源代码语法 v1：
  `ProofForge.Contract.Source` 为状态声明、事件、入口、查询、源本地绑定、状态赋值、事件发射、返回、类型化算术运算符以及用于分配器（allocator）、账户、PDA 派生和 SPL Token CPI 调用的 Solana 扩展声明添加了作用域 `contract_source` 语法。
  `ProofForge.Contract.Examples.Counter` 和 `ProofForge.Contract.Examples.ValueVault` 现在通过此源代码块编写可移植逻辑，同时宏发射用于路由、EVM 选择器填充、Solana 指令标签、IDL 和客户端制品生成的相同 `ContractSpec`/可移植 IR 边界。
- 遗留 `.learn` 解析器/降级种子：
  `ProofForge.Contract.Learn` 现在将 `Examples/Learn/` 下检入的 `.learn` 文件词法分析并解析为可移植标量/事件子集的微型源代码 AST，将该 AST 降级为 `ContractSpec`/可移植 IR，并作为兼容性验证入口而非新产品源代码语言。主要的编写表面仍然是 Lean `.lean` 文件和 Lean SDK 辅助程序。它证明了 `Counter.learn` 和 `ValueVault.learn` 产生与当前 `contract_source` 示例相同的 IR 模块。CLI 仍通过 `--learn --target evm` 和 `--learn --target solana-sbpf-asm` 接受 `.learn` 文件，并保留 `--learn-yul`、`--learn-bytecode` 和 `--learn-sbpf` 作为低层级兼容性便利路径。
  `scripts/portable/value-vault-smoke.sh` 使用 `Examples/Learn/ValueVault.learn` 作为遗留等效性固件，并证明兼容性入口可以路由到 EVM Yul/字节码元数据和 Solana sBPF 汇编/清单/IDL/客户端制品，而无需手动编写 `ContractSpec`。
- Learn Solana 目标扩展语法：
  `ProofForge.Contract.Learn` 现在解析用于 `solana allocator`、`solana account`、`solana pda`、`solana cpi ... spl_token_transfer_checked(...)`, and entry-level `solana derive` / `solana invoke` 的 `SolanaVault.learn` 形式。降级重用了 `ProofForge.Solana` 构建器辅助程序，因此账户/PDA/CPI 元数据仍流经现有的能力计划、清单、IDL、客户端和 sBPF 汇编路径。`Tests/LearnSource.lean` 检查 Learn 降级的 SolanaVault 是否具有与 `ProofForge.Solana.Examples.Vault` 相同的 IR 模块和生成的清单。
- Learn System Program CPI 语法：
  `SystemCpi.learn` 和 `SystemCreateAccountCpi.learn` 现在涵盖了 `solana cpi ... system_transfer(...)`、`solana cpi ... system_create_account(...) owner ...` 以及匹配的入口级 `solana invoke` 语句。`Tests/LearnSource.lean` 证明两个 Learn 文件都降级为与现有 `ProofForge.Solana.Examples.SystemCpi` 和 `ProofForge.Solana.Examples.SystemCreateAccountCpi` 源代码示例相同的 IR 模块和生成的清单。
- Learn SPL Token 操作语法：
  `SplTokenOpsCpi.learn` 现在涵盖了带有选择器的 Learn 入口以及 `spl_token_mint_to`、`spl_token_burn`、`spl_token_approve` 和 `spl_token_revoke` 声明/调用。`Tests/LearnSource.lean` 证明 Learn 文件降级为与相同的 IR 模块和生成的清单。`ProofForge.Solana.Examples.SplTokenOpsCpi`，将字符串密集的 Builder 代码保留为内部预期的 fixture，而不是面向用户的语法。
- Learn log/return-data/compute-unit 语法：
  `LogEvent.learn` 和 `ReturnDataCompute.learn` 现在涵盖了 Solana pubkey/data
  日志辅助语句、return-data set/get 语句以及剩余的
  compute-unit 读取/日志语句。`Tests/LearnSource.lean` 证明了这两个 Learn
  文件降级为与 `ProofForge.Solana.Examples.LogEvent` 和
  `ProofForge.Solana.Examples.ReturnDataCompute` 相同的 IR 模块和生成的 manifest，
  将另一个面向 syscall 的 SDK 切片从仅限 Builder 的 fixture 移至面向用户的 Learn 源代码中。
- Learn memory/crypto/sysvar 语法：
  `Memory.learn`、`Crypto.learn`、`Rent.learn`、`EpochSchedule.learn`、
  `EpochRewards.learn`、`LastRestartSlot.learn` 和 `Clock.learn` 现在涵盖了
  面向用户的 Learn 源代码中的 Solana 内存辅助函数、SHA-256/Keccak-256/BLAKE3 辅助函数以及
  sysvar/context 读取。`Tests/LearnSource.lean`
  证明了这些 Learn 文件降级为与相应 `ProofForge.Solana.Examples.*` fixture 相同的 IR 模块和生成的
  manifest。
- Learn 引用诊断：
  `ProofForge.Contract.Learn` 现在在降级时构建声明引用索引，
  并拒绝未知或不匹配的 Solana CPI 调用、未知
  PDA 派生、无效的 signer seed、使用未声明
  账户的 CPI 声明、不满足要求的可写或
  signer 约束的 CPI 账户声明，以及引用未声明
  状态/账户名称的辅助语句。`Tests/LearnDiagnostics.lean` 固定了这些消息，使
  Learn 的行为类似于经过检查的语言前端，而不是要求用户
  手动编写未经检查的 `ContractSpec` 数据。
- Solana 类型化账户表面：
  `ProofForge.Solana.Surface` 现在增加了 `account_ref`、`pda_ref` 和 `cpi_ref`
  声明，以及类型化 PDA seed、账户约束和 SPL/System CPI
  辅助函数。`ProofForge.Solana.Examples.Vault` 现在使用专用的
  `contract_source` 项，例如 `allocator bump`、`account ... writable`、
  `pda ... seeds [...]`、`cpi ... spl_token_transfer_checked(...)`、`derive
  pda ...`, `invoke ... spl_token_transfer_checked(...)`，并且相同的
  一等源代码语法路径现在涵盖了 `spl_token_set_authority(...)`，
  而不是原始账户/PDA/CPI 字符串或 `use`/`do` 辅助管道。
  目标扩展将声明的账户约束发射到 `manifest.toml`、
  `proof-forge-artifact.json` (`solanaExtensions.accounts`) 以及生成的
  账户验证模式中。
- System create-account 源代码语法：
  `ProofForge.Contract.Source` 现在公开了源代码级的
  `cpi ... system_create_account(...) owner ...` 和
  `invoke ... system_create_account(...) owner ...` 形式。
  `ProofForge.Solana.Examples.SystemCreateAccountCpi` 使用这些形式
  而不是低级 builder API，同时保留现有的生成
  汇编、manifest、制品以及 Surfpool/Web3.js 行为门控。
- SPL Token authority 源代码语法：
  `ProofForge.Contract.Source` 现在公开了源代码级的
  `cpi ... spl_token_set_authority(...) authority_type(...) signer_seeds [...]`
  和 `invoke ... spl_token_set_authority(...) authority_type(...) signer_seeds
  [...]` forms. `ProofForge.Solana.Examples.SplTokenAuthorityCpi` 在一个 Lean `.lean` fixture 中使用这些
  形式，并且生成的制品、Surfpool/Web3.js
  行为门控和 Pinocchio 引用门控都验证了相同的降级
  边界。
- 目标阶段 ABI 选择器水合：
  Learn/ValueVault CLI 发射路径在 EVM
  Yul/字节码发射前立即通过 `cast sig` 从每个入口的 Solidity ABI 签名中派生 EVM 选择器，根据派生
  值验证任何显式选择器，并通过继续使用目标
  指令标签保持 Solana 路由独立。`scripts/portable/value-vault-smoke.sh` 证明相同的
  `.learn` 源代码发射 EVM Yul/字节码元数据以及 Solana sBPF
  汇编/manifest/制品元数据。
- Solana IDL 和 TypeScript 客户端包输出：
  `ProofForge.Backend.Solana.Idl` 从 `manifest.toml` 和制品
  元数据使用的相同指令/账户/PDA/CPI 模式渲染 `proof-forge-idl.json`。`ProofForge.Backend.Solana.Client` 渲染
  `proof-forge-client.ts`，包含 Web3.js `TransactionInstruction` 辅助函数、
  指令数据编码和账户元数据构建。Solana 包
  打印、`--emit-solana-sdk-sbpf`、`--emit-value-vault-ir-sbpf` 以及
  Solana ELF contract-sdk 路径现在发射并哈希这两个文件。

当前边界：- `ProofForge.Contract.Learn` 现在是一个遗留的 `.learn` 兼容性解析器/降级种子，而不是一种新的产品源语言。它涵盖了可移植的 Counter/ValueVault 子集，以及 Vault 级别的 Solana 账户/PDA/SPL Token 转账 CPI 子集、System Program 转账/创建账户 CPI、SPL Token 铸造/销毁/批准/撤销 CPI，以及 Solana 日志/返回数据/计算单元/内存/加密/sysvar 辅助语句。在降级过程中，Solana CPI/PDA 声明和入口辅助语句会针对声明的引用进行交叉检查。CPI 账户操作数必须使用 `solana account ...` 声明；CPI 的可写/签名者要求会根据这些声明进行检查，因此剩余的字符串名称是编译器拥有的标识符，而不是未经检查的用户编写的规范。`ProofForge.Contract.Source` 和 Lean SDK 辅助工具仍然是主要的编写前端；`.learn` 文件仅作为遗留兼容性和等效性固件保留，通过编译时目标 id 复用相同的降级边界。下一个编写差距是将 Lean `.lean` 界面扩展到 Token-2022、类型化账户/数据引用以及更丰富的 Pinocchio 风格账户验证人体工程学；遗留的 `--learn` 包发射不是新语法工作的方向。

剩余优先级切片：

1. Rust/Pinocchio 等效性固件（2-4 天）：通过可靠地安装 Solana rustc/platform-tools，使 Pinocchio 实时等效性测试框架在 CI/本地环境中通过，然后将静态和实时引用覆盖范围扩展到 Token-2022 以及除已检查的转账/铸造/销毁/批准/撤销/设置权限集之外的剩余 SPL 辅助路径。关键对比点是账户顺序、签名者/可写检查、CPI 指令数据以及可观察的状态变化。
2. 更丰富的结构化日志、账户数据和类型化返回辅助工具（3-5 天）：将当前的标量 `sol_log_64_`/`sol_log_data` 事件路径扩展到字符串日志、Anchor 风格的鉴别器/Borsh 负载以及索引事件形式；添加除 `u64` 之外的类型化返回负载辅助工具、哈希语义与目标匹配的可移植 `Expr.hash` 路由，以及复用新内存/syscall 路径的更广泛的账户/数据打包辅助工具，并带有 JavaScript 引用检查。
3. 运行时分配降级（1-2 天）：通过 `runtime.allocator` 路由堆支持的 SDK 结构，在需要时发射实际的向下增长的碰撞指针（bump-pointer）分配代码，并在 `noAllocator` 下拒绝使用分配的结构。
4. 动态每个入口账户架构（3-5 天）：在分派之前用运行时账户解析替换当前的模块级固定架构，使指令数据偏移量不再依赖于每个入口共享相同的账户列表。
5. Token-2022 和更丰富的 SPL 覆盖（每次迭代 3-5 天）：添加经过检查的 Token-2022 扩展路由、关联代币账户设置流程，以及除已涵盖的铸造权限 `set_authority` 路径之外的剩余 SPL 变体，而无需将这些细节移入可移植 IR。
6. 开发者人体工程学和框架界面（每次迭代 3-5 天）：将新的界面层扩展到 Lean `.lean`/Lean SDK 合约语法，提供更丰富的类型化账户/数据包装器、更丰富的生成的客户端 API、更广泛的 SPL/Token-2022 辅助工具覆盖，以及将生成的汇编失败映射回 SDK 声明的诊断。

因此，通往更完整 SDK 的最快可靠路径是：alpha 可观察性基线现已就绪，接下来完成更丰富的 beta syscall 和返回数据切片，然后在添加 Anchor/Pinocchio 级人体工程学之前移除剩余的架构捷径。

## 工作流 8：Move 源代码生成 POC（Aptos 优先）

目标：避免假装 Move 是另一个 Lean 运行时目标。

任务：- 定义可移植 IR 的 Move 兼容子集。
- 生成一个 **Aptos** Move 计数器包（Sui 将在后续切片中跟进）。
- 运行 `aptos move compile/test`。
- 记录必须反馈到 IR 设计中的验证器限制。

验收标准：

- 生成的 Aptos Move 源代码可编译。
- 生成的包包含测试。
- 不支持的 Lean 结构在源代码生成前失败。
- 后续 Sui 对象 POC 被记录为一个独立的里程碑。

## 工作流 9：CI 扩展

参见 [validation-gates.md](validation-gates.md) 了解当前和计划中的验证命令。

目标：在第一天不要求安装所有外部链工具的情况下，保持 CI 的实用性。

任务：

- 将 `lake build` 保留为常驻 CI。
- 仅在 `solc` 和 Foundry 可用时添加 EVM 冒烟测试。
- 为 CosmWasm、Solana 和 Move 添加带有明确工具检查的可选作业。
- 将制品元数据验证添加为独立于工具的作业。

验收标准：

- 基础 CI 不会因为缺少可选链工具而失败。
- 当工具链存在但目标构建失败时，特定目标的 CI 作业会显式报错。
- 元数据 Schema 验证在没有链工具的情况下运行。

## 工作流 10：Psy DPN ZK 目标 spike

目标：在不将 ProofForge 与 Psy 编译器内部机制耦合的情况下，验证 ZK 电路源代码生成目标。

任务：- 已完成：从可移植 IR fixture 生成一个 Counter `.psy` 源文件。
- 已完成：在 `scripts/psy/counter-smoke.sh` 中添加一个临时的 Dargo 包生成器。
- 已完成：将 `dargo test --file` 记录为第一个本地冒烟测试运行器。
- 已完成：使用 `psyup` v0.1.0 macOS arm64 工具链运行 `dargo compile` 并捕获 DPN 电路 JSON。
- 已完成：作为本地用户/合约会话运行 `dargo execute`，并断言两次递增后的 Counter 结果。
- 已完成：调用 `dargo generate-abi` 并捕获非空 ABI JSON。
- 已完成：为 Psy 冒烟测试制品发射带有目标 id `psy-dpn` 的 `proof-forge-artifact.json`。
- 已完成：添加 ContextProbe 作为非 Counter fixture，用于参数降级和上下文读取。
- 已完成：为 `Hash`、类型化哈希 let-绑定、`hash` 和 `hash_two_to_one` 添加 HashProbe，与上游 Psy 哈希测试保持一致。
- 已完成：验证 Psy 制品元数据，包括哈希、字节大小、能力、验证标志和预期执行结果。
- 已完成：从上游 `psy-compiler/tests` 和 `psy-precompiles` 语料库中添加 map/storage-map、断言、有界循环 (bounded-loop)、数组、结构体、聚合 ABI、嵌套聚合、存储嵌套聚合、U32 算术和位运算覆盖。
- 已完成：从上游 `psy-precompiles` 语料库中为本地数组和 ABI 参数添加 U32/Hash limb 打包 (limb packing) 覆盖。
- 已完成：为所有基于 Dargo 的 Psy 冒烟测试编译输出发射并验证 ProofForge 部署清单。
- 已完成：通过 Dargo 编译/执行验证，为 `Map<Hash, Hash, N>` 添加 map 存储路径覆盖。
- 已完成：为上游 map 边界语义添加表达式位置 `storageMapSet` 降级和 MapProbe 覆盖，其中 `set` 和重复的 `insert` 返回前一个 `Hash` 值。
- 已完成：通过 Dargo 编译/执行验证，为标量存储和通用存储路径添加存储引用复合赋值覆盖。
- 已完成：通过 Dargo 编译/执行验证，使用 Psy `pub value: u32` 存储加上标量 `+=` 赋值，添加原生 U32 标量存储覆盖。
- 已完成：通过 Dargo 编译/执行验证，使用 Psy `pub flag: bool` 存储加上 `bool as Felt` 返回类型转换 (return casts)，添加原生 Bool 标量存储覆盖。
- 已完成：通过 Dargo 编译/执行验证，使用 Psy `[bool; N]` 字面量/索引加上 `pub flags: [bool; N]` 存储，添加原生 Bool 固定长度数组和存储数组覆盖。
- 已完成：通过 Dargo 编译/执行验证，使用 Psy `pub root: Hash` 和 `pub roots: [Hash; N]` 添加原生 Hash 标量和存储数组覆盖。
- 已完成：通过 Dargo 编译/执行验证，在 `[Felt; N]` 局部变量上使用 Psy `assert_eq`、`==` 和 `!=` 添加固定长度数组相等性覆盖。
- 已完成：通过 Dargo 编译/执行验证，使用基于 Felt 的存储加上显式 U32 读/写类型转换，添加 U32 存储数组覆盖。
- 已完成：通过 Dargo 编译/执行验证，将基于 Felt 的 U32 存储数组路径复合赋值降级为显式读/更新/写类型转换。
- 已完成：通过 Dargo 编译/执行验证，添加原生 U32 存储结构体字段路径写入、读取和复合赋值覆盖。
- 已完成：添加 Psy IR 覆盖率清单门控，使得每个可移植 IR 构造函数必须被分类为 Psy 后端的已降级、已验证、不支持或结构化。
- 已完成：将 Dargo 冒烟测试包生成重构为共享写入器，以便每个 Psy 冒烟测试在元数据验证之前创建相同的 `src/main.psy` 和 `Dargo.toml` 布局。
- 已完成：允许在 Psy 后端中使用 EVM 风格的入口选择器作为特定于目标的 ABI 元数据；Psy 源代码生成仅使用方法名，并可能在制品元数据中记录选择器以实现跨目标可追溯性。
- 已完成：在源代码生成之前验证 Psy 标识符和重复声明，以免无效名称导致 Dargo 解析器/类型检查器失败。
- 已完成：为没有特定于 fixture 断言的有效 Psy IR 模块添加通用的生成测试回退机制，由 `GenericEntrypointProbe` 支持。黄金源代码、Dargo 编译/执行验证、ABI 生成、部署 manifest 生成以及制品元数据验证。
- 一旦 Psy 工具链暴露了稳定的边界，就将部署 manifest 路径转换为上游压缩的 genesis 部署 JSON，然后执行本地节点/证明器部署冒烟测试。
- 一旦工具链暴露了稳定值，就记录 Dargo/Psy 编译器版本或 commit。

验收标准：

- 生成的 `.psy` 源代码是可读的，并已检入黄金 fixture 或快照。
- `dargo compile` 在装有 Psy 工具链的机器上产生非空的 JSON 制品。
- `dargo execute` 为 Counter 生命周期返回 `result_vm: [2]`。
- `dargo execute` 为 ContextProbe 的 `sum_context(2,3)` 生命周期返回 `result_vm: [15]`。
- `dargo execute` 为 HashProbe 的 `poseidon_hash` 和 `poseidon_pair_hash` 入口返回确定的四 Felt 输出。
- `dargo generate-abi` 产生非空的 ABI JSON 制品。
- `dargo execute` 为通用的非白名单 `GenericEntrypointProbe` 返回 `result_vm: [42]`。
- 制品元数据记录目标 id、fixture id、已使用的能力、制品路径、哈希、字节大小、Dargo 包源代码副本、Dargo 包 manifest 以及验证状态。
- 制品元数据由 Psy 冒烟测试脚本进行机器验证。
- 制品元数据在可用时记录 Dargo/Psy 编译器版本或 commit。
- 不支持的非电路友好型 IR 节点在源代码生成之前失败。
- CI 要么固定一个已知良好的 `psyup` 版本，要么在匹配的工具链 tarball 不可用时明确跳过此关卡。

## 工作流 11：Kaspa Toccata Research 目标

目标：决定 ProofForge 是否以及如何支持 Kaspa 的 Toccata 可编程性堆栈，而不将其伪装成 EVM、账户状态或通用的 ZK 电路目标。

任务：

- 已完成：为候选目标 id `kaspa-toccata` 添加文档优先的目标说明。
- 将该目标归类为 UTXO covenant/based-app 研究，而非 `zk-circuit-sourcegen`。
- 审查 UTXO 状态、covenant 谱系、transaction v1、用户车道、计算预算和内联证明验证的候选能力。
- 决定第一个 spike 应该生成 Silverscript，还是仅围绕手动编写的 covenant 源代码生成目标 manifest。
- 定义一个带有后继输出验证的小型 L1 covenant Counter 类场景。
- 为 covenant 源代码、transaction v1 manifest、covenant 谱系 manifest 和可选的证明验证器 manifest 定义最小制品元数据形状。
- 在 L1 covenant 制品形状明确之前，推迟对 based-app 的支持。

验收标准：

- `docs/targets/kaspa-toccata.md` 记录目标分类和非目标。
- 能力候选者保持文档化，但在通过审查前不会添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已记录的外部工具阻塞器。
- 文档区分了内联 ZK 验证与 `psy-dpn` 风格的电路源代码生成。

## 工作流 12：Stellar Soroban Research 目标

目标：决定 ProofForge 是否以及如何支持 Stellar 智能合约，而不将所有 Wasm 合约链视为同一个目标。

任务：

- 已完成：为候选目标 id `wasm-stellar-soroban` 添加文档优先的目标说明。
- 将 Soroban 归类为 Wasm-host 候选者，而非通用的 Wasm 制品目标。
- 决定第一个 spike 应该生成原生的 Rust/Soroban 包，还是等待直接的 Lean-to-Wasm 宿主桥接。
- 审查地址授权、合约账户授权、存储 TTL、合约规范元数据和 Stellar 资产的候选能力。
- 定义一个练习存储和事件输出的小型 Counter 类场景。
- 为 Wasm、合约规范、部署 manifest、工具链版本和验证结果定义制品元数据。
- 识别本地冒烟测试命令集：`stellar contract build`、沙盒或测试网部署以及调用。

验收标准：- `docs/targets/stellar-soroban.md` 记录了目标分类和非目标。
- 能力候选者保持文档化，但在通过评审前不会被添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已文档化的外部工具阻塞器。
- 尽管 Soroban、NEAR 和 CosmWasm 都使用 Wasm 制品，但文档将它们区分开来。

## 工作流 13: Internet Computer Research 目标

目标：决定 ProofForge 是否以及如何支持 Internet Computer canister，而不将每个 Wasm 制品都视为相同的合约目标。

任务：

- 已完成：为候选者目标 id `wasm-icp-canister` 添加文档优先的目标说明。
- 将 ICP canister 分类为 Wasm-host 候选者，而非通用的 Wasm 制品目标。
- 决定第一个 spike 应该生成原生的 Motoko/Rust CDK 包，还是等待直接的 Lean-to-Wasm canister 桥接。
- 评审以下能力候选者：Candid、update/query 方法模式、stable memory、orthogonal persistence、principals、cycles、异步 canister 间调用、canister 生命周期、certified data 以及管理 canister API。
- 定义一个微型的类 Counter 场景，包含一个 update 方法和一个 query 方法。
- 为 Wasm、Candid、canister manifest、stable-state 或升级策略、工具链版本以及验证结果定义制品元数据。
- 确定本地冒烟测试命令集：本地副本、PocketIC 或 ICP CLI canister 安装/调用流程。

验收标准：

- `docs/targets/internet-computer.md` 记录了目标分类和非目标。
- 能力候选者保持文档化，但在通过评审前不会被添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已文档化的外部工具阻塞器。
- 尽管都使用 Wasm 制品，但文档将 ICP canister 与 NEAR、CosmWasm 和 Soroban 区分开来。

## 工作流 14: TON TVM Research 目标

目标：决定 ProofForge 是否以及如何支持 TON 智能合约，而不假装 TVM 合约是 EVM、Wasm-host、Move 或 ZK 目标。

任务：

- 已完成：为候选者目标 id `ton-tvm` 添加文档优先的目标说明。
- 将 TON 分类为 TVM/Tolk 源代码生成候选者。
- 决定第一个 spike 应该生成 Tolk 源代码/包制品，还是等待更低级别的 TVM/cell IR。
- 评审以下能力候选者：cells、TL-B 元数据、入站消息、出站消息、get 方法、操作列表、`StateInit`、账户状态、TVM gas 以及 jetton/token 集成。
- 定义一个微型的类 Counter 场景，包含一个内部消息和一个 get 方法。
- 为源代码、TVM/BOC 输出、接口元数据、初始状态、消息/操作 schema、工具链版本以及验证结果定义制品元数据。
- 确定本地冒烟测试命令集：Acton/Tolk 编译以及本地测试或模拟器验证。

验收标准：

- `docs/targets/ton-tvm.md` 记录了目标分类和非目标。
- 能力候选者保持文档化，但在通过评审前不会被添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已文档化的外部工具阻塞器。
- 文档将 TON TVM 与 Wasm-host、EVM、Move 和 ZK 目标区分开来。

## 工作流 15: Bitcoin Cash CashScript Research 目标

目标：决定 ProofForge 是否以及如何支持 Bitcoin Cash 智能合约，而不假装 UTXO 支出路径是有状态的合约方法调用。

任务：- 已完成：为候选目标 id `bch-cashscript` 添加文档优先的目标说明。
- 将 BCH/CashScript 分类为 UTXO 脚本/covenants 源代码生成候选。
- 决定第一个 spike 是否应在任何低级 BCH Script 路径之前生成 CashScript 源代码/包制品。
- 审查以下候选能力：UTXO 状态、P2SH 脚本、unlockers、交易内省、covenants、本地状态、CashTokens、时间锁、签名检查、CashScript 制品以及交易构建器验证。
- 定义一个微型 UTXO 支出场景，包含至少一个合约函数和交易构建器冒烟测试。
- 为 `.cash` 源代码、cashc 制品 JSON、字节码、构造函数/unlocker 清单、交易场景、工具链版本和验证结果定义制品元数据。
- 确定本地冒烟测试命令集：`cashc`、CashScript SDK、`MockNetworkProvider` 以及可选的 chipnet/节点后端验证。

验收标准：

- `docs/targets/bitcoin-cash-cashscript.md` 记录了目标分类和非目标。
- 候选能力保持文档化，但在通过审查前不会添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已记录的外部工具阻塞项。
- 文档将 BCH/CashScript 与 EVM、Wasm-host、Move、通用 Bitcoin 以及 Kaspa/Toccata 目标区分开来。

## 工作流 16：Algorand AVM Research 目标

目标：决定 ProofForge 是否以及如何支持 Algorand 智能合约，而不将 AVM 应用伪装成 EVM、Wasm-host、Move、Solana、TVM、UTXO 或 ZK 电路目标。

任务：

- 已完成：为候选目标 id `algorand-avm` 添加文档优先的目标说明。
- 将 Algorand 分类为 AVM/TEAL 源代码或包生成候选。
- 决定第一个 spike 是否应在任何直接 TEAL 发射路径之前生成 Algorand Python 或 Algorand TypeScript 包制品。
- 审查以下候选能力：有状态应用、LogicSig 程序、ARC-4 ABI/应用规范、全局/本地/box 存储、交易组、资源引用、内部交易、Algorand 标准资产、AVM 预算以及 AlgoKit/Puya 制品。
- 定义一个微型有状态 Counter 类应用，包含一个更新方法、一个读取/查询路径、显式存储模式，以及 localnet 或模拟器后端验证。
- 为源代码、approval 字节码、clear-state 字节码、可选的 LogicSig 字节码、ABI/应用规范、存储模式、资源引用、工具链版本和验证结果定义制品元数据。
- 确定本地冒烟测试命令集：AlgoKit/Puya 编译加上 LocalNet 或模拟器后端的创建/调用/查询验证。

验收标准：

- `docs/targets/algorand-avm.md` 记录了目标分类和非目标。
- 候选能力保持文档化，但在通过审查前不会添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已记录的外部工具阻塞项。
- 文档将 Algorand AVM 与 Wasm-host、EVM、Move、Solana、TVM、UTXO 和 ZK 目标区分开来。

## 工作流 17：Cardano Plutus/Aiken Research 目标

目标：决定 ProofForge 是否以及如何支持 Cardano 智能合约，而不将 eUTXO 验证器伪装成有状态的方法调用合约。

任务：- 已完成：为候选 id `cardano-plutus-aiken` 添加文档优先的目标说明。
- 将 Cardano 分类为 eUTXO 验证器源代码生成候选目标。
- 决定第一个 spike 是否应该在任何直接的 Plutus/UPLC 路径之前生成 Aiken 源代码。
- 审查 eUTXO 状态、验证器角色、datum、redeemer、脚本上下文、有效性范围、交易平衡、原生代币、执行单元以及 Plutus 蓝图的候选能力。
- 定义一个带有后继输出验证的微型类 Counter eUTXO 状态机场景。
- 为 Aiken 源代码、UPLC/Plutus 验证器、蓝图、datum/redeemer 模式、交易场景、执行单元、工具链版本和验证结果定义制品元数据。
- 确定本地冒烟测试命令集：Aiken 编译/测试加模拟器、基于 SDK 的交易或基于 cardano-node 的验证。

验收标准：

- `docs/targets/cardano-plutus-aiken.md` 记录目标分类和非目标。
- 能力候选者保持文档化，但在审查前不会添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已记录的外部工具阻塞因素。
- 文档将 Cardano 与 EVM、Wasm-host、Move、Solana、TVM、AVM、通用 Bitcoin、BCH/CashScript 以及 Kaspa/Toccata 目标区分开来。

## 工作流 18：Tezos Michelson/LIGO Research 目标

目标：决定 ProofForge 是否以及如何支持 Tezos 智能合约，而不将 Michelson 操作列表语义隐藏在通用合约调用之后。

任务：

- 已完成：为候选 id `tezos-michelson-ligo` 添加文档优先的目标说明。
- 将 Tezos 分类为 Michelson 源代码/制品目标，并将 LIGO 作为第一个源代码生成路径。
- 审查 Michelson 代码、入口、类型化 Micheline 存储、`big_map`、操作列表、视图、事件、票据、Sapling、委托、gas/存储销毁以及 LIGO 制品的候选能力。
- 定义一个具有一个入口、一个视图、类型化存储以及本地测试或沙盒验证流的微型类 Counter 合约。
- 为 LIGO 源代码、Michelson 输出、参数/存储模式、操作列表、视图/事件清单、工具链版本和验证结果定义制品元数据。
- 确定本地冒烟测试命令集：LIGO 编译/测试加 Octez 沙盒或等效的 Tezos 本地验证。

验收标准：

- `docs/targets/tezos-michelson-ligo.md` 记录目标分类和非目标。
- 能力候选者保持文档化，但在审查前不会添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已记录的外部工具阻塞因素。
- 文档将 Tezos 与 EVM、Wasm-host、Move、Solana、TVM、AVM、UTXO 和 ZK 目标区分开来。

## 工作流 19：Starknet Cairo Research 目标

目标：决定 ProofForge 是否以及如何支持 Starknet 智能合约，而不将 Cairo 链上合约视为通用的 ZK 电路。

任务：

- 已完成：为候选 id `starknet-cairo` 添加文档优先的目标说明。
- 将 Starknet 分类为 Cairo/Sierra/CASM 源代码生成候选目标。
- 审查 Cairo 源代码、Sierra、CASM、类声明、类哈希、Starknet ABI、存储、账户抽象、系统调用、L1/L2 消息传递、Starknet 费用/资源限制以及 Starknet Foundry 验证的候选能力。
- 定义一个具有存储、一个 increment 外部函数、一个 read 函数和一个事件的微型类 Counter 合约。
- 为 Cairo 源代码、Sierra/CASM 制品、ABI、选择器/类哈希元数据、部署清单、工具链版本和验证结果定义制品元数据。
- 确定本地冒烟测试命令集：Scarb 构建加 `snforge` 或基于 devnet 的测试。

验收标准：- `docs/targets/starknet-cairo.md` 记录了目标分类和非目标。
- 能力候选者保持记录状态，但在经过评审前不会添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已记录的外部工具阻塞因素。
- 文档将 Starknet 与 EVM、Wasm-host、Move、Solana、TVM、AVM、UTXO 以及 `psy-dpn` 风格的 ZK 电路目标区分开来。

## 工作流 22: Aleo Leo Research 目标

目标：决定 ProofForge 是否以及如何支持 Aleo 程序，而不将 Aleo 仅视为通用的 ZK 电路目标，或将 Aleo VM 与 Algorand AVM 混淆。

任务：

- 已完成：为候选者 id `aleo-leo` 添加文档优先的目标说明。
- 将 Aleo 分类为 ZK 应用源代码生成候选者，以 Leo 作为第一个源代码边界，Aleo Instructions 作为底层编译器目标，Aleo VM 字节码作为可部署的执行制品。
- 评审以下各项的能力候选者：Leo 源码、Aleo Instructions、Aleo VM、AVM 字节码、ABI、证明者/验证者制品、transitions、finalization、records、mappings、存储、公有/私有输入和输出、程序导入/升级、执行/部署交易、Credits 费用、Leo 测试以及 devnet 验证。
- 定义一个微型的类 Counter 程序，包含一个入口 `fn`、一个公有 `mapping` 和一个 `final { }` 块。
- 定义第二个私有 record 场景，该场景消耗一个加密 record，创建一个后续 record，并仅在需要时记录公有/finalization 影响。
- 为 Leo 源码、程序 id/导入、record/mapping 模式、finalization 清单、Aleo Instructions、Aleo VM 字节码、ABI、证明者/验证者制品、执行/部署交易元数据、工具链版本和验证结果定义制品元数据。
- 确定本地冒烟测试命令集：`leo build`、`leo test`、可选的 `leo test --prove`、`leo execute --print`，以及基于 devnet/devnode 的部署或执行验证。

验收标准：

- `docs/targets/aleo-leo.md` 记录了目标分类和非目标。
- 能力候选者保持记录状态，但在经过评审前不会添加到 `ProofForge.Target.Capability`。
- 第一个 spike 具有可复现的本地验证命令或已记录的外部工具阻塞因素。
- 文档将 Aleo 与 `psy-dpn`、Zcash Shielded、Kaspa/Toccata 内联 ZK、Starknet Cairo、Algorand AVM 以及通用的源代码生成目标区分开来。

## 工作流 20: Bitcoin Script/Miniscript Research 目标

目标：决定 ProofForge 是否以及如何支持比特币基础层支出策略，而不假装 Bitcoin Script 是一个通用的智能合约运行时。

任务：

- 已完成：为候选者 id `bitcoin-script-miniscript` 添加文档优先的目标说明。
- 将比特币分类为通过 Script、Miniscript、描述符、PSBT 和 Bitcoin Core 验证的受限 UTXO 支出策略目标。
- 评审以下各项的能力候选者：Bitcoin Script、Miniscript、描述符、SegWit、Taproot、Tapscript、见证栈、sighash 模式、哈希锁、阈值多签、PSBT 流程、标准性、权重/费用限制以及 Bitcoin Core regtest 验证。
- 定义一个微型的支出策略场景，例如“A 可以立即支出，或者 B 可以在相对时间锁之后支出”。
- 为策略、描述符、输出脚本、见证要求、PSBT/原始交易场景、权重/费用、工具链版本和验证结果定义制品元数据。
- 确定本地冒烟测试命令集：Bitcoin Core regtest、描述符导入或地址派生、PSBT 签名/finalization，以及 `testmempoolaccept` 或等效的支出验证。

验收标准：- `docs/targets/bitcoin-script-miniscript.md` 记录目标分类和非目标。
- 能力候选者保持文档记录，但在通过评审前不会被添加到 `ProofForge.Target.Capability`。
- 第一个 spike 拥有可复现的本地验证命令或已文档化的外部工具阻塞器。
- 文档将 Bitcoin Script/Miniscript 与 EVM、Wasm-host、Move、Solana、TVM、AVM、Cardano eUTXO、BCH/CashScript、Kaspa/Toccata 以及通用智能合约目标区分开来。

## 工作流 21: Zcash 屏蔽 Research 目标

目标：决定 ProofForge 是否以及如何支持 Zcash 屏蔽支付，而不将 Zcash 视为普通 Bitcoin Script 或通用 ZK 智能合约链。

任务：

- 已完成：为候选者 id `zcash-shielded` 添加文档优先的目标说明。
- 将 Zcash 分类为隐私 UTXO/ZK 支付候选者，包含透明 Zcash 流以及 Sapling/Orchard 屏蔽池。
- 评审以下能力候选者：屏蔽隐私、透明池跨越、Sapling、Orchard、屏蔽 note、note 承诺、nullifier、承诺树锚点、Zcash 协议证明、私有 witness、价值平衡约束、查看密钥、统一地址、隐私策略以及 zcashd/库验证。
- 定义一个微型屏蔽支付场景，例如“花费一个 Orchard note，创建一个 Orchard note，揭示一个 nullifier，保持价值平衡，并支付透明手续费”。
- 定义类似 JDL-Z11 的脚本如何表达 `shield`、`spendNote`、`createNote`、`revealNullifier`、`selectAnchor` 和 `privacyPolicy`，同时拒绝全局可变屏蔽存储、方法分发和任意证明验证。
- 为透明输入/输出、屏蔽池、note 输入/输出模式、nullifier、锚点、价值平衡、witness/证明需求、查看密钥披露、工具链版本和验证结果定义制品元数据。
- 确定本地冒烟测试命令集：zcashd RPC 或兼容的 Rust 钱包/协议库，如果本地证明对于 CI 过于沉重，则提供明确的备选阻塞器。

验收标准：

- `docs/targets/zcash-shielded.md` 记录目标分类和非目标。
- 能力候选者保持文档记录，但在通过评审前不会被添加到 `ProofForge.Target.Capability`。
- 第一个 spike 拥有可复现的本地验证命令或已文档化的外部工具阻塞器。
- 文档将 Zcash 与 Bitcoin Script/Miniscript、BCH/CashScript、Kaspa/Toccata 内联 ZK、`psy-dpn` 电路源代码生成以及通用智能合约区分开来。

## 工作流 23: 多链代币 SDK

目标：让用户只需描述一次同质化代币意图，然后让 `--target` 选择在 EVM 上生成 ERC-20 合约或在 Solana 上生成 SPL Token / Token-2022 方案，而无需在面向用户的 SDK 层暴露特定链的代码。

任务：- 已完成：添加 RFC 0006、`ProofForge.Contract.Token.TokenSpec`、目标代币计划以及 `Tests/TokenSpec.lean`。
- 已完成：添加遗留 Learn 代币意图源语法、`ProofForge.Contract.Token.Learn`、`Examples/Learn/ProofToken.learn`、`Examples/Learn/FeeToken.learn`、`Tests/TokenLearn.lean` 以及作为进入 `TokenSpec` 的兼容路径的 `proof-forge --learn-token --target <id>` 计划发射。
- 已完成：为 Learn 代币源添加首个 EVM ERC-20 制品发射器：`ProofForge.Contract.Token.Evm`、`Tests/TokenEvm.lean`、元数据中的标准 ERC-20 选择器/事件、Yul 生成，以及通过 `--learn-token --target evm` 进行的 `solc --strict-assembly` 字节码验证。
- 已完成：添加 `scripts/portable/learn-token-smoke.sh` / `just learn-token-smoke` 以验证来自 Learn 源的 EVM ERC-20 代币制品路径和 Solana Token-2022 计划路径。
- 已完成：添加 `scripts/evm/learn-token-erc20-vm-smoke.sh` / `just learn-token-evm-vm` 以在 EthereumJS VM 中部署生成的 ERC-20 创建字节码，并验证标准 ERC-20 调用、Transfer/Approval 主题以及余额不足回滚行为。
- 已完成：在 Lean `TokenSpec` 层实现 Solana SPL Token / Token-2022 部署计划渲染。`solanaTokenDeploymentPlan` 现在记录铸造账户创建、关联代币账户、`mint_to`、`transfer_checked`、`approve`、`burn`、`revoke`、权限变更、Token-2022 扩展初始化、Solana 程序 id 以及源文档引用。
- 已完成：将 `transfer_fee`、`non_transferable`、`confidential_transfer` 和 `transfer_hook` 等 Token-2022 特性路由到 Token-2022 扩展元数据，而非自定义的单代币程序。规划器会拒绝文档中记录的不兼容的 `transfer_fee` + `non_transferable` 组合。
- 已完成：扩展 `scripts/portable/learn-token-smoke.sh`，使遗留 `.learn` 输入路径重用 Lean `TokenSpec` 计划，发射 SPL Token 和 Token-2022 结构化计划 JSON，并使用 `@solana/spl-token` / `@solana/web3.js` 指令构建器离线验证计划。
- 已完成：添加 `scripts/solana/token-plan-web3-smoke.sh` / `just solana-token-plan-web3` 以在 Surfpool 上执行结构化遗留 SPL Token 计划。实时运行器创建铸造和关联代币账户，铸造初始供应量，执行计划中的 `mint_to`、`transfer_checked`、`approve`、`burn`、`revoke` 和铸造权限 `set_authority` 操作，并通过 Web3.js 读取验证余额、供应量、代理状态和权限撤销。
- 已完成：添加 `scripts/solana/token-2022-transfer-fee-web3-smoke.sh` / `just solana-token-2022-transfer-fee-web3` 以在 Surfpool 上执行结构化 Token-2022 转账手续费计划。实时运行器初始化 `TransferFeeConfig`，创建 Token-2022 关联代币账户，铸造初始供应量，执行 `TransferCheckedWithFee`，验证源余额、接收者净余额和接收者预留手续费，直接从代币账户提取预留手续费，然后进行第二次转账，将预留手续费归集到铸造账户，从铸造账户提取手续费，并通过 Web3.js 读取验证手续费接收者余额以及已清除的账户/铸造预留金额。
- 已完成：在 Surfpool 上添加 `ProofForge.Contract.Token.Examples.SoulboundToken`、`Tests/TokenPlanEmit.lean`、`scripts/solana/token-2022-non-transferable-web3-smoke.sh` 以及 `just solana-token-2022-non-transferable-web3` to execute a Lean `.lean` 基于 TokenSpec 的 Token-2022 不可转账计划。实时运行器初始化 `NonTransferable`，创建 Token-2022 关联代币账户，铸造初始供应量，验证铸造/账户扩展，证明 `TransferChecked` 被拒绝，然后销毁代币并通过 Web3.js 读取验证余额和供应量。
- 实现 EVM ERC-20 降级：ABI/选择器、余额/配额存储、总供应量、transfer/approve/transferFrom、mint/burn 选项、事件以及更广泛的 Foundry/Web3 行为测试。
- 继续对 Token-2022 扩展计划进行 Surfpool 实时验证，涵盖转账手续费初始化、检查转账、直接提取和归集到铸造账户的提取路径，以及不可转账的转账拒绝：机密转账设置和转账钩子路由。
- 为自定义策略（如供应量上限或自定义转账限制）添加可选的 Solana 包装器/权限/转账钩子程序生成。- 一旦 Surfpool 计划运行器落地，使用实时部署账户、工具版本和验证运行结果扩展特定于代币的制品元数据。

验收标准：

- Lean 编写的 `TokenSpec` 具有确定性的 EVM 和 Solana 代币计划；遗留 Learn 代币源降级到相同的 `TokenSpec` 边界。
- EVM 输出发射 ERC-20 Yul/字节码，并使用标准 Web3/Foundry 调用通过 ERC-20 行为测试。
- Solana 输出渲染结构化的 SPL Token / Token-2022 计划，使用 `@solana/spl-token` 离线验证指令构建器，现在在 Surfpool 上执行遗留 SPL Token 计划以及 Token-2022 转账费用和不可转账计划，以创建 mint 和代币账户、铸造供应量、在允许的情况下转账代币、验证余额、验证扣留的转账费用、通过直接账户提取以及 harvest-to-mint 加 mint 提取两种方式收取这些费用、拒绝不可转账的 `TransferChecked`，并销毁不可转账的供应量。机密转账和转账钩子行为仍为后续工作。
- 文档明确说明 Solana 默认不使用每个代币一个的 SPL 合约；它根据计划和 CPI 使用 SPL Token / Token-2022 程序。

## 工作流 24：架构收敛后续工作（合并后）

2026-07 分支合并将 `solana-supprot`、`lookdown` (Wasm/NEAR)、`aleo-support` 和 `cloudflare-support` 合并到主干中，解决了 D-025/D-026/D-027 决策 id 冲突（NEAR 决策重新编号为 D-029–D-031，Aleo 为 D-032，Cloudflare 为 D-033），统一了能力矩阵，并修复了 EVM 事件遍历器、Leo 发射器和 TS 发射器中的 `IR.Statement.release` 语义冲突。剩余后续工作：

任务：

- 在 `development-standards.md` 中记录分支策略：链是目录和目标 id，而不是分支；对 `ProofForge/IR/*`、`ProofForge/Target/*`、`ProofForge/Contract/{Spec,Intent,Source}*`、`docs/capability-registry.md`、`docs/decisions.md` 和 `docs/portable-ir.md` 的更改通过独立的 PR 落地到 `main`。
- 记录 i18n 规则：特性分支不触碰 `docs/zh/*.zh.md` 或 `scripts/i18n/manifest.json`；翻译同步仅在 `main` 上运行。
- 在合并 PR 落地后，停用已合并的远程分支（`DaviRain-Su/solana-supprot`、`DaviRain-Su/lookdown`、`DaviRain-Su/aleo-support`、`DaviRain-Su/cloudflare-support`）。
- 重新生成被合并后清单标记的陈旧 `docs/zh` 翻译（手动合并的决策/能力表已同步；在自动合并下发生更改的叙述性文档应通过 `translate-docs.py` 重新运行）。
- 决定 Solana bump 分配器选择是在合并后的 `TargetProfile.deploymentAllocator?` 抽象下统一，还是保持目标本地化；在 `decisions.md` 中记录结果。
- 统一 CI 工作流：合并后的 `.github/workflows/ci.yml` 现在包含 EVM、Solana-light、NEAR 和 Psy 门控；一旦 Aleo 和 TS/Cloudflare 的工具链（`leo`、`tsc`/`wrangler`）被固定，将它们的冒烟测试添加为可选作业。
- 命名清理：决定公共 SDK 名称，安排 `Lean.Evm` → `ProofForge.*` 命名空间重命名，并执行 Learn 冻结（[authoring-model](authoring-model.md)）。
- 在 RFC 0004 中宣布 `ContractSpec` → EVM 计划 → Yul 为 EVM 产品流水线；将 LCNF → `EmitYul` 标记为 Lean 原生 Experimental 路径。
- 决定 `wasm-cloudflare-workers` 是在 `wasmHost` 下保留其注册表条目，还是移动到独立的离链宿主家族（无共识，无链上状态），以免稀释能力语义；与 D-033 一起记录在 `decisions.md` 中。
- 在 `decisions.md` 中记录阶段完成标准：当前阶段的完成标准是共享场景（Counter，然后是 ValueVault）在 `evm`、`solana-sbpf-asm` 和 `wasm-near` 上通过；在此之前，新的 Research 目标仅添加文档——不更改注册表或能力文件。

验收标准：- `docs/decisions.md` 显示了一个线性决策日志（D-001…D-033，无重复 id），并记录了分配器统一的结果。
- 开发标准包含分支和 i18n 规则。
- 所有四个已合并的链分支均已删除或归档。

## 工作流 25：形式化验证路线图

目标：根据 [formal-verification.md](formal-verification.md)，将平台的核心承诺转换为机器检查的定理。

任务（完整说明请参见路线图）：

- FV-1：证明 `resolveSpec` 的能力路由正确性、拒绝完备性以及 Solana 目标扩展隔离（将 D-027/D-028 作为定理）。
- FV-2：将 `ProofForge/IR/Semantics.lean` 扩展到标量子集之外（映射、数组、结构体、`ifElse`、`boundedFor`、事件），并证明确定性以及有界循环终止性。
- FV-3：证明 `IR/Ownership.lean` 检查器在感知释放（release-aware）语义下的正确性（无释放后使用、无重复释放），为三种不同的 `release` 降级（EmitWat 分配器、EVM/Psy 拒绝、TS no-op）提供依据。
- FV-4：添加一个镜像 `Backend/WasmNear/Refinement.lean` 的 EVM Counter 追踪义务，由 Yul 子集解释器支持；在解释器存在之前，让 Psy/Solana 保持在差异化门控上。
- FV-5：在 IR 值域中统一陈述检查算术（checked-arithmetic）溢出/除法语义，并将溢出分支添加到后端义务中。
- FV-6：证明配对 fixture 子集的 `.learn` 与 `contract_source` 降级等价性（可判定的 `ContractSpec` 相等性）。
- FV-7：证明 Token SDK 计划不变性（全特性路由、文档化的不兼容性诊断、计划良构性）。
- FV-8：基于 IR 语义的面向用户合约不变性，以 ValueVault 作为工作示例。

验收标准：

- 每个落地的 FV 项都是 `decide` 可检查的定理或接入 CI 的 Lean 测试，而不是外部工具依赖。
- 如果没有 FV-4 追踪义务和共享场景差异化门控，后端不能从 Experimental 变更为 Supported。

## 工作流 26：统一 Rust 测试框架 (testkit)

目标：根据 [RFC 0007](rfcs/0007-unified-rust-test-framework.md)，用一种声明式场景格式和 Rust 进程内执行器取代每个链各自散乱的 shell/Node 测试桩。

任务（每个实现分支一个里程碑）：- M1: 创建 `testkit/` Cargo 工作区 (`core` + scenario TOML 模型, 发现, 报告); 将 `runtime/offline-host` 移植到 `harness-near` (wasmtime + NEAR 宿主 shim, 保留分配器计数器); Counter 场景在 `wasm-near` 上通过; 添加 `just testkit` 和一个 CI 步骤。
- M2: 在 revm 上实现 `harness-evm` — 加载发射的运行时字节码，通过 `.evm-methods` 选择器进行调度，解码返回字；Counter 在 `evm` 上通过；首次跨目标等效性断言 (evm ↔ wasm-near 可观察追踪)。
- M3: 在 mollusk-svm 上实现 `harness-solana` — 将 `Tests/solana/*_mollusk.rs.tpl` 逻辑吸收为库代码；Counter 在所有三个目标上通过。状态：Counter 现在通过 `testkit/harness-solana` 中的 `mollusk-svm` 连接，包括黄金汇编、manifest、制品元数据、sBPF ELF 构建、有状态场景执行，以及在 `sbpf` 和 `solana-keygen` 可用时的三目标追踪一致性。ValueVault 现在由 `testkit/scenarios/value-vault.toml`、类型化标量场景参数、`runtime/offline-host --inputs-hex`、NEAR/Wasm EmitWat fixture、Solana ValueVault sBPF/Mollusk harness 以及当 Foundry `cast` 可用于选择器填充时的 EVM/revm harness 覆盖。
- M4: 将黄金文件比较和每个 fixture 的行为脚本迁移到场景步骤中；停用重复的 shell 脚本；将每个 fixture 的 CI 步骤合并到 testkit 运行中。实时/链上真实网关 (Foundry, Anvil deploy, Surfpool, near-sandbox, dargo, leo) 保持为独立的定时或标记任务。状态：第一个 M4 切片已通过场景声明的 `[[artifact]]` 预期就位。Counter 的 Solana 黄金汇编/manifest 检查以及 ValueVault 的 WAT/Yul/sBPF/manifest/制品元数据源码形状检查现在存在于场景 TOML 中，而不是硬编码的特定于 fixture 的 harness 分支。第二个切片添加了嵌套的 `[[artifact.json]]` 和 `[[artifact.toml]]` 检查，因此 Solana Counter 和 ValueVault 的元数据/manifest 字段、指令名称/标签、能力成员身份和验证状态由场景运行器声明式地断言。后续切片移除了重复的 Solana harness 内部元数据/manifest 语义验证器，仅在 `testkit/harness-solana` 中保留运行时调度解析。下一个切片收紧了场景发现，使得在任何 harness 运行之前，未声明目标的空或重复目标 id 以及制品预期都会失败。当前的 EVM 切片将 EVM 制品元数据标识、能力、验证和 ABI 入口名称预期移至场景声明的 `[[artifact.json]]` 检查中，使 `testkit/harness-evm` 仅负责选择器解析和运行时执行。当前的诊断切片添加了场景声明的 `[[diagnostic]]` 预期和一个仅用于诊断的 `unsupported-crosscall` 场景，该场景证明 `solana-sbpf-asm` 以预期的目标/能力消息拒绝可移植的 `crosscall.invoke` 能力。当前的 EVM 黄金切片添加了 `Examples/Evm/Counter.golden.yul` 作为可移植 IR Counter Yul 黄金快照，并使 `testkit/scenarios/counter.toml` 通过 `matches_file` 断言生成的 EVM Yul；较旧的 Lean SDK 合约黄金快照保留在 `Examples/Evm/Contracts/` 下。当前的 Wasm/NEAR 黄金切片添加了 `Examples/WasmNear/Counter.golden.wat`，并使相同的 Counter 场景通过 `matches_file` 断言生成的 EmitWat 输出，因此 Counter 现在对 `wasm-near`、`evm` 和 `solana-sbpf-asm` 具有场景声明的源码等效性。当前的 ValueVault Wasm/NEAR 黄金切片添加了 `Examples/WasmNear/ValueVault.golden.wat`，并使 `testkit/scenarios/value-vault.toml` 通过 `matches_file` 断言生成的 EmitWat 输出。当前的 ValueVault Solana 黄金切片添加了 `Examples/Solana/ValueVault.golden.s` 和 `Examples/Solana/ValueVault.manifest.toml`，使相同的场景通过 `matches_file` 断言生成的 sBPF 汇编和 manifest 输出。当前的 ValueVault EVM 黄金切片添加了 `Examples/Evm/ValueVault.golden.yul` 和使相同的场景通过 `matches_file` 断言生成的 EVM Yul，因此 ValueVault 现在对 `wasm-near`、`solana-sbpf-asm` 和`evm`。当前的元数据文件引用切片增加了嵌套的 `[[artifact.file]]` 检查，使场景能够断言 JSON 元数据文件条目指向 harness 生成的制品，并匹配路径、字节大小和 SHA-256 哈希，同时将 EVM init-code/deploy-manifest 输出暴露为 testkit 制品。当前的跨制品 JSON 切片增加了嵌套的 `[[artifact.jsonArtifact]]` 检查，验证 Solana ValueVault 元数据嵌入了与生成的 IDL 制品相同的 IDL JSON，并将 ValueVault IDL/客户端 schema-shape 检查移至场景 TOML。当前的结构化长度切片向嵌套的 `[[artifact.json]]`/`[[artifact.toml]]` 检查添加了 `length` 断言，并使用它们以声明方式固定 Counter 和 ValueVault 的 ABI 入口、事件、能力、制品、manifest 指令、Solana 指令以及 IDL 指令计数。当前的结构化 schema 切片为嵌套的 JSON/TOML 制品断言增加了 `exists`、`kind` 和 `non_empty` 检查，然后使 Counter 和 ValueVault 将 EVM 部署 manifest 验证为一等场景制品，包括 init-code 模式、缺失的链 profile、未生成的广播状态、ABI 和能力形状，以及指向生成的 Yul、字节码和 init-code 制品的文件引用。

验收标准：

- 当可选的 Solana 工具链可用时，一个场景文件驱动所有三个优先级目标；添加涵盖的功能不需要新的脚本、recipe 或 CI 步骤。
- 使用不支持的能力的场景会断言带有诊断信息的编译时拒绝（绝不静默跳过目标）。
- Runner 默认是确定性的且无网络的；`revm`、`mollusk-svm` 和 `wasmtime` 版本已固定。
- Lean 侧编译器测试（诊断、覆盖率 manifest、形式化锚点）保留在 `Tests/*.lean` 中且不移动。

## 工作流 27：分配器抽象统一

目标：根据 [RFC 0008](rfcs/0008-allocator-abstraction.md)，每个目标绑定一个链中立的分配器模型；解决工作流 24 的分配器统一决策。

任务：

- M1：将 `ProofForge/IR/Allocator.lean` 泛化为 strategy/region/release 三元组（现有构造函数映射到其上；EmitWat 行为保持不变）；在 `decisions.md` 中记录该决策。
- M2：将 Solana 的 `RuntimeAllocator` (`Backend/Solana/Extension.lean`) 合并到共享模型中 —— `solana.allocator.*` 元数据键保留为 Solana 配置语法，但填充共享类型；IDL 从中渲染；`Tests/SolanaAllocator.lean` 已更新。
- M3：添加显式 EVM 绑定（在 call-scratch 内存上 bump；记录 EmitYul/EVM 计划已执行的操作）；定义将 EVM `release` 从拒绝移动到经过检查的 no-op 的标准（受阻于 FV-3 所有权稳健性）。
- M4：在三个 harness 上的 testkit（工作流 26）中添加分配器行为场景；NEAR 断言分配器计数器，EVM/Solana 断言 `release` 作为 no-op 时的可观察追踪相等性。

验收标准：

- 一个 `AllocatorModel` 类型被 EmitWat、Solana 后端和 EVM 绑定使用；不再保留并行的分配器记录。
- 持久状态模型（EVM 存储、Solana 账户、NEAR 存储）明确超出范围且保持不变。
- 通过 `runtime.allocator` 进行的能力门控在针对不支持的 release/strategy 需求的诊断中引用 `alloc.*` id。

## 工作流 28：目标组合排序

目标：执行 [target-roadmap.md](target-roadmap.md) (D-034) 中的分层组合。门控而非日期；每个实现分支一个里程碑。

任务：- Gate G0 (Tier-0 出口)：testkit M3 (工作流 26) 加上在 `evm`、`solana-sbpf-asm`、`wasm-near` 上的共享场景一致性。
- Tier 1a `wasm-cosmwasm`：M1 CosmWasm 宿主导入 + EmitWat 中的 region-allocator ABI (来自 RFC 0008 的 `cosmWasmRegion` 绑定)；M2 Counter 制品通过 `cosmwasm-check`；M3 testkit `harness-cosmwasm` 场景通过，且与 `wasm-near` 具有跨目标等效性；M4 注册表阶段 → Experimental。
- Tier 1b `move-aptos` (与 1a 并行)：M1 IR → 针对 Counter 子集的 Move 模块打印器；M2 `aptos move test` 门禁 + 黄金固定装置；M3 testkit CLI 封装的执行器；M4 能力行已验证；`move-sui` 仅在 M4 之后。
- Tier 2 (每个都在其启用条件之后，见路线图)：`wasm-stellar-soroban` 在 CosmWasm M4 之后；`wasm-icp-canister` 在任何代码之前额外需要一份异步/容器间设计笔记；`starknet-cairo` 是 Aptos M4 之后第一个选中的源代码生成通道；`ton-tvm`、`algorand-avm`、`cardano-plutus-aiken`、`tezos-michelson-ligo` 遵循“一次仅一个活跃的源代码生成 spike”规则。
- Tier 3 Bitcoin 策略家族 (在 Gate G2 开启 = 两个 Tier-1 出口)：M1 策略 IR (谓词树) + 注册表文档中的 `policy.*` 能力 id；M2 针对 2-of-3 + 时间锁恢复共享策略场景的 rust-miniscript/描述符发射；M3 PSBT/regtest testkit 门禁；M4 作为 decide-checked 定理的 Lean 策略属性检查 (路径可达性、参与者无遗漏)。`bch-cashscript`、`zcash-shielded` 和 `kaspa-toccata` 保持在 M4 之后待命。

验收标准：

- 在 Gate G0 之前没有 Tier-1 代码落地；没有 Tier-2 目标在其列出的启用条件之前启动；任何时候最多只有一个源代码生成 spike 处于活跃状态。
- 策略家族目标永远不会出现在合约家族的能力行中；当 Tier 3 开启时，它们在能力注册表中会获得一个单独的 `policy.*` 章节。

## 工作流 29–33：平台硬化 (规划优先)

这些来自 [2026-07 差距分析](platform-gaps-2026-07.md)。每个都以 RFC 而非代码开始；排序钩子列在差距文档中。

- **工作流 29 — CLI 产品界面。** 针对 `proof-forge build|emit|check --target <id> --fixture <id>` 的 RFC，折叠约 136 种发射模式；旧标志在一个版本中变为别名。必须在 testkit M4 绑定到当前标志之前完成规划。
- **工作流 30 — 版本控制和兼容性策略。** 涵盖 IR 版本规则 (与 coverage-manifest 门禁绑定)、制品/部署 schema 稳定性、仅追加的能力 id 以及 SDK 弃用策略的 RFC。
- **工作流 31 — 资源预算作为门禁。** 在 testkit 场景 schema (在 M2/M3 之前) 中扩展每步 gas/CU/near-gas 预算基准和容差带；一致性 (D-034 Gate G0) 要求预算，而不仅仅是行为。锁定的 Solana Counter 基准测量值 (Mollusk 0.13.4, 2026-07-02)：initialize 56 CU，increment 63 CU，get-with-return-data 163 CU，1336 字节 ELF。
- **工作流 32 — 部署生命周期、升级、签名。** 针对升级策略意图 (`immutable | authority | governance`) 的 RFC，该意图按链诚实地降级 (Solana 升级权限、EVM 不可变/代理、NEAR 账户密钥、Aleo `@noupgrade`) 或被拒绝；未签名交易签名边界；live-gate 密钥约定。
- **工作流 33 — 运行时错误模型 + 客户端生成。** 具有每目标编码和 `expect.error` 场景词汇的可移植错误代码 (与工作流 31 的 schema 变更一起规划)；然后是一个将 Solana IDL/TS 客户端生成推广到所有目标的客户端 schema 层 (实现等待 testkit M3)。

## 建议顺序

工作流 1、1.5、2–3、6–7 (注册表、可移植 IR、EVM 元数据、Solana asm) 已基本完成；剩余的每目标细节存在于每个工作流中。后续顺序遵循 [target-roadmap.md](target-roadmap.md) (D-034) 的 tier 门禁：0. 架构收敛后续工作 (工作流 24) 以及来自形式化验证路线图 (工作流 25) 的 FV-1/FV-2。与此同时，来自差距分析的规划优先 RFC：CLI 界面 (29，在 testkit M4 之前)，预算 + 错误词汇表 (31/33，在 testkit M2/M3 冻结场景 schema 之前)，版本控制和部署生命周期 (30/32，docs-agent 并行轨道)。
1. **并行：** 统一 testkit (工作流 26) 和分配器统一 (工作流 27) —— testkit M1/M2 不依赖于分配器 M1/M2；分配器 M4 在 testkit M3 之后落地。
2. Gate G0：通过 testkit 实现 `evm` + `solana-sbpf-asm` + `wasm-near` 的共享场景一致性（结束当前阶段；D-034）。
3. **并行第一梯队：** `wasm-cosmwasm` (工作流 5/28) 和 `move-aptos` (工作流 8/28)。
4. 按启用者划分的第二梯队：CosmWasm 之后是 Soroban；Aptos 之后是 Sui 和 源代码生成 泳道（首选 Starknet）；ICP 额外排在异步设计笔记之后；一次进行一个 源代码生成 spike (工作流 12–19/22, 28)。
5. Gate G2 的 Bitcoin 策略家族 (工作流 11/15/20/21, 28) —— 首先是 miniscript，然后是其后的 CashScript/Zcash/Kaspa。
6. 多链 Token SDK 后续工作 (工作流 23) 同步继续，且剩余的实时门控 CI 矩阵 (工作流 9) 随每个 目标 增长。
7. 云平台设计更新（前提条件：两个以上处于 Experimental 状态且具有共享场景一致性的 目标；D-010）。
