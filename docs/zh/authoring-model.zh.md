# Authoring Model

ProofForge 不应该要求应用开发者直接编写 `ContractSpec` 对象。
`ContractSpec` 是编译器内部边界：源码语法会降低到它，target routing 会消费它，
后端再从对应 IR 和 target-extension metadata 打印目标制品。

## 层次

当前栈里有三层 authoring layer：

| 层 | 状态 | 作用 |
|---|---|---|
| Learn source | 已实现 v0 standalone parser 与 CLI entrypoint | 用户面对的合约语言。开发者写一份 portable contract logic，然后在构建阶段选择 EVM、Solana、Move 或 Wasm 等 target。 |
| `contract_source` | 已实现的 v1 embedded source syntax | 过渡性的 Lean macro frontend。它让仓库能表达 portable state、entrypoint、event、arithmetic，以及第一批 Solana account/PDA/CPI declaration，而不用手写 `ContractSpec` 字符串。 |
| `ContractSpec` / IR | 编译器内部制品 | 进入 target routing、capability check、backend lowering、AST/printer stage、manifest、IDL、client 和 deployable package 的稳定边界。 |

预期用户体验是 Learn-first。`contract_source` 有价值，是因为它能在当前
Lean/Lake 仓库里直接执行并证明 lowering path；但它不是最终语言 parser。
`proof-forge --learn --target <id>` 现在允许 smoke test 与用户从 `.learn`
源码开始，并在编译阶段选择链后端，而不是从 built-in fixture 或手写
`ContractSpec` 开始。target-specific 的 `--learn-yul`、`--learn-bytecode` 和
`--learn-sbpf` 仍作为较低层的便捷路径保留。
同样的规则也适用于协议 SDK intent：`proof-forge --learn-token --target <id>`
会先解析 Learn 的 `token ... { ... }` declaration，再降低到编译器内部的
`TokenSpec` 边界和 target-specific token plan。

因此，带有较多字符串的 `ContractSpec` 与 Builder 示例应被看作编译器 fixture，
不是产品 surface。它们描述的是源码经过 parsing、capability routing 和
target-extension expansion 后交给编译器消费的同一个程序形状。应用开发者应越来越多
看到 `.learn` 文件里的语言语法；测试则继续保留 Builder fixture 作为已评审的
expected IR。

编译器内部的 source AST 和 IR 边界在 parsing 之后用字符串保存 identifier 是正常的；
这不是 authoring model。产品方向是用户编写 Learn 语法，parser 先检查名称和引用，
然后编译器才把这些名称物化到 `ContractSpec`、manifest、IDL、client 和 backend AST
里。

## 源码原则

- Portable contract 应表达业务逻辑，而不是 target-specific deployment detail。
- Target-specific capability 应通过 typed SDK form 请求，而不是 raw string plumbing。
- Chain dispatch 属于 build configuration 和 target routing。只要某个 target
  能提供等价能力，源码就应该保持可复用。
- Solana account/PDA/CPI declaration 这类 target extension 可以出现在 source
  中，但前提是合约确实需要 chain-native semantics。这些 extension 会降低为
  target metadata 和 helper action；除非多个链家族共享同一语义形态，否则不进入
  portable IR constructor。
- 真实协议字节可以继续使用 literal string，例如 PDA literal seed。account、
  owner、capability name、method 或 deployment configuration 不应该主要靠字符串表达。

## 当前语法边界

`ProofForge.Contract.Learn` 现在会解析 `Examples/Learn/` 下 checked-in 的
`.learn` 示例，生成一个小型 source AST，并将该 AST 降低到 `contract_source`
共用的 `ContractSpec`/portable IR 边界。CLI 可以通过 `--target evm` 把
`.learn` 输入路由到 EVM bytecode metadata，也可以通过
`--target solana-sbpf-asm` 路由到 Solana sBPF assembly package；portable
ValueVault smoke 现在使用 `Examples/Learn/ValueVault.learn` 作为 source of
record。parser 目前覆盖 portable scalar/event 子集，以及第一批 Solana
target-extension form：account、PDA derivation、System Program
transfer/create-account CPI，以及 SPL Token transfer、mint、burn、approve 和
revoke CPI。它也支持带 selector 的 entrypoint，例如
`entry mint selector "04"(amount: u64)`，因此 Solana instruction tag 可以在
Learn 源码中表达，而不是只存在于 Builder fixture。Learn statement 现在也覆盖
Solana pubkey/data log、return-data set/get，以及 remaining-compute-unit read/log
helper。同一 source 层也覆盖 Solana memory helper、SHA-256、Keccak-256、BLAKE3
hash helper，以及 Clock、Rent、EpochSchedule、EpochRewards 和 LastRestartSlot
fixture coverage 所需的 sysvar/context read。
Learn lowering 也会在发射 `ContractSpec` 之前校验已声明的 Solana CPI/PDA
引用、已声明的 CPI account 引用、CPI writable/signer 要求、signer seed，以及 helper
state/account 引用，因此剩余带字符串的 identifier 属于被检查过的编译器数据，而不是未检查的
用户面对 spec plumbing。
`ProofForge.Contract.Token.Learn` 会单独解析
`Examples/Learn/ProofToken.learn` 与 `Examples/Learn/FeeToken.learn` 这样的
Learn token intent source。`--learn-token --target evm` 现在会发射 ERC-20
Yul、bytecode 和 artifact metadata，并使用标准 ERC-20 selector 以及
Transfer/Approval topic；`--learn-token --target solana-sbpf-asm` 会发射 SPL
Token plan，并在 `transfer_fee` 这类功能需要 Token Extensions 时自动切到
Token-2022。
`ProofForge.Contract.Source` 仍是可执行的 embedded syntax layer，覆盖：

- portable scalar state；
- 带 typed parameter 的 entrypoint 和 query；
- local binding、assignment、return、event emission 和 checked arithmetic syntax；
- Solana allocator selection；
- Solana account constraint，包括 writable 和 signer declaration；
- Solana PDA declaration 和 derivation statement；
- Solana System Program `transfer` 与 `create_account` CPI declaration 和
  invocation statement；
- Solana SPL Token `transfer_checked`、`mint_to`、`burn`、`approve` 和
  `revoke` CPI declaration 和 invocation statement；
- Solana log、return-data、compute-unit、memory、crypto 和 sysvar helper
  statement。

`ProofForge.Contract.Examples.ValueVault` 这样的示例应被理解为 v1 source
example，而不是最终 `.learn` grammar。它们存在的目的，是在 standalone Learn
parser 引入之前，让编译器流水线保持可执行。
对应的 `.learn` 文件才是产品语言示例；Lean 文件是经过评审的 embedded fixture，
用于证明 lowering equivalence。

## Target Routing

构建 target 决定 lowering path：

```text
Learn source
  -> source AST
  -> ContractSpec / portable IR
  -> target resolver + capability routing
  -> target semantic AST
  -> printer / assembler / package emitter
```

对 Solana 来说，target extension 会挂接 account schema、PDA seed、CPI layout、
IDL、client 和 sBPF assembly helper。对 EVM 来说，routing 会派生 ABI selector、
Yul、bytecode、ABI metadata 和 deployment file。当合约本身是 portable 时，源码作者
不应该手动切换这些内部实现细节。

## 下一步实现

1. 将 Learn parser 从当前 Vault/System CPI Solana 子集扩展到更丰富的
   Token-2022 setup flow，以及剩余框架级 account/data declaration。
2. 逐步用 typed account、owner、program 和 capability reference 替代带字符串的
   source grammar 中的 Solana declaration，同时只在编译器制品内部保留字符串名称。
3. 随着 Wasm、Move 和其他 target 后端从 routing plan 走到 package emitter，
   继续扩展 `--learn --target <id>` 的发射覆盖。
