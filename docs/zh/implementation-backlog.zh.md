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
  `solana-sbpf-linker`, `solana-zig-fork`, `move-sui`, `move-aptos`,
  `psy-dpn`。
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

## 工作流 6: Solana sBPF-Linker spike

目标：在采用分叉编译器之前验证无分叉的 Solana 流水线。

任务：

- 围绕 `zig build-lib -target bpfel-freestanding -femit-llvm-bc` 添加 `zigc-solana-sbpf` 包装器。
- 调用 `sbpf-linker --cpu v2 --export entrypoint`。
- 添加具有一个导出 `entrypoint` 的 `solana_contract_root.zig`。
- 添加最小的 syscall/log 桥接。
- 添加显式指令清单格式（参见 [solana-sbf.md](targets/solana-sbf.md)）。
- 添加 Counter 账户示例。

验收标准：

- 由原生 Zig 生成一个最小的 `entrypoint.bc`。
- `sbpf-linker` 产生一个 `.so`。
- `.so` 在 Mollusk 或 `solana-test-validator` 中运行。
- 该 spike 记录 Lean Zig 运行时是否可以在 sBPF 约束下链接。

## 工作流 7: Solana 运行时决策

目标：决定 ProofForge 在 Solana 上是可以使用完整的 Lean 运行时，还是需要受限的运行时子集。**在工作流 6 产生 spike 数据后运行。**

问题：

- 完整的 Lean Zig 运行时是否可以在 `bpfel-freestanding` 下链接？
- 生成的 ELF 是否通过 Solana 加载器约束？
- 制品大小是否可以接受？
- 4KB 栈压力是否可控？
- 在 Solana 计算预算内，堆分配和引用计数是否可行？

决策结果：

- 在 Solana 上使用完整的 Lean Zig 运行时。
- 在 Solana 上使用受限的 Lean 运行时子集。
- 为不带完整 Lean 运行时的可移植 IR 子集生成直接的 Zig 代码。
- 回退到 `solana-zig` 分叉，同时保持 `sbpf-linker` 开放。

在 [decisions.md](decisions.md) 中记录结果。

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

## 建议顺序

1. 目标注册表（工作流 1）。
2. 可移植 IR + 共享 Counter 场景（工作流 1.5）。
3. EVM 制品元数据和 deploy manifest（工作流 2–3）。
4. Wasm 运行时拆分（工作流 4）。
5. **并行：** CosmWasm spike（工作流 5）和 Solana sbpf-linker spike（工作流 6）。
6. Solana 运行时决策（工作流 7 —— 在 spike 数据之后）。
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
21. CI 目标矩阵（工作流 9）。
22. 云平台设计更新（前提条件：两个以上目标处于 Experimental 阶段；参见 [decisions.md](decisions.md)）。
