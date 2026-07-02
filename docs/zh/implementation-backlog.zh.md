**注意：** 公共验证命令的更改必须在同一次变更中更新 [validation-gates.md](validation-gates.md)。

# 实现 Backlog

此 Backlog 将多链设计转化为可评审的工程切片。它有意将范围限定在本地编译器、制品和冒烟测试工作。云平台应等到至少两个实质上不同的目标在本地正常工作后再开始。

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
  `solana-sbpf-asm`, `solana-sbpf-linker`（已取代）, `solana-zig-fork`,
  `move-sui`, `move-aptos`, `psy-dpn`。
- 定义目标家族、制品种类、所需工具和能力集
  （参见 [capability-registry.md](capability-registry.md)）。
- 为 CLI 和脚本添加目标查找函数。
- 已完成：为 deployment metadata 增加 EVM-compatible chain profile 层，
  首个 profile 是 `evm` compiler target 下的 `robinhood-chain-testnet`。
- 为未知目标和不支持的能力添加诊断信息。

验收标准：

- `evm` 可以在不改变当前 EVM 行为的情况下表示为目标 profile。
- EVM-compatible chain profiles 可以复用 `evm` compiler target，且不会被 target-id lookup
  当成 compiler target 返回。
- 目标 profile 可以声明外部工具需求。
- 不支持的能力错误应包含目标 id、能力 id 以及可用的源代码位置。

## 工作流 1.5：可移植 IR 和共享场景

目标：在进行非 EVM spike 之前定义合约 IR 和 Counter 场景。

任务：

- 根据 [portable-ir.md](portable-ir.md) 实现 IR 节点类型。
- 根据 [shared-scenario.md](shared-scenario.md) 表达 Counter。
- 将 Counter IR 降级到 EVM（直接降级或通过 EmitYul 适配器）。
- 将能力检查器连接到 [capability-registry.md](capability-registry.md)。

验收标准：

- Counter 模块可以在 IR 层不包含 EVM 操作码的情况下用 IR 表示。
- 从 IR 构建的 EVM 与现有的 Counter 行为一致。
- 至少有一个不支持的能力被拒绝，并带有清晰的诊断信息。
- 发射时，IR 版本出现在制品元数据中。

## 工作流 2：制品元数据

参见 [validation-gates.md](validation-gates.md) 了解当前和计划中的验证命令。

目标：每次构建都应产生机器可读的结果，以便后续提供给 CI 和云平台。

任务：

- 已完成（EVM）：为 EVM bytecode build 添加 `proof-forge-artifact.json` schema。
- 已完成（EVM）：为 `--evm-bytecode` 和 portable IR EVM bytecode fixture build 发射 metadata。
- 已完成（EVM）：包含 source module、target id、artifact path、SHA-256、byte size、solc path/version、selector/signature metadata 和 validation status。
- 已完成（EVM）：在 `proof-forge-artifact.json` 和
  `proof-forge-deploy.json` 的 `abi.methods[].signature` 中保留 SDK
  `.evm-methods` 的 Solidity signature；validator 会检查 selector 形态、重复的
  method selector/function/signature、生成的 Yul function name，以及
  signature/arg-count 一致性，SDK 示例门禁会要求 signature 存在。
- 已完成（EVM）：为每个 EVM bytecode build 发射并校验 ProofForge deploy manifest，记录 runtime bytecode 输入、ABI selector、可部署 initcode，以及当前 `not-generated` 的交易广播状态。
- 已完成（EVM）：为每个 EVM bytecode build 生成与 artifact 关联的 `.init.bin` creation bytecode 文件，在 `proof-forge-artifact.json` 和 `proof-forge-deploy.json` 中记录它，并验证 initcode header 会复制并返回引用的 runtime bytecode。
- 已完成（EVM）：添加 `--evm-chain-profile <id>`，让 bytecode build 可以在
  `proof-forge-deploy.json` 中记录已知 EVM chain profile，例如
  `robinhood-chain-testnet` 或 `anvil-local`；validator 会检查 profile id、chain
  id、RPC URLs、explorer、verifier 和 deployment block 的一致性，但不会广播交易。
- 已完成（EVM）：添加 `--evm-constructor-args-hex <hex>`，让 bytecode build 可以把显式 ABI-encoded constructor arguments 追加到生成的 `.init.bin`，在 `proof-forge-deploy.json` 中记录规范化 hex、byte size 和 SHA-256，并校验 initcode tail 与 manifest 一致。
- 已完成（EVM）：添加 `--evm-constructor-param <name:type>`，让 bytecode
  build 可以在 artifact metadata 和 deploy manifest 中记录静态 word
  constructor ABI schema，校验受支持的 schema 类型，并确认显式
  ABI-encoded constructor-argument blob 具有预期的 32-byte word 长度。
- 已完成（EVM）：添加 `--evm-constructor-arg <name=value>`，让 bytecode
  build 可以为 `uint256`、`uint64`、`uint32`、`bool`、`bytes32` 和
  `address` ABI-encode typed constructor values，记录 constructor args 来自
  typed values 还是 raw hex，拒绝缺失、重复和越界的值，并校验生成的 initcode
  tail 与 metadata 和 deploy manifest 一致。
- 已完成（EVM）：在 `abi.entrypoints` 中记录结构化的 portable IR
  selector-facing entrypoint ABI metadata，包括 Solidity-style selector
  signature、IR type name、ABI parameter/return type、展开后的 calldata word
  type/count，以及展开后的 return word type/count；validator 会用
  `cast sig` 校验 selector/signature 一致性，`EvmAbiAggregateProbe` 会通过
  `--expect-entrypoint-abi` 固定聚合 ABI word layout。
- 已完成（EVM）：在 `abi.events` 中记录 portable IR event ABI metadata，包括
  Solidity-style event signature、`topic0`、indexed/data field、展开后的 ABI
  word type，以及 topic/data encoding；EventProbe 通过 `--expect-event` 和
  `cast keccak` 校验每个已发射 event。
- 已完成（EVM）：扩展 `scripts/evm/diagnostic-smoke.sh`，固定 constructor
  CLI 诊断，包括不支持的 dynamic constructor ABI type、缺失或重复的 typed
  value、typed/raw constructor argument source 混用、整数溢出，以及 address
  过短等格式错误的 static-word value。
- 已完成（EVM）：加入 Anvil deploy smoke，通过 `cast send --create` 发送生成的
  Counter `.init.bin`，记录 constructor ABI schema、typed constructor args
  和 `proof-forge-deploy-run.json` artifact，同时记录
  `eth_getTransactionByHash` creation transaction JSON，校验 `anvil-local` chain
  profile、receipt、deployed address、runtime-code match 和 transaction input
  initcode，并通过 JSON-RPC 运行 Counter lifecycle。
- 从第一天起就保持 schema 的版本化。

验收标准：

- EVM 字节码构建将 runtime bytecode、可部署 initcode、元数据和 deploy manifest 并排写入。
- 元数据和 deploy manifest 可以由 CI 脚本独立解析。
- Portable IR bytecode metadata 和 deploy manifest 可以描述 ABI-facing
  entrypoint，包括 selector signature、展开后的 calldata word layout，以及展开后的
  return-data word layout。
- Portable IR bytecode metadata 和 deploy manifest 可以描述 ABI-facing
  events，包括 indexed topic encoding 和非 indexed data-word encoding。
- Deploy manifest 可以携带来自 target registry 的可选 EVM chain profile
  metadata，同时让 transaction broadcast artifacts 明确保持 `not-generated`。
- 本地 Anvil 部署可以消费生成的 deploy manifest 和 initcode，产出经过校验的
  deploy-run artifact，并证明即使 initcode 包含 typed 或 raw ABI-encoded
  constructor-argument tail 和记录的静态 constructor ABI schema，deployed
  runtime code 仍然与生成的 bytecode 一致；deploy-run artifact 也会关联已观察到的
  creation transaction JSON，并验证其 input 等于生成的 initcode，且 deployment
  profile chain id 与实际本地链一致。
- EVM metadata 可以将缺失的可选 version 数据表示为 `null`，而不是格式错误的 metadata。

## 工作流 3：EVM 基线加固

参见 [validation-gates.md](validation-gates.md) 了解当前和计划中的验证命令。

目标：在引入目标模型时保持 EVM 稳定。

任务：

- 保持 `proof-forge --evm-bytecode` 正常工作。
- 已完成：加入 EVM IR 诊断冒烟测试，让不支持的 portable IR 形态在 Yul 生成前给出稳定错误。
- 已完成：加入 EVM IR 覆盖清单 gate，要求每个 portable IR constructor 都被标记为 lowered、validated、unsupported 或 structural。
- 已完成：加入 `AbiScalarProbe`，覆盖 portable IR EVM 的 `U64`、`U32` 和 `Bool` 标量 ABI 参数 decoding，并通过 golden Yul、solc bytecode 和 Foundry malformed-calldata 验证。
- 已完成：加入 EVM IR `assert` 和 `assert_eq` lowering，将其降为 Yul revert guard，并用 `AssertProbe` 跑通 golden Yul、solc bytecode 和 Foundry 成功/失败路径验证。
- 已完成：加入 EVM IR 可变标量 local binding 和 local assignment lowering，并用 `AssignmentProbe` 跑通 golden Yul、solc bytecode 和 Foundry 成功/失败路径验证。
- 已完成：加入 EVM IR local 和标量 storage 复合赋值 lowering，覆盖所有 portable `AssignOp` 变体，并用 `EvmAssignOpProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/原始 slot 验证、metadata 能力校验，以及 malformed target/type 显式诊断。
- 已完成：加入 EVM IR 语句级 `if/else` lowering，将其降为 Yul `switch` block，并用 `ConditionalProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时验证，同时通过 `EvmLoopProbe` 覆盖 EVM 专用的分支内早退。
- 已完成：加入 EVM IR `boundedFor` lowering，将其降为带静态边界的 Yul `for` loop，并用 `EvmLoopProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/原始 storage 验证、metadata 能力校验、通过 Yul `leave` 实现的分支/loop 内早退，以及无效范围显式诊断。
- 已完成：加入 EVM IR context read lowering，将 `userId`、`contractId` 和 `checkpointId` 降为 Yul `caller()`、`address()` 和 `number()`，并用 `ContextProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时验证和 metadata 能力校验。
- 已完成：加入 EVM IR `nativeValue` lowering，将其降为 Yul `callvalue()`，并用 `ContextProbe` 跑通 golden Yul、solc bytecode、Foundry 带 value 调用验证和 `value.native` metadata 能力校验。
- 已完成：加入 EVM IR `eventEmit` lowering，将其降为 Yul `log1`，topic0 为 `keccak256(Solidity-style event signature)`，data 为 32-byte word 字段序列，并用 `EventProbe` 跑通 golden Yul、solc bytecode、Foundry recorded-log 验证、metadata 能力校验，以及 malformed event 显式诊断。
- 已完成：加入 EVM IR `eventEmitIndexed` lowering，支持最多三个 scalar indexed field，降为 Yul `log2`/`log3`/`log4`，覆盖 signature topic0、indexed topic、非 indexed 32-byte word data，并用 `EventProbe` 跑通 golden Yul、solc bytecode、Foundry recorded-log 验证、metadata 能力校验，以及 indexed event 显式诊断。
- 已完成：补齐 EventProbe 对 multi-topic scalar indexed event 的验证缺口。`IndexedTwoValues(uint64,uint64,uint64)` 与 `IndexedThreeValues(uint64,uint64,uint64,uint64)` 现在证明生成的 Yul 会发出 `log3` 和 `log4`，保留有序 scalar indexed topic，校验 metadata selector，通过 `solc` 编译，并通过 Foundry recorded-log 断言。
- 已完成：补齐 EventProbe 对 typed scalar event field 的验证缺口。`TypedScalarEvent(bool,uint32,bytes32)` 与 `IndexedTypedScalar(bool,uint32,bytes32,uint64)` 现在证明 Bool、U32 和 Hash event data word 以及 indexed topic 都能正确 lowering，并覆盖 Bool/U32 dispatcher guard、golden Yul、metadata selector、`solc` 和 Foundry recorded-log 断言。
- 已完成：将 EVM IR event data lowering 从 scalar word 扩展到非 indexed 的扁平 struct field、scalar fixed-array field，以及元素为扁平 struct 的 fixed-array field，按 ABI-style 展开为连续 data word，并支持 `PairEvent((uint64,uint64))`、`ArrayEvent(uint64[2])`、`PairArrayEvent((uint64,uint64)[2])` 这类 canonical Solidity-style event signature；用 `EventProbe` 跑通 golden Yul、solc bytecode、Foundry recorded-log 验证、metadata selector 校验，并为不支持形态的 aggregate indexed field 保留显式诊断。
- 已完成：扩展 EVM IR `eventEmitIndexed` lowering，使扁平 struct indexed field，以及元素为扁平 struct 的 fixed-array indexed field，会先展开为 ABI-style word，再把这些 word 的 `keccak256` 作为 indexed topic。`EventProbe` 现在用 `IndexedPair((uint64,uint64),uint64)` 和 `IndexedPairArray((uint64,uint64)[2],uint64)` 跑通 golden Yul、solc bytecode、metadata selector 校验、Foundry recorded-log topic-hash 验证，并为嵌套或不支持形态的 aggregate indexed field 保留显式诊断。
- 已完成：补齐 EventProbe 对 scalar fixed-array indexed topic 的验证缺口，加入 `IndexedArray(uint64[2],uint64)` 的 golden Yul、metadata selector 校验、solc bytecode 生成和 Foundry recorded-log topic-hash 验证。
- 已完成：扩展 EventProbe 对嵌套 fixed-array event aggregate 的覆盖。`MatrixEvent(uint64[2][2])` 和 `PairMatrixEvent((uint64,uint64)[2][2])` 证明 scalar leaf 与扁平 struct leaf 的非 indexed data 会递归展开；`IndexedMatrix(uint64[2][2],uint64)` 和 `IndexedPairMatrix((uint64,uint64)[2][2],uint64)` 证明 indexed aggregate topic 会对递归展开后的 ABI-style word 做 hash。该 smoke 现在锁定新 selector、event ABI metadata、golden Yul、`solc` bytecode 和 Foundry recorded-log 断言；leaf 为不支持形态或非扁平 struct 的嵌套 array 仍保持显式诊断。
- 已完成：补齐 EventProbe 对 storage-backed 扁平 struct event data 和 indexed aggregate topic 的验证缺口。`StoragePairEvent((uint64,uint64))` 与 `IndexedStoragePair((uint64,uint64),uint64)` 现在证明 whole scalar storage struct write 可以通过 `storageScalarRead` 读回，展开为 event data word，作为 indexed topic hash 输入，并通过 golden Yul、metadata selector、`solc` 和 Foundry recorded logs 验证。
- 已完成：补齐 EventProbe 对 storage-backed fixed-array event aggregate 的验证缺口。`StorageArrayEvent(uint64[2])`、`StoragePairArrayEvent((uint64,uint64)[2])`、`IndexedStorageArray(uint64[2],uint64)` 与 `IndexedStoragePairArray((uint64,uint64)[2],uint64)` 现在证明 storage array read 和 storage array struct field read 可以作为非 indexed event data flattening 与 indexed aggregate topic hashing 的输入，并通过 golden Yul、metadata selector、`solc` 和 Foundry recorded logs 验证。
- 已完成：加入 EVM IR `crosscallInvoke` lowering，将其降为同步 EVM `call` helper，覆盖 selector 打包、word 参数、单 word 返回、调用失败和短返回 revert，并用 `EvmCrosscallProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时验证、metadata 能力校验，以及 malformed crosscall 类型显式诊断。
- 已完成：加入 EVM IR `crosscallInvokeTyped` lowering，支持 `Bool`、`U32`、`U64` 和 `Hash` typed scalar-word 跨合约调用，生成按返回类型区分的 Yul helper，并对 Bool/U32 return data 做范围 guard；用 `EvmCrosscallProbe` 跑通 golden Yul、solc bytecode、Foundry 合法/非法 typed return 验证、metadata entrypoint 校验，同时为当时尚未覆盖的 aggregate 参数/返回形态和 Psy typed crosscall unsupported 增加显式诊断。
- 已完成：将 EVM IR normal `crosscallInvokeTyped` return lowering 从 scalar word 扩展到 entrypoint 直接返回的扁平 struct 和 scalar fixed array，生成按 ABI word shape 区分的 Yul helper，覆盖多 word return-data 长度检查、aggregate return word 中的 Bool/U32 range guard、`EvmCrosscallProbe` golden Yul、solc bytecode、Foundry aggregate struct/array return 验证、metadata selector 校验，并为当时尚未覆盖的 aggregate return shape 保留显式诊断。
- 已完成：将 EVM IR typed crosscall 参数 lowering 从 scalar word 扩展到扁平 aggregate，使 normal、带 value、static 和 delegate typed call 都可以把扁平 struct 与 scalar fixed-array 参数展开为 ABI word。`EvmCrosscallProbe` 现在通过 golden Yul、solc bytecode、Foundry runtime、metadata selector 校验覆盖 normal struct/fixed-array 参数以及 value/static/delegate struct 参数，并为当时尚未覆盖的 aggregate 参数形态保留显式诊断。
- 已完成：加入 EVM IR `crosscallInvokeValueTyped` lowering，支持带 value 的 typed 跨合约调用，把显式 U64 call-value 表达式通过专用 Yul helper 转发到 EVM `call` 的 value slot，同时覆盖 scalar return 以及扁平 struct、scalar fixed-array 的 entrypoint 直接 aggregate return；用 `EvmCrosscallProbe` 跑通 golden Yul、solc bytecode、Foundry `msg.value`/callee balance 验证、aggregate Bool/U32 malformed-return guard、metadata entrypoint 校验，同时为 EVM malformed value/return 和 Psy value-bearing typed crosscall unsupported 增加显式诊断。
- 已完成：加入 EVM IR `crosscallInvokeStaticTyped` lowering，支持 typed `staticcall`，通过不带 value 的 Yul `staticcall` helper 复用 selector/scalar/扁平 aggregate 参数打包、scalar return、扁平 struct 和 scalar fixed-array entrypoint aggregate return 以及 Bool/U32 return guard；用 `EvmCrosscallProbe` 跑通 golden Yul、solc bytecode、Foundry U64 read-only return、Bool/U32/Hash static typed return、static aggregate return、static 扁平 struct 参数、非法 typed return 和 static context 下状态写入失败验证、metadata entrypoint 校验，同时为当时尚未覆盖的 EVM aggregate 参数/返回和 Psy static typed crosscall unsupported 增加显式诊断。
- 已完成：加入 EVM IR `crosscallInvokeDelegateTyped` lowering，支持 typed `delegatecall`，通过不带 value 的 Yul `delegatecall` helper 复用 selector/scalar/扁平 aggregate 参数打包、scalar return、扁平 struct 和 scalar fixed-array entrypoint aggregate return 以及 Bool/U32 return guard；用 `EvmCrosscallProbe` 跑通 golden Yul、solc bytecode、Foundry caller storage 读写、Bool/U32/Hash delegate typed return、delegate aggregate return、delegate 扁平 struct 参数、非法 typed return 验证、metadata entrypoint 校验，同时为当时尚未覆盖的 EVM aggregate 参数/返回和 Psy delegate typed crosscall unsupported 增加显式诊断。
- 已完成：将 EVM IR typed crosscall aggregate 覆盖扩展到元素为扁平 struct 的 fixed-array，覆盖 normal、带 value、static 和 delegate typed call 的参数与 entrypoint 直接返回。`EvmCrosscallProbe` 现在校验 `RemotePair[2]` ABI word 展开、Bool/U32 字段 return guard、golden Yul、solc bytecode、Foundry 运行时行为，以及四种调用模式下的 metadata selector。
- 已完成：将 EVM IR typed crosscall aggregate 覆盖扩展到嵌套标量 fixed-array，覆盖 normal、带 value、static 和 delegate typed call 的参数与 entrypoint 直接返回。`EvmCrosscallProbe` 现在校验 `uint64[2][2]` ABI word 展开、golden Yul、solc bytecode、metadata selector、Foundry 运行时行为、value 转发、staticcall 行为和 delegatecall 行为；在该里程碑时 diagnostics 仍会拒绝 struct 或其他非标量 nested fixed-array leaf，扁平 struct leaf 已由下一条补齐。
- 已完成：将 EVM IR typed crosscall aggregate 覆盖扩展到 leaf 为扁平 struct 的嵌套 fixed-array。`EvmCrosscallProbe` 现在校验 normal、带 value、static 和 delegate typed call 下的 `RemotePair[2][2]` 参数与 entrypoint 直接返回，包括 ABI word 展开、Bool/U32 字段 guard、golden Yul、solc bytecode、metadata selector、Foundry 运行时行为、value 转发、staticcall 行为和 delegatecall 行为；diagnostics 仍会拒绝 leaf 是非扁平 struct 或其他不支持形态的嵌套 fixed-array。
- 已完成：加入 EVM IR `crosscallCreate` 和 `crosscallCreate2` lowering，支持固定 init-code hex。Creation helper 会把 init code 写入 memory，调用 Yul `create`/`create2`，在返回零地址时 revert，并返回部署地址 word；覆盖 golden Yul、solc bytecode、metadata selector、Foundry 部署后 runtime 调用、确定性 CREATE2 地址推导、EVM malformed creation 诊断，以及 Psy unsupported 诊断。
- 已完成：加入 EVM IR direct scalar expression 验证，覆盖 `U64`/`U32` arithmetic、`U64` exponentiation、`U64`/`U32` bitwise 和 shift、predicate、boolean operator、literal、不可变 local、支持的 cast、单 word return、dispatcher guard 和 assertion guard，并用 `EvmExpressionProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/malformed calldata 验证、metadata 能力校验和 CI 覆盖。
- 已完成：加入 EVM IR `Hash` word lowering、`hash4`/`hashValue` 打包，以及通过 Yul `keccak256` helper 实现的 `hash`/`hash_two_to_one` lowering，并用 `EvmHashProbe` 跑通 golden Yul、solc bytecode、Foundry ABI/storage 验证、metadata 能力校验，以及 Hash/U64 类型错配显式诊断。
- 已完成：加入 EVM IR `Map<U64, U64, N>` storage lowering，使用 Solidity-style `keccak256(key, slot)` mapping slot，并用 `EvmMapProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/原始 slot 验证、metadata 能力校验，以及不支持 map 形态和 statement-position 误用的显式诊断。
- 已完成：加入 EVM IR 单段 `mapKey` storage path 复合赋值，限定在 `Map<U64, U64, N>` 上，并用 `EvmMapProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/原始 slot 验证、metadata 能力校验，以及表达式位置/嵌套路径误用的显式诊断。
- 已完成：泛化 EVM IR storage map 到 `U32`、`U64`、`Bool`、`Hash` word key/value 形态，继续复用 Solidity-style `keccak256(key, slot)` mapping slot，并用 `EvmTypedMapProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/原始 slot 验证、`U32`/`Bool` calldata guard、metadata 能力校验、CI 覆盖，以及非 word map 形态的显式诊断。
- 已完成：加入 EVM IR `storage.map.contains` lowering，通过根为 `keccak256(slot || PROOF_FORGE_MAP_PRESENCE)` 的 ProofForge-managed presence slot 表示 key presence，并用 `EvmMapProbe` 和 `EvmTypedMapProbe` 跑通 golden Yul、solc bytecode、U64/U32/Bool/Hash map 的 Foundry value/presence slot 验证、zero-valued present-key 覆盖、metadata 校验，以及 statement-position 误用的显式诊断。
- 已完成：加入 EVM IR 连续 `mapKey` segment 组成的嵌套 map storage path。value storage 会折叠 Solidity-style mapping slot，最终 key 的 presence 会继续使用 ProofForge-managed presence slot；`EvmMapProbe` 和 `EvmTypedMapProbe` 覆盖 golden Yul、solc bytecode、Foundry 原始 slot 验证、U32 dispatcher guard、metadata 校验，以及混合 map/aggregate storage path 的显式诊断。
- 已完成：加入 EVM IR `U64` 固定 storage array lowering，将其降为连续 storage slot 并带运行时 bounds check，并用 `EvmStorageArrayProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/原始 slot 验证、metadata 能力校验，以及不支持 array element 类型的显式诊断。
- 已完成：加入 EVM IR 单段 `index` storage path read/write/compound assignment，限定在 `U64` 固定 storage array 上，复用带 bounds check 的 array slot helper，并扩展 `EvmStorageArrayProbe` 验证。
- 已完成：泛化 EVM IR word storage，支持 `Bool` scalar storage，以及 `U32`/`Bool`/`Hash` 固定 storage array，继续复用带 bounds check 的 array slot helper，并用 `EvmTypedStorageProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/原始 slot 验证、`U32` calldata range guard、metadata 能力校验、CI 覆盖，以及不支持非 word storage element 的显式诊断。
- 已完成：加入 EVM IR 不可变 local fixed-array value lowering，覆盖 `U64`、`U32`、`Bool` 和 `Hash` 元素、静态 literal index、直接 fixed-array literal indexing，并用 `EvmArrayValueProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时验证、metadata 能力校验，以及静态越界 index 的显式诊断。
- 已完成：扩展 EVM IR local fixed-array lowering 到可变 aggregate local，覆盖静态元素赋值、数字元素复合赋值，以及 `U32`/`Bool`/`Hash` 元素写入，并用 `EvmArrayValueProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时验证、metadata entrypoint 校验、CI 覆盖，以及 immutable 元素赋值的显式诊断。
- 已完成：扩展 EVM IR local fixed-array lowering 到动态 local/literal index：表达式 lowering 会携带 local env，动态读取降为按长度生成的 Yul getter helper，动态 local 元素赋值和数字复合赋值降为 `switch`，并用 `EvmArrayValueProbe` 跑通 golden Yul、metadata entrypoint、solc bytecode、Foundry 动态命中与越界 revert 验证。
- 已完成：加入 EVM IR whole local fixed-array assignment，支持从 local value 和 literal 赋值；lowering 会先把 RHS 元素快照到临时 Yul local 再写回目标元素，并用 `EvmArrayValueProbe` 跑通 golden Yul、metadata entrypoint、solc bytecode、Foundry local-source 与自引用 literal RHS 验证。
- 已完成：扩展 EVM IR local fixed-array lowering 到静态嵌套 scalar array，覆盖不可变 read、可变 leaf 赋值、数字 leaf 复合赋值、嵌套 whole-local assignment，以及 RHS 快照，并用 `EvmArrayValueProbe` 跑通 golden Yul、metadata entrypoint、solc bytecode 和 Foundry 运行时验证。扁平 struct 嵌套 leaf 已由 `EvmStructArrayValueProbe` 覆盖；其他不支持 aggregate leaf 仍保持显式诊断。
- 已完成：扩展 EVM IR local fixed-array lowering 到动态嵌套 scalar array index，覆盖用于 read 的 nested getter helper、用于可变 leaf 赋值和复合赋值的嵌套 `switch` lowering、混合静态/动态 path、运行时越界 revert、`EvmArrayValueProbe` golden Yul、metadata entrypoint、solc bytecode 和 Foundry 运行时验证。
- 已完成：加入 EVM IR 扁平不可变 local struct value lowering，覆盖 `U64`、`U32`、`Bool` 和 `Hash` 字段、直接 struct literal field access，并用 `EvmStructValueProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时验证、metadata 能力校验，以及 whole-struct storage 误用和嵌套字段的显式诊断。
- 已完成：扩展 EVM IR 扁平 local struct lowering 到可变 aggregate local，覆盖静态字段赋值、数字字段复合赋值，以及 `U32`/`Bool`/`Hash` 字段写入，并用 `EvmStructValueProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时验证、metadata entrypoint 校验、CI 覆盖，以及 immutable 字段赋值的显式诊断。
- 已完成：加入 EVM IR whole local struct assignment，支持从 local value 和 literal 赋值；lowering 会先把 RHS 字段快照到临时 Yul local 再写回目标字段，并用 `EvmStructValueProbe` 跑通 golden Yul、metadata entrypoint、solc bytecode、Foundry local-source 与自引用 literal RHS 验证。
- 已完成：加入 EVM IR 扁平 struct local fixed array，按 element field 展开为确定性 Yul local，支持静态和动态 `field(arrayGet(localArray, index), name)` 读取、可变字段赋值、数字字段复合赋值、从 local array 或自引用 array literal 做带 RHS 快照的 whole local assignment、`U64`/`U32`/`Bool`/`Hash` 字段覆盖、动态越界 revert，并用 `EvmStructArrayValueProbe` 跑通 golden Yul、metadata entrypoint/能力校验、solc bytecode、Foundry 运行时验证和 CI 覆盖。
- 已完成：扩展 EVM IR 嵌套 local fixed-array 到扁平 struct leaf，按 nested element field 展开为确定性 Yul local，支持静态/动态嵌套字段读取、嵌套可变字段赋值、数字字段复合赋值、从 local array 或自引用嵌套 array literal 做带 RHS 快照的 whole nested local assignment、动态越界 revert，并用 `EvmStructArrayValueProbe` 跑通 golden Yul、metadata entrypoint、solc bytecode、Foundry 运行时验证和 coverage manifest 更新。
- 已完成：加入 EVM IR 扁平 storage struct lowering，覆盖 scalar storage struct、扁平 struct 固定 storage array、直接 struct field effect、scalar `field` storage path、array `index`+`field` storage path、数字字段复合赋值、带 RHS 快照的 whole scalar storage struct read/write、storage-backed ABI struct return、`Bool`/`U32`/`Hash` 字段，并用 `EvmStorageStructProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/原始 slot 验证、metadata 能力校验、CI 覆盖，以及缺失字段和非扁平 storage struct 的显式诊断。
- 已完成：验证 EVM IR storage-backed aggregate ABI return：扩展 `EvmStorageArrayProbe` 的 `return_values()`，从 storage-array element read 组装 fixed-array return；扩展 `EvmStorageStructProbe` 的 `return_points()`，从扁平 struct 固定 storage array 的字段 read 组装 fixed-array-of-struct return；覆盖 golden Yul、solc bytecode、metadata selector 校验、Foundry ABI 解码和原始 slot 检查。
- 已完成：加入 EVM IR 静态聚合 ABI lowering，覆盖 fixed-array 和 struct 参数/返回、嵌套标量 fixed array，以及元素为扁平 struct 的 fixed array、calldata word flattening、`U32`/`Bool` 聚合 word guard、多 word return-data encoding，并用 `EvmAbiAggregateProbe` 跑通 golden Yul、solc bytecode、Foundry 运行时/malformed calldata 验证、metadata 能力校验、结构化 `abi.entrypoints` selector/calldata/return word-layout 校验、CI 覆盖，以及 Unit、零长度 array、非扁平 struct field 和嵌套 crosscall aggregate array 的显式诊断。
- 已完成：补齐 EVM aggregate ABI 对 `Hash` leaf 的验证缺口。`HashPair(bytes32,bytes32)`、`pick_hash(bytes32[2])` 和 `make_hash_array(bytes32,bytes32)` 现在证明 `Hash`/`bytes32` 字段与 fixed array 能通过 calldata 和 return-data encoding 展开，并覆盖 golden Yul、metadata selector、`solc`、Foundry ABI 解码，以及短 `bytes32[2]` calldata 拒绝。
- 已完成：为 SDK EVM 示例（`Counter`、`ArrayExample`、`SimpleToken`、`ERC20`、`Ownable`、`Pausable` 和 `VerifiedVault`）添加 golden Yul 输出，并让 `scripts/evm/build-examples.sh` 在校验 metadata 前先 diff 生成的 Yul 与这些 fixture。
- 已完成：为 SDK 和 portable IR EVM bytecode build 在当前 `solc --strict-assembly` 流程周围添加 metadata 发射与校验。
- 保留 Foundry 冒烟测试作为成熟的 EVM 冒烟测试。

验收标准：

- `lake build` 通过。
- `scripts/evm/diagnostic-smoke.sh` 通过。
- `scripts/evm/check-ir-coverage-manifest.py` 通过。
- `scripts/evm/build-examples.sh` 在装有 `solc` 的机器上成功。
- `scripts/evm/foundry-smoke.sh` 在装有 Foundry 的机器上成功。
- 生成的元数据指向字节码制品并记录 `target: evm`。

## 工作流 4：Wasm 宿主运行时拆分

目标：使 Wasm 宿主适配器由目标驱动，而不是假设每个 Wasm 合约都是 NEAR。

任务：

- 将链 extern 声明从通用的 EmitZig 运行时 extern 中移出。
- 添加由目标选择的宿主桥接列表。
- 保留 NEAR 桥接作为参考实现。
- 添加带有分配器和 region ABI 的 CosmWasm 桥接骨架。

验收标准：- Wasm 构建可以显式选择 NEAR 或 CosmWasm 桥接。
- 通用 Wasm 运行时不会强制链接 NEAR 宿主函数。
- `wasm-near` 和 `wasm-cosmwasm` 可以具有不同的必需导出。

## 工作流 5: CosmWasm spike

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
- `instantiate`、`execute` 和 `query` 存在于导出中。
- 冒烟测试可以增加并查询计数器状态。

## 工作流 6: Solana sBPF Assembly 工具链集成（Phase 0）

目标：端到端验证 direct-assembly 路线，即一个固定 `.s` 文件可以通过
blueshift-gg/sbpf 工具链生成可加载 ELF。该路线取代旧的 sbpf-linker spike（D-026）。

任务：

- 通过 `cargo install --git https://github.com/blueshift-gg/sbpf.git` 安装 `sbpf`。
- 添加 `--emit-sbpf-asm` CLI 模式，写出固定 `entrypoint.s`（返回成功，不解析账户）。
- 对固定 `.s` 运行 `sbpf build`，验证生成有效 eBPF ELF。
- 验证 `sbpf disassemble` 可以 round-trip 该 ELF。
- 在制品元数据中记录工具链版本。

验收标准：

- [x] `sbpf build` 产生被识别为 `ELF 64-bit LSB ... eBPF` 的 `.so`。
- [x] `sbpf disassemble` 产生与输入匹配的 assembly。
- [x] `--emit-sbpf-asm` 写出无 assembly 错误的有效 `.s`。
- [x] `proof-forge-artifact.json` 记录 `target: "solana-sbpf-asm"`。
- [ ] `sbpf` 通过 `cargo install` 安装到 PATH（当前从源码构建）。

参考：[solana-sbpf-asm 设计文档](targets/solana-sbpf-asm.md),
[RFC 0005](rfcs/0005-solana-sbpf-assembly-backend.md)。

## 工作流 7: Solana sBPF Assembly Counter Codegen（Phase 1）

目标：将 portable IR Counter 模块降级为 sBPF assembly 并通过 `sbpf test`。
这是 assembly 路线的第一个真实 codegen 后端。

任务：

- 实现 `ProofForge.Backend.Solana.StateLayout`：根据 instruction manifest 计算账户字段 offset，并发射 `.equ` 常量。
- 实现 `ProofForge.Backend.Solana.SbpfAsm`：将 `IR.Module` 降为 `.s`：
  - entrypoint adapter：解析序列化账户，根据 instruction discriminant 分派。
  - account validation：根据 manifest 检查 signer、writable、owner。
  - expression lowering：literal、local、add/sub、comparison、cast。
  - statement lowering：letBind、assign、assignOp、ifElse、return、assert。
  - effect lowering：按 account-data offset 读写 storageScalar。
- 添加 `--solana-elf` CLI 模式：发射 `.s` 后调用 `sbpf build`。
- 与 `.s` 一起生成 instruction manifest (`manifest.toml`)。
- 创建 `Examples/Solana/Counter.lean` + manifest。
- 运行 `sbpf test` (Mollusk)，并运行 Surfpool/Web3.js live deployment 冒烟。

验收标准：

- Counter 场景（initialize、increment、get）通过 `sbpf test`。
- Surfpool/Web3.js live smoke 通过（可选，取决于工具是否可用）。
- 能力检查器用清晰诊断拒绝使用不支持能力的 IR 模块，诊断包含 target id 和 capability id。
- 同一个 portable IR Counter 模块可以降级到 EVM 和 Solana。
- 制品元数据记录 `target: "solana-sbpf-asm"`、`irVersion`、entrypoints 和使用的 capabilities。

范围外（Phase 2+）：maps、struct types、events、bounded loops、Borsh serialization、完整 SPL Token 数据布局、完整 live CPI 矩阵覆盖，以及 Rust/Pinocchio 等价性。CPI 和 PDA 仍按 D-027 留在 Solana 特定层：SDK 通过 target capability call 和 sBPF helper action 路由它们，而不是把它们加入 portable IR。

参考：[solana-sbpf-asm 设计文档](targets/solana-sbpf-asm.md) 的 Phased Implementation Plan。

### Phase 1 进度（增量子项）

工作流 7 的 Phase 1 后端（`ProofForge.Backend.Solana.SbpfAsm`）以增量方式落地。每个子项都自带可运行的验证门禁，以便在全部验收标准闭合前可以看到部分进展：

- [x] IR → sBPF AST → text pipeline；entrypoint adapter 按第一条 instruction-data byte 分派（V-GATE-SOLANA-01/02；Phase 0 基线）。
- [x] Counter codegen（literal、local、`add`、标量 storage 读/写/`assignOp`、`letBind`/`letMutBind`、`assign`、`return`）；Mollusk 冒烟覆盖 initialize / increment 0→1 / increment 5→6 / get→return_data（V-GATE-SOLANA-03）。
- [x] 控制流 + 断言覆盖：比较表达式（`.eq`/`.ne`/`.lt`/`.le`/`.gt`/`.ge`），布尔表达式（`.boolAnd`/`.boolOr`/`.boolNot`），语句级 `.ifElse` then/else 降级（使用 fresh 命名 label），以及 `.assert` 和 `.assertEq` 降级到共享的 `assert_fail`（exit 2）/ `assert_eq_fail`（exit 3）label。Fixture：`ProofForge.IR.Examples.ControlFlowAssertProbe`（三个 entrypoint：`lifecycle`、`guarded_increment`、`equality_guard`）；CLI 模式 `--emit-control-ir-sbpf`；确定性发射门禁 `scripts/solana/emit-control-smoke.sh`（不需要 `sbpf`）；Mollusk 运行时门禁 `scripts/solana/control-smoke.sh`（6 项断言：lifecycle x2、guarded_increment 成功 + assert revert、equality_guard 成功 + assertEq revert）（V-GATE-SOLANA-08）。
- [x] instruction manifest（`manifest.toml`）与 `.s` 一起生成。
      `ProofForge.Backend.Solana.SbpfAsm.renderManifest` 按 Phase 1 默认账户约定（writable=true、signer=false、owner=program）输出 target、program 占位 id 和每条 instruction 的 TOML 表。`--emit-counter-ir-sbpf` 与 `--emit-control-ir-sbpf` 在 `.s` 旁生成 `manifest.toml` 并作为 artifact 入元数据。
- [x] `--solana-elf` CLI 模式：发射 `.s`、写 `manifest.toml`、搭建 `sbpf` 项目、调用 `sbpf build`、将产物 `.so` 复制到指定输出，并在 artifact 元数据中记录 `sbpfBuild: passed`。
- [x] account validation：按 manifest 检查 signer / writable / owner。每个 entrypoint 开头注入 prologue，检查账户头 offset 10 的 `is_writable` 并将 offset 48 起的 owner 与序列化 program id 比对。失败出口为 4（`error_not_writable`）、5（`error_signer`）、6（`error_owner`）。Phase 1 Mollusk 运行时门禁关闭 direct-account-mapping ABI，以使用 legacy 嵌入式账户数据布局。
- [x] `Examples/Solana/Counter.lean` + manifest 作为自包含示例。包含跟踪的 `Counter.golden.s`、`Counter.manifest.toml`，以及 CI 可运行的 `scripts/solana/build-examples.sh` 负责发射并做 diff。
- [x] 能力检查器以清晰诊断拒绝不支持的能力/目标组合，诊断含 target id 和 capability id。`Tests/SolanaDiagnostics.lean` 与 `scripts/solana/diagnostic-smoke.sh` 覆盖 8 个 `crosscall.invoke` 家族用例，作为 V-GATE-SOLANA-05 的基础。
- [x] Solana SDK target extension 将 `ProofForge.Solana` 的 PDA/CPI API 路由到 capability plan metadata，生成 `manifest.toml` 的 extension definition 与 entrypoint action section，并在 handler 中、IR body 之前注入 helper call（`sol_pda_derive_<name>`、`sol_cpi_<name>`），同时保存/恢复 Solana input 指针 `r1`。覆盖：`Tests/SolanaSdk.lean`、`Tests/SolanaSdkManifest.lean`、`scripts/solana/sdk-smoke.sh`（可用时执行 `sbpf build`）。
- [x] Surfpool/Web3.js live deployment 冒烟（V-GATE-SOLANA-04）。可选门禁 `scripts/solana/surfpool-web3-smoke.sh` 会构建 Counter ELF、启动 Surfpool、用 Solana CLI 部署、通过 `@solana/web3.js` 创建 program-owned counter account、调用 initialize/increment/get、检查 account data 0→1→2，并验证 `get` return data。该脚本通过 `--solana-sbpf-arch v0` 直接产出兼容 Solana CLI 部署的 ELF，并对 Surfpool 使用 `--use-rpc`。
- [x] `--solana-elf` 暴露 `--solana-sbpf-arch v0|v3`，并在 `proof-forge-artifact.json` 记录选定架构。默认保持 `v3`；Surfpool live deployment 在当前 CLI/runtime 组合完整接受新版 sbpf feature set 之前使用 `v0`。
- [x] PDA helper runtime packing 现在会在调用 `sol_create_program_address` 前生成静态 ASCII seed byte buffer、Solana `Slice { ptr, len }` seed table、动态 program-id 指针计算，以及 32-byte PDA result buffer。覆盖：`Tests/SolanaSdkManifest.lean` 与 `scripts/solana/sdk-smoke.sh`。
- [x] PDA typed seed lowering 现在保留兼容用的 `seeds` 字段，同时增加面向
  target 的 typed descriptor，覆盖 literal/UTF-8 bytes、account pubkey、bump
  seed 和 scalar instruction-data seed。Solana target extension 会消费这些
  descriptor，将 `bump?` 加入 effective syscall seed list，在 manifest/artifact
  metadata 中发射 `typed_seeds`/`typedSeeds`，并在声明 `account?` 时把派生
  PDA pubkey 与对应账户 pubkey 做校验。覆盖：`Tests/SolanaSdk.lean`、
  `Tests/SolanaSdkManifest.lean`、`Tests/SolanaPdaSeeds.lean`、
  `scripts/solana/sdk-smoke.sh`、`scripts/solana/pda-web3-smoke.sh`。
- [x] 标准 Solana protocol SDK helper 现在覆盖 System Program 的 transfer/create-account，以及 SPL Token 的 transfer_checked/mint_to/burn/approve/revoke。它们通过 target capability metadata 路由，写入 `solana.cpi.protocol`、规范化 `data_layout`、account metas、signer seeds 和 instruction-data source name，并进入生成的 manifest 与 artifact JSON。覆盖：`Tests/SolanaSdk.lean`、`Tests/SolanaSdkManifest.lean`、`scripts/solana/sdk-smoke.sh`。
- [x] Runtime allocator target extension 现在建模 Solana 默认 downward-bump allocator（`heap_start = "0x300000000"`、`heap_bytes = 32768`），并提供与 Pinocchio no-heap entrypoint 对齐的 `noAllocator`/deny-dynamic 选项。选中的 allocator 会通过 `runtime.allocator` capability metadata 路由，并进入 `manifest.toml`、`proof-forge-artifact.json` 和 assembly metadata。覆盖：`Tests/SolanaAllocator.lean`、`Tests/SolanaSdk.lean`、`Tests/SolanaSdkManifest.lean`、`scripts/solana/sdk-smoke.sh`。
- [x] Runtime memory target extension 现在将 Solana-only SDK action 通过
  `runtime.memory` capability metadata 路由，并把 entrypoint action 降为基于
  生成 state-account offset 的 `sol_memcpy_`、`sol_memcmp_` 和 `sol_memset_`
  helper。生成的 manifest 与 artifact JSON 会记录
  `[[solana.entrypoint_memory]]` / `memoryActions`；Web3.js 会在
  program-owned account 上验证 copied bytes、compare result 和 fill pattern。
  覆盖：`Tests/SolanaMemory.lean` 与 `scripts/solana/memory-web3-smoke.sh`。
- [x] Return-data 和 compute-budget target extension 现在将 Solana-only SDK
  action 通过 `runtime.return_data` 与 `runtime.compute_units` capability
  metadata 路由。Return-data action 会把 state-backed byte slice 降为
  `sol_set_return_data`，也可以通过 `sol_get_return_data` 读取最近一次 CPI
  的 return-data buffer 与 program id；compute-budget action 会把
  feature-gated `sol_remaining_compute_units` syscall 的结果写入 state，
  profiling action 会降为 `sol_log_compute_units_`。生成的 manifest
  会记录 `[[solana.entrypoint_return_data]]` 与
  `[[solana.entrypoint_compute_units]]`。覆盖：
  `Tests/SolanaReturnDataCompute.lean`。
- [x] 生成的 Solana SDK instruction schema 现在使用 module-wide multi-account account list，取代旧的单账户 manifest。schema 包含 state account、PDA account、CPI account 和 executable CPI program account；sBPF backend 会从同一份 schema 计算 `INSTRUCTION_DATA` offset，并在 prologue 中按 schema 校验 signer/writable 约束和 program-owned account。账户列表会进入 `manifest.toml` 与 `proof-forge-artifact.json`。覆盖：`Tests/SolanaSdkManifest.lean`、`Tests/SolanaCpiPacking.lean`、`scripts/solana/sdk-smoke.sh`。
- [x] System Program transfer/create-account 与 SPL Token CPI instruction-data packing 现在会把标准 instruction bytes 写入 C `SolInstruction` payload。System transfer/create-account 使用 bincode-style `u32` discriminator，加 `u64` lamports/space 和 owner pubkey 字段；SPL Token `transfer_checked`、`mint_to`、`burn`、`approve`、`revoke` 使用标准 token instruction tag 和 amount/decimals layout。value source 可以绑定到生成的 scalar state offset、数字 literal 或已解码的 scalar entrypoint parameter。CPI helper 也会打包 program id bytes、C `SolAccountMeta[]`、绑定到生成的 multi-account input layout 的 `SolAccountInfo[]`、signer seed table，以及 syscall register setup。覆盖：`Tests/SolanaCpiPacking.lean`、`Tests/SolanaSdkManifest.lean`、`scripts/solana/sdk-smoke.sh`。
- [x] System Program transfer CPI 现在具备 Surfpool/Web3.js live 行为门禁。`ProofForge.Solana.Examples.SystemCpi` 会构建生成的 `--solana-system-cpi-elf` fixture；entrypoint 读取 scalar `lamports` instruction parameter，执行 System Program transfer CPI，并把转账数写入 program-owned state account。`scripts/solana/system-cpi-web3-smoke.sh` 会校验 artifact schema，用 Solana CLI 在 Surfpool 部署 ELF，通过 `@solana/web3.js` 调用，并同时检查 recipient lamport delta 和 state data。sBPF lowering 会在 direct account mapping 下从序列化账户布局计算 instruction-data pointer，并保存在 `r9`，避免 internal helper call 跨 callee stack frame 时丢失该指针。覆盖：`just solana-system-cpi-web3` / V-GATE-SOLANA-10。
- [x] System Program `create_account` CPI 现在具备 Surfpool/Web3.js live 行为门禁。`ProofForge.Solana.Examples.SystemCreateAccountCpi` 会构建生成的 `--solana-system-create-account-cpi-elf` fixture；entrypoint 读取 scalar `lamports` 和 `space` instruction parameter，使用 payer 与 new-account signer 执行 System Program `create_account` CPI，创建 program-owned account，并把两个值写入已有 program-owned state account。Web3.js harness 会检查新 account 的 owner、data length、lamports，以及 state account 记录的值。覆盖：`just solana-system-create-account-cpi-web3` / V-GATE-SOLANA-11。
- [x] SPL Token `transfer_checked` CPI 现在具备 Surfpool/Web3.js live 行为门禁。`ProofForge.Solana.Examples.SplTokenTransferCheckedCpi` 会构建生成的 `--solana-spl-token-transfer-cpi-elf` fixture；entrypoint 读取 scalar `amount` instruction parameter，使用 source authority signer 执行 SPL Token `transfer_checked` CPI，并把 amount 写入 program-owned state。Web3.js harness 会通过 `@solana/spl-token` 创建 mint 和 source/destination token accounts，检查 token balance delta 与 state 记录。sBPF lowering 现在会在每个 entry/helper stack frame 里构建 runtime account pointer table，因此可变长度 SPL Token account data 不会让 internal helper call 里的 account offset 失效。覆盖：`just solana-spl-token-transfer-cpi-web3` / V-GATE-SOLANA-12。
- [x] Entry instruction-data decoding 现在把第 0 字节作为 entrypoint tag，从 `instruction_data+1` 起按 packed scalar parameter 解码到 stack local。初始 scalar ABI 支持 `U64`、`U32` 和 `Bool`，在 `manifest.toml`/`proof-forge-artifact.json` 中发射 per-entrypoint parameter schema 和 minimum instruction-data length，对过短 payload 返回 `error_instruction_data`，并把同一组固定 input offset 暴露给 CPI value binding，因此 SPL Token `transfer_checked` 这类 SDK 调用可以从用户 instruction parameter 读取 `amount`，不再落到 placeholder。覆盖：`Tests/SolanaCpiPacking.lean`、`Tests/SolanaSdkManifest.lean` 和 `scripts/solana/sdk-smoke.sh`。

### Solana SDK 补齐路线图

基线：截至 2026-07-02，Solana 路线已经具备 direct sBPF assembly emission、
通过 Surfpool/Web3.js 部署 Counter、SDK capability metadata、生成
manifest/artifact、module-wide multi-account schema、标准 System/SPL Token CPI
data packing、bump-allocator metadata、scalar entrypoint parameter decoding、
typed PDA seed lowering、live System Program transfer/create-account CPI
validation、live SPL Token `transfer_checked` CPI validation，以及 live SPL
Token `mint_to`/`burn`/`approve`/`revoke` CPI validation，加上通过
`sol_log_64_` 验证的 live scalar `events.emit` 日志路径、通过
`sol_log_pubkey` 验证的 live account-pubkey log 路径、通过 `sol_log_data`
验证的 live state-backed data-log 路径，以及 `contextRead checkpointId`
的 live `Clock.slot` sysvar validation，加上通过 `sol_memcpy_`、
`sol_memmove_`、`sol_memcmp_` 和 `sol_memset_` 验证的 live `runtime.memory`
路径，以及通过 `sol_sha256`、`sol_keccak256` 和 feature-gated `sol_blake3`
验证的 Solana-only live `crypto.hash` 路径，以及通过 `sol_get_rent_sysvar`
验证的 live `Rent.lamports_per_byte_year` sysvar 路径，以及通过
`sol_get_epoch_schedule_sysvar` 验证的、当前 RPC 暴露的全部
`EpochSchedule` 字段：`slots_per_epoch`、`leader_schedule_slot_offset`、
`warmup`、`first_normal_epoch` 和 `first_normal_slot`，加上通过
`sol_get_epoch_rewards_sysvar` 验证的 live `EpochRewards` 路径，覆盖
`distribution_starting_block_height`、`num_partitions`、
`parent_blockhash_word0..3`、`total_points_low/high`、`total_rewards`、
`distributed_rewards` 和 `active`，以及通过 `sol_get_sysvar` 和
`SysvarLastRestartS1ot1111111111111111111111` sysvar id 验证的
feature-gated live `LastRestartSlot.last_restart_slot` 路径。Live SDK 覆盖
现在还包括把 `runtime.return_data` 降为 `sol_set_return_data` 与
`sol_get_return_data`，并验证 empty read、set-return simulation 和同一条
instruction 内 set/get roundtrip；同时也包括把 `runtime.compute_units` 降为
feature-gated `sol_remaining_compute_units` state write 和 profiling log
`sol_log_compute_units_`。
下面估算默认一名工程师持续在这个分支推进，当前 direct-assembly 架构保持稳定，并且本地
`sbpf`/Surfpool/Solana CLI 工具链可用。

| 层级 | 预计工作量 | 完成标准 |
|---|---:|---|
| SDK alpha：可写可跑的 Solana 程序 | 3-5 个集中工程日 | 简单程序可以使用 state、PDA seed、scalar instruction parameter、System Program CPI、SPL Token CPI、logs/return data，以及 Web3.js 行为测试，不需要手写 assembly 补丁。 |
| SDK beta：可与参考实现对比的 Solana backend | 2-3 个集中工程周 | ProofForge 输出可以与同一套 account schema 的 Rust/Pinocchio fixture 对比，覆盖关键 syscall，验证 live CPI 行为，并支持 per-entrypoint account schema。 |
| Anchor/Pinocchio 级开发体验 | beta 之后 4-6 个集中工程周 | SDK 提供 account constraint、typed account/data helper、IDL/client generation、更完整 SPL/Token-2022 覆盖，以及接近框架级 workflow 的稳定诊断。 |

已完成的 alpha 切片：

- Instruction ABI hardening：parameter payload length bounds check、
  `manifest.toml` 和 `proof-forge-artifact.json` 中的 per-entrypoint parameter
  schema，以及稳定的 scalar parameter metadata 已经落地。
- PDA typed seed lowering：`literalSeed`/`utf8Seed`、`accountSeed`、
  `bumpSeed` 和 `paramSeed` descriptor 现在会 lowering 为 Solana seed slice，
  `bump?` 会参与 effective seed list，声明的 PDA account 可以与派生 pubkey
  进行校验。
- PDA/Web3.js derivation fixture：`scripts/solana/pda-web3-smoke.sh` 会读取生成的
  SDK Vault `typedSeeds` artifact data，并用 `PublicKey.findProgramAddressSync`
  和 `PublicKey.createProgramAddressSync` 校验 literal/account/bump descriptor
  语义；harness 也覆盖 UTF-8 与 instruction-parameter resolver 行为。
- Live System Program transfer CPI fixture：`scripts/solana/system-cpi-web3-smoke.sh`
  会在 Surfpool 上构建并部署生成的 transfer CPI 程序，通过 Web3.js 调用，并证明
  lamport movement 与 state write 都成立。
- Live System Program create-account CPI fixture：`scripts/solana/system-create-account-cpi-web3-smoke.sh`
  会在 Surfpool 上构建并部署生成的 create-account CPI 程序，通过 Web3.js
  调用，并证明新 account 的 owner/space/lamports 与 state write 都成立。
- Live SPL Token transfer-checked CPI fixture：`scripts/solana/spl-token-transfer-cpi-web3-smoke.sh`
  会在 Surfpool 上构建并部署生成的 transfer_checked CPI 程序，用
  `@solana/spl-token` 创建 SPL Token 测试账户，通过 Web3.js 调用，并证明
  source/destination token balance delta 与 state write 都成立。
- Live SPL Token ops CPI fixture：`scripts/solana/spl-token-ops-cpi-web3-smoke.sh`
  会在 Surfpool 上构建并部署生成的 `mint_to`/`burn`/`approve`/`revoke`
  CPI 程序，校验生成的四 entrypoint artifact schema，用
  `@solana/spl-token` 创建 SPL Token 测试账户，通过 Web3.js 调用全部四个
  entrypoint，并证明 supply/balance/delegate 变化与 state write 都成立。
- Live scalar event、pubkey log 与 data log fixture：`scripts/solana/log-event-web3-smoke.sh`
  会在 Surfpool 上构建并部署生成的 `events.emit` 程序，通过 Web3.js 调用，
  验证生成的 `sol_log_64_` transaction log 包含稳定的 `AmountEvent` tag 与
  scalar `amount` 字段，并证明 program-owned state account 记录了同一个值。同一
  fixture 现在还会校验 Solana-only `logAccountPubkey` metadata，调用生成的
  `log_state_pubkey` entrypoint，并证明 `sol_log_pubkey` 会记录 state account 的
  base58 pubkey。它也会校验 Solana-only `logStateData` metadata，调用
  `log_state_data`，并证明 `sol_log_data` 会为 state-backed `amount` bytes
  产出 base64 `Program data:` payload。
- Live Clock sysvar fixture：`scripts/solana/clock-sysvar-web3-smoke.sh`
  会在 Surfpool 上构建并部署生成的 `contextRead checkpointId` 程序，把它降级到
  `sol_get_clock_sysvar`，通过 Web3.js 调用，并证明记录的 `Clock.slot`
  与观察到的 transaction slot 一致。
- Live memory syscall fixture：`scripts/solana/memory-web3-smoke.sh`
  会在 Surfpool 上构建并部署生成的 `runtime.memory` 程序，通过 Web3.js
  调用，并通过读取 program-owned state 中的 copied value、moved value、
  compare result 和 fill bytes 证明 `sol_memcpy_`、`sol_memmove_`、
  `sol_memcmp_` 与 `sol_memset_` 的效果。
- Return-data/compute-units SDK fixture：
  `Tests/SolanaReturnDataCompute.lean` 会证明 `runtime.return_data` 与
  `runtime.compute_units` 通过 Solana-only capability metadata 路由、在 EVM
  上被拒绝，并且会生成 manifest section 与 sBPF helper call，覆盖
  `sol_set_return_data`、`sol_get_return_data`、feature-gated
  `sol_remaining_compute_units` 和 `sol_log_compute_units_`。
  `scripts/solana/return-data-compute-web3-smoke.sh` 会在 Surfpool 上构建并部署
  生成的 `--solana-return-data-compute-elf` fixture，校验 artifact action
  metadata，验证无数据时的 `sol_get_return_data` 读取，通过 Web3.js simulation
  returnData 确认 `sol_set_return_data`，检查同一条 instruction 内的 set/get
  roundtrip 与 program id words，记录非零 remaining-compute-units value，并确认
  compute-unit log。
- Live SHA-256/Keccak-256/Blake3 syscall fixture：`scripts/solana/crypto-hash-web3-smoke.sh`
  会在 Surfpool 上构建并部署生成的 Solana-only `crypto.hash` 程序，通过
  Web3.js 调用 `set_preimage`、`hash_preimage`、`keccak_preimage` 和
  `blake3_preimage`，并证明 account 中保存的 32-byte digest 与同一
  little-endian preimage 的 Node SHA-256 和 `@noble/hashes`
  Keccak-256/Blake3 reference hash 一致。Blake3 action 会在 manifest 与
  artifact metadata 中标记为 feature-gated。
- Live Rent sysvar fixture：`scripts/solana/rent-sysvar-web3-smoke.sh` 会在
  Surfpool 上构建并部署生成的 Solana-only `sysvar` target-extension 程序，
  通过 Web3.js 调用 `record_rent`，并证明记录的
  `Rent.lamports_per_byte_year` 与 Rent sysvar account data 一致。
- Live EpochSchedule sysvar fixture：
  `scripts/solana/epoch-schedule-sysvar-web3-smoke.sh` 会在 Surfpool 上构建并
  部署生成的 Solana-only `sysvar` target-extension 程序，通过 Web3.js 调用
  `record_epoch_schedule`，并证明记录的 `EpochSchedule.slots_per_epoch`、
  `EpochSchedule.leader_schedule_slot_offset`、`EpochSchedule.warmup`、
  `EpochSchedule.first_normal_epoch` 和 `EpochSchedule.first_normal_slot`
  与 RPC `getEpochSchedule()` 字段一致。
- Live EpochRewards sysvar fixture：
  `scripts/solana/epoch-rewards-sysvar-web3-smoke.sh` 会在 Surfpool 上构建并
  部署生成的 Solana-only `sysvar` target-extension 程序，通过 Web3.js 调用
  `record_epoch_rewards`，并证明 `sol_get_epoch_rewards_sysvar` 会把
  `EpochRewards` 字段记录进 state。`parent_blockhash` 先暴露为四个
  little-endian `u64` word 视图，`total_points` 先暴露为 low/high `u64`
  word 视图，直到 portable scalar 层支持一等宽值输出 state。
- Live LastRestartSlot sysvar fixture：
  `scripts/solana/last-restart-slot-sysvar-web3-smoke.sh` 会在 Surfpool 上构建并
  部署生成的 Solana-only `sysvar` target-extension 程序，通过 Web3.js 调用
  `record_last_restart_slot`，并证明 feature-gated
  `LastRestartSlot.last_restart_slot` 读取会通过 `sol_get_sysvar` lowering，
  且与 LastRestartSlot sysvar account data 一致。该 action 会在 manifest 与
  artifact metadata 中标记为 `feature_gated`。

已完成的 beta scaffolding 切片：

- Pinocchio System transfer reference contract：
  `references/solana/pinocchio/system-transfer` 提供了一个 checked-in
  no-allocator Pinocchio reference，对齐
  `ProofForge.Solana.Examples.SystemCpi` 的 System transfer account schema。
  `scripts/solana/pinocchio-system-transfer-equivalence.sh` 会 emit
  ProofForge System CPI artifact，并将 instruction tag、parameter ABI、
  account order、signer/writable constraint、CPI protocol/data layout 和
  state-write contract 与 reference manifest/source 对比。
- Pinocchio System transfer live-equivalence harness：
  `scripts/solana/pinocchio-system-transfer-live-equivalence.sh` 已接好
  ProofForge ELF 与 checked-in Pinocchio reference ELF 的构建、同一
  Surfpool instance 部署、同一 Web3.js transfer scenario 调用，以及
  recipient lamport delta 和 state write 对比。若 `cargo-build-sbf` 找不到
  Solana rustc/platform-tools，该 harness 会 skip。

剩余优先切片：

1. Rust/Pinocchio equivalence fixture（2-4 天）：在 CI/local 环境稳定安装
   Solana rustc/platform-tools，让 System transfer live-equivalence harness
   通过；然后为 create-account 和 SPL Token account schema 增加对应
   reference program。关键比较点是 account order、signer/writable check、
   CPI instruction data 和可观察 state change。
2. 更丰富的 return data、sysvars、crypto、logs 与 memory helpers（3-5 天）：
   将当前 scalar `sol_log_64_`/`sol_log_data` event 路径扩展到 string log、
   Anchor-style discriminator/Borsh payload 与 indexed event 形态；为 `sol_get_return_data` 增加 CPI return-value 处理与验证、
   `u64` 之外的 typed return payload helper、更多 Clock/Rent 字段、
   generic account-passed sysvar 读取、语义匹配时的 portable `Expr.hash`
   路由，以及复用新 memory syscall 路径的更广 account/data packing helper，
   并与 JavaScript reference 对比。
3. Runtime allocation lowering（1-2 天）：后续 heap-backed SDK structure 通过
   `runtime.allocator` 路由；需要动态分配时生成真实 downward bump-pointer
   allocation code；在 `noAllocator` 下拒绝使用分配的结构。
4. Dynamic per-entrypoint account schema（3-5 天）：用 dispatch 前的 runtime
   account parsing 替换当前 module-wide fixed schema，使 instruction-data offset
   不再依赖所有 entrypoint 使用同一套账户列表。
5. Token-2022 与更丰富的 SPL coverage（每轮 3-5 天）：增加 checked
   mint/burn/approve variants、authority changes、associated-token account
   setup flows，以及 Token-2022 extension routes，同时不把这些细节上移到
   portable IR。
6. Developer ergonomics 和框架层体验（每轮 3-5 天）：增加 account constraint
   helper、typed account wrapper、IDL/client generation、更完整 SPL/Token-2022
   helper 覆盖，以及能把 generated assembly failure 映射回 SDK declaration 的诊断。

最快可信路线是：alpha observability baseline 现在已经落地；下一步先关闭更丰富的
beta syscall 与 return-data 切片，再移除剩余架构捷径，最后补
Anchor/Pinocchio 级别的开发体验。

## 工作流 8: Move 源代码生成 POC（Aptos 优先）

目标：避免将 Move 伪装成另一个 Lean 运行时目标。

任务：

- 定义可移植 IR 的 Move 兼容子集。
- 生成一个 **Aptos** Move 计数器包（Sui 将在单独的分片中跟进）。
- 运行 `aptos move compile/test`。
- 记录必须反馈到 IR 设计中的验证器限制。

验收标准：

- 生成的 Aptos Move 源代码可编译。
- 生成的包具有测试。
- 不支持的 Lean 结构在代码生成前失败。
- 后续的 Sui 对象 POC 被记录为一个单独的里程碑。

## 工作流 9: CI 扩展

有关当前和计划的验证命令，请参见 [validation-gates.md](validation-gates.md)。

目标：在第一天不需要每个外部链工具的情况下保持 CI 的实用性。

任务：

- 将 `lake build` 保留为常驻 CI。
- 仅在 `solc` 和 Foundry 可用时添加 EVM 冒烟测试。
- 为 CosmWasm、Solana 和 Move 添加带有明确工具检查的可选作业。
- 将制品元数据验证添加为独立于工具的作业。

验收标准：

- 基础 CI 不会因为缺少可选链工具而失败。
- 当特定目标的工具链存在但目标构建失败时，相应的 CI 作业会显式报错。
- 元数据架构验证在没有链工具的情况下运行。

## 工作流 10: Psy DPN ZK 目标 spike

目标：验证 ZK 电路源代码生成目标，而不将 ProofForge 与 Psy 编译器内部机制耦合。

任务：

- 已完成：从一个可移植 IR fixture 生成一个 Counter `.psy` 源文件。
- 已完成：在 `scripts/psy/counter-smoke.sh` 中添加一个临时 Dargo 包生成器。
- 已完成：将 `dargo test --file` 记录为第一个本地冒烟测试运行器。
- 已完成：使用 `psyup` v0.1.0 macOS arm64 工具链运行 `dargo compile` 并捕获 DPN 电路 JSON。
- 已完成：运行 `dargo execute` 并断言 Counter、ContextProbe 和 HashProbe 的结果。
- 已完成：调用 `dargo generate-abi` 并捕获非空 ABI JSON。
- 已完成：使用目标 id `psy-dpn` 发射 `proof-forge-artifact.json`。
- 已完成：添加 ContextProbe，用于参数 lowering 和 context reads。
- 已完成：添加 HashProbe，用于 `Hash`、typed hash let-bindings、`hash` 和 `hash_two_to_one`。
- 已完成：校验 Psy 制品元数据，包括 hash、byte size、能力、validation flag 和预期执行结果。
- 已完成：加入来自上游 `psy-compiler/tests` 和 `psy-precompiles` 语料的 map/storage-map、断言、有界循环、数组、结构体、ABI 聚合、嵌套聚合、U32 arithmetic、bitwise、U32/Bool storage，以及 storage path 覆盖。
- 已完成：支持 `storageMapSet` 在表达式位置返回旧 `Hash` 值，并用 MapProbe 覆盖 `set` 和重复 `insert` 的 previous-value 语义。
- 已完成：加入原生 Bool 标量存储覆盖，使用 Psy `pub flag: bool`、原生 bool 读写和 `bool as Felt` 返回转换，并通过 Dargo compile/execute 验证。
- 已完成：加入原生 Bool 固定数组和存储数组覆盖，使用 Psy `[bool; N]` literal/index 与 `pub flags: [bool; N]` 存储，并通过 Dargo compile/execute 验证。
- 已完成：加入原生 Hash 标量存储和存储数组覆盖，使用 Psy `pub root: Hash` 与 `pub roots: [Hash; N]`，并通过 Dargo compile/execute 验证。
- 已完成：加入固定数组 equality 覆盖，使用 Psy `assert_eq`、`==` 和 `!=` 验证 `[Felt; N]` local 数组，并通过 Dargo compile/execute 验证。
- 已完成：加入 Felt-backed U32 存储数组的 storage path 复合赋值 lowering，将其降为显式 read/update/write cast，并通过 Dargo compile/execute 验证。
- 已完成：加入原生 U32 存储结构体字段 path 的写入、读取和复合赋值覆盖，并通过 Dargo compile/execute 验证。
- 已完成：为没有 fixture 专用断言的合法 Psy IR 模块添加通用 generated test fallback，并用 `GenericEntrypointProbe` 跑通 golden、Dargo compile/execute、ABI、deploy manifest 和 artifact metadata 校验。
- 待办：等 Psy 工具链暴露稳定边界后，把 ProofForge deploy manifest 转成上游 compressed genesis deploy JSON，并进一步做本地 node/prover 部署冒烟测试。

验收标准：

- 生成的 `.psy` 源代码是可读的，并已检入黄金 fixture 或快照中。
- `dargo compile` 在安装了 Psy 工具链的机器上生成一个非空的 JSON 制品。
- `dargo execute` 针对 Counter lifecycle 返回 `result_vm: [2]`。
- `dargo execute` 针对 ContextProbe 的 `sum_context(2,3)` 返回 `result_vm: [15]`。
- `dargo execute` 针对 HashProbe 的两个入口返回确定性的四 Felt 输出。
- `dargo execute` 针对非白名单 `GenericEntrypointProbe` 返回 `result_vm: [42]`。
- `dargo generate-abi` 生成非空 ABI JSON 制品。
- 制品元数据记录目标 id、fixture id、使用的能力、制品路径、hash、byte size 和 validation status。
- Psy 冒烟脚本会机器校验制品元数据。
- 制品元数据记录了 Dargo/Psy 编译器版本或 commit。
- 不支持的非电路友好 IR 节点在源代码生成之前失败。

## 工作流 11: Kaspa Toccata Research 目标

目标：判断 ProofForge 是否以及如何支持 Kaspa 的 Toccata 可编程栈，同时避免把它误建模为 EVM、账户状态链或通用 ZK 电路目标。

任务：

- 已完成：为候选 id `kaspa-toccata` 添加文档优先的目标说明。
- 将目标归类为 UTXO covenant / based-app research，而不是 `zk-circuit-sourcegen`。
- 审查 UTXO state、covenant lineage、transaction v1、user lane、compute budget 和 inline proof verification 的候选能力。
- 决定第一版 spike 是生成 Silverscript，还是只围绕手写 covenant source 生成 target manifest。
- 定义一个带 successor-output validation 的极小 L1 covenant Counter-like 场景。
- 定义 covenant source、transaction v1 manifest、covenant lineage manifest 和可选 proof verifier manifest 的最小制品元数据形态。
- 在 L1 covenant 制品形态清楚前，暂缓 based-app 支持。

验收标准：

- `docs/targets/kaspa-toccata.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档区分 inline ZK verification 与 `psy-dpn` 风格的电路源代码生成。

## 工作流 12: Stellar Soroban Research 目标

目标：判断 ProofForge 是否以及如何支持 Stellar smart contracts，同时避免把所有 Wasm 合约链视为同一个目标。

任务：

- 已完成：为候选 id `wasm-stellar-soroban` 添加文档优先的目标说明。
- 将 Soroban 归类为 Wasm-host candidate，而不是通用 Wasm artifact target。
- 决定第一版 spike 是生成 native Rust/Soroban package，还是等待直接 Lean-to-Wasm host bridge。
- 审查 address authorization、contract-account authorization、storage TTL、contract spec metadata 和 Stellar assets 的候选能力。
- 定义一个使用 storage 和 event output 的极小 Counter-like 场景。
- 定义 Wasm、contract spec、deployment manifest、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：`stellar contract build`、sandbox 或 testnet deploy，以及 invoke。

验收标准：

- `docs/targets/stellar-soroban.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 Soroban 与 NEAR、CosmWasm，尽管三者都使用 Wasm 制品。

## 工作流 13: Internet Computer Research 目标

目标：判断 ProofForge 是否以及如何支持 Internet Computer canisters，同时避免把所有 Wasm 制品视为同一种合约目标。

任务：

- 已完成：为候选 id `wasm-icp-canister` 添加文档优先的目标说明。
- 将 ICP canister 归类为 Wasm-host candidate，而不是通用 Wasm artifact target。
- 决定第一版 spike 是生成 native Motoko/Rust CDK package，还是等待直接 Lean-to-Wasm canister bridge。
- 审查 Candid、update/query method modes、stable memory、orthogonal persistence、principals、cycles、async inter-canister calls、canister lifecycle、certified data 和 management canister API 的候选能力。
- 定义一个包含一个 update method 和一个 query method 的极小 Counter-like 场景。
- 定义 Wasm、Candid、canister manifest、stable-state 或 upgrade policy、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：local replica、PocketIC 或 ICP CLI canister install/call flow。

验收标准：

- `docs/targets/internet-computer.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 ICP canister 与 NEAR、CosmWasm、Soroban，尽管它们都使用 Wasm 制品。

## 工作流 14: TON TVM Research 目标

目标：判断 ProofForge 是否以及如何支持 TON smart contracts，同时避免把 TVM 合约误建模为 EVM、Wasm-host、Move 或 ZK 目标。

任务：

- 已完成：为候选 id `ton-tvm` 添加文档优先的目标说明。
- 将 TON 归类为 TVM/Tolk sourcegen candidate。
- 决定第一版 spike 是生成 Tolk source/package artifacts，还是等待更底层的 TVM/cell IR。
- 审查 cells、TL-B metadata、inbound messages、outbound messages、get methods、action lists、`StateInit`、account status、TVM gas 和 jetton/token integration 的候选能力。
- 定义一个包含一个 internal message 和一个 get method 的极小 Counter-like 场景。
- 定义 source、TVM/BOC output、interface metadata、initial state、message/action schema、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：Acton/Tolk compile 和 local test 或 emulator validation。

验收标准：

- `docs/targets/ton-tvm.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 TON TVM 与 Wasm-host、EVM、Move 和 ZK 目标。

## 工作流 15: Bitcoin Cash CashScript Research 目标

目标：判断 ProofForge 是否以及如何支持 Bitcoin Cash smart contracts，同时避免把 UTXO spend paths 误建模为 stateful contract method calls。

任务：

- 已完成：为候选 id `bch-cashscript` 添加文档优先的目标说明。
- 将 BCH/CashScript 归类为 UTXO script/covenant sourcegen candidate。
- 决定第一版 spike 是否先生成 CashScript source/package artifacts，再考虑更底层的 BCH Script 路径。
- 审查 UTXO state、P2SH scripts、unlockers、transaction introspection、covenants、local state、CashTokens、timelocks、signature checks、CashScript artifacts 和 transaction-builder validation 的候选能力。
- 定义一个包含至少一个 contract function 和 transaction-builder smoke 的极小 UTXO spend 场景。
- 定义 `.cash` source、cashc artifact JSON、bytecode、constructor/unlocker manifest、transaction scenario、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：`cashc`、CashScript SDK、`MockNetworkProvider`，以及可选 chipnet/node-backed validation。

验收标准：

- `docs/targets/bitcoin-cash-cashscript.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 BCH/CashScript 与 EVM、Wasm-host、Move、generic Bitcoin 和 Kaspa/Toccata 目标。

## 工作流 16: Algorand AVM Research 目标

目标：判断 ProofForge 是否以及如何支持 Algorand smart contracts，同时避免把 AVM applications 误建模为 EVM、Wasm-host、Move、Solana、TVM、UTXO 或 ZK circuit 目标。

任务：

- 已完成：为候选 id `algorand-avm` 添加文档优先的目标说明。
- 将 Algorand 归类为 AVM/TEAL source 或 package-generation candidate。
- 决定第一版 spike 是否先生成 Algorand Python 或 Algorand TypeScript package artifacts，再考虑 direct TEAL emitter 路径。
- 审查 stateful applications、LogicSig programs、ARC-4 ABI/app specs、global/local/box storage、transaction groups、resource references、inner transactions、Algorand Standard Assets、AVM budget 和 AlgoKit/Puya artifacts 的候选能力。
- 定义一个极小 stateful Counter-like application，包含一个 update method、一个 read/query path、显式 storage schema，以及 localnet 或 simulator-backed validation。
- 定义 source、approval bytecode、clear-state bytecode、可选 LogicSig bytecode、ABI/app spec、storage schema、resource references、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：AlgoKit/Puya compile，加上 LocalNet 或 simulator-backed create/call/query validation。

验收标准：

- `docs/targets/algorand-avm.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 Algorand AVM 与 Wasm-host、EVM、Move、Solana、TVM、UTXO 和 ZK 目标。

## 工作流 17: Cardano Plutus/Aiken Research 目标

目标：判断 ProofForge 是否以及如何支持 Cardano smart contracts，同时避免把 eUTXO validators 误建模为 stateful method-call contracts。

任务：

- 已完成：为候选 id `cardano-plutus-aiken` 添加文档优先的目标说明。
- 将 Cardano 归类为 eUTXO validator sourcegen candidate。
- 决定第一版 spike 是否先生成 Aiken source，再考虑 direct Plutus/UPLC 路径。
- 审查 eUTXO state、validator roles、datum、redeemer、script context、validity ranges、transaction balancing、native tokens、execution units 和 Plutus blueprints 的候选能力。
- 定义一个带 successor-output validation 的极小 Counter-like eUTXO state-machine 场景。
- 定义 Aiken source、UPLC/Plutus validators、blueprint、datum/redeemer schemas、transaction scenario、execution units、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：Aiken compile/test，加上 emulator、SDK-backed transaction 或 cardano-node-backed validation。

验收标准：

- `docs/targets/cardano-plutus-aiken.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 Cardano 与 EVM、Wasm-host、Move、Solana、TVM、AVM、generic Bitcoin、BCH/CashScript 和 Kaspa/Toccata 目标。

## 工作流 18: Tezos Michelson/LIGO Research 目标

目标：判断 ProofForge 是否以及如何支持 Tezos smart contracts，同时避免用 generic contract calls 隐藏 Michelson operation-list semantics。

任务：

- 已完成：为候选 id `tezos-michelson-ligo` 添加文档优先的目标说明。
- 将 Tezos 归类为 Michelson source/artifact target，并以 LIGO 作为第一版 sourcegen 路径。
- 审查 Michelson code、entrypoints、typed Micheline storage、`big_map`、operation lists、views、events、tickets、Sapling、delegation、gas/storage burn 和 LIGO artifacts 的候选能力。
- 定义一个极小 Counter-like contract，包含一个 entrypoint、一个 view、typed storage，以及 local test 或 sandbox validation flow。
- 定义 LIGO source、Michelson output、parameter/storage schema、operation list、view/event manifest、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：LIGO compile/test 加上 Octez sandbox 或等价 Tezos local validation。

验收标准：

- `docs/targets/tezos-michelson-ligo.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 Tezos 与 EVM、Wasm-host、Move、Solana、TVM、AVM、UTXO 和 ZK 目标。

## 工作流 19: Starknet Cairo Research 目标

目标：判断 ProofForge 是否以及如何支持 Starknet smart contracts，同时避免把 Cairo chain contracts 当成 generic ZK circuits。

任务：

- 已完成：为候选 id `starknet-cairo` 添加文档优先的目标说明。
- 将 Starknet 归类为 Cairo/Sierra/CASM sourcegen candidate。
- 审查 Cairo source、Sierra、CASM、class declaration、class hash、Starknet ABI、storage、account abstraction、syscalls、L1/L2 messaging、Starknet fee/resource constraints 和 Starknet Foundry validation 的候选能力。
- 定义一个极小 Counter-like contract，包含 storage、increment external function、read function 和一个 event。
- 定义 Cairo source、Sierra/CASM artifacts、ABI、selector/class-hash metadata、deployment manifest、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：Scarb build 加上 `snforge` 或 devnet-backed tests。

验收标准：

- `docs/targets/starknet-cairo.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 Starknet 与 EVM、Wasm-host、Move、Solana、TVM、AVM、UTXO 和 `psy-dpn` 风格 ZK circuit targets。

## 工作流 22: Aleo Leo Research 目标

目标：判断 ProofForge 是否以及如何支持 Aleo programs，同时避免把 Aleo 仅当成
generic ZK circuit target，或把 Aleo VM 与 Algorand AVM 混淆。

任务：

- 已完成：为候选 id `aleo-leo` 添加文档优先的目标说明。
- 将 Aleo 归类为 ZK application sourcegen candidate，以 Leo 作为第一版 source
  boundary，Aleo Instructions 作为更低层 compiler target，Aleo VM bytecode 作为
  deployable execution artifact。
- 审查 Leo source、Aleo Instructions、Aleo VM、AVM bytecode、ABI、
  prover/verifier artifacts、transitions、finalization、records、mappings、
  storage、public/private inputs and outputs、program imports/upgrades、
  execute/deploy transactions、Credits fees、Leo tests 和 devnet validation 的候选能力。
- 定义一个极小 Counter-like program，包含一个 entry `fn`、一个 public
  `mapping` 和一个 `final { }` block。
- 定义第二个 private-record scenario，consume 一个 encrypted record、create 一个
  successor record，并只在必要时记录 public/finalization effects。
- 定义 Leo source、program id/imports、record/mapping schemas、finalization
  manifest、Aleo Instructions、Aleo VM bytecode、ABI、prover/verifier artifacts、
  execute/deploy transaction metadata、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：`leo build`、`leo test`、可选 `leo test --prove`、
  `leo execute --print`，以及 devnet/devnode-backed deploy 或 execute validation。

验收标准：

- `docs/targets/aleo-leo.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 Aleo 与 `psy-dpn`、Zcash Shielded、Kaspa/Toccata inline ZK、
  Starknet Cairo、Algorand AVM 和 generic source-generation targets。

## 工作流 20: Bitcoin Script/Miniscript Research 目标

目标：判断 ProofForge 是否以及如何支持 Bitcoin base-layer spending policies，同时避免把 Bitcoin Script 误建模为 general smart-contract runtime。

任务：

- 已完成：为候选 id `bitcoin-script-miniscript` 添加文档优先的目标说明。
- 将 Bitcoin 归类为受限 UTXO spending-policy target，通过 Script、Miniscript、descriptors、PSBT 和 Bitcoin Core validation。
- 审查 Bitcoin Script、Miniscript、descriptors、SegWit、Taproot、Tapscript、witness stacks、sighash modes、hash locks、threshold multisig、PSBT flows、standardness、weight/fee constraints 和 Bitcoin Core regtest validation 的候选能力。
- 定义一个极小 spending-policy scenario，例如 “A can spend immediately, or B can spend after a relative timelock”。
- 定义 policy、descriptor、output script、witness requirements、PSBT/raw transaction scenario、weight/fee、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：Bitcoin Core regtest、descriptor import 或 address derivation、PSBT signing/finalization，以及 `testmempoolaccept` 或等价 spend validation。

验收标准：

- `docs/targets/bitcoin-script-miniscript.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 Bitcoin Script/Miniscript 与 EVM、Wasm-host、Move、Solana、TVM、AVM、Cardano eUTXO、BCH/CashScript、Kaspa/Toccata 和 generic smart-contract targets。

## 工作流 21: Zcash Shielded Research 目标

目标：判断 ProofForge 是否以及如何支持 Zcash shielded payments，同时避免把
Zcash 当成 plain Bitcoin Script 或 generic ZK smart-contract chain。

任务：

- 已完成：为候选 id `zcash-shielded` 添加文档优先的目标说明。
- 将 Zcash 归类为 privacy UTXO/ZK payment candidate，包含 transparent
  Zcash flows 和 Sapling/Orchard shielded pools。
- 审查 shielded privacy、transparent pool crossings、Sapling、Orchard、
  shielded notes、note commitments、nullifiers、commitment tree anchors、
  Zcash protocol proofs、private witnesses、value-balance constraints、
  viewing keys、unified addresses、privacy policy 和 zcashd/library validation
  的候选能力。
- 定义一个极小 shielded payment scenario，例如 “spend one Orchard note,
  create one Orchard note, reveal one nullifier, preserve value balance, and
  pay a transparent fee”。
- 定义 JDL-Z11-like 脚本如何表达 `shield`、`spendNote`、`createNote`、
  `revealNullifier`、`selectAnchor` 和 `privacyPolicy`，同时拒绝 global
  mutable shielded storage、method dispatch 和 arbitrary proof verification。
- 定义 transparent inputs/outputs、shielded pool、note input/output schema、
  nullifiers、anchors、value balance、witness/proving requirements、
  viewing-key disclosure、toolchain versions 和 validation result 的制品元数据。
- 确定本地 smoke 命令集：zcashd RPC 或兼容的 Rust wallet/protocol library；
  如果本地 proving 对 CI 太重，则明确记录 fallback blocker。

验收标准：

- `docs/targets/zcash-shielded.md` 记录目标分类和非目标。
- 候选能力保持在文档中，不在审查前加入 `ProofForge.Target.Capability`。
- 第一版 spike 有可重复的本地验证命令，或记录清楚的外部工具 blocker。
- 文档明确区分 Zcash 与 Bitcoin Script/Miniscript、BCH/CashScript、
  Kaspa/Toccata inline ZK、`psy-dpn` circuit sourcegen 和 generic smart
  contracts。

## 工作流 23: Multi-Chain Token SDK

目标：用户只描述一次 fungible token intent，然后由 `--target` 决定是在
EVM 上生成 ERC-20 合约，还是在 Solana 上生成 SPL Token / Token-2022
计划；用户层 SDK 不暴露链专属代码。

任务：

- 已完成：增加 RFC 0006、`ProofForge.Contract.Token.TokenSpec`、target
  token plan，以及 `Tests/TokenSpec.lean`。
- 实现 EVM ERC-20 降级：ABI/selectors、balance/allowance storage、total
  supply、transfer/approve/transferFrom、mint/burn 选项、events，以及
  Foundry/Web3 行为测试。
- 实现 Solana SPL Token plan 渲染：mint 创建、associated token account
  创建、mint_to、transfer_checked、approve、burn、authority 变更，并通过
  `@solana/spl-token` 做 Web3.js 验证。
- 将 transfer fee、non-transferable、confidential transfer、transfer hook
  等 Token-2022 功能路由到 Token-2022 extension 初始化，而不是默认生成
  custom per-token program。
- 为 capped supply 或 custom transfer restriction 等自定义策略增加可选的
  Solana wrapper/authority/transfer-hook program 生成。
- 输出 token-specific artifact metadata，记录 standard、target、operations、
  extension set、deployment accounts、tool versions 和 validation results。

验收标准：

- 同一个 `TokenSpec` 能生成确定性的 EVM 与 Solana token plans。
- EVM 输出通过标准 Web3/Foundry ERC-20 行为测试。
- Solana 输出能在 Surfpool 上创建 mint 和 token accounts、mint 初始供应、
  transfer tokens，并用 `@solana/spl-token` 验证 balances。
- 文档明确说明 Solana 默认不是 per-token SPL 合约，而是通过 plan 和 CPI
  使用 SPL Token / Token-2022 programs。

## 建议顺序

1. 目标注册表（工作流 1）。
2. 可移植 IR + 共享 Counter 场景（工作流 1.5）。
3. EVM 制品元数据和 deploy manifest（工作流 2–3）。
4. Wasm 运行时拆分（工作流 4）。
5. **并行：** CosmWasm spike（工作流 5）和 Solana sBPF assembly 工具链集成（工作流 6，D-026 取代旧 sbpf-linker spike）。
6. Solana sBPF assembly Counter codegen（工作流 7，D-026）。
7. Move Aptos POC（工作流 8）。
8. 一旦 IR fixture 存在，进行 Psy DPN 源代码生成 spike（工作流 10）。
9. 在任何 registry 变更前进行 Kaspa Toccata research target review（工作流 11）。
10. 在任何 registry 变更前进行 Stellar Soroban research target review（工作流 12）。
11. 在任何 registry 变更前进行 Internet Computer research target review（工作流 13）。
12. 在任何 registry 变更前进行 Algorand AVM research target review（工作流 16）。
13. 在任何 registry 变更前进行 Cardano Plutus/Aiken research target review（工作流 17）。
14. 在任何 registry 变更前进行 Tezos Michelson/LIGO research target review（工作流 18）。
15. 在任何 registry 变更前进行 Starknet Cairo research target review（工作流 19）。
16. 在任何 registry 变更前进行 Aleo Leo research target review（工作流 22）。
17. 在任何 registry 变更前进行 TON TVM research target review（工作流 14）。
18. 在任何 registry 变更前进行 Bitcoin Script/Miniscript research target review（工作流 20）。
19. 在任何 registry 变更前进行 Zcash Shielded research target review（工作流 21）。
20. 在任何 registry 变更前进行 Bitcoin Cash CashScript research target review（工作流 15）。
21. EVM 与 Solana 本地验证路径都可运行后，推进 Multi-chain Token SDK（工作流 23）。
22. CI 目标矩阵（工作流 9）。
23. 云平台设计更新（前提条件：两个以上目标处于 Experimental 阶段；参见 [decisions.md](decisions.md)）。
