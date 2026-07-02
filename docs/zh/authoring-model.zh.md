# Authoring Model

ProofForge 不应该要求应用开发者直接编写 `ContractSpec` 对象。
`ContractSpec` 是编译器内部边界：源码语法会降低到它，target routing 会消费它，
后端再从对应 IR 和 target-extension metadata 打印目标制品。

## 层次

当前栈里有三层 authoring layer：

| 层 | 状态 | 作用 |
|---|---|---|
| Learn source | 计划中的独立源码格式 | 用户面对的合约语言。开发者写一份 portable contract logic，然后在构建阶段选择 EVM、Solana、Move 或 Wasm 等 target。 |
| `contract_source` | 已实现的 v1 embedded source syntax | 过渡性的 Lean macro frontend。它让仓库能表达 portable state、entrypoint、event、arithmetic，以及第一批 Solana account/PDA/CPI declaration，而不用手写 `ContractSpec` 字符串。 |
| `ContractSpec` / IR | 编译器内部制品 | 进入 target routing、capability check、backend lowering、AST/printer stage、manifest、IDL、client 和 deployable package 的稳定边界。 |

预期用户体验是 Learn-first。`contract_source` 有价值，是因为它能在当前
Lean/Lake 仓库里直接执行并证明 lowering path；但它不是最终语言 parser。

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

`ProofForge.Contract.Source` 现在覆盖：

- portable scalar state；
- 带 typed parameter 的 entrypoint 和 query；
- local binding、assignment、return、event emission 和 checked arithmetic syntax；
- Solana allocator selection；
- Solana account constraint；
- Solana PDA declaration 和 derivation statement；
- Solana System Program `transfer` 与 `create_account` CPI declaration 和
  invocation statement；
- Solana SPL Token `transfer_checked` CPI declaration 和 invocation statement。

`ProofForge.Contract.Examples.ValueVault` 这样的示例应被理解为 v1 source
example，而不是最终 `.learn` grammar。它们存在的目的，是在 standalone Learn
parser 引入之前，让编译器流水线保持可执行。

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

1. 为 `Examples/Learn/` 下 checked-in 的 `.learn` 示例定义一个小的 source AST，
   而不是只把它们当作文档样例。
2. 将该 AST 降低到现有 `ContractSpec` 边界，并与当前 macro-generated module 做结果对比。
3. 逐步用 typed account、owner、program 和 capability reference 替代带字符串的
   Solana declaration。
4. 保持 backend artifact check 不变，让新的 Learn 语法证明能生成同样的 EVM/Solana package output。
