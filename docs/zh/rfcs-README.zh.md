# ProofForge RFCs

RFC 定义了 ProofForge 持久的架构决策。它们在实现前描述预期的能力，并将当前行为与 Research 或未来的后端目标区分开。

流程：提案以 Draft 开始，当记录在 [decisions.md](../decisions.md) 且交叉链接的文档达成一致时转为 **Accepted**。

## 索引

| RFC | 状态 | 摘要 |
|---|---|---|
| [0001](0001-multichain-platform.md) | Accepted | Lean 优先的多链合约平台架构 |
| [0002](0002-target-implementation-design.md) | Accepted | 目标 profile、构建流水线和后端实现设计 |
| [0003](0003-portable-ir-and-runtime.md) | Draft | 可移植 IR、能力降级、运行时 profile |
| [0004](0004-evm-semantic-plan.md) | Draft | EVM semantic plan 与 Yul AST 边界 |
| [0005](0005-solana-sbpf-assembly-backend.md) | Accepted | Solana sBPF assembly 后端，即绕过 Zig runtime 的 direct codegen 路线 |
| [0006](0006-multichain-token-sdk.md) | Draft | 多链 Token SDK：EVM 上生成 ERC-20，Solana 上生成 SPL Token / Token-2022 计划 |

## 相关

- [文档索引](../INDEX.md)
- [设计决策](../decisions.md)
- [实现待办事项](../implementation-backlog.md)
- [目标说明](../targets/README.md)
- [中文文档](../zh/README.md)
