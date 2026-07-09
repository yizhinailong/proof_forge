# 链无关(chain-agnostic)缺口分析 —— 从现在到"完全不考虑链"还差什么

> 目标:开发者写合约时**完全不碰任何链概念**(NEAR 跨合约、Solana CPI、EVM call、各链 host
> runtime、token 标准……全被抽象掉)。本文按组件层盘点 **已完成 / 部分 / 缺失**,并把缺口分成
> **两堆**:①**机械缺口**(枚举 + 物化 + 诚实拒绝,有现成机器能磨)②**根本性语义冲突**(链之间
> 真的不一致,必须做设计决策,papering 不过去)。**②才是风险所在——Move 当年就是在这些点上分裂的。**
>
> 非权威原生中文分析(见 [README](README.md))。配套:[产品内核 north-star](product-north-star.md)。

## 判断准则:一个概念要么"抽象+物化",要么"诚实拒绝"

"完全链无关"= 每一处链概念泄漏,都必须被:**(a) 抽象成便携词汇 + 各链物化**,或 **(b) 诚实拒绝**
(preflight reject,而不是静默生成错代码)。项目已有这套机器(capability + Preflight + HostRuntime
honesty reject);缺的是把还没抽象的概念灌进去,以及解决几个抽象不了、只能设计取舍的硬骨头。

## 一、核心计算 & 状态 —— 基本 DONE

| 组件 | 状态 | 说明 |
|---|---|---|
| 算术/位运算/比较/布尔/cast/控制流/类型 | ✅ | IR 已覆盖(含 checked overflow node 字段) |
| 存储 scalar / map / array / struct / dynamic | ✅ | capability `storageScalar/Map/Array/…` |
| **可迭代集合**(有序 map、set、分页遍历) | ❌ **缺** | 各链差异极大(EVM 无原生迭代;Solana 账户;NEAR trie);DeFi/NFT 常用 |
| **定点数 / decimals**(fixed-point) | ❌ **缺**(`fixedPoint` 0 文件) | token/DeFi 刚需,没有便携定点数学 |

## 二、你点名的三块

### (A) 跨合约调用 —— PARTIAL,含一个根本性冲突

- **已有**:便携面 `declareRemote` / `remoteCall` / `remoteCallRef`(逻辑 peer,不碰 host 池索引)→
  物化到 EVM call / Solana CPI / NEAR promise;Solana CPI 账户打包、PDA signer seeds、SPL-token
  `initialize_account3/mint` 都真跑通;honesty reject 已制度化。
- **机械缺口**:类型化返回值 decode、多目标返回 ABI 统一。
- **🔴 根本性冲突:同步 vs 异步。** EVM/Solana 是**同步**(同一 tx 内返回);NEAR 是**异步**
  (promise + callback,结果在后续 block)。现在 NEAR 异步是 **opt-in 逃生口**(`nearPromiseThen`),
  **没被抽象**。要真链无关,必须二选一:
  - **(a) 便携面只暴露"同步请求-响应"子集**,底层在 NEAR 上编译成 promise+callback(对"调用并用返回值"
    这类简单场景可行)——**推荐先做这个**;
  - **(b) 暴露一个便携的 async/continuation 模型**(更通用但更难)。
- **🔴 根本性冲突:Solana 必须预先声明账户。** Solana CPI 要求提前知道所有 touched 账户;EVM/NEAR
  不用。要让开发者不传账户,**编译器必须从逻辑里推断账户集**(存储可推断;动态跨调难)。已部分做
  (CPI account packing),但通用推断未完成。

### (B) Host runtime 环境方法 —— PARTIAL,词汇是 EVM 味的(这块你要的 plan 设计)

- **已有**:`ContextField`(15 个:userId/timestamp/epochHeight/chainId/gasPrice/gasLeft/baseFee/
  prevRandao/coinbase/origin/blockHash…)+ `Target/HostRuntime.lean` 统一 catalog(opcode/syscall/
  host-import 一张表,带 n/a honesty reject)。
- **问题**:`ContextField` **是 EVM 味的**——`gasPrice/baseFee/prevRandao/coinbase/origin` 全是 EVM
  概念,不是链无关词汇。
- **建议的 plan 设计(在 `HostRuntime.lean` 上,把 `ContextField` 重表达成便携 `HostEnv`,分三桶):**

  | 桶 | 语义 | 便携词汇 | 各链物化 |
  |---|---|---|---|
  | **1 通用**(每链都有) | 直接映射 | `blockTime` / `blockHeight` / `chainId` / `caller` / `selfAddress` / `attachedValue` | EVM `block.timestamp/number`·`msg.sender`;NEAR `block_timestamp/block_index`·`predecessor`;Solana `Clock.unix_timestamp/slot`·signer |
  | **2 近似**(语义相近、单位/名不同) | 映射 + 语义注记 | `epoch` / `gasOrComputeBudgetLeft` / `blockHash` / `randomness` | EVM `gasleft`↔Solana compute-units↔NEAR prepaid_gas;EVM `prevRandao`↔Solana slot-hash↔NEAR `random_seed` |
  | **3 链专属** | 诚实拒绝 / opt-in 扩展 | `coinbase`·`baseFee`·`tx.origin`(EVM);Solana rent/sysvar;NEAR signer≠predecessor | 缺该概念的链上 **reject**(或像 `Source.Solana` opt-in) |

  即:一个便携 `HostEnv` 枚举 + `materializeEnv : Target → HostEnv → Except Reject Lowering` 表。
  `HostRuntime.lean` 是它的家;`ContextField` 应改写成建在它之上。
- **✅ 已落地(step 1)**:`ProofForge.Target.HostRuntime.HostEnv` + 三桶 +
  `materializeEnv` / `requireHostEnv`。**诚实规则**:只有该 target 已有真实 lower/host
  路径才 `.ok`(例如 NEAR `chainId` / `gasLeft` **拒绝**,不别名 `block_index` / 不发明
  `sol_get_cluster`)。IR `ContextField.toHostEnv` 桥接;测试覆盖 triad 矩阵。
  文档:[host-runtime.md](../host-runtime.md) §8 HostEnv。后续仍缺:便携 Address、
  把 lower 路径强制走 `materializeEnv`、补 Solana timestamp/self 与 NEAR chainId 等 lower。
- **🟠 附带冲突:caller 身份类型不同**——EVM `msg.sender`(20 字节)vs NEAR 命名账户(字符串)vs
  Solana pubkey(32 字节)。需要便携 `Address/Identity` 类型(见三-⑤)。

### (C) Token —— FORMING,需要在"不兼容模型"上做统一接口

- **已有**:`Contract/Token.lean` 有 `TokenStandard` + `TokenFeature`(transferFee/nonTransferable/
  confidentialTransfer/transferHook…);`FungibleToken/FeeToken/RoleGatedToken/SoulboundToken` 示例;
  ERC20/SPL/NEP-141 客户端。但 `Contract/Token/` 目前 EVM 偏重(Evm/EvmSpec/EvmWrap)。
- **🔴 根本性冲突:授权/权限模型不对齐。** ERC20 有 `approve/allowance`;SPL 有 `delegate` + 独立的
  mint/freeze authority + associated token account + (Token-2022) extensions;NEP-141 有 storage
  deposit + `ft_transfer_call`(带回调),**没有 allowance**。统一 token 必须:选一个**公共接口**
  (`transfer/balanceOf/mint/burn`)+ 把分歧部分(allowance/authority/storage-deposit)建模成
  **可选 feature**(`TokenFeature` 是对的起点)+ 各链 materialize/reject。
- **缺失**:decimals/定点(见一);NFT/多 token(ERC721/1155、Metaplex、NEP-171);metadata 标准。

## 三、你问的"还差哪些组件"(其余轴)

| 组件 | 状态 | 缺口 / 冲突 |
|---|---|---|
| ④ 访问控制 / auth | PARTIAL | Ownable/AccessControl/roles 在长;需统一角色模型 + 链原生 auth(signer vs sender vs predecessor)+ 多签 |
| ⑤ **身份 / 地址** | ❌ **缺便携类型** | EVM 20 字节 / Solana 32 字节 pubkey / NEAR 命名账户——**根本不同**;需便携 `Address` 类型 + 校验 + 转换。**阻塞 caller/crosscall/token** |
| ⑥ 升级 / 生命周期 | PARTIAL,EVM 味 | deploy/init 多;但 upgrade/proxy 是 EVM 概念(delegatecall proxy)。**🔴 冲突**:EVM proxy vs Solana program-upgrade-authority vs NEAR 重部署+migrate;需链无关升级 + 状态版本迁移 |
| ⑦ value / 原生币 | PARTIAL | `valueNative` 有;语义不同(msg.value vs lamports vs attached deposit);余额查询、转账 |
| ⑧ crypto | PARTIAL | `cryptoHash` 有;缺签名验证(ecrecover/ed25519)、hash 家族(keccak/sha256/poseidon)各链映射 |
| ⑨ 错误模型 | PARTIAL | assertions/revert/`ErrorCatalog` 有;需便携错误(code/message + 各链如何 surface) |
| ⑩ 序列化 / ABI | FORMING | AbiEncode(EVM)/JsonEncode(NEAR)/Borsh(Solana)在长;需便携 schema 词汇 → 各链编码收口 |
| ⑪ 事件 / 日志 | 基本 DONE | `eventsEmit` 有;indexed/topic 语义各链不同,需注记 |
| ⑫ 时间 / 随机 | PARTIAL | timestamp 有;**随机是冲突**(EVM prevRandao vs Solana slot-hash vs NEAR random_seed vs VRF);多为"不可信随机",需诚实标注 |
| ⑬ 资源计量 / gas | PARTIAL | `computeUnits` 有;gas 模型不同;需便携"资源预算"抽象或诚实忽略 |

## 四、最有用的结论:把缺口分两堆

### 堆 1 —— 机械缺口(纯 plumbing,有现成机器,是"工作量"不是"风险")

大多数 host-env 方法、存储、事件、错误、序列化、crypto hash、部署、gas 计量。**用你已有的
`HostRuntime catalog + capability + Preflight reject` 这台机器,逐个枚举 + 物化 + 诚实拒绝即可。**
这是剩余组件的大头,可并行、可交给 agent 批量磨。

### 堆 2 —— 根本性语义冲突(必须做设计决策,plumbing 绕不过去)

**这五个是愿景成败的关键点(Move 正是在这些点上分裂的):**

1. **同步 vs 异步调用(NEAR)** —— #1 难。定策略:同步子集 only(拒绝异步)还是便携 continuation 模型。
2. **Solana 账户模型** —— 必须预声明账户;编译器要从逻辑推断账户集(已部分)。
3. **地址 / 身份模型** —— 20 字节 / 32 字节 / 命名账户;需便携 `Address` 类型。
4. **Token 授权/权限模型** —— 无公共分母;用 feature flag 建模分歧。
5. **升级模型** —— proxy vs upgrade-authority vs 重部署。

**这五个每一个都不是"多写代码",而是"选一个语义契约,并让不满足的链诚实拒绝"。**

## 五、到"真正完成"的建议路线

1. **✅ 去 EVM 化 host-env 词汇**(`HostEnv` + 三桶 + `materializeEnv` 在 `HostRuntime.lean`;
   `ContextField.toHostEnv` 桥接)——catalog/诚实拒绝已落地;lower 路径逐步强制走表。
2. **便携 `Address/Identity` 类型** —— 解锁 caller / crosscall / token,是多处冲突的公共前置。
3. **跨调:定同步子集策略 + 账户推断** —— 让开发者永不传账户、永不写 promise。
4. **统一 Token 接口 + feature flag** —— 覆盖 ERC20/SPL/NEP-141;补 decimals/定点。
5. **链无关升级 / 生命周期 + 状态迁移**。
6. **用 catalog+reject 机器批量磨机械堆**(crypto / 错误 / 序列化 / 集合 / 事件)。
7. **FV 作诚实性兜底** —— 每个抽象要么"可证物化"要么"诚实拒绝"(你已有的纪律)。

## 六、一句话

> **机械堆是"工作量",有现成机器,可并行磨;真正决定成败的是那 5 个根本性语义冲突(同步/异步、
> Solana 账户、地址、token 授权、升级)——它们要的是设计取舍 + 诚实拒绝,不是多写代码。** 先做
> host-env 去 EVM 化 + 便携 Address 两个高杠杆前置,再逐个啃那 5 个硬骨头,机械堆交给 agent 批量推。
